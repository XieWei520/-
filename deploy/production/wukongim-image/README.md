# WuKongIM Patched Production Image

This directory owns the production WuKongIM v2 image patch that removes raw token values from authentication failure logs.

At Task 2, this directory owns only the upstream pin, the patch, and the static patch verifier. The production build and apply scripts are added by Task 3.

Production before the patch used `registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2`, labeled `v2.2.4-20260313` at commit `94b06a4694fa791604a26af3b7b6f279c42d7a12`.

The patched image tag is `wukongim/wukongim:v2.2.4-redacted-20260503`.

Verify an already-patched WuKongIM source tree from the repository root:

```bash
python deploy/production/wukongim-image/scripts/verify_patch_static.py <patched-wukongim-source-root>
```

After Task 3 adds scripts, build the patched image from the repository root:

```bash
bash deploy/production/wukongim-image/scripts/build_patched_image.sh
```

After Task 3 adds scripts, apply the patched image from the repository root:

```bash
bash deploy/production/wukongim-image/scripts/apply_remote_wukongim_image.sh
```

Verify recent logs after restart:

```bash
docker compose --env-file .env logs --since 5m wukongim | python3 /tmp/wukongim-redaction-tools/secret_log_scan.py --source wukongim-post-restart
```
