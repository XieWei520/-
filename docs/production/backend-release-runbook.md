# Backend Release Runbook

This runbook describes the current low-downtime release path for the production
host at `42.194.218.158`, using the compose stack under
`/opt/wukongim-prod/src/deploy/production`.

## Current-State Release Promise

- `tsdd-api` and `callgateway`: rebuild + recreate with container health checks
  and smoke/perf probes before handoff.
- `wukongim`: controlled restart only. Existing long connections may reconnect
  during a gateway release, so avoid restarting it during routine API releases.
- `nginx`, `mysql`, `redis`, `minio`, `coturn`, `livekit`: out of scope for the
  normal API/call gateway release path unless the change explicitly requires it.

## Preflight

1. Confirm current service state:
   `docker compose --env-file .env ps`
2. Record the current build markers from `.env`:
   `BUILD_VERSION`, `BUILD_COMMIT`, `BUILD_COMMIT_DATE`, `BUILD_TREE_STATE`
3. Snapshot `.env` before editing build metadata.
4. Confirm `scripts/smoke_test.py` and `scripts/perf_probe.py` are present on
   the host.
5. Confirm the fixed rollback target you will use if the release regresses.

## Firewall Safety Notes

- Keep `5100/tcp` and `5200/tcp` open while clients still connect directly to
  WuKongIM instead of an upstream proxy.
- Do not close TURN or LiveKit UDP ranges (`3478/udp`, `49160:49220/udp`,
  `50000:50100/udp`) while voice/video is enabled.
- MySQL and Redis should remain loopback-only or Docker-internal; do not expose
  them as part of a routine release.

## Release Sequence

1. Run the operator entry point:

   ```powershell
   .\scripts\ops\deploy_backend_remote.ps1 `
     -BuildVersion "prod-20260417-210000" `
     -BuildCommit "manual-20260417-210000" `
     -BuildCommitDate "2026-04-17" `
     -BuildTreeState "manual-sync"
   ```

2. The PowerShell wrapper uploads `scripts/ops/remote_redeploy.sh` to `/tmp`
   on the server and executes it with the release metadata.
3. The remote helper:
   - backs up `.env`
   - updates `BUILD_*` markers in `.env`
   - rebuilds `tsdd-api` and `callgateway`
   - recreates only those two services
   - waits for health checks
   - runs `scripts/smoke_test.py`
   - runs `scripts/perf_probe.py`
   - prints final `docker compose ps`

## Validation Gates

- `docker compose --env-file .env ps` shows healthy `tsdd-api` and
  `callgateway`.
- `python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10`
  completes successfully.
- `python3 scripts/perf_probe.py --base-url http://127.0.0.1 --samples 20 --timeout 10`
  completes successfully.
- `grep '^BUILD_' .env` matches the intended release markers.

## Rollback

1. Use the `.env` backup printed by `remote_redeploy.sh`, for example:
   `/opt/wukongim-prod/src/deploy/production/backups/releases/.env.before-<timestamp>`
2. Restore that backup to `.env`.
3. Rebuild and recreate the same two services:

   ```bash
   cp /opt/wukongim-prod/src/deploy/production/backups/releases/.env.before-<timestamp> .env
   docker compose --env-file .env build tsdd-api callgateway
   docker compose --env-file .env up -d --no-deps tsdd-api callgateway
   ```

4. Re-run health checks, `smoke_test.py`, and `perf_probe.py`.
5. Verify `grep '^BUILD_' .env` matches the rollback target before ending the incident.
