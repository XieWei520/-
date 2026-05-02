#!/usr/bin/env python3
from __future__ import annotations

import argparse
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

_DANGEROUS_WORD = (
    r"acttoken|expecttoken|authorization|api[_-]?key|api[_-]?secret|"
    r"password|secret|credential|token"
)

_SECRET_FIELD_RE = re.compile(
    rf"""
    (?P<prefix>
        (?<![A-Za-z0-9_-])
        (?P<field_quote>["']?)
        (?P<field>[A-Za-z_][A-Za-z0-9_-]*(?:{_DANGEROUS_WORD})[A-Za-z0-9_-]*)
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


def _is_safe_metadata_field(field: str) -> bool:
    return field.lower().replace("-", "_") in _SAFE_TOKEN_FIELDS


def _redacted_value(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return f"{value[0]}<redacted>{value[-1]}"
    return "<redacted>"


def scan_text(text: str, *, source: str = "stdin") -> ScanResult:
    finding_count = 0
    report_lines: list[str] = []

    for line_number, line in enumerate(text.splitlines(), start=1):
        line_findings = 0

        def redact(match: re.Match[str]) -> str:
            nonlocal finding_count, line_findings
            if _is_safe_metadata_field(match.group("field")):
                return match.group(0)

            finding_count += 1
            line_findings += 1
            return f"{match.group('prefix')}{_redacted_value(match.group('value'))}"

        redacted_line = _SECRET_FIELD_RE.sub(redact, line)
        if line_findings:
            report_lines.append(f"{source}:{line_number}: {redacted_line}")

    return ScanResult(finding_count, "\n".join(report_lines))


def _scan_inputs(paths: Iterable[str], *, source: str | None) -> ScanResult:
    total_findings = 0
    reports: list[str] = []

    path_list = list(paths)
    if not path_list:
        result = scan_text(sys.stdin.read(), source=source or "stdin")
        return result

    for raw_path in path_list:
        path = Path(raw_path)
        result = scan_text(
            path.read_text(encoding="utf-8", errors="replace"),
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

    result = _scan_inputs(args.paths, source=args.source)
    if result.redacted_report:
        print(result.redacted_report)

    return 1 if result.finding_count else 0


if __name__ == "__main__":
    raise SystemExit(main())
