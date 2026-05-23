# Backend Metrics Rollout

This runbook covers the Phase 2 backend metrics patch only. It does not deploy,
restart, or switch production services unless the operator runs the explicit
approval-gated commands below.

## Local Validation

From `C:\Users\COLORFUL\Desktop\WuKong`, validate the tracked rollout tooling:

```powershell
.\scripts\ops\phase2_backend_metrics_prepare.ps1 -RunTests
flutter test test/scripts/ops/phase2_backend_metrics_prepare_test.dart
flutter test test/scripts/ops/backend_metrics_rollout_test.dart
```

The script runs `go test -count=1 ./pkg/metrics` under `serverlib`, then the
message/file compile gate:

```powershell
go test -count=1 -mod=readonly -run '^$' ./modules/message ./modules/file
```

The compile gate is intentional in this environment because the full
message/file package tests require external MySQL and file test assets.

## Metrics Token

When `WUKONGIM_METRICS_TOKEN` is set, the backend `/metrics` endpoint requires
`Authorization: Bearer <token>` for every caller, including loopback. When the
token is intentionally unset, only loopback requests are accepted. Do not commit
the token to git; inject it through the Prometheus runtime secret mechanism for
that environment.

Prometheus reads the token from
`credentials_file: /run/secrets/wukongim_metrics_token`. Before starting or
reloading a monitoring stack, create the host file outside git. For production:

```bash
cd /opt/wukongim-prod/src/deploy/production
mkdir -p ./secrets
install -m 0600 /dev/null ./secrets/wukongim_metrics_token
printf '%s' '<metrics-token>' > ./secrets/wukongim_metrics_token
```

`deploy/production/docker-compose.observability.yaml` mounts
`./secrets/wukongim_metrics_token` into the Prometheus container as read-only.
Set the same value in production `.env` as `WUKONGIM_METRICS_TOKEN=<metrics-token>`
so `tsdd-api` and Prometheus agree.

For the local `ops/monitoring` compose stack, create
`ops/monitoring/secrets/wukongim_metrics_token` with the same token used when
starting the local backend. The file may be empty only when Prometheus scrapes
from the same loopback network namespace as the backend; the provided Docker
bridge topology uses `host.docker.internal:8080`, so use a token.

## Production Sync

Production source sync is explicit and approval-gated. The required flag pair is
`-Run -AllowProductionSync`:

```powershell
.\scripts\ops\phase2_backend_metrics_prepare.ps1 `
  -Run `
  -AllowProductionSync
```

The script syncs only these backend files to `/opt/wukongim-prod/src`:

- `main.go`
- `modules/message/api.go`
- `modules/file/api.go`
- `serverlib/pkg/metrics/metrics.go`
- `serverlib/pkg/metrics/metrics_test.go`

Record the printed `phase2_backend_metrics_sync_backup_dir` value before doing
anything else. That directory is the source rollback point for this rollout.

## Optional Build

Build the production `tsdd-api` image only after source sync has completed. The
build approval flag pair is `-BuildImage -AllowProductionBuild`:

```powershell
.\scripts\ops\phase2_backend_metrics_prepare.ps1 `
  -Run `
  -AllowProductionSync `
  -BuildImage `
  -AllowProductionBuild
```

This builds the image but does not restart or recreate running services.

## Service Switch

Switching live services is a separate operator decision and requires explicit
approval:

```powershell
.\scripts\ops\phase6_backend_service_switch.ps1 `
  -Run `
  -AllowProductionServiceSwitch
```

Use this only after the source sync and optional image build output have been
reviewed.

## Smoke Checks

Run these checks after the service switch. If `WUKONGIM_METRICS_TOKEN` is set,
the `/metrics` smoke check must include the bearer token even when run on
loopback. If the token is intentionally unset, only loopback requests are
accepted.

```bash
curl -fsS http://127.0.0.1:8080/v1/ping
curl -fsS -H "Authorization: Bearer <metrics-token>" http://127.0.0.1:8080/metrics | head
```

If `WUKONGIM_METRICS_TOKEN` is intentionally unset for a loopback-only scrape,
the metrics smoke check is:

```bash
curl -fsS http://127.0.0.1:8080/metrics | head
```

If the external release URL is already routed through nginx, also check:

```bash
curl -fsS https://infoequity.cn/v1/ping
```

In Prometheus, confirm the `wukongim_api` target is up and scraping
`host.docker.internal:8080` with `metrics_path: /metrics`.

## Rollback

If the rollout regresses, restore the files from the backup directory printed by
the sync step:

```bash
cd /opt/wukongim-prod/src
backup_dir=/opt/wukongim-prod/src/deploy/production/backups/phase2-backend-metrics-source-sync/<timestamp>
cp -p "$backup_dir/main.go" main.go
cp -p "$backup_dir/modules/message/api.go" modules/message/api.go
cp -p "$backup_dir/modules/file/api.go" modules/file/api.go
rm -rf serverlib/pkg/metrics
if [ -d "$backup_dir/serverlib/pkg/metrics" ]; then
  mkdir -p serverlib/pkg
  cp -a "$backup_dir/serverlib/pkg/metrics" serverlib/pkg/metrics
fi
cd /opt/wukongim-prod/src/deploy/production
docker compose --env-file .env build tsdd-api
docker compose --env-file .env up -d --no-deps --force-recreate tsdd-api
```

Re-run `/v1/ping`, localhost `/metrics`, and Prometheus target health checks
after rollback. If the previous version did not have `serverlib/pkg/metrics`,
the `rm -rf` step removes the added package.

## PromQL Queries

Request rate by route:

```promql
sum by (route, method) (rate(wukongim_http_requests_total[5m]))
```

p95 HTTP latency by route:

```promql
histogram_quantile(0.95, sum by (le, route, method) (rate(wukongim_http_request_duration_seconds_bucket[5m])))
```

5xx rate:

```promql
sum by (route, method) (rate(wukongim_http_requests_total{status_class="5xx"}[5m]))
```

p95 operation latency:

```promql
histogram_quantile(0.95, sum by (le, operation) (rate(wukongim_operation_duration_seconds_bucket[5m])))
```

File upload failures:

```promql
sum(rate(wukongim_operation_total{operation="file_upload",result="failure"}[5m]))
```
