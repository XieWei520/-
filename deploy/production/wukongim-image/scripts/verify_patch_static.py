#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CONNECT_SOURCE = Path("internal/user/handler/event_connect.go")
TOKEN_FINGERPRINT_SIGNATURE = "func tokenFingerprint(token string) string"
RAW_FIELD_RE = re.compile(r'zap\.String\(\s*"(?P<field>expectToken|actToken)"\s*,\s*(?P<value>device\.Token|connectPacket\.Token)\s*\)')
MANAGER_RAW_RE = re.compile(r'zap\.String\(\s*"token"\s*,\s*connectPacket\.Token\s*\)')
DIRECT_TOKEN_LOG_RE = re.compile(
    r'zap\.(?P<constructor>[A-Za-z][A-Za-z0-9_]*)\(\s*"(?P<field>[^"]*)"\s*,\s*(?P<value>device\.Token|connectPacket\.Token)\s*\)'
)
RAW_TOKEN_RETURN_RE = re.compile(r'\breturn\s+token\b')
REQUIRED_SNIPPETS = (
    '"crypto/sha256"',
    '"encoding/hex"',
    TOKEN_FINGERPRINT_SIGNATURE,
    'zap.String("stage", "manager_token")',
    'zap.String("tokenHash", tokenFingerprint(connectPacket.Token))',
    'zap.String("stage", "device_token")',
    'zap.String("expectedTokenHash", tokenFingerprint(device.Token))',
    'zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token))',
)
REQUIRED_FINGERPRINT_BODY_SNIPPETS = (
    "sha256.Sum256([]byte(token))",
    "hex.EncodeToString(sum[:])[:12]",
)


def extract_function_body(text: str, signature: str) -> str | None:
    signature_start = text.find(signature)
    if signature_start == -1:
        return None
    body_start = text.find("{", signature_start + len(signature))
    if body_start == -1:
        return None

    depth = 0
    for index in range(body_start, len(text)):
        char = text[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[body_start + 1:index]
    return None


def verify_source(root: Path) -> list[str]:
    source_path = root / CONNECT_SOURCE
    if not source_path.is_file():
        return [f"missing source file: {source_path}"]
    text = source_path.read_text(encoding="utf-8", errors="replace")
    failures: list[str] = []
    for match in RAW_FIELD_RE.finditer(text):
        failures.append(f"raw token log field {match.group('field')} still logs {match.group('value')}")
    if MANAGER_RAW_RE.search(text):
        failures.append('manager raw token log still uses zap.String("token", connectPacket.Token)')
    for match in DIRECT_TOKEN_LOG_RE.finditer(text):
        failures.append(f"direct token value is still logged via zap.{match.group('constructor')}: {match.group(0)}")
    for required in REQUIRED_SNIPPETS:
        if required not in text:
            failures.append(f"missing required redaction snippet: {required}")

    fingerprint_body = extract_function_body(text, TOKEN_FINGERPRINT_SIGNATURE)
    if fingerprint_body is None:
        failures.append(f"missing {TOKEN_FINGERPRINT_SIGNATURE} body")
    else:
        if RAW_TOKEN_RETURN_RE.search(fingerprint_body):
            failures.append("tokenFingerprint must not return raw token with return token")
        for required in REQUIRED_FINGERPRINT_BODY_SNIPPETS:
            if required not in fingerprint_body:
                failures.append(f"missing required tokenFingerprint hash snippet: {required}")
    return failures


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Statically verify WuKongIM connect-token logs are redacted.")
    parser.add_argument("source_root", help="Path to a WuKongIM source checkout.")
    args = parser.parse_args(argv)
    failures = verify_source(Path(args.source_root))
    if failures:
        for failure in failures:
            print(f"error: {failure}", file=sys.stderr)
        return 1
    sys.stdout.buffer.write(b"WuKongIM token log patch static verification passed\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
