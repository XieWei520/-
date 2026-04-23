#!/usr/bin/env python3
"""
Shared auth helpers that mirror the Flutter client's signing contract.
"""

import hashlib
import json
import os
import string
import time
from random import SystemRandom
from typing import Any, Dict, Optional

APP_ID = os.getenv("WK_APP_ID", "wukongchat")
APP_KEY = os.getenv("WK_APP_KEY", "25b002c6be2d539f264c")
_NONCE_ALPHABET = string.ascii_letters + string.digits
_RANDOM = SystemRandom()


def compact_json_dumps(data: Any) -> str:
    """Serialize JSON using the compact format used for request signing."""
    return json.dumps(data, ensure_ascii=False, separators=(",", ":"))


def encode_data_for_sign(data: Any) -> str:
    """Encode request data exactly like the Flutter client before signing."""
    if data is None:
        return ""

    try:
        import requests
    except ImportError:  # pragma: no cover - requests is a hard dependency here
        requests = None

    if requests is not None and isinstance(data, requests.models.RequestEncodingMixin):
        return ""

    if data.__class__.__name__ == "FormData":
        return ""
    if isinstance(data, str):
        return data
    if isinstance(data, (dict, list, int, float, bool)):
        return compact_json_dumps(data)
    try:
        return compact_json_dumps(data)
    except (TypeError, ValueError):
        return ""


def generate_nonce(length: int = 16) -> str:
    """Generate a random nonce using the same character class as the app."""
    return "".join(_RANDOM.choice(_NONCE_ALPHABET) for _ in range(length))


def build_signed_headers(
    data: Any = None,
    token: Optional[str] = None,
    device_id: Optional[str] = None,
    device_session_id: Optional[str] = None,
    include_json_content_type: bool = True,
    app_id: Optional[str] = None,
    app_key: Optional[str] = None,
    timestamp_ms: Optional[int] = None,
    nonce: Optional[str] = None,
) -> Dict[str, str]:
    """Build request headers compatible with the Flutter app."""
    resolved_app_id = app_id or APP_ID
    resolved_app_key = app_key or APP_KEY
    resolved_timestamp = str(timestamp_ms if timestamp_ms is not None else int(time.time() * 1000))
    resolved_nonce = nonce or generate_nonce(16)
    encoded = encode_data_for_sign(data)
    sign_source = f"{encoded}{resolved_nonce}{resolved_timestamp}{resolved_app_key}"
    sign = hashlib.md5(sign_source.encode("utf-8")).hexdigest()

    headers: Dict[str, str] = {
        "Accept": "application/json",
        "appid": resolved_app_id,
        "timestamp": resolved_timestamp,
        "noncestr": resolved_nonce,
        "sign": sign,
    }
    if include_json_content_type:
        headers["Content-Type"] = "application/json"
    if token:
        headers["token"] = token
    if device_id:
        headers["X-Device-ID"] = device_id
    if device_session_id:
        headers["X-Device-Session-ID"] = device_session_id
    return headers
