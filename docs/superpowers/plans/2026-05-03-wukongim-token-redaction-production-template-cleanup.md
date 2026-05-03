# WuKongIM Token Redaction, Production Template, and Dirty Branch Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix WuKongIM token leakage at the source, commit non-secret production deployment templates, deploy the patched image safely, then clean the original dirty workspace without losing work.

**Architecture:** Add a repository-owned WuKongIM image patch bundle pinned to the production upstream commit; verify the patch statically before any build; build and apply the patched image on the production host with rollback backup. Capture the remote production deployment as an allowlisted, non-secret `deploy/production/` snapshot with tests. Clean the original dirty branch only after patch/archive/stash backups are created and verified.

**Tech Stack:** Git, PowerShell, Bash, Python `unittest`, Docker Compose, SSH, WuKongIM Go source, existing `scripts/ops/secret_log_scan.py`.

---

## File Structure

Implementation worktree:

`C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\wukongim-token-redaction-prod-template-cleanup`

Create:

- `deploy/production/wukongim-image/README.md` — operator notes for the patched WuKongIM image.
- `deploy/production/wukongim-image/upstream.env` — upstream repo, commit, base version, patched image tag.
- `deploy/production/wukongim-image/patches/0001-redact-connect-token-logs.patch` — source fix.
- `deploy/production/wukongim-image/scripts/verify_patch_static.py` — static verifier.
- `deploy/production/wukongim-image/scripts/build_patched_image.sh` — remote image build script.
- `deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh` — remote compose switch script.
- `deploy/production/wukongim-image/tests/test_verify_patch_static.py` — verifier tests.
- `deploy/production/README.md` and allowlisted production snapshot files.
- `deploy/production/tests/test_production_snapshot_safety.py` — snapshot secret/path guard.
- `docs/production/2026-05-03-wukongim-token-redaction-verification.md` — deployment proof.
- `docs/production/2026-05-03-dirty-branch-cleanup.md` — cleanup proof.

External dirty-branch backup directory:

`C:\Users\COLORFUL\Desktop\WuKong-cleanup-backups\20260503-wukong-dirty-branch`

---

## Task 1: Static Verifier for Patched WuKongIM Source

**Files:**
- Create: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\wukongim-token-redaction-prod-template-cleanup\deploy\production\wukongim-image\scripts\verify_patch_static.py`
- Create: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\wukongim-token-redaction-prod-template-cleanup\deploy\production\wukongim-image\tests\test_verify_patch_static.py`

- [ ] **Step 1: Write the failing verifier tests**

Create `deploy/production/wukongim-image/tests/test_verify_patch_static.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "verify_patch_static.py"


class VerifyPatchStaticTests(unittest.TestCase):
    def _write_source(self, body: str) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        source = root / "internal" / "user" / "handler"
        source.mkdir(parents=True)
        (source / "event_connect.go").write_text(textwrap.dedent(body), encoding="utf-8")
        return root

    def _run(self, root: Path) -> subprocess.CompletedProcess[bytes]:
        return subprocess.run([sys.executable, str(SCRIPT), str(root)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def test_rejects_raw_act_and_expect_token_fields(self) -> None:
        root = self._write_source('''
            package handler
            import "go.uber.org/zap"
            func f() {
                h.Error("token verify fail", zap.String("expectToken", device.Token), zap.String("actToken", connectPacket.Token))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"expectToken", result.stderr)
        self.assertIn(b"actToken", result.stderr)

    def test_rejects_manager_raw_token_field(self) -> None:
        root = self._write_source('''
            package handler
            import "go.uber.org/zap"
            func f() {
                h.Error("manager token verify fail", zap.String("token", connectPacket.Token))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 1)
        self.assertIn(b"manager raw token", result.stderr.lower())

    def test_accepts_hash_only_redacted_logging(self) -> None:
        root = self._write_source('''
            package handler
            import (
                "crypto/sha256"
                "encoding/hex"
                "go.uber.org/zap"
            )
            func tokenFingerprint(token string) string {
                if token == "" { return "empty" }
                sum := sha256.Sum256([]byte(token))
                return hex.EncodeToString(sum[:])[:12]
            }
            func f() {
                h.Error("manager token verify fail", zap.String("stage", "manager_token"), zap.String("tokenHash", tokenFingerprint(connectPacket.Token)))
                h.Error("token verify fail", zap.String("stage", "device_token"), zap.String("expectedTokenHash", tokenFingerprint(device.Token)), zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)))
            }
        ''')
        result = self._run(root)
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", errors="replace"))
        self.assertEqual(result.stdout, b"WuKongIM token log patch static verification passed\n")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```powershell
