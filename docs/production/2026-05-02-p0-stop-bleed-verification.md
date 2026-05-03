# P0 IM Stop-Bleed Verification Report

> Date: 2026-05-03 (Asia/Shanghai)
> Host: ubuntu@42.194.218.158
> Scope: release validation, secret-log scan, coturn TLS/DTLS, pending-call fallback defaults.
> Plan file name retained from 2026-05-02 planning session.

## Local Flutter Verification

- Command: `flutter test test/modules/video_call/call_runtime_recovery_test.dart`
- Result: PASS — `+23: All tests passed!`

## Local Script Verification

- Command: `python scripts/ops/tests/test_secret_log_scan.py`
  - Result: PASS — `Ran 12 tests ... OK`
- Command: `powershell ... Invoke-Pester ... remote_redeploy_release_gate.Tests.ps1`
  - Result: PASS — `Passed: 7 Failed: 0`
- Command: `powershell ... Invoke-Pester ... coturn_tls_probe_source.Tests.ps1`
  - Result: PASS — `Passed: 5 Failed: 0`
- Command: `D:\Apps\Git\bin\bash.exe -n scripts/ops/remote_redeploy.sh`
  - Result: PASS — exit `0`
- Command: `D:\Apps\Git\bin\bash.exe -n scripts/ops/coturn_tls_probe.sh`
  - Result: PASS — exit `0`
- Command: `python -m py_compile scripts/ops/secret_log_scan.py scripts/ops/tests/test_secret_log_scan.py`
  - Result: PASS — exit `0`

## Remote Release Validation

- Backup directory: `/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-20260503042155`
- Command: `cd /opt/wukongim-prod/src/deploy/production/scripts && python3 test_smoke_test.py && python3 test_perf_probe.py`
  - Result: PASS — smoke URL tests `Ran 6 tests ... OK`; perf URL tests `Ran 8 tests ... OK`
- Command: `python3 -m py_compile smoke_test.py perf_probe.py test_smoke_test.py test_perf_probe.py`
  - Result: PASS — exit `0`
- CLI validation spot-checks:
  - Public HTTP with `--allow-http-base-url`: exits `2`, emits concise `Use HTTPS` error, no `Traceback`.
  - Query/fragment base URLs: exits `2`, no `Traceback`.
- Command: `python3 scripts/smoke_test.py --base-url https://infoequity.qingyunshe.top --timeout 10`
  - Result: PASS — `smoke test passed`
- Command: `python3 scripts/perf_probe.py --base-url https://infoequity.qingyunshe.top --samples 3 --concurrency 1 --timeout 10`
  - Result: PASS — `request_count=6`, `failure_count=0`, `failure_rate=0.0`, `concurrency=1`

## Remote coturn Verification

- Backup directory: `/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-20260503085117`
- Pre-change evidence included:
  - `WARNING: Bad configuration format: no-loopback-peers`
  - `WARNING: cannot find private key file: /etc/coturn/certs/privkey.pem`
  - `WARNING: cannot start TLS and DTLS listeners because private key file is not set properly`
- Certificate copies:
  - `rendered/coturn-certs/fullchain.pem`: readable by coturn container
  - `rendered/coturn-certs/privkey.pem`: readable by coturn container; file metadata only recorded, key content not printed
- Config changes:
  - `no-loopback-peers` removed from `config/turnserver.conf.tpl` and `rendered/turnserver.conf`
  - `docker-compose.yaml` coturn mounts now use `./rendered/coturn-certs/fullchain.pem` and `./rendered/coturn-certs/privkey.pem`
- Command: `docker compose --env-file .env config >/tmp/p0-stop-bleed-compose.yaml`
  - Result: PASS — `COMPOSE_CONFIG_OK`
- Command: `docker compose --env-file .env up -d --no-deps coturn`
  - Result: PASS — coturn container `Up`
- Command: coturn cert readability + warning scan
  - Result: PASS — `CERT_READABLE`, `PRIVKEY_READABLE`, `COTURN_WARNINGS_CLEARED`
- Command: `/tmp/coturn_tls_probe.sh /opt/wukongim-prod/src/deploy/production`
  - Container identity: `uid=65534(nobody) gid=65534(nogroup)`
  - Cert/key readability: `CERT_READABLE`, `PRIVKEY_READABLE`
  - STUN 3478: PASS — UDP reflexive address returned for `127.0.0.1`
  - TURN UDP 3478: auth-specific failure — `Cannot complete Allocation`; coturn logs show test user credentials are not configured. This is not a TLS/cert failure.
  - TURNS 5349 TLS: PASS — `Protocol version: TLSv1.3`, `Ciphersuite: TLS_AES_256_GCM_SHA384`, `Verification: OK`

## Remote Secret Log Scan

- Command: tail-1000 scan from `tsdd-api`, `callgateway`, and `wukongim` piped through `scripts/ops/secret_log_scan.py`
  - Result: PASS — scanner exit `0`, no findings in the most recent 1000 log lines per service.
- Extended historical scan: tail-5000 scan from the same services
  - Result: FAIL — scanner exit `1`; historical `wukongim` logs include token verification failures with `expectToken=<redacted>` and `actToken=<redacted>`.
  - `tsdd-api`: no raw secret findings in scanned tail
  - `callgateway`: no raw secret findings in scanned tail
  - `wukongim`: historical raw token fields remain in Docker log history; scanner output redacted values and did not print raw token values.

## Remaining P0 Risk

WuKongIM official image `registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2` has emitted raw token fields (`expectToken`, `actToken`) in historical token verification failure logs. This Flutter repository cannot directly patch that binary image. Until the image/source path is remediated, release gates should run `scripts/ops/secret_log_scan.py` and treat new raw secret findings as release-blocking.

## Rollback Notes

- Remote release script rollback: restore `smoke_test.py`, `perf_probe.py`, and tests from `/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-20260503042155/scripts/`.
- coturn rollback: restore backed-up `docker-compose.yaml`, `turnserver.conf.tpl`, and `rendered/turnserver.conf` from `/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-20260503085117/`, then run `docker compose --env-file .env up -d --no-deps coturn`.
- Certificate copies in `rendered/coturn-certs/` can be removed after rollback if compose no longer references them.