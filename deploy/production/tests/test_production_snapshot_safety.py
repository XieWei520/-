"""Safety checks for the production deployment template snapshot.

Run directly from the repository root:
    python deploy/production/tests/test_production_snapshot_safety.py
"""

from __future__ import annotations

import re
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = ROOT.parents[1]

REQUIRED_FILES = (
    "README.md",
    "docker-compose.yaml",
    "Dockerfile.tsdd",
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
    "/backups/",
    "/certs/",
    "/keys/",
    "/__pycache__/",
    "/.git/",
    "/admin-src/.git/",
    "/build/",
    "/manager/dist",
    "/nginx/html",
    "/admin/dist",
    "/admin-custom/dist",
)

DENIED_SUFFIXES = (
    ".pem",
    ".key",
    ".pyc",
    ".sql",
    ".db",
    ".sqlite",
    ".sqlite3",
    ".log",
    ".gz",
    ".zip",
    ".tar",
    ".tgz",
    ".p12",
    ".pfx",
    ".jks",
)

SECRET_ASSIGNMENT_RE = re.compile(
    r"""
    ^\s*(?:-\s*)?(?:export\s+)?
    (?P<name>[A-Za-z_][A-Za-z0-9_-]*(?:PASSWORD|PASS|PWD|SECRET|TOKEN|KEY|CREDENTIAL|DSN)[A-Za-z0-9_-]*)
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


def _should_skip_secret_scan(path: Path) -> bool:
    rel = "/" + _rel(path)
    if path.suffix.lower() == ".py" and path.name.startswith("test_"):
        return True

    return False


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

    def test_compose_build_dockerfile_paths_exist_under_repo_root(self) -> None:
        compose = (ROOT / "docker-compose.yaml").read_text(encoding="utf-8")
        dockerfile_paths = re.findall(r"^\s*dockerfile:\s*([^#\n]+?)\s*$", compose, re.MULTILINE)

        repo_root = REPO_ROOT.resolve()
        missing: list[str] = []
        for raw_path in dockerfile_paths:
            dockerfile = raw_path.strip().strip("\"'")
            resolved = (repo_root / dockerfile).resolve()
            try:
                resolved.relative_to(repo_root)
            except ValueError:
                missing.append(dockerfile)
                continue
            if not resolved.is_file():
                missing.append(dockerfile)

        self.assertEqual([], missing, f"Compose build.dockerfile paths must exist: {missing}")

    def test_wide_compose_build_context_has_root_dockerignore_guards(self) -> None:
        compose = (ROOT / "docker-compose.yaml").read_text(encoding="utf-8")
        self.assertRegex(compose, r"(?m)^\s*context:\s*\.\./\.\.\s*$")

        dockerignore = REPO_ROOT / ".dockerignore"
        self.assertTrue(
            dockerignore.is_file(),
            "Compose uses the repo root as Docker build context, so root .dockerignore is required.",
        )
        patterns = {
            line.strip()
            for line in dockerignore.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        }
        required_patterns = {
            ".env",
            ".env.*",
            "!.env.example",
            "!**/.env.example",
            ".git",
            "**/.git",
            "deploy/production/.env",
            "deploy/production/.env.bak*",
            "deploy/production/rendered/",
            "deploy/production/logs/",
            "deploy/production/data/",
            "deploy/production/backups/",
            "deploy/production/certs/",
            "deploy/production/keys/",
            "**/__pycache__/",
            "**/*.pyc",
            "build/",
            "**/build/",
            "**/*.pem",
            "**/*.key",
            "**/*.sql",
            "**/*.db",
            "**/*.sqlite",
            "**/*.sqlite3",
            "**/*.log",
            "**/*.gz",
            "**/*.zip",
            "**/*.tar",
            "**/*.tgz",
            "**/*.p12",
            "**/*.pfx",
            "**/*.jks",
        }

        self.assertEqual([], sorted(required_patterns - patterns))

    def test_dockerfile_documents_full_backend_source_layout_requirement(self) -> None:
        combined = "\n".join(
            [
                (ROOT / "Dockerfile.tsdd").read_text(encoding="utf-8"),
                (ROOT / "README.md").read_text(encoding="utf-8"),
            ]
        ).lower()
        required_phrases = (
            "complete backend source layout",
            "flutter worktree snapshot",
            "go.mod",
            "go.sum",
            "serverlib",
            "main.go",
            "configs",
        )

        missing = [phrase for phrase in required_phrases if phrase not in combined]
        self.assertEqual([], missing)

    def test_secret_scan_skip_helper_only_skips_python_tests(self) -> None:
        should_skip = (
            ROOT / "scripts" / "test_smoke_test.py",
            ROOT / "tests" / "test_production_snapshot_safety.py",
            ROOT / "nested" / "tests" / "test_fixture.py",
            ROOT / "nested" / "test_fixture.py",
        )
        not_skipped = (
            ROOT / "scripts" / "smoke_test.py",
            ROOT / "scripts" / "test_fixture.txt",
            ROOT / "tests" / "fixture.py",
            ROOT / "tests" / "live.env",
            ROOT / "nested" / "tests" / "test_fixture.txt",
            ROOT / "config" / "wk.yaml.tpl",
        )

        self.assertEqual([], [_rel(path) for path in should_skip if not _should_skip_secret_scan(path)])
        self.assertEqual([], [_rel(path) for path in not_skipped if _should_skip_secret_scan(path)])

    def test_secret_scanner_flags_common_password_dsn_and_camelcase_names(self) -> None:
        samples = (
            "TSDD_ADMIN_PWD",
            "MYSQL_DSN",
            "redisPass",
            "adminpwd",
        )

        misses: list[str] = []
        for name in samples:
            line = f"{name}=runtimevalue123"
            match = SECRET_ASSIGNMENT_RE.match(line)
            if match is None or _secret_value_is_placeholder(match.group("value")):
                misses.append(name)

        self.assertEqual([], misses, "Secret scanner must recognize common secret-like variable names")

    def test_secret_scanner_scans_non_python_test_fixtures(self) -> None:
        with tempfile.TemporaryDirectory(dir=ROOT) as temp_dir:
            fixture = Path(temp_dir) / "tests" / "live.env"
            fixture.parent.mkdir(parents=True, exist_ok=True)
            fixture.write_text("MYSQL_DSN=runtimevalue123\n", encoding="utf-8")

            self.assertFalse(_should_skip_secret_scan(fixture))
            line = fixture.read_text(encoding="utf-8").strip()
            match = SECRET_ASSIGNMENT_RE.match(line)
            self.assertIsNotNone(match)
            assert match is not None
            self.assertFalse(_secret_value_is_placeholder(match.group("value")))

    def test_denied_suffixes_cover_runtime_dump_archive_and_keystore_artifacts(self) -> None:
        expected = {
            ".pem",
            ".key",
            ".pyc",
            ".sql",
            ".db",
            ".sqlite",
            ".sqlite3",
            ".log",
            ".gz",
            ".zip",
            ".tar",
            ".tgz",
            ".p12",
            ".pfx",
            ".jks",
        }

        self.assertEqual(set(), expected.difference(DENIED_SUFFIXES))

    def test_denied_path_markers_cover_runtime_vcs_and_build_artifacts(self) -> None:
        denied_samples = (
            ROOT / "backups" / "mysql.sql",
            ROOT / "certs" / "server.crt",
            ROOT / "keys" / "service.pub",
            ROOT / ".git" / "config",
            ROOT / "build" / "bundle.js",
        )

        uncovered = [
            _rel(path)
            for path in denied_samples
            if not any(_path_matches_marker(path, marker) for marker in DENIED_PATH_MARKERS)
        ]

        self.assertEqual([], uncovered)

    def test_runtime_secret_and_build_artifact_paths_are_absent(self) -> None:
        violations: list[str] = []
        for path in _all_paths():
            rel = _rel(path)
            if any(_path_matches_marker(path, marker) for marker in DENIED_PATH_MARKERS):
                violations.append(rel)
            if path.is_file() and path.suffix.lower() in DENIED_SUFFIXES:
                violations.append(rel)
            if path.name == ".env" or (path.name.startswith(".env.") and path.name != ".env.example"):
                violations.append(rel)

        self.assertEqual([], sorted(set(violations)), "Denied runtime, secret, or build artifact paths were found")

    def test_secret_like_assignments_use_placeholders(self) -> None:
        violations: list[str] = []

        for path in _all_paths():
            if not path.is_file() or _should_skip_secret_scan(path):
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
