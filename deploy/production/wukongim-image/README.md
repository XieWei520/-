# WuKongIM Patched Production Image

This directory owns the production WuKongIM v2 image patch that removes raw token values from authentication failure logs.

Production before the patch used `registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2`, labeled `v2.2.4-20260313` at commit `94b06a4694fa791604a26af3b7b6f279c42d7a12`.

The patched image tag is `wukongim/wukongim:v2.2.4-redacted-20260503`.

Verify an already-patched WuKongIM source tree from the repository root:

```bash
python deploy/production/wukongim-image/scripts/verify_patch_static.py <patched-wukongim-source-root>
```

Build the patched image from the repository root:

```bash
bash deploy/production/wukongim-image/scripts/build_patched_image.sh
```

The build script pins the upstream commit, applies `patches/0001-redact-connect-token-logs.patch`, runs the static verifier, and then builds with the committed `Dockerfile.patched-binary`. That Dockerfile compiles only the patched Go server binary and copies it into the official WuKongIM v2 runtime base, avoiding the upstream Yarn/demo/web build path. The source checkout must still contain upstream `web/dist` files because WuKongIM embeds those assets at Go compile time; the script removes a `web/dist` entry from the upstream `.dockerignore` before `docker build` when needed.

If the source tree was pre-uploaded or pre-fetched on a host without reliable GitHub access, use:

```bash
WUKONGIM_BUILD_ROOT=/path/to/pinned-source \
WUKONGIM_SKIP_FETCH=1 \
  bash deploy/production/wukongim-image/scripts/build_patched_image.sh
```

Apply the patched image from the repository root:

```bash
bash deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh
```

Verify recent logs after restart:

```bash
docker compose --env-file .env logs --since 5m wukongim | python3 /tmp/wukongim-redaction-tools/secret_log_scan.py --source wukongim-post-restart
```