python deploy/production/wukongim-image/tests/test_verify_patch_static.py
```

Expected: FAIL because `verify_patch_static.py` does not exist.

- [ ] **Step 3: Implement the verifier**

Create `deploy/production/wukongim-image/scripts/verify_patch_static.py`:

```python
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
    print("WuKongIM token log patch static verification passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```powershell
python deploy/production/wukongim-image/tests/test_verify_patch_static.py
python -m py_compile deploy/production/wukongim-image/scripts/verify_patch_static.py
```

Expected: `Ran 3 tests ... OK`, then `py_compile` exits 0.

- [ ] **Step 5: Commit**

```powershell
git add deploy/production/wukongim-image/scripts/verify_patch_static.py deploy/production/wukongim-image/tests/test_verify_patch_static.py
git commit -m "test: verify wukongim token log redaction patch"
```

---

## Task 2: WuKongIM Patch Bundle

**Files:**
- Create: `deploy/production/wukongim-image/upstream.env`
- Create: `deploy/production/wukongim-image/patches/0001-redact-connect-token-logs.patch`
- Create: `deploy/production/wukongim-image/README.md`

- [ ] **Step 1: Create upstream pin**

Create `deploy/production/wukongim-image/upstream.env`:

```bash
WUKONGIM_UPSTREAM_REPO=https://github.com/WuKongIM/WuKongIM.git
WUKONGIM_UPSTREAM_COMMIT=94b06a4694fa791604a26af3b7b6f279c42d7a12
WUKONGIM_BASE_VERSION=v2.2.4-20260313
WUKONGIM_PATCHED_IMAGE=wukongim/wukongim:v2.2.4-redacted-20260503
```

- [ ] **Step 2: Create source patch**

Create `deploy/production/wukongim-image/patches/0001-redact-connect-token-logs.patch` by applying these exact source edits to upstream `internal/user/handler/event_connect.go` and then exporting `git diff`:

```go
import (
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"time"
)
```

Replace the manager token failure log with:

```go
h.Error("manager token verify fail",
	zap.String("uid", uid),
	zap.Uint64("sourceNodeId", event.SourceNodeId),
	zap.String("stage", "manager_token"),
	zap.String("tokenHash", tokenFingerprint(connectPacket.Token)),
)
```

Replace the device token mismatch log with:

```go
h.Error("token verify fail",
	zap.String("uid", uid),
	zap.Uint64("sourceNodeId", event.SourceNodeId),
	zap.String("deviceFlag", connectPacket.DeviceFlag.String()),
	zap.String("stage", "device_token"),
	zap.String("expectedTokenHash", tokenFingerprint(device.Token)),
	zap.String("actualTokenHash", tokenFingerprint(connectPacket.Token)),
)
```

Add below `handleConnect`:

```go
func tokenFingerprint(token string) string {
	if token == "" {
		return "empty"
	}
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])[:12]
}
```

Export the patch:

```powershell
$src = 'C:\Users\COLORFUL\.codex\tmp\WuKongIM-src'
git -C $src checkout --detach 94b06a4694fa791604a26af3b7b6f279c42d7a12
git -C $src reset --hard
# edit internal/user/handler/event_connect.go exactly as shown above
git -C $src diff -- internal/user/handler/event_connect.go > deploy/production/wukongim-image/patches/0001-redact-connect-token-logs.patch
```

- [ ] **Step 3: Verify patch applies and passes static verifier**

Run:

```powershell
$src = 'C:\Users\COLORFUL\.codex\tmp\WuKongIM-src'
git -C $src checkout --detach 94b06a4694fa791604a26af3b7b6f279c42d7a12
git -C $src reset --hard
git -C $src apply C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\wukongim-token-redaction-prod-template-cleanup\deploy\production\wukongim-image\patches\0001-redact-connect-token-logs.patch
python deploy/production/wukongim-image/scripts/verify_patch_static.py $src
```

Expected: `WuKongIM token log patch static verification passed`.

- [ ] **Step 4: Create README**

Create `deploy/production/wukongim-image/README.md`:

```markdown
# WuKongIM Patched Production Image

This directory owns the production WuKongIM v2 image patch that removes raw token values from authentication failure logs.

Production before the patch used `registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2`, labeled `v2.2.4-20260313` at commit `94b06a4694fa791604a26af3b7b6f279c42d7a12`.

