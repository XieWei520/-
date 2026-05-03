# WuKongIM Token Redaction, Production Template, and Dirty Branch Cleanup Design

> Date: 2026-05-03 (Asia/Shanghai)
> Branch: `codex/wukongim-token-redaction-prod-template-cleanup`
> Source workspace: `C:\Users\COLORFUL\Desktop\WuKong`
> Remote host: `ubuntu@42.194.218.158`
> Remote production root: `/opt/wukongim-prod/src/deploy/production`

## 1. Objective

Complete the next production-readiness sequence in this exact order:

1. Fix the WuKongIM token log source so authentication failures no longer emit raw token values.
2. Solidify the current remote production deployment templates and operational scripts into the repository.
3. Clean the current dirty development branch without losing potentially valuable user work.

This design intentionally separates source remediation, deployment-template capture, and dirty-branch cleanup. The first two are implemented in the isolated worktree. The third operates against the original dirty workspace only after the production-safe artifacts are committed.

## 2. Evidence and Root Cause

Remote production currently runs WuKongIM from image `registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2`. Docker labels identify the image as WuKongIM `v2.2.4-20260313`, source revision `94b06a4694fa791604a26af3b7b6f279c42d7a12`, with image ID `sha256:fe13fca9ef635359910593ee17d10f1e582993e805e74321e8186b955710216b`.

The raw-token leakage is in upstream WuKongIM v2 source, not in this Flutter client repository and not in production YAML configuration. At source revision `94b06a4694fa791604a26af3b7b6f279c42d7a12`, `internal/user/handler/event_connect.go` logs authentication failures with raw token fields:

- manager connection failures include a raw `token` field;
- normal user connection failures include raw `expectToken` and `actToken` fields.

A check of WuKongIM `v2.2.5-20260422`, `latest`, and `origin/v2` shows the same v2 logging pattern remains. WuKongIM `origin/main` has moved to a different gateway path and does not show the same `actToken`/`expectToken` strings in the checked files, but that is not a low-risk drop-in upgrade for the current production v2 line.

## 3. Chosen Approach

Use a source fix plus a release gate:

1. Build a patched WuKongIM v2 image from the exact production upstream revision.
2. Replace raw token log fields with deterministic, non-secret fingerprints and contextual metadata.
3. Switch production to an explicit, immutable local patched image tag.
4. Keep `scripts/ops/secret_log_scan.py` in the deployment gate to prevent regression.

This approach is preferred over log filtering because it fixes the application source that emits the secret. Log filtering may remain a defense-in-depth option, but it must not be the primary remediation.

## 4. WuKongIM Source Remediation Design

### 4.1 Source and Patch Ownership

The repository will gain a small, auditable production image build bundle under:

```text
deploy/production/wukongim-image/
```

Planned files:

```text
deploy/production/wukongim-image/README.md
deploy/production/wukongim-image/upstream.env
deploy/production/wukongim-image/patches/0001-redact-connect-token-logs.patch
deploy/production/wukongim-image/scripts/build_patched_image.sh
deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh
deploy/production/wukongim-image/scripts/verify_patch_static.py
deploy/production/wukongim-image/tests/test_verify_patch_static.py
```

`upstream.env` records the exact source of truth:

```text
WUKONGIM_UPSTREAM_REPO=https://github.com/WuKongIM/WuKongIM.git
WUKONGIM_UPSTREAM_COMMIT=94b06a4694fa791604a26af3b7b6f279c42d7a12
WUKONGIM_BASE_VERSION=v2.2.4-20260313
WUKONGIM_PATCHED_IMAGE=wukongim/wukongim:v2.2.4-redacted-20260503
```

### 4.2 Log Shape After Fix

The patched source must not include raw token values in authentication failure logs. The replacement fields are:

- `uid`
- `sourceNodeId`
- `deviceFlag` where available
- `stage`, using values such as `manager_token` or `device_token`
- `tokenHash` or `actualTokenHash`
- `expectedTokenHash` for device-token mismatch diagnostics

The fingerprint function uses SHA-256 and returns a short prefix such as the first 12 hexadecimal characters. Empty values are reported as `empty`; non-empty values are never printed directly. This is enough to correlate repeated failures without exposing the token.

### 4.3 Remote Deployment Flow

The production deployment script will perform the following in order:

1. Create a backup under `/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-<timestamp>`.
2. Save current `docker-compose.yaml`, `.env.example`, `config/*.tpl`, and relevant script files into that backup.
3. Clone or update the WuKongIM upstream source into a build directory under `/home/ubuntu/wukongim-build-src`.
4. Check out `94b06a4694fa791604a26af3b7b6f279c42d7a12`.
5. Apply `0001-redact-connect-token-logs.patch`.
6. Run the static patch verifier before build.
7. Build the Docker image with tag `wukongim/wukongim:v2.2.4-redacted-20260503`.
8. Patch production `docker-compose.yaml` to use the patched image for the `wukongim` service.
9. Run `docker compose --env-file .env config`.
10. Restart only the `wukongim` service with `docker compose --env-file .env up -d --no-deps wukongim`.
11. Verify the container image tag and health status.
12. Run recent log scans from a post-restart window. Historical Docker log lines may still contain old findings; post-restart findings are release-blocking.

