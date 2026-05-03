#!/usr/bin/env python3
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import random
import re
import statistics
import string
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from urllib import error, request
from urllib.parse import urlparse, urlunparse

DEFAULT_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
DEFAULT_APP_ID = "wukongchat"
DEFAULT_APP_KEY = "<app-signing-secret>"
SENSITIVE_KEY_RE = re.compile(r"(token|password|passwd|pwd|secret|key|authorization|sign)", re.IGNORECASE)
HIGH_ENTROPY_VALUE_RE = re.compile(r"(?=[A-Za-z0-9_./+=:-]{32,})(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9_./+=:-]+")
REDACTION = "<redacted>"
ENDPOINT_PATHS = {
    "setting": "/v1/extra/user/setting",
    "favorites": "/v1/extra/favorites?page=1&page_size=10",
}


class ProbeFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class CollectedSamples:
    samples_by_endpoint: dict[str, list[float]]
    failure_count: int
    failures: list[str]


def load_env(env_file: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not env_file.exists():
        return values

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def env_int(env: dict[str, str], key: str, fallback: int) -> int:
    value = env.get(key, "").strip()
    if not value:
        return fallback
    try:
        return int(value)
    except ValueError:
        return fallback


def default_base_url(env: dict[str, str]) -> str:
    if env.get("TSDD_BASE_URL"):
        return env["TSDD_BASE_URL"].rstrip("/")

    host = env.get("EXTERNAL_IP", "127.0.0.1").strip() or "127.0.0.1"
    port = env_int(env, "PUBLIC_HTTP_PORT", 80)
    if port == 80:
        return f"http://{host}"
    if port == 443:
        return f"https://{host}"
    return f"http://{host}:{port}"


def explain_http_base_url(base_url: str) -> str:
    parsed = urlparse(base_url)
    https_url = urlunparse(("https", parsed.netloc, parsed.path.rstrip("/"), "", "", ""))
    return (
        f"Production release probes must use HTTPS. Refusing HTTP base URL: {base_url}. "
        f"Use HTTPS instead: {https_url}"
    )


def _is_loopback_host(hostname: str | None) -> bool:
    return (hostname or "").lower() in {"127.0.0.1", "localhost", "::1"}


def validate_base_url(base_url: str, *, allow_http: bool = False) -> str:
    parsed = urlparse(base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"Invalid --base-url: {base_url}")
    if parsed.query or parsed.fragment:
        raise ValueError(
            f"Invalid --base-url: query/fragment are not allowed: {base_url}"
        )

    normalized = urlunparse((parsed.scheme, parsed.netloc, parsed.path.rstrip("/"), "", "", ""))
    if parsed.scheme == "http" and not allow_http:
        raise ValueError(explain_http_base_url(normalized))
    if parsed.scheme == "http" and allow_http and not _is_loopback_host(parsed.hostname):
        raise ValueError(explain_http_base_url(normalized))
    return normalized


def nonce(length: int = 16) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(random.choice(alphabet) for _ in range(length))


def encode_for_sign(payload: object | None) -> str:
    if payload is None:
        return ""
    if isinstance(payload, str):
        return payload
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=False)


def redact_sensitive(value: object, *, parent_key: str = "") -> object:
    if SENSITIVE_KEY_RE.search(parent_key):
        return REDACTION
    if isinstance(value, dict):
        return {
            str(key): redact_sensitive(item, parent_key=str(key))
            for key, item in value.items()
        }
    if isinstance(value, list):
        return [redact_sensitive(item, parent_key=parent_key) for item in value]
    if isinstance(value, tuple):
        return [redact_sensitive(item, parent_key=parent_key) for item in value]
    if isinstance(value, str):
        return HIGH_ENTROPY_VALUE_RE.sub(REDACTION, value)
    return value


