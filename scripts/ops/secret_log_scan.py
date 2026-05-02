#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class ScanResult:
    finding_count: int
    redacted_report: str


_SAFE_TOKEN_FIELDS = {
    "token_empty",
    "token_hash",
    "token_length",
    "token_len",
    "token_sha256",
    "token_sha256_prefix",
}

_DANGEROUS_FIELD_TERMS = (
    "acttoken",
    "expecttoken",
    "authorization",
    "apikey",
    "apisecret",
    "password",
    "secret",
    "credential",
    "token",
)

_FIELD_ASSIGNMENT_RE = re.compile(
    r"""
    (?P<prefix>
        (?<![A-Za-z0-9_-])
        (?P<field_quote>["']?)
        (?P<field>[A-Za-z_][A-Za-z0-9_-]*)
        (?P=field_quote)
        \s*[:=]\s*
    )
    (?P<value>
        "(?:\\.|[^"\\])*"
        |'(?:\\.|[^'\\])*'
        |(?:Bearer\s+)?[^\s,}}\]]+
    )
    """,
    re.IGNORECASE | re.VERBOSE,
)


class _InputReadError(Exception):
    pass


def _normalized_field(field: str) -> str:
    return field.lower().replace("-", "_")


def _is_safe_metadata_field(field: str) -> bool:
    return _normalized_field(field) in _SAFE_TOKEN_FIELDS


def _is_secret_field(field: str) -> bool:
    if _is_safe_metadata_field(field):
        return False

    compact_field = _normalized_field(field).replace("_", "")
    return any(term in compact_field for term in _DANGEROUS_FIELD_TERMS)


def _redacted_value(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return f"{value[0]}<redacted>{value[-1]}"
    return "<redacted>"


def _redact_line(line: str) -> tuple[int, str]:
    line_findings = 0

    def redact(match: re.Match[str]) -> str:
        nonlocal line_findings
        if not _is_secret_field(match.group("field")):
            return match.group(0)

        line_findings += 1
        return f"{match.group('prefix')}{_redacted_value(match.group('value'))}"

    redacted_line = _FIELD_ASSIGNMENT_RE.sub(redact, line)
    return line_findings, redacted_line


def _docker_log_payload(line: str) -> str | None:
    stripped = line.lstrip()
    if not stripped.startswith("{"):
        return None

    try:
        payload = json.loads(line)
    except json.JSONDecodeError:
        return None

    if not isinstance(payload, dict):
        return None

    log_value = payload.get("log")
    if not isinstance(log_value, str):
        return None

    return log_value


def scan_text(text: str, *, source: str = "stdin") -> ScanResult:
    finding_count = 0
    report_lines: list[str] = []

    for line_number, line in enumerate(text.splitlines(), start=1):
        scan_lines = [line]
        docker_payload = _docker_log_payload(line)
        if docker_payload is not None:
            scan_lines = docker_payload.splitlines()

        for scan_line in scan_lines:
            line_findings, redacted_line = _redact_line(scan_line)
            finding_count += line_findings

            if line_findings:
                report_lines.append(f"{source}:{line_number}: {redacted_line}")

    return ScanResult(finding_count, "\n".join(report_lines))


def _scan_inputs(paths: Iterable[str], *, source: str | None) -> ScanResult:
    total_findings = 0
    reports: list[str] = []

    path_list = list(paths)
    if not path_list:
        stdin_text = sys.stdin.buffer.read().decode("utf-8", errors="replace")
        result = scan_text(stdin_text, source=source or "stdin")
        return result

    for raw_path in path_list:
        path = Path(raw_path)
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            detail = exc.strerror or str(exc)
            raise _InputReadError(f"{path}: {detail}") from exc

        result = scan_text(
            text,
            source=source or str(path),
        )
        total_findings += result.finding_count
        if result.redacted_report:
            reports.append(result.redacted_report)

    return ScanResult(total_findings, "\n".join(reports))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Scan logs for secret-looking fields and redact values in reports.",
    )
    parser.add_argument("paths", nargs="*", help="Files to scan. Reads stdin when omitted.")
    parser.add_argument("--source", help="Source label for reports.")
    args = parser.parse_args(argv)

    try:
        result = _scan_inputs(args.paths, source=args.source)
    except _InputReadError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if result.redacted_report:
        print(result.redacted_report)

    return 1 if result.finding_count else 0


if __name__ == "__main__":
    raise SystemExit(main())