The rollback path restores the backed-up `docker-compose.yaml` and restarts only `wukongim`.

## 5. Production Template Solidification Design

The repository will gain a canonical production deployment snapshot under:

```text
deploy/production/
```

The snapshot includes source-controlled, non-secret deployment assets:

```text
deploy/production/README.md
deploy/production/docker-compose.yaml
deploy/production/.env.example
deploy/production/config/wk.yaml.tpl
deploy/production/config/tsdd.yaml.tpl
deploy/production/config/turnserver.conf.tpl
deploy/production/config/livekit.yaml.tpl
deploy/production/mysql/conf.d/production.cnf
deploy/production/nginx/default.conf.template
deploy/production/nginx/nginx.conf
deploy/production/scripts/render_config.py
deploy/production/scripts/smoke_test.py
deploy/production/scripts/perf_probe.py
deploy/production/scripts/production_doctor.py
deploy/production/scripts/edge_health_check.py
deploy/production/scripts/mysql_health_check.py
deploy/production/scripts/call_stack_smoke.py
deploy/production/scripts/apply_device_flag_migration.py
deploy/production/scripts/backup_mysql.sh
deploy/production/scripts/restore_mysql.sh
deploy/production/scripts/bootstrap_server.sh
deploy/production/scripts/test_*.py
```

The snapshot excludes runtime or secret-bearing material:

```text
.env
.env.bak*
rendered/
logs/
data/
backup/
manager/dist*/
nginx/html*/
admin/dist*/
admin-custom/dist*/
admin-src/.git/
*.pem
*.key
__pycache__/
```

The README will document the remote source path, the exclusions, the render/test sequence, and the release-gate commands. Template tests run locally against the repository copy so production drift becomes visible before future remote changes.

## 6. Dirty Branch Cleanup Design

The original workspace remains at:

```text
C:\Users\COLORFUL\Desktop\WuKong
```

Current branch there is `codex/customer-service-entry-personal-routing` and is intentionally dirty. Cleanup must be non-destructive:

1. Export a safety patch of staged and unstaged tracked changes.
2. Export a file list and archive of untracked files.
3. Capture `git status --short --branch`, staged names, unstaged names, and untracked names into a cleanup report.
4. Remove tool/runtime pollution from the index and working tree when it is safe to do so, especially `.gsd/`, `.bg-shell/`, and transient audit shell scripts.
5. Preserve product changes in a named stash or coherent branch commit, depending on what the user wants after reviewing the cleanup report.
6. Keep the main production remediation branch independent from the dirty feature branch.

The cleanup task will not delete user work without a restorable backup and explicit final confirmation for any irreversible action.

## 7. Verification Plan

Local verification in the implementation worktree:

- `python deploy/production/wukongim-image/tests/test_verify_patch_static.py`
- `python scripts/ops/tests/test_secret_log_scan.py`
- `python -m py_compile` for new Python scripts
- shell syntax checks for new shell scripts
- production-template Python tests copied under `deploy/production/scripts/test_*.py`

Remote verification on `ubuntu@42.194.218.158`:

- `docker compose --env-file .env config`
- patched image build success
- `docker compose --env-file .env up -d --no-deps wukongim`
- `docker compose --env-file .env ps wukongim`
- `docker inspect` confirming the patched image tag
- recent `wukongim` logs scanned through `scripts/ops/secret_log_scan.py`
- release smoke test over HTTPS public base URL

Dirty branch verification:

- backup files exist and are readable
- original dirty changes are recoverable from patch/archive/stash
- final `git status --short --branch` reflects the user-approved cleanup target

## 8. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Upstream WuKongIM build is slow or web asset build fails | Build from the exact upstream Dockerfile first; if the web asset step fails due registry availability, document the failing command and switch to a minimal binary-only build only after preserving equivalent embedded assets strategy. |
| Production restart causes IM disruption | Restart only `wukongim`, preserve compose backup, verify health immediately, and keep rollback command ready. |
| Historical Docker logs still contain raw token findings | Use post-restart `--since` windows for source-fix verification and document historical residue separately. |
| Template snapshot accidentally includes secrets | Use explicit allowlist plus denylist, scan copied files for secret field patterns, and never copy `.env`, certs, rendered config, logs, data, or backups. |
| Dirty branch cleanup loses user work | Create patch/archive/stash before cleanup and avoid irreversible deletion until the restore path is verified. |

## 9. Acceptance Criteria

- WuKongIM patched source no longer contains raw token fields in connection-auth failure logs.
- Production `wukongim` runs the patched image tag after backup and compose validation.
- Recent post-restart logs have no raw `actToken`, `expectToken`, manager token, password, secret, credential, or authorization findings when scanned.
- `deploy/production/` contains non-secret production templates and tests that can be used for future remote deployments.
- The original dirty branch is backed up and cleaned according to the user-approved cleanup mode.
