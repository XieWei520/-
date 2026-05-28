# Phase 4 Sync Load Reduction Rollout

This runbook deploys only the Phase 4 backend sync load reduction batch:

- `syncSensitiveWords` no-change fast path for repeated current-version requests.
- Focused backend tests for the no-change cache primitive and response shape.
- No database schema changes.
- No client release required for this backend-only batch.

Do not deploy client builds, admin-dashboard changes, monitoring changes, or service topology changes as part of this batch.

## Preconditions

Run from the repository root on the operator workstation.

```powershell
git status --short
flutter test test/scripts/ops/phase4_sync_load_reduction_prepare_test.dart
```

Run backend verification from the local backend snapshot:

```powershell
.\scripts\ops\phase4_sync_load_reduction_prepare.ps1 -RunTests

Push-Location .codex-backend-work/src
go test -count=1 ./modules/message -run 'TestPhase4|TestSyncSensitiveWords|TestProhibit'
Pop-Location
```

## Baseline PromQL

Before syncing files, capture the current 24-hour production baseline in Prometheus:

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[24h]))
topk(25, sum by (route, method) (increase(wukongim_http_requests_total[24h])))
sum by (route, method) (increase(wukongim_http_requests_total[24h]))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[24h])))
sum(increase(wukongim_http_requests_total{route="unknown"}[24h]))
```

Also capture the shorter 30-minute gate window immediately before rollout:

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[30m]))
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))
```

Expected before rollout:

- `up{job="wukongim_api"}` is `1`.
- 5xx count is `0` or unchanged from the pre-rollout baseline.
- `route="unknown"` stays at `0`.

## Dry Run

```powershell
.\scripts\ops\phase4_sync_load_reduction_prepare.ps1 -RunTests
.\scripts\ops\phase4_sync_load_reduction_prepare.ps1
```

The dry run prints the file manifest, verifies it against the reviewed Phase 4
manifest embedded in the script, and does not write production. Confirm the
allowlist contains only:

- `modules/message/api.go`
- `modules/message/phase4_sync_load_test.go`

## Sync Source And Build

This copies the allowlisted files to `/opt/wukongim-prod/src` and creates a
timestamped backup under
`/opt/wukongim-prod/backups/phase4-sync-load-reduction-source-sync`, outside
the source tree. Build only through the one-shot sync+build command so the
script can verify and isolate the Docker build context before building.
Build-only mode is intentionally unsupported.

```powershell
.\scripts\ops\phase4_sync_load_reduction_prepare.ps1 -Run -AllowProductionSync -BuildImage -AllowProductionBuild
```

Record the printed values:

```text
phase4_sync_load_reduction_sync_backup_dir=<remote backup dir>
phase4_sync_load_reduction_absent_files_manifest=<remote backup dir>/.phase4_absent_files
phase4_sync_load_reduction_build_context=verified
phase4_sync_load_reduction_build_context_root=<remote tmp>/build-context
phase4_sync_load_reduction_previous_image_tag=wukongim/tsdd-api:phase4-pre-<timestamp>
```

Before build, the script verifies the effective Docker build context:
`go.mod`, `go.sum`, `main.go`, `assets`, `configs`, `internal`, `modules`,
`pkg`, and `serverlib`. The only allowed build-context changes are the two
Phase 4 files listed in this runbook.

The image build uses a temporary build context:

```bash
docker compose --env-file .env -f "<remote tmp>/docker-compose.phase4-build.yaml" build tsdd-api
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

Observe for 30 minutes after the service switch. Use the same 30-minute PromQL
baseline queries:

```promql
up{job="wukongim_api"}
sum by (status_class) (increase(wukongim_http_requests_total[30m]))
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
histogram_quantile(0.99, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[30m])))
sum(increase(wukongim_http_requests_total{route="unknown"}[30m]))
```

Pass criteria:

- `up{job="wukongim_api"}` remains `1`.
- 5xx remains `0`; any sustained 5xx increase triggers rollback.
- `route="unknown"` remains `0`.
- Hot-route p95/p99 does not regress materially against the pre-rollout baseline.
- `GET /v1/message/sync/sensitivewords` request rate drops after clients receive current-version no-change responses.

## Rollback

If smoke checks fail or the 30-minute gates regress, restore from the recorded backup directory:

```bash
ssh ubuntu@42.194.218.158 'set -euo pipefail; backup_dir="<phase4_sync_load_reduction_sync_backup_dir>"; cd /opt/wukongim-prod/src; rsync -a --exclude .phase4_absent_files "$backup_dir"/ ./'
ssh ubuntu@42.194.218.158 'set -euo pipefail; backup_dir="<phase4_sync_load_reduction_sync_backup_dir>"; cd /opt/wukongim-prod/src; if [ -f "$backup_dir/.phase4_absent_files" ]; then while IFS= read -r path; do case "$path" in modules/message/api.go|modules/message/phase4_sync_load_test.go) rm -f -- "$path" ;; /*|*..*|*\\*|"") echo "unsafe rollback absent path: $path" >&2; exit 1 ;; *) echo "rollback absent path outside Phase 4 allowlist: $path" >&2; exit 1 ;; esac; done < "$backup_dir/.phase4_absent_files"; fi'
ssh ubuntu@42.194.218.158 'set -euo pipefail; previous_image_tag="<phase4_sync_load_reduction_previous_image_tag>"; docker image inspect "$previous_image_tag" >/dev/null; docker tag "$previous_image_tag" wukongim/tsdd-api:production-local'
```

Then switch back with:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

Re-run smoke checks and the 30-minute PromQL gates after rollback.
