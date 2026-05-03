#!/usr/bin/env python3
from __future__ import annotations

import argparse
import socket
import ssl
from dataclasses import dataclass
from pathlib import Path
from urllib import error, parse, request


DEFAULT_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
DEFAULT_TIMEOUT = 5.0
DEFAULT_OPEN_PORTS = (80, 443)
DEFAULT_CLOSED_PORTS = (5100, 5200, 5001, 6979, 3306, 6379, 9000, 9001)


@dataclass(frozen=True)
class PortCheck:
    name: str
    port: int
    expected_open: bool


@dataclass(frozen=True)
class CheckResult:
    name: str
    ok: bool
    detail: str


def load_env(env_file: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not env_file.exists():
        return values

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def env_int(env: dict[str, str], key: str, fallback: int) -> int:
    value = env.get(key, "").strip()
    if not value:
        return fallback
    try:
        return int(value)
    except ValueError:
        return fallback


def env_float(env: dict[str, str], key: str, fallback: float) -> float:
    value = env.get(key, "").strip()
    if not value:
        return fallback
    try:
        return float(value)
    except ValueError:
        return fallback


def _host_with_optional_port(host: str, port: int) -> str:
    if port == 443:
        return host
    return f"{host}:{port}"


def default_base_url(env: dict[str, str]) -> str:
    value = env.get("TSDD_BASE_URL", "").strip()
    if value:
        return value.rstrip("/")

    host = (
        env.get("PUBLIC_DOMAIN", "").strip()
        or env.get("EXTERNAL_IP", "").strip()
        or "127.0.0.1"
    )
    if host.startswith("http://") or host.startswith("https://"):
        return host.rstrip("/")

    port = env_int(env, "PUBLIC_HTTPS_PORT", 443)
    return f"https://{_host_with_optional_port(host, port)}"


def default_ws_url(env: dict[str, str], base_url: str) -> str:
    value = env.get("PUBLIC_WS_URL", "").strip() or env.get("WK_WS_URL", "").strip()
    if value:
        return value.rstrip("/")

    parsed = parse.urlparse(base_url)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    host = parsed.netloc or parsed.path
    return f"{scheme}://{host}/ws"


def default_target_host(env: dict[str, str], base_url: str) -> str:
    value = env.get("EXTERNAL_IP", "").strip() or env.get("PUBLIC_DOMAIN", "").strip()
    if value:
        return value
    parsed = parse.urlparse(base_url)
    return parsed.hostname or "127.0.0.1"


def can_connect(host: str, port: int, timeout: float) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def evaluate_port_check(check: PortCheck, is_open: bool) -> CheckResult:
    expected = "open" if check.expected_open else "closed"
    actual = "open" if is_open else "closed"
    return CheckResult(
        name=f"tcp:{check.port} {check.name}",
        ok=is_open == check.expected_open,
        detail=f"expected {expected}, observed {actual}",
    )


def parse_http_status(raw_response: bytes) -> int | None:
    line = raw_response.split(b"\r\n", 1)[0].decode("ascii", errors="replace")
    parts = line.split()
    if len(parts) < 2 or not parts[0].startswith("HTTP/"):
        return None
    try:
        return int(parts[1])
    except ValueError:
        return None


def build_websocket_handshake(host: str, path: str, secure: bool) -> bytes:
    authority = host
    if not path.startswith("/"):
        path = f"/{path}"
    origin_scheme = "https" if secure else "http"
    request_text = (
        f"GET {path} HTTP/1.1\r\n"
        f"Host: {authority}\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
        "Sec-WebSocket-Version: 13\r\n"
        f"Origin: {origin_scheme}://{authority}\r\n"
        "\r\n"
    )
    return request_text.encode("ascii")


def fetch_status(url: str, timeout: float, insecure_tls: bool) -> tuple[int | None, str | None]:
    context = None
    if url.startswith("https://") and insecure_tls:
        context = ssl._create_unverified_context()
    req = request.Request(url, method="GET")
    try:
        with request.urlopen(req, timeout=timeout, context=context) as resp:
            resp.read(256)
            return resp.status, None
    except error.HTTPError as exc:
        return exc.code, None
    except (TimeoutError, OSError, error.URLError, ssl.SSLError) as exc:
        return None, str(exc)


def check_http_ping(base_url: str, timeout: float, insecure_tls: bool) -> CheckResult:
    url = f"{base_url.rstrip('/')}/v1/ping"
    status, issue = fetch_status(url, timeout=timeout, insecure_tls=insecure_tls)
    if issue:
        return CheckResult("https api ping", False, f"{url} failed: {issue}")
    return CheckResult(
        "https api ping",
        status == 200,
        f"{url} returned HTTP {status}, expected 200",
    )


def websocket_upgrade_status(ws_url: str, timeout: float, insecure_tls: bool) -> tuple[int | None, str | None]:
    parsed = parse.urlparse(ws_url)
    secure = parsed.scheme == "wss"
    if parsed.scheme not in ("ws", "wss"):
        return None, f"unsupported websocket scheme: {parsed.scheme}"
    if not parsed.hostname:
        return None, f"websocket URL has no host: {ws_url}"

    port = parsed.port or (443 if secure else 80)
    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"
    authority = parsed.netloc

    try:
        with socket.create_connection((parsed.hostname, port), timeout=timeout) as sock:
            sock.settimeout(timeout)
            stream: socket.socket | ssl.SSLSocket = sock
            if secure:
                context = ssl._create_unverified_context() if insecure_tls else ssl.create_default_context()
                stream = context.wrap_socket(sock, server_hostname=parsed.hostname)
            stream.sendall(build_websocket_handshake(authority, path, secure=secure))
            raw = stream.recv(1024)
            return parse_http_status(raw), None
    except (TimeoutError, OSError, ssl.SSLError) as exc:
        return None, str(exc)


def check_websocket(ws_url: str, timeout: float, insecure_tls: bool) -> CheckResult:
    status, issue = websocket_upgrade_status(
        ws_url=ws_url,
        timeout=timeout,
        insecure_tls=insecure_tls,
    )
    if issue:
        return CheckResult("websocket /ws", False, f"{ws_url} failed: {issue}")
    return CheckResult(
        "websocket /ws",
        status == 101,
        f"{ws_url} returned HTTP {status}, expected 101",
    )


def parse_ports(value: str, fallback: tuple[int, ...]) -> tuple[int, ...]:
    if not value.strip():
        return fallback
    ports: list[int] = []
    for chunk in value.split(","):
        item = chunk.strip()
        if not item:
            continue
        ports.append(int(item))
    return tuple(ports)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    pre_parser = argparse.ArgumentParser(add_help=False)
    pre_parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE))
    pre_args, _ = pre_parser.parse_known_args(argv)
    env = load_env(Path(pre_args.env_file))
    base_url = default_base_url(env)

    parser = argparse.ArgumentParser(
        description="Check the production HTTPS/WSS edge and ensure raw IM ports stay closed."
    )
    parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE), help="Path to .env file.")
    parser.add_argument("--base-url", default=base_url, help="Public HTTPS API base URL.")
    parser.add_argument("--ws-url", default=default_ws_url(env, base_url), help="Public websocket URL.")
    parser.add_argument("--host", default=default_target_host(env, base_url), help="Host/IP for TCP port checks.")
    parser.add_argument(
        "--open-ports",
        default=",".join(str(port) for port in DEFAULT_OPEN_PORTS),
        help="Comma-separated TCP ports that must be open.",
    )
    parser.add_argument(
        "--closed-ports",
        default=",".join(str(port) for port in DEFAULT_CLOSED_PORTS),
        help="Comma-separated TCP ports that must be closed or filtered.",
    )
    parser.add_argument(
        "--skip-port-checks",
        action="store_true",
        help="Only check HTTPS ping and websocket upgrade.",
    )
    parser.add_argument(
        "--insecure-tls",
        action="store_true",
        help="Disable TLS certificate verification for HTTPS/WSS checks.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=env_float(env, "EDGE_HEALTH_TIMEOUT", DEFAULT_TIMEOUT),
        help="Per-check timeout in seconds.",
    )
    return parser.parse_args(argv)


