#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

import edge_health_check


DEFAULT_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
DEFAULT_REQUIRED_SERVICES = (
    "nginx",
    "wukongim",
    "tsdd-api",
    "callgateway",
    "mysql",
    "redis",
    "minio",
)
DEFAULT_LOG_SERVICES = ("nginx", "tsdd-api", "callgateway", "wukongim")
SEVERE_LOG_PATTERN = re.compile(
    r"\b(panic|fatal|traceback|exception|segmentation fault)\b|\b(ERROR|FATAL|PANIC)\b",
    re.IGNORECASE,
)
SEVERE_JSON_LEVELS = {"error", "fatal", "panic"}


@dataclass(frozen=True)
class ServiceStatus:
    service: str
    state: str
    health: str


@dataclass(frozen=True)
class CheckResult:
    name: str
    ok: bool
    detail: str


def parse_compose_ps_json(text: str) -> dict[str, ServiceStatus]:
    stripped = text.strip()
    if not stripped:
        return {}

    rows: list[object]
    if stripped.startswith("["):
        loaded = json.loads(stripped)
        rows = loaded if isinstance(loaded, list) else []
    else:
        rows = [json.loads(line) for line in stripped.splitlines() if line.strip()]

    statuses: dict[str, ServiceStatus] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        service = str(row.get("Service") or row.get("service") or row.get("Name") or "").strip()
        if not service:
            continue
        statuses[service] = ServiceStatus(
            service=service,
            state=str(row.get("State") or row.get("state") or "").strip().lower(),
            health=str(row.get("Health") or row.get("health") or "").strip().lower(),
        )
    return statuses


def evaluate_services(
    statuses: dict[str, ServiceStatus],
    required_services: tuple[str, ...] = DEFAULT_REQUIRED_SERVICES,
) -> CheckResult:
    issues: list[str] = []
    for service in required_services:
        status = statuses.get(service)
        if status is None:
            issues.append(f"{service} missing")
            continue
        if status.state != "running":
            issues.append(f"{service} state={status.state or 'unknown'}")
            continue
        if status.health and status.health != "healthy":
            issues.append(f"{service} health={status.health}")

    if issues:
        return CheckResult("compose services", False, "; ".join(issues))
    return CheckResult(
        "compose services",
        True,
        f"{len(required_services)}/{len(required_services)} required services running",
    )


def scan_log_issues(log_text: str, limit: int = 20) -> list[str]:
    issues: list[str] = []
    for raw_line in log_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        structured_level = _extract_json_log_level(line)
        if structured_level is not None:
            is_severe = structured_level in SEVERE_JSON_LEVELS
        else:
            is_severe = SEVERE_LOG_PATTERN.search(line) is not None
        if is_severe:
            issues.append(line)
            if len(issues) >= limit:
                break
    return issues


def _extract_json_log_level(line: str) -> str | None:
    start = line.find("{")
    if start == -1:
        return None
    try:
        payload = json.loads(line[start:])
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    level = payload.get("level")
    if not isinstance(level, str):
        return None
    return level.strip().lower()


def evaluate_logs(log_text: str) -> CheckResult:
    issues = scan_log_issues(log_text)
    if issues:
        preview = " | ".join(issues[:3])
        return CheckResult("recent severe logs", False, f"{len(issues)} issue line(s): {preview}")
    return CheckResult("recent severe logs", True, "no severe patterns in recent service logs")


