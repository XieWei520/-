from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


TEXT_SUFFIXES = {
    ".dart",
    ".html",
    ".js",
    ".json",
    ".md",
    ".txt",
    ".yaml",
    ".yml",
}

SKIP_PARTS = {
    ".dart_tool",
    ".git",
    ".gradle",
    ".idea",
    ".vscode",
    "build",
    "docs/superpowers",
    "release_packages",
    "TangSengDaoDaoManager-main",
}

# Common characters produced when UTF-8 Chinese text is decoded as CP936/GBK.
# Keep this list conservative: candidates still need to appear in suspicious
# clusters, not merely as a single character.
SUSPICIOUS_CHARS = set(
    "\u581d\u5a11\u6d93\u6fb6\u934f\u935b\u9363\u9365\u9366"
    "\u9385\u93ae\u93b5\u9418\u9428\u943e\u95ab\u95b0\u95b2"
    "\u951b\u9526\u952f\u9534\u95c2\u9a9e\u9225\u9239\u923a"
    "\u9241\u9333\u9369\u9422\u6c2d\u866b\u7ad8\u7e5d\u3129"
)

LATIN_MOJIBAKE_MARKERS = (
    "\u00c3",
    "\u00c2",
    "\u00e2\u20ac",
    "\u00e2\u0080",
    "\ufffd",
)


@dataclass(frozen=True)
class Finding:
    path: Path
    line_number: int
    kind: str
    original: str
    suggestion: str | None


def git_paths() -> list[Path]:
    tracked = subprocess.check_output(
        ["git", "ls-files"], text=True, encoding="utf-8"
    ).splitlines()
    others = subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard"],
        text=True,
        encoding="utf-8",
    ).splitlines()
    paths = []
    for raw in tracked + others:
        path = Path(raw)
        if path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        normalized = path.as_posix()
        if any(part in path.parts for part in SKIP_PARTS) or any(
            normalized.startswith(prefix + "/") for prefix in SKIP_PARTS
        ):
            continue
        paths.append(path)
    return sorted(set(paths))


def suspicious_score(text: str) -> int:
    score = sum(1 for ch in text if ch in SUSPICIOUS_CHARS)
    score += sum(text.count(marker) * 3 for marker in LATIN_MOJIBAKE_MARKERS)
    score += text.count("?") if any(ch in SUSPICIOUS_CHARS for ch in text) else 0
    return score


def cjk_count(text: str) -> int:
    return sum(
        1
        for ch in text
        if "\u3400" <= ch <= "\u4dbf"
        or "\u4e00" <= ch <= "\u9fff"
        or "\uf900" <= ch <= "\ufaff"
    )


def try_cp936_repair(text: str) -> str | None:
    try:
        repaired = text.encode("cp936").decode("utf-8")
    except UnicodeError:
        return None
    if repaired == text:
        return None
    if suspicious_score(repaired) >= suspicious_score(text):
        return None
    if cjk_count(repaired) == 0:
        return None
    return repaired


def iter_segments(line: str) -> list[str]:
    # Scan contiguous non-ASCII clusters, allowing '?' because lossy mojibake
    # often ends with replacement question marks.
    return re.findall(r"[\u0080-\uffff?]{2,}", line)


def scan_file(path: Path) -> list[Finding]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return [
            Finding(
                path=path,
                line_number=0,
                kind="invalid-utf8",
                original="",
                suggestion=None,
            )
        ]

    findings: list[Finding] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        for segment in iter_segments(line):
            repaired = try_cp936_repair(segment)
            if repaired is not None:
                findings.append(
                    Finding(path, line_number, "auto-cp936", segment, repaired)
                )
                continue
            if suspicious_score(segment) >= 2:
                findings.append(
                    Finding(path, line_number, "manual-review", segment, None)
                )
    return findings


def main() -> int:
    findings: list[Finding] = []
    for path in git_paths():
        findings.extend(scan_file(path))

    for finding in findings:
        original = finding.original.encode("unicode_escape").decode("ascii")
        print(f"{finding.path}:{finding.line_number}: {finding.kind}: {original}")
        if finding.suggestion is not None:
            suggestion = finding.suggestion.encode("unicode_escape").decode("ascii")
            print(f"  -> {suggestion}")
    print(f"TOTAL {len(findings)}")
    return 1 if findings else 0


if __name__ == "__main__":
    raise SystemExit(main())
