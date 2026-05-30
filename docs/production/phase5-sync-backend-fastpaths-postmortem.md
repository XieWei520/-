# Phase 5 Sync Backend Fast Paths Postmortem

**Reader:** future WuKongIM production operator or agent continuing backend optimization work.

**Post-read action:** understand what happened during the Phase 5 production rollout, avoid repeating the migration and nginx switch failures, and carry the action items into Phase 6.

**Date:** 2026-05-30

## Status

Phase 5 is deployed and stable.

Final production gate evidence:

- `up{job="wukongim_api"} = 1`.
- No 5xx in the final 30-minute Prometheus gate.
- `route="unknown"` had no data, treated as zero.
- `GET /v1/message/prohibit_words/sync` p95 was about `0.004751s`.
- `GET /v1/message/prohibit_words/sync` p99 was about `0.004951s`.
- `tsdd-api`, `callgateway`, and `nginx` were healthy.
- `/v1/ping` returned `{"status":200}`.
- Recent nginx 502 checks were clean after the nginx restart fix.
- Recent `tsdd-api` panic/error checks were clean.
- Running `tsdd-api` image was `sha256:559b70a20ded1f44841c3bb16b2e144e2caa7fb3de3f77d79869fa171ed5e717`.

No rollback is required for the final Phase 5 state.

## What Changed

Phase 5 was a backend-only sync fast-path batch:

- Added a no-change fast path for `GET /v1/message/prohibit_words/sync`.
- Added a DB helper for the current max `prohibit_words.version`.
- Added an additive `idx_prohibit_words_version` index migration.
- Hardened the Phase 5 prepare script manifest to include the reviewed backend files and SQL migration.
- Hardened the backend service switch script so nginx is restarted after backend container recreation.
- Added tests for the SQL migration shape and nginx restart behavior.

There was no client release and no service topology change.

## Timeline

All times are Asia/Shanghai unless otherwise stated.

| Time | Event |
|---|---|
| 2026-05-29 21:48 | Phase 4 had about 22 hours of production evidence. Phase 5 was selected as a narrow backend fast-path batch for `prohibit_words/sync`. |
| 2026-05-29 late evening | Phase 5 source sync and image build were prepared. The previous production image was tagged as `wukongim/tsdd-api:phase5-pre-20260529T155013Z`. |
| 2026-05-29 23:50 | Production source backup was created under `/opt/wukongim-prod/backups/phase5-sync-backend-fastpaths-source-sync/20260529T235009+0800`. |
| First switch | `tsdd-api` failed at startup because the new SQL migration file had no `sql-migrate` Up/Down annotations. |
| Immediate response | Rollback was started. The previous image tag was restored, source was restored from the backup, and the added SQL file was removed via the absent-files manifest. |
| During rollback window | The manually created production index `idx_prohibit_words_version` was left in place because it was additive and not the cause of the API startup failure. |
| Fix pass | The migration was rewritten with `-- +migrate Up` and `-- +migrate Down`; the Up path became idempotent by checking `information_schema.STATISTICS`. |
| Second switch | Backend service switch succeeded, but external `/v1/ping` stayed 502 even though nginx could reach `tsdd-api:8090` from inside the Docker network. |
| Nginx fix | `nginx -s reload` was not enough to refresh the Docker upstream IP reliably after backend container recreation. Restarting the nginx container fixed external `/v1/ping`. |
| Final gate | The 30-minute production gate passed with API up, no 5xx, no unknown routes, stable route latency, and healthy compose services. |

## Failure 1: Migration Parse Failure

### Symptoms

`tsdd-api` failed during startup migration processing with:

```text
ERROR: no Up/Down annotations found, so no statements were executed.
```

The SQL file existed, but `sql-migrate` did not execute it because it lacked the required annotations.

### Root Cause

The initial migration file used plain SQL plus a comment-style "Down" section, but the production migration runner expects explicit `sql-migrate` annotations:

```sql
-- +migrate Up
...
-- +migrate Down
...
```