def redact_text(text: str) -> str:
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        json_start = text.find("{")
        if json_start != -1:
            try:
                parsed = json.loads(text[json_start:])
            except json.JSONDecodeError:
                pass
            else:
                return (
                    text[:json_start]
                    + json.dumps(redact_sensitive(parsed), separators=(",", ":"), ensure_ascii=False)
                )
        redacted = re.sub(
            r"(?i)([\"']?(?:token|password|passwd|pwd|secret|key|authorization|sign)[\"']?)(\s*[=:]\s*[\"']?)([^\"'\s,;&}]+)",
            rf"\1\2{REDACTION}",
            text,
        )
        return HIGH_ENTROPY_VALUE_RE.sub(REDACTION, redacted)
    return json.dumps(redact_sensitive(parsed), separators=(",", ":"), ensure_ascii=False)


def describe_response_shape(payload: object) -> str:
    if isinstance(payload, dict):
        keys = sorted(str(key) for key in payload.keys())
        parts = [f"object keys={keys}"]
        data = payload.get("data")
        if isinstance(data, dict):
            parts.append(f"data keys={sorted(str(key) for key in data.keys())}")
        elif data is not None:
            parts.append(f"data type={type(data).__name__}")
        return "; ".join(parts)
    if isinstance(payload, list):
        return f"list length={len(payload)}"
    return f"type={type(payload).__name__}"


def build_headers(
    app_id: str,
    app_key: str,
    payload: object | None,
    token: str | None,
    device_id: str,
    device_session_id: str,
) -> dict[str, str]:
    timestamp = str(int(time.time() * 1000))
    nonce_value = nonce()
    encoded = encode_for_sign(payload)
    sign_source = f"{encoded}{nonce_value}{timestamp}{app_key}"
    sign = hashlib.md5(sign_source.encode("utf-8")).hexdigest()

    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "appid": app_id,
        "timestamp": timestamp,
        "noncestr": nonce_value,
        "sign": sign,
        "X-Device-ID": device_id,
        "X-Device-Session-ID": device_session_id,
    }
    if token:
        headers["token"] = token
    return headers


def extract_required_field(payload: object, field: str) -> str:
    if isinstance(payload, dict):
        value = payload.get(field)
        if isinstance(value, str) and value:
            return value
        if isinstance(value, int):
            return str(value)

        data = payload.get("data")
        if isinstance(data, dict):
            return extract_required_field(data, field)

    raise RuntimeError(
        f"Response did not contain required field '{field}'; response shape: {describe_response_shape(payload)}"
    )


def request_json(
    base_url: str,
    method: str,
    path: str,
    app_id: str,
    app_key: str,
    device_id: str,
    device_session_id: str,
    payload: object | None = None,
    token: str | None = None,
    timeout: float = 20.0,
) -> object:
    url = f"{base_url.rstrip('/')}{path}"
    body = None
    if payload is not None:
        body = encode_for_sign(payload).encode("utf-8")

    headers = build_headers(
        app_id=app_id,
        app_key=app_key,
        payload=payload,
        token=token,
        device_id=device_id,
        device_session_id=device_session_id,
    )
    req = request.Request(url=url, data=body, headers=headers, method=method.upper())

    try:
        with request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
    except error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        if exc.code == 308:
            location = exc.headers.get("Location", "")
            raise RuntimeError(
                f"{method.upper()} {path} received HTTP 308 redirect to {redact_text(location)}. "
                f"Use an HTTPS --base-url such as https://infoequity.qingyunshe.top."
            ) from exc
        raise RuntimeError(
            f"{method.upper()} {path} failed with HTTP {exc.code}: {redact_text(raw)}"
        ) from exc
    except error.URLError as exc:
        raise RuntimeError(f"{method.upper()} {path} failed: {redact_text(str(exc))}") from exc

    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise RuntimeError(
            f"{method.upper()} {path} returned non-JSON body: {redact_text(raw)}"
        ) from exc


def timed_get(
    base_url: str,
    path: str,
    app_id: str,
    app_key: str,
    device_id: str,
    device_session_id: str,
    token: str,
    timeout: float,
) -> float:
    started = time.perf_counter()
    request_json(
        base_url=base_url,
        method="GET",
        path=path,
        app_id=app_id,
        app_key=app_key,
        device_id=device_id,
        device_session_id=device_session_id,
        token=token,
        timeout=timeout,
    )
    return (time.perf_counter() - started) * 1000.0


