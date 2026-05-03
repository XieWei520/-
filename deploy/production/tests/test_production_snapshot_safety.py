"""Safety checks for the production deployment template snapshot.

Run directly from the repository root:
    python deploy/production/tests/test_production_snapshot_safety.py
"""

from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

REQUIRED_FILES = (
    "README.md",
    "docker-compose.yaml",
    ".env.example",
    "config/wk.yaml.tpl",
    "config/tsdd.yaml.tpl",
    "config/turnserver.conf.tpl",
    "config/livekit.yaml.tpl",
    "mysql/conf.d/production.cnf",
    "nginx/default.conf.template",
    "nginx/nginx.conf",
    "scripts/render_config.py",
    "scripts/smoke_test.py",
    "scripts/perf_probe.py",
    "scripts/production_doctor.py",
    "scripts/edge_health_check.py",
    "scripts/mysql_health_check.py",
    "scripts/call_stack_smoke.py",
    "scripts/apply_device_flag_migration.py",
    "scripts/backup_mysql.sh",
    "scripts/restore_mysql.sh",
    "scripts/bootstrap_server.sh",
    "scripts/test_smoke_test.py",
    "scripts/test_perf_probe.py",
    "scripts/test_production_doctor.py",
)

DENIED_PATH_MARKERS = (
    "/rendered/",
    "/logs/",
    "/data/",
    "/backup/",
    "/__pycache__/",
    "/admin-src/.git/",
    "/manager/dist",
    "/nginx/html",
    "/admin/dist",
    "/admin-custom/dist",
)

DENIED_SUFFIXES = (".pem", ".key", ".pyc")

SECRET_ASSIGNMENT_RE = re.compile(
    r"""
    ^\s*(?:-\s*)?(?:export\s+)?
    (?P<name>[A-Za-z_][A-Za-z0-9_-]*(?:PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)[A-Za-z0-9_-]*)
    \s*(?::|=)\s*
    (?P<value>[^#\n]*?)
    \s*(?:\#.*)?$
    """,
    re.IGNORECASE | re.VERBOSE,
)

TEXT_SUFFIXES = {
    "",
    ".conf",
    ".cnf",
    ".css",
    ".env",
    ".example",
    ".html",
    ".js",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".template",
    ".tpl",
    ".txt",
    ".yaml",
    ".yml",
}


def _rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def _all_paths() -> list[Path]:
    if not ROOT.exists():
        return []
    return sorted(ROOT.rglob("*"), key=lambda p: _rel(p))


def _path_matches_marker(path: Path, marker: str) -> bool:
    rel = "/" + _rel(path)
    if path.is_dir():
        rel = rel.rstrip("/") + "/"

    if marker.endswith("/"):
        return marker in rel

    return rel == marker or rel.startswith(marker.rstrip("/") + "/")


def _secret_value_is_placeholder(value: str, source: Path | None = None) -> bool:
    cleaned = value.strip().rstrip(",")
    if not cleaned:
        return True

    source_suffix = source.suffix.lower() if source is not None else ""
    literal_prefixes = ("'", '"', "r'", 'r"', "u'", 'u"', "b'", 'b"', "f'", 'f"', "fr'", 'fr"', "rf'", 'rf"')
    if source_suffix == ".py" and not cleaned.lower().startswith(literal_prefixes):
        # Python type annotations, keyword forwarding, and variable references are not literal secret values.
        return True

    lower_cleaned = cleaned.lower()
    for prefix in ("fr", "rf", "r", "u", "b", "f"):
        if lower_cleaned.startswith(prefix) and len(cleaned) > len(prefix) and cleaned[len(prefix)] in {'"', "'"}:
            cleaned = cleaned[len(prefix):]
            break

    if len(cleaned) >= 2 and cleaned[0] == cleaned[-1] and cleaned[0] in {'"', "'"}:
        cleaned = cleaned[1:-1].strip()

    if not cleaned:
        return True

    lowered = cleaned.lower()
    if cleaned.startswith("${") and cleaned.endswith("}"):
        return True
    if cleaned.startswith("{{") and cleaned.endswith("}}"):
        return True
    if cleaned.startswith("<") and cleaned.endswith(">"):
        return True
    if cleaned.startswith("$"):
        return True
    if lowered in {"changeme", "change-me", "change_me", "example"}:
        return True
    if lowered.startswith(("your-", "your_")):
        return True
    if any(marker in lowered for marker in ("changeme", "change-me", "change_me", "change", "example", "placeholder")):
        return True

    return False


class ProductionSnapshotSafetyTest(unittest.TestCase):
    def test_required_files_are_present(self) -> None:
        missing = [rel for rel in REQUIRED_FILES if not (ROOT / rel).is_file()]
        self.assertEqual([], missing, f"Missing required snapshot files: {missing}")

    def test_runtime_secret_and_build_artifact_paths_are_absent(self) -> None:
        violations: list[str] = []
        for path in _all_paths():
            rel = _rel(path)
            if any(_path_matches_marker(path, marker) for marker in DENIED_PATH_MARKERS):
                violations.append(rel)
            if path.is_file() and path.suffix.lower() in DENIED_SUFFIXES:
                violations.append(rel)
            if path.name == ".env" or path.name.startswith(".env.bak"):
                violations.append(rel)

        self.assertEqual([], sorted(set(violations)), "Denied runtime, secret, or build artifact paths were found")

    def test_secret_like_assignments_use_placeholders(self) -> None:
        violations: list[str] = []
        this_file = Path(__file__).resolve()

        for path in _all_paths():
            if not path.is_file() or path.resolve() == this_file:
                continue
            if path.suffix.lower() not in TEXT_SUFFIXES and not path.name.endswith((".template", ".tpl", ".example")):
                continue

            try:
                lines = path.read_text(encoding="utf-8").splitlines()
            except UnicodeDecodeError:
                continue

            for line_number, line in enumerate(lines, start=1):
                match = SECRET_ASSIGNMENT_RE.match(line)
                if not match:
                    continue
                if _secret_value_is_placeholder(match.group("value"), path):
                    continue
                # Do not include the value in assertion output.
                violations.append(f"{_rel(path)}:{line_number}:{match.group('name')}")

        self.assertEqual([], violations, "Secret-like assignment values must be placeholders")


if __name__ == "__main__":
    unittest.main(verbosity=2)