def _read_float(payload: dict[str, object], key: str) -> float | None:
    value = payload.get(key)
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def evaluate_perf_payload(
    text: str,
    setting_p95_limit_ms: float,
    favorites_p95_limit_ms: float,
    max_failure_rate: float,
) -> CheckResult:
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        return CheckResult("perf probe", False, f"invalid JSON: {exc}")
    if not isinstance(payload, dict):
        return CheckResult("perf probe", False, "perf probe did not return a JSON object")

    setting_p95 = _read_float(payload, "setting_p95_ms")
    favorites_p95 = _read_float(payload, "favorites_p95_ms")
    failure_rate = _read_float(payload, "failure_rate")
    if setting_p95 is None or favorites_p95 is None:
        return CheckResult("perf probe", False, f"missing p95 fields: {payload!r}")
    if failure_rate is None:
        return CheckResult("perf probe", False, f"missing failure_rate field: {payload!r}")

    issues: list[str] = []
    if setting_p95 > setting_p95_limit_ms:
        issues.append(f"setting_p95_ms={setting_p95} > {setting_p95_limit_ms}")
    if favorites_p95 > favorites_p95_limit_ms:
        issues.append(f"favorites_p95_ms={favorites_p95} > {favorites_p95_limit_ms}")
    if failure_rate > max_failure_rate:
        issues.append(f"failure_rate={failure_rate} > {max_failure_rate}")
    if issues:
        return CheckResult("perf probe", False, "; ".join(issues))

    return CheckResult(
        "perf probe",
        True,
        f"setting_p95_ms={setting_p95}; favorites_p95_ms={favorites_p95}; failure_rate={failure_rate}",
    )


def run_command(args: list[str], cwd: Path, timeout: float) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=str(cwd),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )


def run_compose_ps(env_file: Path, cwd: Path, timeout: float) -> CheckResult:
    proc = run_command(
        ["docker", "compose", "--env-file", str(env_file), "ps", "--format", "json"],
        cwd=cwd,
        timeout=timeout,
    )
    if proc.returncode != 0:
        return CheckResult("compose services", False, proc.stdout.strip() or "docker compose ps failed")
    try:
        statuses = parse_compose_ps_json(proc.stdout)
    except (json.JSONDecodeError, TypeError) as exc:
        return CheckResult("compose services", False, f"could not parse compose JSON: {exc}")
    return evaluate_services(statuses)


def run_recent_log_scan(
    env_file: Path,
    cwd: Path,
    services: tuple[str, ...],
    tail: int,
    since: str,
    timeout: float,
) -> CheckResult:
    log_args = ["docker", "compose", "--env-file", str(env_file), "logs", f"--tail={tail}"]
    if since.strip():
        log_args.append(f"--since={since.strip()}")
    log_args.extend(services)
    proc = run_command(
        log_args,
        cwd=cwd,
        timeout=timeout,
    )
    if proc.returncode != 0:
        return CheckResult("recent severe logs", False, proc.stdout.strip() or "docker compose logs failed")
    return evaluate_logs(proc.stdout)


def run_edge_check(args: argparse.Namespace) -> CheckResult:
    edge_args = edge_health_check.parse_args(
        [
            "--env-file",
            str(args.env_file),
            "--timeout",
            str(args.edge_timeout),
            *(["--insecure-tls"] if args.insecure_tls else []),
        ]
    )
    results = edge_health_check.run_checks(edge_args)
    failures = [result for result in results if not result.ok]
    if failures:
        preview = "; ".join(f"{item.name}: {item.detail}" for item in failures[:3])
        return CheckResult("edge health", False, f"{len(failures)}/{len(results)} failed: {preview}")
    return CheckResult("edge health", True, f"{len(results)}/{len(results)} edge checks healthy")


