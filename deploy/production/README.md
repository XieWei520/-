# Production deployment template snapshot

This directory is a sanitized snapshot of the production deployment template from:

`ubuntu@42.194.218.158:/opt/wukongim-prod/src/deploy/production`

It is intended to keep the deployment templates, operational scripts, and local safety tests under review without committing runtime state or secrets. The `wukongim-image/` directory is preserved from Tasks 1-3 and contains the patched-image bundle for the token-redaction work.

## Included file classes

- `docker-compose.yaml` and `.env.example` for the production template shape.
- `config/*.tpl` renderer inputs for WukongIM, TSDD, TURN, and LiveKit.
- `mysql/conf.d/production.cnf` production MySQL configuration.
- `nginx/*.conf*` Nginx template/config files.
- `scripts/*.py` and `scripts/*.sh` operational helpers, health checks, smoke/perf probes, migration helper, and backup/restore/bootstrap scripts.
- Selected allowlisted `scripts/test_*.py` script-level regression tests for the included operational helpers.
- `tests/test_production_snapshot_safety.py` repository safety checks for the snapshot.

## Explicitly excluded

Do not commit production runtime state or secrets here. Excluded classes include:

- `.env` and `.env.bak*` files.
- Rendered configs under `rendered/`.
- Runtime logs under `logs/`.
- Databases, object stores, or service state under `data/`.
- Backups under `backup/`.
- TLS certificates and private keys (`*.pem`, `*.key`) and real cert/key material.
- Built frontend/admin artifacts such as `manager/dist`, `nginx/html`, `admin/dist`, and `admin-custom/dist`.
- VCS metadata such as `admin-src/.git/`.
- Python bytecode/cache directories such as `__pycache__/` and `*.pyc`.

Secret-like example/template values are placeholders only. The snapshot sanitizes remote-specific TLS path values and uses placeholders for values such as LiveKit app keys, TURN TLS paths, and Nginx TLS paths.

## Local verification

From the repository root:

```powershell
python deploy/production/tests/test_production_snapshot_safety.py
python deploy/production/scripts/test_smoke_test.py
python deploy/production/scripts/test_perf_probe.py
python deploy/production/scripts/test_production_doctor.py
python -m py_compile deploy/production/scripts/render_config.py deploy/production/scripts/smoke_test.py deploy/production/scripts/perf_probe.py deploy/production/scripts/production_doctor.py deploy/production/tests/test_production_snapshot_safety.py
bash -n deploy/production/scripts/backup_mysql.sh deploy/production/scripts/restore_mysql.sh deploy/production/scripts/bootstrap_server.sh
```

If `bash` is not on `PATH` on Windows, prepend Git Bash first:

```powershell
$env:PATH='D:\Apps\Git\bin;'+$env:PATH
```

## Remote smoke/perf examples

Run these only from an operational context with authorized placeholder values supplied outside version control. Do not paste real secrets into commit messages, logs, or issue comments.

```bash
python scripts/smoke_test.py \
  --base-url https://infoequity.qingyunshe.top \
  --app-id <app-id> \
  --app-key <app-signing-secret> \
  --password <temporary-account-password>

python scripts/perf_probe.py \
  --base-url https://infoequity.qingyunshe.top \
  --app-id <app-id> \
  --app-key <app-signing-secret> \
  --password <temporary-account-password> \
  --samples 20 \
  --concurrency 4 \
  --setting-p95-limit-ms 500 \
  --favorites-p95-limit-ms 500
```

For a broader post-deploy check on the production host, configure `.env` locally on the host and run:

```bash
python scripts/production_doctor.py --env-file .env --perf-samples 20 --perf-concurrency 4
```