def percentile(values: list[float], p: float) -> float:
    ordered = sorted(values)
    index = int((len(ordered) - 1) * p)
    return ordered[index]


def _metric_summary(samples: list[float], prefix: str) -> dict[str, float | int | None]:
    if not samples:
        return {
            f"{prefix}_count": 0,
            f"{prefix}_avg_ms": None,
            f"{prefix}_p95_ms": None,
            f"{prefix}_max_ms": None,
        }
    return {
        f"{prefix}_count": len(samples),
        f"{prefix}_avg_ms": round(statistics.mean(samples), 2),
        f"{prefix}_p95_ms": round(percentile(samples, 0.95), 2),
        f"{prefix}_max_ms": round(max(samples), 2),
    }


def summarize_probe_result(
    setting_samples: list[float],
    favorite_samples: list[float],
    failure_count: int,
) -> dict[str, float | int | None]:
    request_count = len(setting_samples) + len(favorite_samples) + failure_count
    result: dict[str, float | int | None] = {}
    result.update(_metric_summary(setting_samples, "setting"))
    result.update(_metric_summary(favorite_samples, "favorites"))
    result["request_count"] = request_count
    result["failure_count"] = failure_count
    result["failure_rate"] = 0.0 if request_count == 0 else failure_count / request_count
    return result


def evaluate_thresholds(
    payload: dict[str, float | int | None],
    setting_p95_limit_ms: float | None,
    favorites_p95_limit_ms: float | None,
    max_failure_rate: float | None,
) -> list[str]:
    issues: list[str] = []
    setting_p95 = payload.get("setting_p95_ms")
    favorites_p95 = payload.get("favorites_p95_ms")
    failure_rate = payload.get("failure_rate")

    if (
        setting_p95_limit_ms is not None
        and isinstance(setting_p95, (int, float))
        and float(setting_p95) > setting_p95_limit_ms
    ):
        issues.append(f"setting_p95_ms={float(setting_p95)} > {setting_p95_limit_ms}")
    if (
        favorites_p95_limit_ms is not None
        and isinstance(favorites_p95, (int, float))
        and float(favorites_p95) > favorites_p95_limit_ms
    ):
        issues.append(
            f"favorites_p95_ms={float(favorites_p95)} > {favorites_p95_limit_ms}"
        )
    if (
        max_failure_rate is not None
        and isinstance(failure_rate, (int, float))
        and float(failure_rate) > max_failure_rate
    ):
        issues.append(f"failure_rate={float(failure_rate)} > {max_failure_rate}")
    return issues


def collect_samples(
    endpoints: tuple[str, ...],
    sample_count: int,
    concurrency: int,
    request_once,
) -> CollectedSamples:
    effective_sample_count = max(1, sample_count)
    effective_concurrency = max(1, concurrency)
    samples_by_endpoint = {endpoint: [] for endpoint in endpoints}
    failures: list[str] = []
    jobs = [endpoint for endpoint in endpoints for _ in range(effective_sample_count)]

    def execute(endpoint: str) -> tuple[str, float | None, str | None]:
        try:
            return endpoint, float(request_once(endpoint)), None
        except Exception as exc:
            return endpoint, None, f"{endpoint}: {redact_text(str(exc))}"

    if effective_concurrency == 1:
        results = [execute(endpoint) for endpoint in jobs]
    else:
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=min(effective_concurrency, len(jobs))
        ) as executor:
            results = list(executor.map(execute, jobs))

    for endpoint, duration_ms, failure in results:
        if failure is not None:
            failures.append(failure)
            continue
        assert duration_ms is not None
        samples_by_endpoint[endpoint].append(duration_ms)

    return CollectedSamples(
        samples_by_endpoint=samples_by_endpoint,
        failure_count=len(failures),
        failures=failures,
    )