def run_perf_probe(args: argparse.Namespace, cwd: Path) -> CheckResult:
    proc = run_command(
        [
            sys.executable,
            str(cwd / "scripts" / "perf_probe.py"),
            "--env-file",
            str(args.env_file),
            "--samples",
            str(args.perf_samples),
            "--concurrency",
            str(args.perf_concurrency),
            "--timeout",
            str(args.perf_timeout),
            "--max-failure-rate",
            str(args.max_failure_rate),
        ],
        cwd=cwd,
        timeout=max(
            args.perf_timeout
            * (((args.perf_samples * 2) // max(1, args.perf_concurrency)) + 4),
            30.0,
        ),
    )
    if proc.returncode != 0:
        text = proc.stdout.strip()
        if text.startswith("{"):
            return evaluate_perf_payload(
                text,
                setting_p95_limit_ms=args.setting_p95_limit_ms,
                favorites_p95_limit_ms=args.favorites_p95_limit_ms,
                max_failure_rate=args.max_failure_rate,
            )
        return CheckResult("perf probe", False, text or "perf probe failed")
    return evaluate_perf_payload(
        proc.stdout.strip(),
        setting_p95_limit_ms=args.setting_p95_limit_ms,
        favorites_p95_limit_ms=args.favorites_p95_limit_ms,
        max_failure_rate=args.max_failure_rate,
    )


def run_mysql_health_check(args: argparse.Namespace, cwd: Path) -> CheckResult:
    proc = run_command(
        [
            sys.executable,
            str(cwd / "scripts" / "mysql_health_check.py"),
            "--env-file",
            str(args.env_file),
            "--max-long-query-time",
            str(args.mysql_max_long_query_time),
            "--timeout",
            str(args.mysql_timeout),
        ],
        cwd=cwd,
        timeout=max(args.mysql_timeout * 3, 30.0),
    )
    text = proc.stdout.strip()
    if proc.returncode != 0:
        return CheckResult("mysql health", False, text or "mysql health check failed")
    return CheckResult("mysql health", True, text.splitlines()[-1] if text else "mysql health check passed")


def parse_csv(value: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in value.split(",") if item.strip())


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run production post-deploy diagnostics for compose, logs, edge health, and API latency."
    )
    parser.add_argument("--env-file", type=Path, default=DEFAULT_ENV_FILE, help="Path to .env file.")
    parser.add_argument("--compose-timeout", type=float, default=20.0, help="docker compose command timeout.")
    parser.add_argument("--log-tail", type=int, default=120, help="Recent log lines per service to inspect.")
    parser.add_argument("--log-since", default="30m", help="docker compose logs --since window.")
    parser.add_argument(
        "--log-services",
        default=",".join(DEFAULT_LOG_SERVICES),
        help="Comma-separated services for recent severe log scanning.",
    )
    parser.add_argument("--skip-edge", action="store_true", help="Skip edge_health_check.")
    parser.add_argument("--edge-timeout", type=float, default=5.0, help="Per edge health check timeout.")
    parser.add_argument("--insecure-tls", action="store_true", help="Disable TLS verification for edge checks.")
    parser.add_argument("--skip-perf", action="store_true", help="Skip perf_probe.")
    parser.add_argument("--perf-samples", type=int, default=10, help="Samples per endpoint for perf_probe.")
    parser.add_argument("--perf-concurrency", type=int, default=2, help="Concurrent request workers for perf_probe.")
    parser.add_argument("--perf-timeout", type=float, default=20.0, help="Per-request perf timeout.")
    parser.add_argument("--setting-p95-limit-ms", type=float, default=250.0, help="setting p95 latency limit.")
    parser.add_argument("--favorites-p95-limit-ms", type=float, default=250.0, help="favorites p95 latency limit.")
    parser.add_argument("--max-failure-rate", type=float, default=0.0, help="Maximum allowed perf request failure ratio.")
    parser.add_argument("--skip-mysql", action="store_true", help="Skip MySQL slow-query/index health checks.")
    parser.add_argument("--mysql-timeout", type=float, default=20.0, help="Per MySQL health command timeout.")
    parser.add_argument(
        "--mysql-max-long-query-time",
        type=float,
        default=0.5,
        help="Maximum allowed MySQL long_query_time in seconds.",
    )
    return parser.parse_args(argv)


def render_result(result: CheckResult) -> str:
    verdict = "PASS" if result.ok else "FAIL"
    return f"[{verdict}] {result.name:<20} {result.detail}"


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    cwd = Path(__file__).resolve().parent.parent
    results = [
        run_compose_ps(args.env_file, cwd=cwd, timeout=args.compose_timeout),
        run_recent_log_scan(
            args.env_file,
            cwd=cwd,
            services=parse_csv(args.log_services),
            tail=args.log_tail,
            since=args.log_since,
            timeout=args.compose_timeout,
        ),
    ]
    if not args.skip_edge:
        results.append(run_edge_check(args))
    if not args.skip_mysql:
        results.append(run_mysql_health_check(args, cwd=cwd))
    if not args.skip_perf:
        results.append(run_perf_probe(args, cwd=cwd))

    for result in results:
        print(render_result(result))

    failures = [result for result in results if not result.ok]
    if failures:
        print(f"production doctor failed: {len(failures)}/{len(results)} checks unhealthy")
        return 1

    print(f"production doctor passed: {len(results)}/{len(results)} checks healthy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
