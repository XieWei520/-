#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Iterator
from pathlib import Path

CONNECT_SOURCE = Path("internal/user/handler/event_connect.go")
TOKEN_FINGERPRINT_SIGNATURE = "func tokenFingerprint(token string) string"
RAW_FIELD_RE = re.compile(r'zap\.String\(\s*"(?P<field>expectToken|actToken)"\s*,\s*(?P<value>device\.Token|connectPacket\.Token)\s*\)')
MANAGER_RAW_RE = re.compile(r'zap\.String\(\s*"token"\s*,\s*connectPacket\.Token\s*\)')
ZAP_CALL_START_RE = re.compile(r'\bzap\.(?P<constructor>[A-Za-z][A-Za-z0-9_]*)\s*\(')
TOKEN_VALUE_RE = re.compile(r'(?<![A-Za-z0-9_])(?:device\.Token|connectPacket\.Token)(?![A-Za-z0-9_])')
ALLOWED_TOKEN_FINGERPRINT_CALL_RE = re.compile(r'tokenFingerprint\(\s*(?:device\.Token|connectPacket\.Token)\s*\)')
FINGERPRINT_RETURN_RE = re.compile(r'\breturn\s+(?P<expr>[^}\n]+)')
SAFE_TOKEN_FINGERPRINT_BODY_RE = re.compile(
    r'''
    \A\s*
    if\s+token\s*==\s*""\s*\{\s*
        return\s+"empty"\s*;?\s*
    \}\s*;?\s*
    sum\s*:=\s*sha256\.Sum256\(\s*\[\]\s*byte\s*\(\s*token\s*\)\s*\)\s*;?\s*
    return\s+hex\.EncodeToString\(\s*sum\s*\[\s*:\s*\]\s*\)\s*\[\s*:\s*12\s*\]\s*;?\s*
    \Z
    ''',
    re.DOTALL | re.VERBOSE,
)
EXPECTED_TOKEN_FINGERPRINT_BODY = (
    'if token == "" { return "empty" }; '
    'sum := sha256.Sum256([]byte(token)); '
    'return hex.EncodeToString(sum[:])[:12]'
)
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
ALLOWED_FINGERPRINT_RETURNS = {
    '"empty"',
    "hex.EncodeToString(sum[:])[:12]",
}


def strip_go_comments(text: str) -> str:
    return re.sub(r'/\*.*?\*/|//[^\n]*', '', text, flags=re.DOTALL)


def mask_go_strings_and_comments(text: str) -> str:
    chars = list(text)
    index = 0
    while index < len(chars):
        char = chars[index]
        next_char = chars[index + 1] if index + 1 < len(chars) else ""
        if char == "/" and next_char == "/":
            start = index
            index += 2
            while index < len(chars) and chars[index] != "\n":
                index += 1
            for mask_index in range(start, index):
                chars[mask_index] = " "
            continue
        if char == "/" and next_char == "*":
            start = index
            index += 2
            while index + 1 < len(chars) and not (chars[index] == "*" and chars[index + 1] == "/"):
                index += 1
            index = min(index + 2, len(chars))
            for mask_index in range(start, index):
                chars[mask_index] = " "
            continue
        if char in {'"', "'", "`"}:
            quote = char
            start = index
            index += 1
            escaped = False
            while index < len(chars):
                current = chars[index]
                if quote != "`" and escaped:
                    escaped = False
                elif quote != "`" and current == "\\":
                    escaped = True
                elif current == quote:
                    index += 1
                    break
                index += 1
            for mask_index in range(start, index):
                chars[mask_index] = " "
            continue
        index += 1
    return "".join(chars)


def find_matching_paren(text: str, open_index: int) -> int | None:
    depth = 0
    index = open_index
    quote: str | None = None
    escaped = False
    in_line_comment = False
    in_block_comment = False
    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""
        if in_line_comment:
            if char == "\n":
                in_line_comment = False
            index += 1
            continue
        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote is not None:
            if quote != "`" and escaped:
                escaped = False
            elif quote != "`" and char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue
        if char == "/" and next_char == "/":
            in_line_comment = True
            index += 2
            continue
        if char == "/" and next_char == "*":
            in_block_comment = True
            index += 2
            continue
        if char in {'"', "'", "`"}:
            quote = char
            index += 1
            continue
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    return None


def iter_zap_calls(text: str) -> Iterator[tuple[str, str]]:
    search_start = 0
    while match := ZAP_CALL_START_RE.search(text, search_start):
        open_index = match.end() - 1
        close_index = find_matching_paren(text, open_index)
        if close_index is None:
            search_start = match.end()
            continue
        yield match.group("constructor"), text[match.start():close_index + 1]
        search_start = close_index + 1


def zap_call_contains_raw_token(call_text: str) -> bool:
    allowed_removed = ALLOWED_TOKEN_FINGERPRINT_CALL_RE.sub("tokenFingerprint(<allowed>)", call_text)
    code_only = mask_go_strings_and_comments(allowed_removed)
    return TOKEN_VALUE_RE.search(code_only) is not None


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


def verify_token_fingerprint_body(fingerprint_body: str) -> list[str]:
    failures: list[str] = []
    body_without_comments = strip_go_comments(fingerprint_body)
    if not SAFE_TOKEN_FINGERPRINT_BODY_RE.fullmatch(body_without_comments):
        failures.append(f"tokenFingerprint body must exactly match safe implementation: {EXPECTED_TOKEN_FINGERPRINT_BODY}")
    returns = [match.group("expr").strip().rstrip(";").strip() for match in FINGERPRINT_RETURN_RE.finditer(body_without_comments)]
    if not returns:
        failures.append("tokenFingerprint has no return statements")
    for return_expr in returns:
        if return_expr not in ALLOWED_FINGERPRINT_RETURNS:
            failures.append(f"unsafe tokenFingerprint return: return {return_expr}")
    return failures


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
    for constructor, call_text in iter_zap_calls(text):
        if zap_call_contains_raw_token(call_text):
            failures.append(f"raw token value is still logged via zap.{constructor}: {call_text}")
    for required in REQUIRED_SNIPPETS:
        if required not in text:
            failures.append(f"missing required redaction snippet: {required}")

    fingerprint_body = extract_function_body(text, TOKEN_FINGERPRINT_SIGNATURE)
    if fingerprint_body is None:
        failures.append(f"missing {TOKEN_FINGERPRINT_SIGNATURE} body")
    else:
        failures.extend(verify_token_fingerprint_body(fingerprint_body))
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
