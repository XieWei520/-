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
RAW_FIELD_RE = re.compile(r'zap\.String\(\s*"(?P<field>expectToken|actToken)"\s*,\s*(?P<value>device\s*\.\s*Token|connectPacket\s*\.\s*Token)\s*\)')
MANAGER_RAW_RE = re.compile(r'zap\.String\(\s*"token"\s*,\s*connectPacket\s*\.\s*Token\s*\)')
ZAP_CALL_START_RE = re.compile(r'\bzap\.(?P<constructor>[A-Za-z][A-Za-z0-9_]*)\s*\(')
LOGGING_CALL_START_RE = re.compile(r'\.(?P<constructor>Infow|Errorw|Warnw|Debugw|Fatalw|Panicw|DPanicw|Infof|Errorf|Warnf|Debugf|Fatalf|Panicf|DPanicf|Info|Error|Warn|Debug|Fatal|Panic|DPanic|WithLazy|With)\s*\(')
DIRECT_SINK_CALL_START_RE = re.compile(r'\b(?P<constructor>fmt\.(?:Println|Printf|Print)|log\.(?:Println|Printf|Print|Fatalln|Fatalf|Fatal|Panicln|Panicf|Panic))\s*\(')
TOKEN_SELECTOR_PATTERN = r'(?:device\s*\.\s*Token|connectPacket\s*\.\s*Token)'
TOKEN_VALUE_RE = re.compile(r'(?<![A-Za-z0-9_])' + TOKEN_SELECTOR_PATTERN + r'(?![A-Za-z0-9_])')
ALLOWED_TOKEN_FINGERPRINT_CALL_RE = re.compile(
    r'(?<![A-Za-z0-9_.])tokenFingerprint(?![A-Za-z0-9_])\s*\(\s*'
    + TOKEN_SELECTOR_PATTERN + r'\s*\)'
)
IDENTIFIER_PATTERN = r'[A-Za-z_][A-Za-z0-9_]*'
TOKEN_ALIAS_ASSIGNMENT_RE = re.compile(
    r'(?:^|[;\n{]|\b(?:if|for|switch)\s+)\s*(?:'
    r'var\s+(?P<var_name>' + IDENTIFIER_PATTERN + r')(?:\s+[^=\n;]+)?\s*=\s*'
    r'|(?P<assign_name>' + IDENTIFIER_PATTERN + r')\s*(?::=|=)\s*)'
    + TOKEN_SELECTOR_PATTERN + r'(?=$|[\s;,\)}])',
    re.MULTILINE,
)
UNSAFE_TOKEN_RETURN_RE = re.compile(r'\breturn\s+(?P<expr>[^\n;}]*(?:\btoken\b|' + TOKEN_SELECTOR_PATTERN + r')[^\n;}]*)')
REQUIRED_IMPORTS = (
    "crypto/sha256",
    "encoding/hex",
)
REQUIRED_ZAP_FIELDS = (
    (
        'zap.String("stage", "manager_token")',
        re.compile(r'\Azap\.String\(\s*"stage"\s*,\s*"manager_token"\s*\)\Z', re.DOTALL),
    ),
    (
        'zap.String("tokenHash", tokenFingerprint(connectPacket.Token))',
        re.compile(
            r'\Azap\.String\(\s*"tokenHash"\s*,\s*tokenFingerprint\(\s*connectPacket\s*\.\s*Token\s*\)\s*\)\Z',
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
            r'\Azap\.String\(\s*"expectedTokenHash"\s*,\s*tokenFingerprint\(\s*device\s*\.\s*Token\s*\)\s*\)\Z',
            re.DOTALL,
        ),
    ),
    (
        'zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token))',
        re.compile(
            r'\Azap\.String\(\s*"actualTokenHash"\s*,\s*tokenFingerprint\(\s*connectPacket\s*\.\s*Token\s*\)\s*\)\Z',
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


def iter_direct_sink_calls(text: str) -> Iterator[tuple[str, str]]:
    yield from iter_balanced_calls(text, DIRECT_SINK_CALL_START_RE)


def find_token_aliases(code_view: str) -> set[str]:
    aliases: set[str] = set()
    for match in TOKEN_ALIAS_ASSIGNMENT_RE.finditer(code_view):
        alias = match.group("var_name") or match.group("assign_name")
        if alias is not None:
            aliases.add(alias)
    return aliases


def token_alias_reference_re(token_aliases: set[str]) -> re.Pattern[str] | None:
    if not token_aliases:
        return None
    aliases = "|".join(re.escape(alias) for alias in sorted(token_aliases, key=len, reverse=True))
    return re.compile(r'(?<![A-Za-z0-9_])(?:' + aliases + r')(?![A-Za-z0-9_])')


def call_contains_raw_token(call_text: str, token_aliases: set[str]) -> bool:
    allowed_removed = ALLOWED_TOKEN_FINGERPRINT_CALL_RE.sub("tokenFingerprint(<allowed>)", call_text)
    code_only = mask_go_strings_and_comments(allowed_removed)
    if TOKEN_VALUE_RE.search(code_only):
        return True
    alias_re = token_alias_reference_re(token_aliases)
    return alias_re.search(code_only) is not None if alias_re is not None else False



def verify_required_zap_fields(zap_calls: list[tuple[str, str]]) -> list[str]:
    failures: list[str] = []
    call_texts = [call_text.strip() for _constructor, call_text in zap_calls]
    for required, pattern in REQUIRED_ZAP_FIELDS:
        if not any(pattern.fullmatch(call_text) for call_text in call_texts):
            failures.append(f"missing required zap field: {required}")
    return failures


def extract_import_paths(text: str, code_view: str) -> set[str]:
    paths: set[str] = set()
    for match in re.finditer(r"\bimport\b", code_view):
        index = match.end()
        while index < len(code_view) and code_view[index].isspace():
            index += 1
        if index >= len(code_view):
            continue
        if code_view[index] == "(":
            close_index = find_matching_paren(code_view, index)
            if close_index is None:
                continue
            import_block = text[index + 1:close_index]
            paths.update(re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', import_block))
            paths.update(re.findall(r'`([^`]*)`', import_block))
            continue
        line_end = text.find("\n", index)
        if line_end == -1:
            line_end = len(text)
        import_line = text[index:line_end]
        paths.update(re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', import_line))
        paths.update(re.findall(r'`([^`]*)`', import_line))
    return paths


def verify_required_imports(text: str, code_view: str) -> list[str]:
    failures: list[str] = []
    imported_paths = extract_import_paths(text, code_view)
    for required in REQUIRED_IMPORTS:
        if required not in imported_paths:
            failures.append(f'missing required redaction snippet: "{required}" (missing required import: {required})')
    return failures


def extract_function_body(text: str, signature: str, code_view: str) -> str | None:
    signature_start = code_view.find(signature)
    if signature_start == -1:
        return None
    body_start = code_view.find("{", signature_start + len(signature))
    if body_start == -1:
        return None

    depth = 0
    index = body_start
    while index < len(code_view):
        char = code_view[index]
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
    code_view = mask_go_strings_and_comments(text)
    token_aliases = find_token_aliases(code_view)
    failures: list[str] = []
    zap_calls = list(iter_zap_calls(text))
    for _constructor, call_text in zap_calls:
        for match in RAW_FIELD_RE.finditer(call_text):
            failures.append(f"raw token log field {match.group('field')} still logs {match.group('value')}")
        if MANAGER_RAW_RE.search(call_text):
            failures.append('manager raw token log still uses zap.String("token", connectPacket.Token)')
    for constructor, call_text in zap_calls:
        if call_contains_raw_token(call_text, token_aliases):
            failures.append(f"raw token value is still logged via zap.{constructor}: {call_text}")
    for constructor, call_text in iter_logging_calls(text):
        if call_contains_raw_token(call_text, token_aliases):
            failures.append(f"raw token value is still logged via {constructor}: {call_text}")
    for constructor, call_text in iter_direct_sink_calls(text):
        if call_contains_raw_token(call_text, token_aliases):
            failures.append(f"raw token value is still logged via {constructor}: {call_text}")
    failures.extend(verify_required_imports(text, code_view))
    failures.extend(verify_required_zap_fields(zap_calls))

    fingerprint_body = extract_function_body(text, TOKEN_FINGERPRINT_SIGNATURE, code_view)
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
