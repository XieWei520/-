# Phase 3 Backend Optimization Rollout

This runbook deploys only the Phase 3 low-risk backend optimization batch:

- `/v1/users/:uid/im` 5-second route cache.
- `conversation/syncack` dedupe and cache cleanup.
- MinIO client reuse and bucket readiness cache.
- Storage operation metrics.

Do not deploy client builds, schema changes, or admin-dashboard changes as part of this batch.

## Preconditions

Run from the repository root on the operator workstation.

```powershell
git status --short
flutter test test/scripts/ops/phase3_backend_optimization_prepare_test.dart
```

Run backend verification from the local backend snapshot:

```powershell
Push-Location .codex-backend-work/src/serverlib
go test -count=1 ./pkg/metrics -run TestStorageOperationMetricsDoNotLeakObjectPaths
Pop-Location

Push-Location .codex-backend-work/src
go test -count=1 ./modules/user -run 'TestUserIM_'
go test -count=1 ./modules/message -run 'TestBuildUserLastOffsetsDedupesByChannelWithMaxSeq|TestClearSyncConversationCacheRemovesUserEntries'
go test -count=1 ./modules/file -run 'TestServiceMinioReusesClientAndBucketReadinessForUpload|TestMinio'
Pop-Location
```

## Baseline PromQL

Before syncing files, capture the current 30-minute production baseline in Prometheus:

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[30m]))
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
sum by (operation, result) (increase(wukongim_operation_total[30m]))
sum by (provider, operation, result) (increase(wukongim_storage_operation_total[30m]))
sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))
```

Expected before rollout:

- `up{job="wukongim_api"}` is `1`.
- 5xx count is `0` or unchanged from the pre-rollout baseline.
- `route="unknown"` stays at `0`.

## Dry Run

```powershell
.\scripts\ops\phase3_backend_optimization_prepare.ps1 -RunTests
.\scripts\ops\phase3_backend_optimization_prepare.ps1
```

The dry run prints the file manifest, verifies it against the reviewed Phase 3
manifest embedded in the script, and does not write production. Confirm the
allowlist contains only:

- `modules/user/api.go`
- `modules/user/api_im_route_test.go`
- `modules/message/api_conversation.go`
- `modules/message/api_conversation_syncack_test.go`
- `modules/file/service_minio.go`
- `modules/file/service_minio_test.go`
- `serverlib/pkg/metrics/metrics.go`
- `serverlib/pkg/metrics/metrics_test.go`

## Sync Source And Optional One-Shot Build

This copies the allowlisted files to `/opt/wukongim-prod/src` and creates a
timestamped backup. Use either one-shot sync+build, or sync then build-only.
Do not run a second sync just to build, because a second sync would create a
backup of already-updated source files.

```powershell
.\scripts\ops\phase3_backend_optimization_prepare.ps1 -Run -AllowProductionSync
```

Record the printed value:

```text
phase3_backend_optimization_sync_backup_dir=<remote backup dir>
```

Also record the absent-file manifest if printed:

```text
phase3_backend_optimization_absent_files_manifest=<remote backup dir>/.phase3_absent_files
```

For one-shot sync+build, run this command instead of the sync-only command:

```powershell
.\scripts\ops\phase3_backend_optimization_prepare.ps1 -Run -AllowProductionSync -BuildImage -AllowProductionBuild
```

## Build Image Only

If the source sync already succeeded and you recorded the first backup
directory, build the backend image without syncing source files again:

```powershell
.\scripts\ops\phase3_backend_optimization_prepare.ps1 -Run -BuildImage -AllowProductionBuild
```

The build-only path verifies the remote source files still match the reviewed
Phase 3 manifest, then runs:

```bash
docker compose --env-file .env build tsdd-api
```

## Switch Service

Switch only after the sync and image build succeed:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

## Smoke Checks

Run immediately after switch:

```bash
ssh ubuntu@42.194.218.158 'set -euo pipefail; cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env ps tsdd-api'
ssh ubuntu@42.194.218.158 'curl -k -fsS https://infoequity.cn/v1/ping'
ssh ubuntu@42.194.218.158 'docker exec wukongim_prod-tsdd-api-1 wget --header="Authorization: Bearer <metrics-token>" -q -O - http://127.0.0.1:8090/metrics | head'
```

## 30-Minute Observation Gates

Observe for 30 minutes after the service switch. Use the same PromQL baseline queries:

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[30m]))
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
sum by (operation, result) (increase(wukongim_operation_total[30m]))
sum by (provider, operation, result) (increase(wukongim_storage_operation_total[30m]))
sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))
```

Pass criteria:

- `up{job="wukongim_api"}` remains `1`.
- 5xx remains `0`; any sustained 5xx increase triggers rollback.
- `route="unknown"` remains `0`.
- Hot-route p95/p99 does not regress materially against the pre-rollout baseline.
- `wukongim_storage_operation_total` appears with bounded labels only: `provider`, `operation`, `result`.

## Rollback

If smoke checks fail or the 30-minute gates regress, restore from the recorded backup directory:

```bash
ssh ubuntu@42.194.218.158 'set -euo pipefail; backup_dir="<phase3_backend_optimization_sync_backup_dir>"; cd /opt/wukongim-prod/src; rsync -a "$backup_dir"/ ./'
ssh ubuntu@42.194.218.158 'set -euo pipefail; backup_dir="<phase3_backend_optimization_sync_backup_dir>"; cd /opt/wukongim-prod/src; if [ -f "$backup_dir/.phase3_absent_files" ]; then while IFS= read -r path; do case "$path" in modules/user/api.go|modules/user/api_im_route_test.go|modules/message/api_conversation.go|modules/message/api_conversation_syncack_test.go|modules/file/service_minio.go|modules/file/service_minio_test.go|serverlib/pkg/metrics/metrics.go|serverlib/pkg/metrics/metrics_test.go) rm -f -- "$path" ;; /*|*..*|*\\*|"") echo "unsafe rollback absent path: $path" >&2; exit 1 ;; *) echo "rollback absent path outside Phase 3 allowlist: $path" >&2; exit 1 ;; esac; done < "$backup_dir/.phase3_absent_files"; fi'
ssh ubuntu@42.194.218.158 'set -euo pipefail; cd /opt/wukongim-prod/src/deploy/production; docker compose --env-file .env build tsdd-api'
```

Then switch back with:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

Re-run smoke checks and the 30-minute PromQL gates after rollback.