def render_result(result: CheckResult) -> str:
    verdict = "PASS" if result.ok else "FAIL"
    return f"[{verdict}] {result.name:<18} {result.detail}"


def run_checks(args: argparse.Namespace) -> list[CheckResult]:
    results: list[CheckResult] = []
    if not args.skip_port_checks:
        for port in parse_ports(args.open_ports, DEFAULT_OPEN_PORTS):
            check = PortCheck(name="public edge", port=port, expected_open=True)
            results.append(evaluate_port_check(check, can_connect(args.host, port, args.timeout)))
        for port in parse_ports(args.closed_ports, DEFAULT_CLOSED_PORTS):
            check = PortCheck(name="internal service", port=port, expected_open=False)
            results.append(evaluate_port_check(check, can_connect(args.host, port, args.timeout)))

    results.append(check_http_ping(args.base_url, timeout=args.timeout, insecure_tls=args.insecure_tls))
    results.append(check_websocket(args.ws_url, timeout=args.timeout, insecure_tls=args.insecure_tls))
    return results


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    results = run_checks(args)
    for result in results:
        print(render_result(result))

    failures = [result for result in results if not result.ok]
    if failures:
        print(f"edge health check failed: {len(failures)}/{len(results)} checks unhealthy")
        return 1

    print(f"edge health check passed: {len(results)}/{len(results)} checks healthy")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
