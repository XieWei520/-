#!/usr/bin/env python3
from __future__ import annotations

import ssl
from pathlib import Path
from urllib import error, request


DEFAULT_ENV_FILE = Path(__file__).resolve().parent.parent / ".env"


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


def request_status(url: str) -> int:
    req = request.Request(url, method="GET")
    context = ssl.create_default_context()
    try:
        with request.urlopen(req, timeout=10, context=context) as resp:
            return resp.status
    except error.HTTPError as exc:
        return exc.code


def main() -> None:
    env = load_env(DEFAULT_ENV_FILE)
    base = env.get("TSDD_BASE_URL", "https://wemx.cc").rstrip("/")

    api_status = request_status(f"{base}/v1/ping")
    assert api_status == 200, f"unexpected ping status: {api_status}"

    gateway_status = request_status(f"{base}/v1/callgateway/healthz")
    assert gateway_status == 200, f"unexpected gateway status: {gateway_status}"

    livekit_status = request_status(f"{base}/livekit")
    assert livekit_status in (200, 401, 404, 426), f"unexpected livekit status: {livekit_status}"


if __name__ == "__main__":
    main()