The local plan and runbook examples also showed the unannotated form, so the mistake was documented as if it were valid.

### Corrective Action

The Phase 5 migration now has:

- `-- +migrate Up`.
- `-- +migrate Down`.
- An idempotent Up migration that checks `information_schema.STATISTICS`.
- Tests that assert both annotations and the idempotency check are present in the SQL and patch artifact.

## Failure 2: Nginx Upstream Cache After Backend Recreate

### Symptoms

After a later service switch, `tsdd-api` and `callgateway` were healthy and nginx could reach `tsdd-api:8090` inside Docker, but external `/v1/ping` still returned 502.

### Root Cause

The backend containers were recreated. Nginx kept using a stale upstream resolution after `nginx -s reload`; the reload did not reliably refresh the Docker DNS/upstream target for the recreated API container.

### Corrective Action

The backend service switch now:

- Recreates only `tsdd-api` and `callgateway`.
- Waits for both services to become healthy.
- Runs `nginx -t` inside the nginx container.
- Restarts the nginx container with Docker Compose.
- Checks external `/v1/ping`.
- Checks recent nginx logs for 502 after the restart point.

## Rollback Actions Used

The rollback path worked and should remain the model for future backend batches:

- Restore the previous API image from `wukongim/tsdd-api:phase5-pre-20260529T155013Z`.
- Restore production source from `/opt/wukongim-prod/backups/phase5-sync-backend-fastpaths-source-sync/20260529T235009+0800`.
- Use the absent-files manifest to remove files that did not exist before the sync.
- Switch backend services through the guarded service switch script.
- Re-run smoke checks and Prometheus gates.

The additive `idx_prohibit_words_version` index was left in place. Additive indexes should normally remain after rollback unless there is direct evidence that the index itself caused the incident.

## Verification After Fix

Local and production verification completed:

- `flutter test test/scripts/ops/phase5_sync_backend_fastpaths_prepare_test.dart test/scripts/ops/phase6_backend_service_switch_test.dart` passed.
- `go test -count=1 ./modules/message -run 'TestPhase4|TestPhase5|TestSyncSensitiveWords|TestProhibit'` passed in the backend snapshot.
- Phase 5 patch reverse and forward apply checks passed.
- Phase 5 prepare dry run passed.
- Independent review found no blockers.
- Production 30-minute gate passed.

The hardening commit is:

```text
8f9a8afd fix: harden phase5 production rollout gates
```

## Lessons Learned

1. Migration syntax is a production gate, not a style detail.

   Every new backend SQL migration must be checked for `sql-migrate` Up/Down annotations before image build or service switch.

2. Additive production migrations must be idempotent when a manual fix may have already been applied.

   The Phase 5 index was created manually during the incident window. The final migration had to tolerate that state instead of failing on duplicate index creation.

3. Backend container recreation can invalidate nginx upstream state.

   A backend switch that recreates upstream containers must restart nginx after `nginx -t`; an in-process reload is not enough for this production topology.

4. Rollback needs source, image, and absent-file state.

   Restoring only the image is not enough when production source was synced. The absent-files manifest is required to remove files introduced by the failed rollout.

5. Production gate thresholds need to be numeric.

   "No material regression" should be written as concrete p95/p99 thresholds before the switch, so rollback decisions are mechanical under pressure.

## Phase 6 Action Items

- Add a reusable SQL migration lint that fails when new `modules/**/sql/*.sql` files lack `-- +migrate Up` or `-- +migrate Down`.
- Add a migration idempotency policy for additive indexes created during staged or manual production fixes.
- Standardize backend service switch behavior so all backend release paths restart nginx after recreating upstream services.
- Add immediate post-switch internal and external ping checks to every backend runbook.
- Add a recent nginx 502 gate after the nginx restart timestamp.
- Keep the 5-minute immediate gate plus the 30-minute production gate for backend releases.
- Use production Prometheus hot-route evidence to choose the next optimization target instead of guessing.