The patched image tag is `wukongim/wukongim:v2.2.4-redacted-20260503`.

Build on the production host:

```bash
cd /opt/wukongim-prod/src/deploy/production
bash deploy/production/wukongim-image/scripts/build_patched_image.sh
```

Apply on the production host:

```bash
cd /opt/wukongim-prod/src/deploy/production
bash deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh
```

Verify recent logs after restart:

```bash
docker compose --env-file .env logs --since 5m wukongim | python3 /tmp/wukongim-redaction-tools/secret_log_scan.py --source wukongim-post-restart
```
```

- [ ] **Step 5: Commit**

```powershell
git add deploy/production/wukongim-image/upstream.env deploy/production/wukongim-image/patches/0001-redact-connect-token-logs.patch deploy/production/wukongim-image/README.md
git commit -m "fix: define wukongim token log redaction patch"
```

---

## Task 3: Remote Build and Apply Scripts

**Files:**
- Create: `deploy/production/wukongim-image/scripts/build_patched_image.sh`
- Create: `deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh`

- [ ] **Step 1: Create build script**

Create `deploy/production/wukongim-image/scripts/build_patched_image.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${IMAGE_DIR}/upstream.env"
BUILD_ROOT="${WUKONGIM_BUILD_ROOT:-/home/ubuntu/wukongim-build-src}"
PATCH_FILE="${IMAGE_DIR}/patches/0001-redact-connect-token-logs.patch"
VERIFY_SCRIPT="${IMAGE_DIR}/scripts/verify_patch_static.py"
log() { printf '[wukongim-image] %s\n' "$*"; }
[[ -f "${PATCH_FILE}" ]] || { echo "error: missing ${PATCH_FILE}" >&2; exit 2; }
[[ -f "${VERIFY_SCRIPT}" ]] || { echo "error: missing ${VERIFY_SCRIPT}" >&2; exit 2; }
if [[ -d "${BUILD_ROOT}/.git" ]]; then
  git -C "${BUILD_ROOT}" fetch --tags --prune origin
else
  rm -rf "${BUILD_ROOT}"
  git clone "${WUKONGIM_UPSTREAM_REPO}" "${BUILD_ROOT}"
