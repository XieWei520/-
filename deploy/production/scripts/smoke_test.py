#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import string
import sys
import time
from pathlib import Path
from urllib import error, parse, request
from urllib.parse import urlparse, urlunparse

DEFAULT_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"
DEFAULT_APP_ID = "wukongchat"
DEFAULT_APP_KEY = "<app-signing-secret>"
SENSITIVE_NAME_PATTERN = r"password|passwd|pass|pwd|secret|token|key|credential|authorization|sign|dsn"
SENSITIVE_KEY_RE = re.compile(SENSITIVE_NAME_PATTERN, re.IGNORECASE)
SENSITIVE_FIELD_RE = re.compile(
    r"(?P<field>[\"']?[A-Za-z0-9_.-]*(?:%s)[A-Za-z0-9_.-]*[\"']?)"
    r"(?P<assignment>\s*[=:]\s*)"
    r"(?:(?P<quote>[\"'])(?P<quoted_value>[^\r\n]*?)(?P=quote)|(?P<unquoted_value>[^\r\n,;&}]*?))"
    r"(?=(?:[,;&}]|\s+[A-Za-z0-9_.-]+\s*[=:]|$))"
    % SENSITIVE_NAME_PATTERN,
    re.IGNORECASE | re.MULTILINE,
)
HIGH_ENTROPY_VALUE_RE = re.compile(r"(?=[A-Za-z0-9_./+=:-]{32,})(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9_./+=:-]+")
REDACTION = "<redacted>"


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


def _redact_sensitive_field(match: re.Match[str]) -> str:
    quote = match.group("quote") or ""
    return f"{match.group('field')}{match.group('assignment')}{quote}{REDACTION}{quote}"


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
        redacted = SENSITIVE_FIELD_RE.sub(_redact_sensitive_field, text)
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


def parse_args() -> argparse.Namespace:
    pre_parser = argparse.ArgumentParser(add_help=False)
    pre_parser.add_argument("--env-file", default=str(DEFAULT_ENV_FILE))
    pre_args, _ = pre_parser.parse_known_args()
    env = load_env(Path(pre_args.env_file))

    parser = argparse.ArgumentParser(
        description="Run the production smoke test against user registration and extra endpoints."
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
    parser.add_argument("--password", default="SmokePass123", help="Password used for the temporary account.")
    parser.add_argument("--device-id", default="codex-device", help="Device identifier header and payload value.")
    parser.add_argument("--device-session-id", default="codex-session", help="Device session identifier header.")
    parser.add_argument("--device-name", default="Codex Smoke", help="Device name in registration payload.")
    parser.add_argument("--device-model", default="Desktop", help="Device model in registration payload.")
    parser.add_argument("--username-prefix", default="codex_smoke", help="Prefix for the temporary username.")
    parser.add_argument("--timeout", type=float, default=20.0, help="Per-request timeout in seconds.")
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
    uid = extract_required_field(register_response, "uid")

    request_json(
        base_url=args.base_url,
        method="GET",
        path=f"/v1/users/{parse.quote(uid)}",
        app_id=args.app_id,
        app_key=args.app_key,
        device_id=args.device_id,
        device_session_id=args.device_session_id,
        token=token,
        timeout=args.timeout,
    )
    request_json(
        base_url=args.base_url,
        method="GET",
        path="/v1/extra/user/setting",
        app_id=args.app_id,
        app_key=args.app_key,
        device_id=args.device_id,
        device_session_id=args.device_session_id,
        token=token,
        timeout=args.timeout,
    )
    request_json(
        base_url=args.base_url,
        method="GET",
        path="/v1/extra/favorites?page=1&page_size=10",
        app_id=args.app_id,
        app_key=args.app_key,
        device_id=args.device_id,
        device_session_id=args.device_session_id,
        token=token,
        timeout=args.timeout,
    )

    print("smoke test passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