def parse_args() -> argparse.Namespace:
    pre_parser = argparse.ArgumentParser(add_help=False)
    pre_parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE))
    pre_args, _ = pre_parser.parse_known_args()
    env = load_env(Path(pre_args.env_file))

    parser = argparse.ArgumentParser(
        description="Probe extra setting and favorites latency through a registered temporary user."
    )
    parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE), help="Path to .env file.")
    parser.add_argument("--base-url", default=default_base_url(env), help="Public API base URL.")
    parser.add_argument(
        "--allow-http-base-url",
        action="store_true",
        help="Allow HTTP only for explicit loopback diagnostics; production release probes should use HTTPS.",
    )
    parser.add_argument("--app-id", default=DEFAULT_APP_ID, help="appid header value.")
    parser.add_argument("--app-key", default=DEFAULT_APP_KEY, help="App signing secret.")
    parser.add_argument("--password", default="PerfPass123", help="Password used for the temporary account.")
    parser.add_argument("--device-id", default="codex-perf-device", help="Device identifier header and payload value.")
    parser.add_argument("--device-session-id", default="codex-perf-session", help="Device session identifier header.")
    parser.add_argument("--device-name", default="Codex Perf", help="Device name in registration payload.")
    parser.add_argument("--device-model", default="Desktop", help="Device model in registration payload.")
    parser.add_argument("--username-prefix", default="codex_perf", help="Prefix for the temporary username.")
    parser.add_argument("--samples", type=int, default=20, help="Number of samples per endpoint.")
    parser.add_argument("--concurrency", type=int, default=1, help="Concurrent request workers.")
    parser.add_argument("--timeout", type=float, default=20.0, help="Per-request timeout in seconds.")
    parser.add_argument("--setting-p95-limit-ms", type=float, default=None, help="Optional setting p95 latency gate.")
    parser.add_argument("--favorites-p95-limit-ms", type=float, default=None, help="Optional favorites p95 latency gate.")
    parser.add_argument("--max-failure-rate", type=float, default=0.0, help="Maximum allowed failed request ratio.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        args.base_url = validate_base_url(
            args.base_url,
            allow_http=args.allow_http_base_url,
        )
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(2) from None
    timestamp = int(time.time())
    username = f"{args.username_prefix}_{timestamp}"

    register_payload = {
        "username": username,
        "password": args.password,
        "device": {
            "device_id": args.device_id,
            "device_name": args.device_name,
            "device_model": args.device_model,
        },
    }

    register_response = request_json(
        base_url=args.base_url,
        method="POST",
        path="/v1/user/usernameregister",
        app_id=args.app_id,
        app_key=args.app_key,
        device_id=args.device_id,
        device_session_id=args.device_session_id,
        payload=register_payload,
        timeout=args.timeout,
    )

    token = extract_required_field(register_response, "token")

    def request_once(endpoint: str) -> float:
        path = ENDPOINT_PATHS[endpoint]
        return timed_get(
            base_url=args.base_url,
            path=path,
            app_id=args.app_id,
            app_key=args.app_key,
            device_id=args.device_id,
            device_session_id=args.device_session_id,
            token=token,
            timeout=args.timeout,
        )

    collected = collect_samples(
        endpoints=("setting", "favorites"),
        sample_count=args.samples,
        concurrency=args.concurrency,
        request_once=request_once,
    )
    result = summarize_probe_result(
        setting_samples=collected.samples_by_endpoint["setting"],
        favorite_samples=collected.samples_by_endpoint["favorites"],
        failure_count=collected.failure_count,
    )
    result["concurrency"] = max(1, args.concurrency)
    if collected.failures:
        result["failures"] = collected.failures[:10]
    threshold_issues = evaluate_thresholds(
        result,
        setting_p95_limit_ms=args.setting_p95_limit_ms,
        favorites_p95_limit_ms=args.favorites_p95_limit_ms,
        max_failure_rate=args.max_failure_rate,
    )
    if threshold_issues:
        result["threshold_issues"] = threshold_issues
    print(json.dumps(result, ensure_ascii=False))
    return 1 if threshold_issues else 0


if __name__ == "__main__":
    raise SystemExit(main())