fi
git -C "${BUILD_ROOT}" checkout --detach "${WUKONGIM_UPSTREAM_COMMIT}"
git -C "${BUILD_ROOT}" reset --hard
git -C "${BUILD_ROOT}" apply "${PATCH_FILE}"
python3 "${VERIFY_SCRIPT}" "${BUILD_ROOT}"
docker build -t "${WUKONGIM_PATCHED_IMAGE}" "${BUILD_ROOT}"
docker image inspect "${WUKONGIM_PATCHED_IMAGE}" --format 'id={{.Id}} created={{.Created}} size={{.Size}}'
log "Built image: ${WUKONGIM_PATCHED_IMAGE}"
```

- [ ] **Step 2: Create apply script**

Create `deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROD_ROOT="$(cd "${IMAGE_DIR}/../.." && pwd)"
source "${IMAGE_DIR}/upstream.env"
COMPOSE_FILE="${PROD_ROOT}/docker-compose.yaml"
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_DIR="/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-${STAMP}"
log() { printf '[wukongim-apply] %s\n' "$*"; }
[[ -f "${COMPOSE_FILE}" ]] || { echo "error: missing ${COMPOSE_FILE}" >&2; exit 2; }
docker image inspect "${WUKONGIM_PATCHED_IMAGE}" >/dev/null
mkdir -p "${BACKUP_DIR}/config" "${BACKUP_DIR}/scripts" "${BACKUP_DIR}/wukongim-image"
cp "${COMPOSE_FILE}" "${BACKUP_DIR}/docker-compose.yaml"
cp "${PROD_ROOT}/.env.example" "${BACKUP_DIR}/.env.example" 2>/dev/null || true
cp "${PROD_ROOT}"/config/*.tpl "${BACKUP_DIR}/config/" 2>/dev/null || true
cp "${PROD_ROOT}"/scripts/*.py "${BACKUP_DIR}/scripts/" 2>/dev/null || true
cp -R "${IMAGE_DIR}/." "${BACKUP_DIR}/wukongim-image/"
python3 - "${COMPOSE_FILE}" "${WUKONGIM_PATCHED_IMAGE}" <<'PY'
from pathlib import Path
import re
import sys
compose = Path(sys.argv[1])
image = sys.argv[2]
text = compose.read_text(encoding="utf-8")
pattern = re.compile(r'(?ms)^(\s*wukongim:\n(?:(?!^\s{2}[A-Za-z0-9_-]+:).)*?^\s*image:\s*).*$')
new_text, count = pattern.subn(rf'\1{image}', text, count=1)
if count != 1:
    raise SystemExit("error: could not replace wukongim image")
compose.write_text(new_text, encoding="utf-8")
PY
cd "${PROD_ROOT}"
docker compose --env-file .env config >/tmp/wukongim-token-redaction-compose.yaml
docker compose --env-file .env up -d --no-deps wukongim
echo "BACKUP_DIR=${BACKUP_DIR}"
echo "PATCHED_IMAGE=${WUKONGIM_PATCHED_IMAGE}"
```

- [ ] **Step 3: Run syntax checks**

```powershell
bash -n deploy/production/wukongim-image/scripts/build_patched_image.sh
bash -n deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh
```

Expected: both exit 0.

- [ ] **Step 4: Commit**

```powershell
git add deploy/production/wukongim-image/scripts/build_patched_image.sh deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh
git commit -m "ops: add wukongim patched image deployment scripts"
```

---

## Task 4: Production Template Snapshot and Safety Test

**Files:**
- Populate: `deploy/production/`
- Create: `deploy/production/tests/test_production_snapshot_safety.py`

- [ ] **Step 1: Write failing snapshot safety test**

Create `deploy/production/tests/test_production_snapshot_safety.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED_FILES = [
    "README.md", "docker-compose.yaml", ".env.example",
    "config/wk.yaml.tpl", "config/tsdd.yaml.tpl", "config/turnserver.conf.tpl", "config/livekit.yaml.tpl",
    "mysql/conf.d/production.cnf", "nginx/default.conf.template", "nginx/nginx.conf",
    "scripts/render_config.py", "scripts/smoke_test.py", "scripts/perf_probe.py", "scripts/production_doctor.py",
    "scripts/edge_health_check.py", "scripts/mysql_health_check.py", "scripts/call_stack_smoke.py",
    "scripts/apply_device_flag_migration.py", "scripts/backup_mysql.sh", "scripts/restore_mysql.sh", "scripts/bootstrap_server.sh",
    "scripts/test_smoke_test.py", "scripts/test_perf_probe.py", "scripts/test_production_doctor.py",
]
DENIED_PARTS = ("/rendered/", "/logs/", "/data/", "/backup/", "/__pycache__/", "/admin-src/.git/", "/manager/dist", "/nginx/html", "/admin/dist", "/admin-custom/dist")
DENIED_SUFFIXES = (".pem", ".key", ".pyc")
SECRET_VALUE_RE = re.compile(r"(?im)^\s*[A-Z0-9_]*(?:PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)[A-Z0-9_]*\s*=\s*(?!\$\{|<|changeme|change-me|example|your-|$).{8,}$")


class ProductionSnapshotSafetyTests(unittest.TestCase):
    def test_required_files_exist(self) -> None:
        self.assertEqual([p for p in REQUIRED_FILES if not (ROOT / p).is_file()], [])

    def test_runtime_and_secret_paths_are_excluded(self) -> None:
        bad: list[str] = []
        for path in ROOT.rglob("*"):
            if not path.is_file():
                continue
            rel = path.relative_to(ROOT).as_posix()
            wrapped = f"/{rel}"
            if path.name == ".env" or path.name.startswith(".env.bak") or rel.endswith(DENIED_SUFFIXES) or any(part in wrapped for part in DENIED_PARTS):
                bad.append(rel)
        self.assertEqual(sorted(set(bad)), [])

    def test_no_literal_secret_values_in_snapshot(self) -> None:
        findings: list[str] = []
        for path in ROOT.rglob("*"):
            if path.is_file() and not path.relative_to(ROOT).as_posix().startswith("tests/"):
                text = path.read_text(encoding="utf-8", errors="replace")
                findings.extend(f"{path.relative_to(ROOT).as_posix()}: {m.group(0)}" for m in SECRET_VALUE_RE.finditer(text))
        self.assertEqual(findings, [])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run test and confirm it fails before snapshot is populated**

```powershell
python deploy/production/tests/test_production_snapshot_safety.py
```

Expected: FAIL with missing required files.

- [ ] **Step 3: Copy allowlisted remote files to a staging directory**

```powershell
$stage = 'C:\Users\COLORFUL\.codex\tmp\wukong-production-snapshot-20260503'
Remove-Item -Recurse -Force $stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stage | Out-Null
scp -r ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/docker-compose.yaml $stage\
scp -r ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/.env.example $stage\
scp -r ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/config $stage\config
scp -r ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/mysql $stage\mysql
scp -r ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/nginx $stage\nginx
scp -r ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/scripts $stage\scripts
```

- [ ] **Step 4: Populate repository snapshot using the allowlist**

Copy only these files from `$stage` into `deploy/production/`: `docker-compose.yaml`, `.env.example`, `config/*.tpl`, `mysql/conf.d/production.cnf`, `nginx/default.conf.template`, `nginx/nginx.conf`, and script files matching `render_config.py`, `smoke_test.py`, `perf_probe.py`, `production_doctor.py`, `edge_health_check.py`, `mysql_health_check.py`, `call_stack_smoke.py`, `apply_device_flag_migration.py`, `backup_mysql.sh`, `restore_mysql.sh`, `bootstrap_server.sh`, and `test_*.py`.

- [ ] **Step 5: Create snapshot README**

Create `deploy/production/README.md` documenting included files, excluded runtime/secret paths, local tests, and remote smoke/perf commands.

- [ ] **Step 6: Run snapshot tests**

```powershell
python deploy/production/tests/test_production_snapshot_safety.py
python deploy/production/scripts/test_smoke_test.py
python deploy/production/scripts/test_perf_probe.py
python deploy/production/scripts/test_production_doctor.py
python -m py_compile deploy/production/scripts/render_config.py deploy/production/scripts/smoke_test.py deploy/production/scripts/perf_probe.py deploy/production/scripts/production_doctor.py deploy/production/tests/test_production_snapshot_safety.py
bash -n deploy/production/scripts/backup_mysql.sh deploy/production/scripts/restore_mysql.sh deploy/production/scripts/bootstrap_server.sh
```

Expected: all exit 0.

- [ ] **Step 7: Commit**

```powershell
git add deploy/production
git commit -m "ops: add production deployment template snapshot"
```

---

## Task 5: Remote Deployment and Verification Report

**Files:**
- Create: `docs/production/2026-05-03-wukongim-token-redaction-verification.md`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`

- [ ] **Step 1: Upload patch bundle and scanner**

```powershell
ssh ubuntu@42.194.218.158 "mkdir -p /opt/wukongim-prod/src/deploy/production/deploy/production/wukongim-image /tmp/wukongim-redaction-tools"
scp -r deploy/production/wukongim-image/* ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production/deploy/production/wukongim-image/
scp scripts/ops/secret_log_scan.py ubuntu@42.194.218.158:/tmp/wukongim-redaction-tools/secret_log_scan.py
```

- [ ] **Step 2: Build patched image remotely**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && bash deploy/production/wukongim-image/scripts/build_patched_image.sh"
```

Expected: output includes `WuKongIM token log patch static verification passed` and `Built image: wukongim/wukongim:v2.2.4-redacted-20260503`.

- [ ] **Step 3: Apply patched image remotely**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && bash deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh"
```

Expected: output includes `BACKUP_DIR=/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-...`.

- [ ] **Step 4: Verify container and logs**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env config >/tmp/wukongim-token-redaction-compose-verify.yaml && docker compose --env-file .env ps wukongim && docker inspect wukongim_prod-wukongim-1 --format '{{.Config.Image}} {{.State.Status}} {{.State.Health.Status}}'"
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env logs --since 5m wukongim" | python scripts/ops/secret_log_scan.py --source wukongim-post-restart
```

Expected: patched image is running and scanner exits 0.

- [ ] **Step 5: Run HTTPS smoke/perf**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 scripts/smoke_test.py --base-url https://infoequity.qingyunshe.top --timeout 10 && python3 scripts/perf_probe.py --base-url https://infoequity.qingyunshe.top --samples 3 --concurrency 1 --timeout 10"
```

Expected: smoke passes and perf reports `failure_rate=0.0`.

- [ ] **Step 6: Write verification report and commit**

Create `docs/production/2026-05-03-wukongim-token-redaction-verification.md` with observed build, backup, image, scanner, smoke, perf, and rollback evidence. Then run:

```powershell
git add docs/production/2026-05-03-wukongim-token-redaction-verification.md
git commit -m "docs: verify wukongim token redaction deployment"
```

---

## Task 6: Original Dirty Branch Backup and Cleanup

**Files:**
- External backup: `C:\Users\COLORFUL\Desktop\WuKong-cleanup-backups\20260503-wukong-dirty-branch`
- Create: `docs/production/2026-05-03-dirty-branch-cleanup.md`

- [ ] **Step 1: Back up staged, unstaged, and untracked work**

```powershell
$main = 'C:\Users\COLORFUL\Desktop\WuKong'
$backup = 'C:\Users\COLORFUL\Desktop\WuKong-cleanup-backups\20260503-wukong-dirty-branch'
New-Item -ItemType Directory -Force -Path $backup | Out-Null
git -C $main status --short --branch | Tee-Object -FilePath "$backup\status-before.txt"
git -C $main diff --cached --binary > "$backup\staged.patch"
git -C $main diff --binary > "$backup\unstaged.patch"
git -C $main diff --cached --name-status > "$backup\staged-name-status.txt"
git -C $main diff --name-status > "$backup\unstaged-name-status.txt"
git -C $main ls-files --others --exclude-standard > "$backup\untracked-files.txt"
```

- [ ] **Step 2: Copy and zip untracked files**

```powershell
$main = 'C:\Users\COLORFUL\Desktop\WuKong'
$backup = 'C:\Users\COLORFUL\Desktop\WuKong-cleanup-backups\20260503-wukong-dirty-branch'
$archiveRoot = Join-Path $backup 'untracked-copy'
New-Item -ItemType Directory -Force -Path $archiveRoot | Out-Null
Get-Content "$backup\untracked-files.txt" | Where-Object { $_ -ne '' } | ForEach-Object {
  $src = Join-Path $main $_
  $dst = Join-Path $archiveRoot $_
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  if (Test-Path $src -PathType Leaf) { Copy-Item -Force $src $dst }
}
if (Test-Path "$archiveRoot\*") { Compress-Archive -Path "$archiveRoot\*" -DestinationPath "$backup\untracked-copy.zip" -Force }
```

- [ ] **Step 3: Stash and verify clean status**

```powershell
$main = 'C:\Users\COLORFUL\Desktop\WuKong'
git -C $main stash push --include-untracked -m "backup before wukongim token redaction cleanup 2026-05-03"
git -C $main stash list --date=local | Select-Object -First 5
git -C $main status --short --branch | Tee-Object -FilePath 'C:\Users\COLORFUL\Desktop\WuKong-cleanup-backups\20260503-wukong-dirty-branch\status-after-stash.txt'
```

Expected: status shows only branch header.

- [ ] **Step 4: Write cleanup report and commit**

Create `docs/production/2026-05-03-dirty-branch-cleanup.md` recording backup path, stash message, status before/after, and recovery command. Then run:

```powershell
git add docs/production/2026-05-03-dirty-branch-cleanup.md
git commit -m "docs: record dirty branch cleanup backup"
```

---

## Task 7: Final Verification

**Files:** Verify all created files; no new code files expected.

- [ ] **Step 1: Run local verification matrix**

```powershell
python deploy/production/wukongim-image/tests/test_verify_patch_static.py
python deploy/production/tests/test_production_snapshot_safety.py
python scripts/ops/tests/test_secret_log_scan.py
python deploy/production/scripts/test_smoke_test.py
python deploy/production/scripts/test_perf_probe.py
python deploy/production/scripts/test_production_doctor.py
python -m py_compile deploy/production/wukongim-image/scripts/verify_patch_static.py deploy/production/scripts/render_config.py deploy/production/scripts/smoke_test.py deploy/production/scripts/perf_probe.py deploy/production/scripts/production_doctor.py deploy/production/tests/test_production_snapshot_safety.py
bash -n deploy/production/wukongim-image/scripts/build_patched_image.sh deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh deploy/production/scripts/backup_mysql.sh deploy/production/scripts/restore_mysql.sh deploy/production/scripts/bootstrap_server.sh
```

Expected: all commands exit 0.

- [ ] **Step 2: Re-check remote image and post-restart logs**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps wukongim && docker inspect wukongim_prod-wukongim-1 --format '{{.Config.Image}} {{.State.Status}} {{.State.Health.Status}}'"
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env logs --since 10m wukongim" | python scripts/ops/secret_log_scan.py --source wukongim-final-post-restart
```

Expected: patched image is running and scanner exits 0.

- [ ] **Step 3: Verify original workspace and implementation worktree status**

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong status --short --branch
git status --short --branch
git log --oneline -8
```

Expected: original workspace is clean; implementation worktree is clean with all task commits present.
