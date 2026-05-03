#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

CONNECT_SOURCE = Path("internal/user/handler/event_connect.go")
RAW_FIELD_RE = re.compile(r'zap\.String\("(?P<field>expectToken|actToken)",\s*(?P<value>device\.Token|connectPacket\.Token)\)')
MANAGER_RAW_RE = re.compile(r'zap\.String\("token",\s*connectPacket\.Token\)')
DIRECT_TOKEN_LOG_RE = re.compile(r'zap\.String\("[^"]*",\s*(device\.Token|connectPacket\.Token)\)')
REQUIRED_SNIPPETS = (
    '"crypto/sha256"',
    '"encoding/hex"',
    "func tokenFingerprint(token string) string",
    'zap.String("stage", "manager_token")',
    'zap.String("tokenHash", tokenFingerprint(connectPacket.Token))',
    'zap.String("stage", "device_token")',
    'zap.String("expectedTokenHash", tokenFingerprint(device.Token))',
    'zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token))',
)


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
        snippet = match.group(0)
        if "tokenFingerprint(" not in snippet:
            failures.append(f"direct token value is still logged: {snippet}")
    for required in REQUIRED_SNIPPETS:
        if required not in text:
            failures.append(f"missing required redaction snippet: {required}")
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
