# Phase 5 Sync Backend Fast Paths Rollout

This runbook deploys the Phase 5 sync backend fast paths batch. It is backend-only: it deploys the `GET /v1/message/prohibit_words/sync` no-change fast path and the `prohibit_words(version)` index migration. It does not require a client release and does not change service topology.

The reader is the production operator applying the backend batch, validating the service, and rolling back if the 30-minute gate fails.

## Preconditions

Run the local verification commands before preparing or switching production:

```powershell
flutter test test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart
Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestSyncSensitiveWords|TestProhibit'
Pop-Location
```

Confirm the working tree contains only the intended backend fast-path artifacts before running the production sync command.

## Baseline PromQL

Capture a 30-minute baseline immediately before the switch. Keep the values with the rollout notes so the gate can compare post-switch behavior against current production.

API availability:

```promql
up{job="wukongim_api"}
```

Status class counts over 30 minutes:

```promql
sum by (status_class) (increase(wukongim_http_requests_total[30m]))
```

Top routes over 30 minutes:

```promql
topk(20, sum by (route, method) (increase(wukongim_http_requests_total[30m])))
```

Route latency p95 over 30 minutes:

```promql
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
```

Route latency p99 over 30 minutes:

```promql
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
```

Unknown route traffic over 30 minutes:

```promql
sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))
```

## Dry Run

Run the prepare script test path first:

```powershell
.\scripts\ops\phase5_sync_backend_fastpaths_prepare.ps1 -RunTests
```

Then run the dry run without production sync or build flags:

```powershell
.\scripts\ops\phase5_sync_backend_fastpaths_prepare.ps1
```

The prepare script allowlist must be exactly:

```text
modules/message/api.go
modules/message/db.go
modules/message/phase4_sync_load_test.go
modules/message/sql/message-20260529-01.sql
```

## Sync Source And Build

Run the production sync and image build only after the dry run output is clean:

```powershell
.\scripts\ops\phase5_sync_backend_fastpaths_prepare.ps1 -Run -AllowProductionSync -BuildImage -AllowProductionBuild
```

Record these output fields from the prepare script:

```text
phase5_sync_backend_fastpaths_sync_backup_dir
phase5_sync_backend_fastpaths_absent_files_manifest
phase5_sync_backend_fastpaths_build_context=verified
phase5_sync_backend_fastpaths_previous_image_tag=wukongim/tsdd-api:phase5-pre-<timestamp>
```

Do not proceed if `phase5_sync_backend_fastpaths_build_context` is not `verified`.

## Database Migration

Apply the additive index migration:

```sql
CREATE INDEX idx_prohibit_words_version ON prohibit_words (version);
```

Verify the index exists:

```sql
SELECT INDEX_NAME, TABLE_NAME, COLUMN_NAME, SEQ_IN_INDEX
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'prohibit_words'
  AND INDEX_NAME = 'idx_prohibit_words_version'
ORDER BY SEQ_IN_INDEX;
```

Expected result: one row for `idx_prohibit_words_version` on `prohibit_words.version`.

## Service Switch

Switch the backend service after the image build and migration verification complete:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

## Smoke Checks

Run the service and edge checks from the production host:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps tsdd-api callgateway nginx"
ssh ubuntu@42.194.218.158 "curl -k -fsS https://infoequity.cn/v1/ping"
```

The compose check must show `tsdd-api`, `callgateway`, and `nginx` running. The ping endpoint must return successfully.

## 30-Minute Gate

Watch the same PromQL used for the baseline for 30 minutes after the switch. The rollout passes only when all criteria hold:

- `up{job="wukongim_api"}` is `1`.
- 5xx status class traffic is `0`.
- Unknown route traffic is `0`.
- p95 and p99 latency are not materially regressed from the pre-switch baseline.
- `GET /v1/message/prohibit_words/sync` p95 and p99 are near baseline.

If any criterion fails, start rollback.

## Rollback

Use the recorded `phase5_sync_backend_fastpaths_previous_image_tag` to restore the previous API image:

```text
wukongim/tsdd-api:phase5-pre-<timestamp>
```

Use `phase5_sync_backend_fastpaths_sync_backup_dir` to restore the backend source files that were replaced by the production sync. If the prepare output recorded `phase5_sync_backend_fastpaths_absent_files_manifest`, use it to remove files that were absent before the sync and should not remain after rollback.

After restoring the previous source and image tag, rerun the service switch:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

Repeat the smoke checks and continue monitoring the 30-minute gate metrics until production returns to the pre-rollout baseline.

The additive `idx_prohibit_words_version` index can normally remain in place after rollback unless a verified database issue points to the index as the cause. If that happens, remove it only under the database rollback procedure approved for the incident.
