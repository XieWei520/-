#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Iterator
from pathlib import Path

CONNECT_SOURCE = Path("internal/user/handler/event_connect.go")
TOKEN_FINGERPRINT_SIGNATURE = "func tokenFingerprint(token string) string"
EXACT_TOKEN_FINGERPRINT_BODY = (
    'if token == "" { return "empty" } '
    "sum := sha256.Sum256([]byte(token)) "
    "return hex.EncodeToString(sum[:])[:12]"
)
RAW_FIELD_RE = re.compile(r'zap\.String\(\s*"(?P<field>expectToken|actToken)"\s*,\s*(?P<value>device\.Token|connectPacket\.Token)\s*\)')
MANAGER_RAW_RE = re.compile(r'zap\.String\(\s*"token"\s*,\s*connectPacket\.Token\s*\)')
ZAP_CALL_START_RE = re.compile(r'\bzap\.(?P<constructor>[A-Za-z][A-Za-z0-9_]*)\s*\(')
LOGGING_CALL_START_RE = re.compile(r'\.(?P<constructor>Infow|Errorw|Warnw|Debugw|Infof|Errorf|Warnf|Debugf)\s*\(')
TOKEN_VALUE_RE = re.compile(r'(?<![A-Za-z0-9_])(?:device\.Token|connectPacket\.Token)(?![A-Za-z0-9_])')
ALLOWED_TOKEN_FINGERPRINT_CALL_RE = re.compile(
    r'(?<![A-Za-z0-9_.])tokenFingerprint(?![A-Za-z0-9_])\s*\(\s*'
    r'(?:device\.Token|connectPacket\.Token)\s*\)'
)
UNSAFE_TOKEN_RETURN_RE = re.compile(r'\breturn\s+(?P<expr>[^\n;}]*(?:\btoken\b|device\.Token|connectPacket\.Token)[^\n;}]*)')
REQUIRED_SNIPPETS = (
    '"crypto/sha256"',
    '"encoding/hex"',
    TOKEN_FINGERPRINT_SIGNATURE,
)
REQUIRED_ZAP_FIELDS = (
    (
        'zap.String("stage", "manager_token")',
        re.compile(r'\Azap\.String\(\s*"stage"\s*,\s*"manager_token"\s*\)\Z', re.DOTALL),
    ),
    (
        'zap.String("tokenHash", tokenFingerprint(connectPacket.Token))',
        re.compile(
            r'\Azap\.String\(\s*"tokenHash"\s*,\s*tokenFingerprint\(\s*connectPacket\.Token\s*\)\s*\)\Z',
            re.DOTALL,
        ),
    ),
    (
        'zap.String("stage", "device_token")',
        re.compile(r'\Azap\.String\(\s*"stage"\s*,\s*"device_token"\s*\)\Z', re.DOTALL),
    ),
    (
        'zap.String("expectedTokenHash", tokenFingerprint(device.Token))',
        re.compile(
            r'\Azap\.String\(\s*"expectedTokenHash"\s*,\s*tokenFingerprint\(\s*device\.Token\s*\)\s*\)\Z',
            re.DOTALL,
        ),
    ),
    (
        'zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token))',
        re.compile(
            r'\Azap\.String\(\s*"actualTokenHash"\s*,\s*tokenFingerprint\(\s*connectPacket\.Token\s*\)\s*\)\Z',
            re.DOTALL,
        ),
    ),
)

def strip_go_comments(text: str) -> str:
    chars = list(text)
    output: list[str] = []
    index = 0
    quote: str | None = None
    escaped = False
    while index < len(chars):
        char = chars[index]
        next_char = chars[index + 1] if index + 1 < len(chars) else ""
        if quote is not None:
            output.append(char)
            if quote != "`" and escaped:
                escaped = False
            elif quote != "`" and char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue
        if char in {'"', "'", "`"}:
            quote = char
            output.append(char)
            index += 1
            continue
        if char == "/" and next_char == "/":
            output.extend("  ")
            index += 2
            while index < len(chars) and chars[index] != "\n":
                output.append(" ")
                index += 1
            continue
        if char == "/" and next_char == "*":
            output.extend("  ")
            index += 2
            while index + 1 < len(chars) and not (chars[index] == "*" and chars[index + 1] == "/"):
                output.append("\n" if chars[index] == "\n" else " ")
                index += 1
            if index + 1 < len(chars):
                output.extend("  ")
                index += 2
            continue
        output.append(char)
        index += 1
    return "".join(output)


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
                chars[mask_index] = "\n" if chars[mask_index] == "\n" else " "
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
                chars[mask_index] = "\n" if chars[mask_index] == "\n" else " "
            continue
        index += 1
    return "".join(chars)


def find_matching_paren(text: str, open_index: int) -> int | None:
    depth = 0
    index = open_index
    quote: str | None = None
    escaped = False
    while index < len(text):
        char = text[index]
        if quote is not None:
            if quote != "`" and escaped:
                escaped = False
            elif quote != "`" and char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
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


