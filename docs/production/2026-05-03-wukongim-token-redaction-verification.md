# WuKongIM Token Redaction Deployment Verification

> Date: 2026-05-03 (Asia/Shanghai)  
> Host: `ubuntu@42.194.218.158`  
> Scope: patched WuKongIM image build, compose switch, recent secret-log scan, HTTPS smoke/perf checks.  
> Reader: an operator who needs to confirm which image is running and how to roll back safely.

## Summary

- Patched image now running: `wukongim/wukongim:v2.2.4-redacted-20260503`.
- Production compose backup created: `/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-20260503213116-2325673`.
- Recent post-restart `wukongim` logs scanned with `scripts/ops/secret_log_scan.py`: PASS, scanner exit `0`.
- HTTPS smoke and perf probes: PASS, `failure_rate=0.0`.

## Build Evidence

The original remote build script first attempted to clone upstream source directly on the production host. That path timed out because the host-side GitHub source fetch did not finish in the local command window. A second direct archive fetch attempt against the upstream commit also timed out. The stale fetch/build processes were terminated before continuing.

To avoid waiting on production-host GitHub transfer, the pinned upstream source (`94b06a4694fa791604a26af3b7b6f279c42d7a12`) was fetched locally, patched, statically verified, packaged, and uploaded to the production host.

Local pre-upload source verification:

```text
WuKongIM token log patch static verification passed
```

Remote source verification before image build:

```text
WuKongIM token log patch static verification passed
```

The upstream Dockerfile builds demo/web frontend assets through Yarn before compiling the Go server. That path was not used for the final production patch image because it had already blocked on external package/source fetches, while this change only replaces the Go server binary containing the token-log redaction patch.

Final image build used the patched source and a minimal Dockerfile. The reproducible version of that Dockerfile is now committed at `deploy/production/wukongim-image/Dockerfile.patched-binary`; `deploy/production/wukongim-image/scripts/build_patched_image.sh` builds with it after applying and statically verifying the redaction patch. The Dockerfile:

1. compiled `/home/app` from the patched Go source;
2. kept the upstream generated `web/dist` in the Docker context so Go embed succeeds;
3. used `registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2` as the runtime base; and
4. copied only the patched `/home/app` into that base image.

Remote build result:

```text
Successfully built c021f47b6e98
Successfully tagged wukongim/wukongim:v2.2.4-redacted-20260503
id=sha256:c021f47b6e98c28ae6b52314bf9198b15f761956396231ab452b244e27c85436 created=2026-05-03T13:28:52.348931738Z size=200343012
```

Post-review reproducibility check from the committed build path (`2026-05-03 22:20 +08:00`):

```bash
WUKONGIM_BUILD_ROOT=/home/ubuntu/wukongim-build-src-uploaded \
WUKONGIM_SKIP_FETCH=1 \
  bash /tmp/wukongim-committed-build-check/wukongim-image/scripts/build_patched_image.sh
```

Result:

```text
WuKongIM token log patch static verification passed
Successfully built 0077ec62cf26
Successfully tagged wukongim/wukongim:v2.2.4-redacted-20260503
id=sha256:0077ec62cf269685a5542238fc42a8bf9cbe05a1f52c5cc161b704f106594b36 created=2026-05-03T14:20:12.225864224Z size=200338916
```

## Deployment Evidence

The patch bundle was uploaded under the production tree and normalized to LF line endings before execution. The apply script was executed with an explicit production root:

```bash
WUKONGIM_PROD_ROOT=/opt/wukongim-prod/src/deploy/production \
  bash deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh
```

Result:

```text
[wukongim-apply] Checking patched image exists: wukongim/wukongim:v2.2.4-redacted-20260503
[wukongim-apply] Created deployment backup at /home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-20260503213116-2325673
[wukongim-apply] Updating wukongim image in /opt/wukongim-prod/src/deploy/production/docker-compose.yaml
[wukongim-apply] Validating compose configuration
[wukongim-apply] wukongim service is running
BACKUP_DIR=/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-20260503213116-2325673
PATCHED_IMAGE=wukongim/wukongim:v2.2.4-redacted-20260503
```

Compose emitted an existing orphan-container warning for `wukongim_prod-admin-nginx-1`; it did not block the `wukongim` recreate.

## Container and Recent Log Verification

Command:

```bash
cd /opt/wukongim-prod/src/deploy/production
docker compose --env-file .env ps wukongim
docker inspect wukongim_prod-wukongim-1 --format '{{.Config.Image}} {{.State.Status}} {{.State.Health.Status}}'
docker compose --env-file .env logs --since 5m wukongim > /tmp/wukongim-post-restart.log
python3 /tmp/wukongim-redaction-tools/secret_log_scan.py --source wukongim-post-restart /tmp/wukongim-post-restart.log
```

Result:

```text
wukongim_prod-wukongim-1   wukongim/wukongim:v2.2.4-redacted-20260503   Up ... (healthy)
wukongim/wukongim:v2.2.4-redacted-20260503 running healthy
58 /tmp/wukongim-post-restart.log
scanner_rc=0
```

Only recent post-restart logs were used for the release gate. Older Docker log history can still contain historical raw-token failures from the previous official image and should not be used as proof of the patched image behavior.

## HTTPS Smoke and Perf Verification

Command:

```bash
cd /opt/wukongim-prod/src/deploy/production
python3 scripts/smoke_test.py --base-url https://infoequity.qingyunshe.top --timeout 10
python3 scripts/perf_probe.py --base-url https://infoequity.qingyunshe.top --samples 3 --concurrency 1 --timeout 10
```

Result:

```text
smoke test passed
{"setting_count": 3, "setting_avg_ms": 32.86, "setting_p95_ms": 28.49, "setting_max_ms": 43.8, "favorites_count": 3, "favorites_avg_ms": 22.05, "favorites_p95_ms": 21.69, "favorites_max_ms": 23.07, "request_count": 6, "failure_count": 0, "failure_rate": 0.0, "concurrency": 1}
```

## Rollback

Rollback assets are under:

```text
/home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-20260503213116-2325673
```

To roll back the compose image selection:

```bash
cd /opt/wukongim-prod/src/deploy/production
cp /home/ubuntu/wukong-deploy-backups/wukongim-token-redaction-20260503213116-2325673/docker-compose.yaml docker-compose.yaml
docker compose --env-file .env up -d --no-deps wukongim
docker compose --env-file .env ps wukongim
```

Then scan only a fresh post-rollback log window and run smoke/perf again before declaring rollback complete.

## Follow-up Note

The production-host source fetch and the upstream full Dockerfile path were not reliable enough for this deployment window. The checked-in build path now supports the verified binary-only Dockerfile and a pre-fetched source tree:

```bash
WUKONGIM_BUILD_ROOT=/path/to/pinned-source \
WUKONGIM_SKIP_FETCH=1 \
  bash deploy/production/wukongim-image/scripts/build_patched_image.sh
```

When `WUKONGIM_SKIP_FETCH=1` is not set, the script still performs the normal clone/fetch path for hosts with reliable access to the upstream repository.