def iter_balanced_calls(text: str, start_re: re.Pattern[str]) -> Iterator[tuple[str, str]]:
    search_text = mask_go_strings_and_comments(text)
    search_start = 0
    while match := start_re.search(search_text, search_start):
        open_index = match.end() - 1
        close_index = find_matching_paren(text, open_index)
        if close_index is None:
            search_start = match.end()
            continue
        yield match.group("constructor"), text[match.start():close_index + 1]
        search_start = close_index + 1


def iter_zap_calls(text: str) -> Iterator[tuple[str, str]]:
    yield from iter_balanced_calls(text, ZAP_CALL_START_RE)


def iter_logging_calls(text: str) -> Iterator[tuple[str, str]]:
    yield from iter_balanced_calls(text, LOGGING_CALL_START_RE)

def zap_call_contains_raw_token(call_text: str) -> bool:
    allowed_removed = ALLOWED_TOKEN_FINGERPRINT_CALL_RE.sub("tokenFingerprint(<allowed>)", call_text)
    code_only = mask_go_strings_and_comments(allowed_removed)
    return TOKEN_VALUE_RE.search(code_only) is not None



def verify_required_zap_fields(zap_calls: list[tuple[str, str]]) -> list[str]:
    failures: list[str] = []
    call_texts = [call_text.strip() for _constructor, call_text in zap_calls]
    for required, pattern in REQUIRED_ZAP_FIELDS:
        if not any(pattern.fullmatch(call_text) for call_text in call_texts):
            failures.append(f"missing required zap field: {required}")
    return failures


def extract_function_body(text: str, signature: str) -> str | None:
    signature_start = text.find(signature)
    if signature_start == -1:
        return None
    body_start = text.find("{", signature_start + len(signature))
    if body_start == -1:
        return None

    depth = 0
    index = body_start
    quote: str | None = None
    escaped = False
    while index < len(text):
        char = text[index]
        if quote is not None:
            if quote != "`" and escaped:
                escaped = False
            elif quote != "`" and char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            index += 1
            continue
        if char in {'"', "'", "`"}:
            quote = char
            index += 1
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return text[body_start + 1:index]
        index += 1
    return None


def normalize_token_fingerprint_body(body: str) -> str:
    normalized = re.sub(r"\s+", " ", body).strip()
    normalized = re.sub(r"\s*==\s*", " == ", normalized)
    normalized = re.sub(r"\s*:=\s*", " := ", normalized)
    normalized = re.sub(r"\s*\{\s*", " { ", normalized)
    normalized = re.sub(r"\s*\}\s*", " } ", normalized)
    normalized = re.sub(r"\[\s*:\s*\]", "[:]", normalized)
    normalized = re.sub(r"\[\s*:\s*([0-9]+)\s*\]", r"[:\1]", normalized)
    normalized = re.sub(r"\[\s*\]\s*byte", "[]byte", normalized)
    normalized = re.sub(r"\(\s+", "(", normalized)
    normalized = re.sub(r"\s+\)", ")", normalized)
    normalized = re.sub(r"\s+", " ", normalized).strip()
    return normalized


def verify_token_fingerprint_body(fingerprint_body: str) -> list[str]:
    failures: list[str] = []
    normalized_body = normalize_token_fingerprint_body(fingerprint_body)
    if normalized_body != EXACT_TOKEN_FINGERPRINT_BODY:
        failures.append(f"tokenFingerprint body must exactly match safe implementation: {EXACT_TOKEN_FINGERPRINT_BODY}")
    masked_body = mask_go_strings_and_comments(fingerprint_body)
    for match in UNSAFE_TOKEN_RETURN_RE.finditer(masked_body):
        return_expr = match.group("expr").strip()
        failures.append(f"unsafe tokenFingerprint return: return {return_expr}")
    return failures


def verify_source(root: Path) -> list[str]:
    source_path = root / CONNECT_SOURCE
    if not source_path.is_file():
        return [f"missing source file: {source_path}"]
    raw_text = source_path.read_text(encoding="utf-8", errors="replace")
    text = strip_go_comments(raw_text)
    failures: list[str] = []
    zap_calls = list(iter_zap_calls(text))
    for _constructor, call_text in zap_calls:
        for match in RAW_FIELD_RE.finditer(call_text):
            failures.append(f"raw token log field {match.group('field')} still logs {match.group('value')}")
        if MANAGER_RAW_RE.search(call_text):
            failures.append('manager raw token log still uses zap.String("token", connectPacket.Token)')
    for constructor, call_text in zap_calls:
        if zap_call_contains_raw_token(call_text):
            failures.append(f"raw token value is still logged via zap.{constructor}: {call_text}")
    for constructor, call_text in iter_logging_calls(text):
        if zap_call_contains_raw_token(call_text):
            failures.append(f"raw token value is still logged via {constructor}: {call_text}")
    for required in REQUIRED_SNIPPETS:
        if required not in text:
            failures.append(f"missing required redaction snippet: {required}")
    failures.extend(verify_required_zap_fields(zap_calls))

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
