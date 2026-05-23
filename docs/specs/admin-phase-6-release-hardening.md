# Spec: Admin Control Plane Phase 6 Release Hardening

## Objective
Prepare the local admin/backend Phase 5 work for a safe production rollout without mutating production during preparation.

Phase 6 is not a new business-feature phase. It closes release risks for audit, user purge, response contracts, database migrations, MinIO deletion, rollback, and operator verification.

Success means a human operator can decide whether production is ready by running documented checks and reviewing explicit pass/fail evidence.

## Tech Stack
- Admin frontend: `C:\Users\COLORFUL\Desktop\WuKong\TangSengDaoDaoManager-main`, Vue 3, TypeScript, Vite, Element Plus.
- Local backend copy: `C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src`, Go, MySQL, Redis, MinIO.
- Production host: `ssh ubuntu@42.194.218.158`.
- Production source path to confirm before deployment: `/opt/wukongim-prod/src`.

## Commands
Admin frontend:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\TangSengDaoDaoManager-main
pnpm test:probe
pnpm smoke:admin
pnpm typecheck
pnpm lint
pnpm build
```

Backend local pure tests:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src
go test github.com/TangSengDaoDao/TangSengDaoDaoServerLib/testutil -run "Test(TestMySQL|ConfigureTestDependencies)"
go test ./modules/common -run "Test(ToMaintenanceResp|LaunchPolicyRespIncludesMaintenance|NormalizeAdminAuditLog|AdminAuditLogResp)"
go test ./modules/user -run "Test(UserPurgePreviewResponse|UserPurgeJobResponse|BuildUserPurgePlan|ValidatePurgeUserReq|ExtractPurgeObjectKeys|SQLTableName|UserPurgeSQLSteps|PersonalChannelPurgeWhere|DeleteUserPurgeObjects|UserPurgeResultFinalError)"
go test ./modules/common ./modules/user -run '^$'
```

Backend isolated dependency stack:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src
powershell -NoProfile -ExecutionPolicy Bypass -File testenv\phase6-preflight.ps1
docker compose -f testenv\docker-compose.phase6.yaml up -d

$env:TSDD_TEST_MYSQL_ADDR='127.0.0.1:13306'
$env:TSDD_TEST_MYSQL_USER='root'
$env:TSDD_TEST_MYSQL_PASSWORD='demo'
$env:TSDD_TEST_REDIS_ADDR='127.0.0.1:16379'
$env:TSDD_TEST_MINIO_URL='http://127.0.0.1:19000'
$env:TSDD_TEST_MINIO_ACCESS_KEY='phase6admin'
$env:TSDD_TEST_MINIO_SECRET_KEY='phase6secret'

go test ./modules/common ./modules/user
```

If Docker is installed later but the preflight must be syntax-checked without external dependencies:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src
powershell -NoProfile -ExecutionPolicy Bypass -File testenv\phase6-preflight.ps1 -SkipDocker -SkipPortCheck
```

Backend isolated dependency shutdown:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\.codex-backend-work\src
docker compose -f testenv\docker-compose.phase6.yaml down
```

Backend contract probe, read-only by default:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\TangSengDaoDaoManager-main
$env:ADMIN_API_BASE_URL='https://<host>/v1'
pnpm probe:admin-backend
```

Production inventory dry-run, no SSH:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_production_inventory.ps1
```

Production inventory, read-only SSH only:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_production_inventory.ps1 -Run
```

Production MySQL schema inventory, read-only SSH and `information_schema` queries only:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_mysql_schema_inventory.ps1 -Run
```

Production Phase 6 migration readiness gate, read-only:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_migration_readiness_gate.ps1 -Run
```

Production migration backup plan, dry-run only:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_migration_backup_plan.ps1
```

Production migration backup creation, only after explicit approval for production writes:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_migration_backup_plan.ps1 -Run -AllowProductionWrites
```

Production Phase 6 migration apply, only after valid backup and explicit approval:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_apply_migrations.ps1 -Run -AllowProductionMigration
```

Production backend source sync and image build, without service switch:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_backend_release_prepare.ps1 -Run -AllowProductionSync -BuildImage -AllowProductionBuild
```

Production backend service switch, after the image has been built and explicit approval has been given:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch
```

Production legacy admin cleanup, staged and gated:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_admin_legacy_cleanup.ps1 -Run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_admin_legacy_cleanup.ps1 -Run -AllowAdminCutover
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\ops\phase6_admin_legacy_cleanup.ps1 -Run -AllowLegacyAdminCleanup
```

Authenticated contract probe:

```powershell
$env:ADMIN_API_BASE_URL='https://<host>/v1'
$env:ADMIN_TOKEN='<admin-token>'
pnpm probe:admin-backend
```

Reason enforcement probe, only after confirming sentinel validation runs before mutation:

```powershell
$env:ADMIN_API_BASE_URL='https://<staging-host>/v1'
$env:ADMIN_TOKEN='<admin-token>'
$env:ADMIN_PROBE_MUTATIONS='true'
pnpm probe:admin-backend
```

## Project Structure
- `docs/specs/admin-backend-interface-matrix.md` tracks backend route and response contract status.
- `docs/specs/admin-vip-launch-policy-user-purge.md` tracks the cross-feature control-plane contract.
- `docs/specs/admin-phase-6-release-hardening.md` is the Phase 6 release gate and runbook.
- `TangSengDaoDaoManager-main/scripts/admin-backend-probe.mjs` probes backend auth, route presence, reason enforcement, and response shape.
- `TangSengDaoDaoManager-main/scripts/admin-backend-probe.test.mjs` tests the probe helpers without network access.
- `.codex-backend-work/src/modules/user/user_purge.go` owns purge execution and object deletion result reporting.
- `.codex-backend-work/src/modules/common/sql/common-20260520-01.sql` adds launch maintenance columns and `admin_audit_log`.
- `.codex-backend-work/src/modules/user/sql/user-20260520-01.sql` adds `user_purge_job` and `user_purge_verification`.
- `scripts/ops/phase6_migration_readiness_gate.ps1` turns read-only production schema checks into `ready_for_phase6_migration`, `already_migrated`, or `inconsistent_phase6_schema`.
- `scripts/ops/phase6_migration_backup_plan.ps1` prepares the pre-migration DB/source backup under `/home/ubuntu/wukongim-phase6-backups` and requires `-Run -AllowProductionWrites` before it writes production backup files.
- `scripts/ops/phase6_apply_migrations.ps1` applies `common-20260520-01.sql` and `user-20260520-01.sql` only after backup checksum verification and `ready_for_phase6_migration`; it requires `-Run -AllowProductionMigration`.
- `scripts/ops/phase6_backend_release_prepare.ps1` syncs the reviewed Phase 6 backend source file set and can build `tsdd-api`/`callgateway` images without switching or restarting running services.
- `scripts/ops/phase6_backend_service_switch.ps1` switches `tsdd-api` and `callgateway` to the prepared image, waits for health, validates and reloads nginx, checks external `/v1/ping`, and fails if recent nginx logs contain 502 responses.
- `scripts/ops/phase6_admin_legacy_cleanup.ps1` stages legacy admin cleanup. It first inventories the old `admin-nginx` route, then can cut `/admin/` over to main nginx static assets, and only after verification can remove the old orphan container and archive old admin directories.

## Code Style
Probe checks should be explicit contracts, not string-only smoke tests:

```js
{
  id: 'audit-log-presence',
  method: 'GET',
  path: '/manager/audit/logs',
  query: { page_index: '1', page_size: '1' },
  contract: 'paged-list'
}
```

High-risk backend results must keep enough detail for later audit and retry:

```go
type userPurgeResult struct {
    ObjectDeleteCount  int                    `json:"object_delete_count"`
    ObjectDeleteErrors []userPurgeObjectError `json:"object_delete_errors,omitempty"`
}
```

## Testing Strategy
- Probe helper tests are small Node tests and must not require a live backend.
- Admin smoke remains a static contract gate for route/menu/API wrapper coverage.
- Backend pure tests cover audit normalization, redaction, purge plan generation, SQL shape, response shape, and MinIO failure reporting.
- Backend test dependency config is environment-driven through `TSDD_TEST_MYSQL_*`, `TSDD_TEST_REDIS_*`, and `TSDD_TEST_MINIO_*` so integration checks can run on isolated local ports instead of shared defaults.
- DB integration tests must run against an isolated MySQL schema matching production before any production migration.
- MinIO integration tests must run against a test bucket before any production purge endpoint is enabled.

## Boundaries
- Always:
  - Keep production checks read-only unless the user explicitly approves a mutation.
  - Treat backend auth/audit as the security boundary.
  - Keep missing endpoints visible as `接口未接入`.
  - Preserve purge job and audit evidence even when object deletion fails.
  - Back up database and source before production migration or deployment.
- Ask first:
  - SSH write operations on `ubuntu@42.194.218.158`.
  - Applying SQL migrations.
  - Restarting services or Docker containers.
  - Running reason-enforcement mutation probes against production.
- Never:
  - Run a real user purge against production as a smoke test.
  - Use production user data to prove same-phone re-registration.
  - Hide a failed MinIO object deletion behind a successful purge job.
  - Store production tokens, DB passwords, or MinIO secrets in repo files.

## Success Criteria
- `pnpm test:probe` passes.
- `pnpm smoke:admin` passes.
- `pnpm typecheck`, `pnpm lint`, and `pnpm build` pass or documented pre-existing blockers are listed.
- Backend focused pure tests pass.
- `go test ./modules/common ./modules/user -run '^$'` compiles the touched backend modules.
- The contract probe checks:
  - unauthenticated manager endpoints reject access;
  - authenticated read endpoints expose frontend-compatible response shape;
  - high-risk route presence is visible;
  - reason-enforcement mutation probes are skipped by default.
- Isolated DB integration proves:
  - same phone can register again after purge;
  - old UID/token/device state cannot authenticate;
  - configured hard-delete tables no longer reference old UID/phone;
  - purge verification rows are written.
- Isolated MinIO integration proves:
  - existing objects are physically deleted;
  - missing objects are idempotent or recorded deterministically;
  - failed deletes write `object_delete_errors` and leave the job in failed state with result details.

## Release Checklist
1. Freeze source revision:
   - record frontend commit or diff summary;
   - record backend local changed paths;
   - record SQL migration filenames:
     - `common-20260520-01.sql`;
     - `user-20260520-01.sql`.
2. Verify local quality gates:
   - run all admin commands in this spec;
   - run backend focused tests in this spec.
3. Inspect production schema read-only:
   - run `scripts/ops/phase6_production_inventory.ps1 -Run` and save the output;
   - run `scripts/ops/phase6_mysql_schema_inventory.ps1 -Run` and save the output;
   - run `scripts/ops/phase6_migration_readiness_gate.ps1 -Run` and require `ready_for_phase6_migration` before first migration;
   - confirm every purge table exists or is intentionally absent;
   - confirm `app_config` does not already have partial `maintenance_enabled`, `maintenance_title`, or `maintenance_message` columns unless the migration has already been recorded;
   - confirm `gorp_migrations` does not already contain partial Phase 6 migration records;
   - confirm all Phase 6 indexes are either absent with the table absent or fully present with the migration record;
   - confirm partition counts for message, message_user_extra, and channel_offset;
   - confirm `user.phone`, `user.username`, and related unique indexes.
4. Prepare backups:
   - dry-run `scripts/ops/phase6_migration_backup_plan.ps1`;
   - after explicit approval, run `scripts/ops/phase6_migration_backup_plan.ps1 -Run -AllowProductionWrites`;
   - verify database dump checksum before migration;
   - verify source directory archive checksum before code sync;
   - MinIO bucket lifecycle snapshot or object inventory for purge-owned prefixes.
5. Stage deployment:
   - apply migrations to staging/isolated DB;
   - run integration purge with synthetic user only;
   - verify same-phone re-registration and old-token rejection.
6. Production deployment, only after explicit approval:
   - copy reviewed backend files;
   - apply migrations with `scripts/ops/phase6_apply_migrations.ps1 -Run -AllowProductionMigration`;
   - require `phase6_apply_migrations=applied`;
   - build backend;
   - deploy admin `dist` under `/admin/`;
   - switch backend services with `scripts/ops/phase6_backend_service_switch.ps1 -Run -AllowProductionServiceSwitch`.
7. Post-deploy read checks:
   - health endpoints;
   - `/admin/` deep-link refresh;
   - `scripts/ops/phase6_migration_readiness_gate.ps1 -Run` returns `phase6_migration_readiness=already_migrated`;
   - external `https://infoequity.cn/v1/ping` returns `{"status":200}`;
   - nginx logs for the post-reload window contain no 502 responses;
   - authenticated audit log query;
   - read-only contract probe.

## Rollback Plan
Frontend rollback:
- restore previous `/admin/` static artifact or container image;
- if rolling back the 2026-05-20 legacy-admin cleanup, restore `nginx/default.conf.template` from `/opt/wukongim-prod/src/deploy/production/backups/phase6-admin-cleanup/20260520T224005+0800/default.conf.template.before-admin-cutover`, restore archived admin directories from `/opt/wukongim-prod/src/deploy/production/backups/phase6-admin-cleanup/legacy-archive-20260520T224212+0800`, recreate the old `admin-nginx` container only if needed, then `docker compose --env-file .env up -d --no-deps --force-recreate nginx`;
- verify `/admin/login` and `/admin/home` load.

Backend binary rollback:
- redeploy previous backend build or source archive;
- restart backend service;
- run health check and read-only admin probe.

Database rollback:
- `admin_audit_log`, `user_purge_job`, and `user_purge_verification` are additive tables and should usually remain for accountability.
- Do not drop audit/purge tables after a failed deploy if any production high-risk action has written rows.
- If migrations must be rolled back before any writes, use the migration Down SQL only after backup confirmation.
- Do not run Down after any audit or purge write has occurred in production.

## Migration Notes
- `common-20260520-01.sql` Up performs `ALTER TABLE app_config ADD COLUMN` for maintenance mode fields and creates `admin_audit_log`.
- `common-20260520-01.sql` Up also uses `CREATE INDEX` for audit query paths.
- `user-20260520-01.sql` Up creates `user_purge_job`, `user_purge_verification`, and their lookup indexes.
- `ALTER TABLE app_config ADD COLUMN` and MySQL `CREATE INDEX` are not idempotent when the target column or index already exists. The production schema inventory must be reviewed before applying these migrations.
- `sql-migrate` records these migrations in `gorp_migrations` using the migration filename as `id`: `common-20260520-01.sql` and `user-20260520-01.sql`.
- Down SQL drops the audit/purge evidence tables and maintenance columns. Do not run Down after production writes unless this is a separately approved incident recovery action with a verified backup.

User purge rollback:
- Physical purge is intentionally not reversible.
- Rollback for purge means stopping further purge executions, preserving job/audit rows, and restoring from pre-purge backups only under a separate incident procedure.

## Current Status
- Local admin probe now validates response contracts for paged lists, purge preview, and purge job reads.
- Local admin probe has a Node test suite and `pnpm test:probe`.
- Local backend purge result now records MinIO/object delete failures in `object_delete_errors`.
- A purge job with object delete failures is marked failed while retaining `result_json`.
- Local backend test utilities now support isolated MySQL, Redis, and MinIO endpoint overrides through `TSDD_TEST_*` environment variables.
- `testenv/docker-compose.phase6.yaml` provides a local-only MySQL/Redis/MinIO stack on non-default host ports for Phase 6 integration verification.
- `testenv/phase6-preflight.ps1` checks local Phase 6 dependency settings before starting Docker Compose.
- `scripts/ops/phase6_production_inventory.ps1` standardizes read-only production path, compose, service, and capacity inventory. It defaults to dry-run and requires `-Run` before SSH.
- `scripts/ops/phase6_mysql_schema_inventory.ps1` standardizes read-only MySQL schema inventory through the production compose `mysql` service. It uses `SHOW DATABASES`, `gorp_migrations`, and `information_schema` queries only.
- `scripts/ops/phase6_migration_readiness_gate.ps1` standardizes the migration decision point. `ready_for_phase6_migration` means no Phase 6 objects or records are present, `already_migrated` means all expected objects and records are present, and `inconsistent_phase6_schema` means a human must stop and inspect before any migration.
- `scripts/ops/phase6_migration_backup_plan.ps1` standardizes pre-migration DB/source backup commands. It defaults to dry-run and refuses to write production backup files unless both `-Run` and `-AllowProductionWrites` are present.
- `scripts/ops/phase6_apply_migrations.ps1` standardizes production Phase 6 DB migration apply. It verifies the baseline backup checksums, refuses to write without `-Run -AllowProductionMigration`, and rejects generated remote scripts that contain unexpected control characters.
- `scripts/ops/phase6_backend_release_prepare.ps1` standardizes backend source sync and image build. It refuses to sync without `-Run -AllowProductionSync`, refuses image builds without `-BuildImage -AllowProductionBuild`, backs up overwritten source files under `deploy/production/backups/phase6-source-sync`, and does not run `docker compose up`, `restart`, or `down`.
- `scripts/ops/phase6_backend_service_switch.ps1` standardizes the approved backend service switch. It refuses to execute without `-Run -AllowProductionServiceSwitch`, recreates only `tsdd-api` and `callgateway`, waits for both services to become healthy, runs `nginx -t`, reloads nginx, checks external `/v1/ping`, and fails if recent nginx logs contain 502 responses.
- `scripts/ops/phase6_admin_legacy_cleanup.ps1` standardizes removal of the legacy admin deployment. It defaults to dry-run, requires explicit gates for cutover and cleanup, backs up `nginx/default.conf.template`, archives `admin`, `admin-src`, `admin-custom`, and `manager`, and refuses cleanup while main nginx still references `admin_nginx`.
- Production backup attempt notes from 2026-05-20:
  - `/opt/wukongim-prod/backups/phase6` was not writable by `ubuntu`, so the backup root moved to `/home/ubuntu/wukongim-phase6-backups`;
  - backup `20260520T124451Z` only contains a DB dump and is not the release baseline;
  - backup `20260520T124710Z` stopped at source archive due to runtime certificate/log permissions and is not the release baseline;
  - backup `20260520T125141Z` stopped at compose archive due to runtime data/log permissions and is not the release baseline;
  - valid release baseline backup is `/home/ubuntu/wukongim-phase6-backups/20260520T125818Z`.
- Valid release baseline backup checksums from 2026-05-20:
  - `im_prod.sql.gz`: `163045bf17433f4c9568e8821f78dee74f78e4d806b2804e14c888ee13c94714`, size `1035321`;
  - `source.tar.gz`: `b71f09627f25e79b76eebd1af4176c32acbcdac64e727afa0705361ae96a42a6`, size `1149439923`;
  - `production-compose.tar.gz`: `27806ec3e9b8038d6e12c528b22bc71a314bfe197168adef98fbb506efd34361`, size `1097663912`.
- Valid backup permission check:
  - `/home/ubuntu/wukongim-phase6-backups` is `drwx------`;
  - `/home/ubuntu/wukongim-phase6-backups/20260520T125818Z` is `drwx------`;
  - backup files are `rw-------`;
  - `sha256sum -c` passed for all three archive checksums.
- Read-only production inventory was run on 2026-05-20:
  - host: `VM-0-13-ubuntu`, Ubuntu kernel `6.8.0-101-generic`;
  - Docker `28.2.2`, Docker Compose `2.37.1`;
  - compose root confirmed: `/opt/wukongim-prod/src/deploy/production`;
  - source root confirmed: `/opt/wukongim-prod/src`, but it is not a git repository;
  - active compose services: `admin-nginx`, `mysql`, `redis`, `wukongim`, `minio`, `tsdd-api`, `livekit`, `callgateway`, `nginx`, `coturn`;
  - `.env` markers: `PUBLIC_DOMAIN=infoequity.cn`, `TSDD_BASE_URL=https://infoequity.cn`, `BUILD_VERSION=prod-web-push-20260520-1645`;
  - disk `/` has about `133G` available; memory has about `5.0Gi` available.
- Pre-migration read-only production MySQL schema inventory was run on 2026-05-20:
  - active database: `im_prod`;
  - total tables reported by `information_schema.tables`: `89`;
  - purge-related existing tables include `user`, `device`, `friend`, `group`, `group_member`, `message`, `message_extra`, `message_user_extra`, and `channel_offset`;
  - required Phase 5/6 tables `admin_audit_log`, `user_purge_job`, and `user_purge_verification` are not present yet and must be added by migration before production admin purge/audit operations are enabled;
  - `app_config` is present but does not yet contain `maintenance_enabled`, `maintenance_title`, or `maintenance_message`;
  - `gorp_migrations` is present with `id` and `applied_at` columns;
  - Phase 6 migration records `common-20260520-01.sql` and `user-20260520-01.sql` are missing;
  - Phase 6 migration readiness gate returned `ready_for_phase6_migration` on 2026-05-20;
  - `user` already contains `vip_level`, `vip_expire_time`, and `customer_service_rank`;
  - `user` unique indexes currently visible: primary key `id`, unique `uid`, unique `short_no`; no unique index on `phone` or `username` was reported by this narrowed inventory query.
- Production Phase 6 DB migration was applied on 2026-05-20 21:21:11 +08:00 with `scripts/ops/phase6_apply_migrations.ps1 -Run -AllowProductionMigration`:
  - backup checksums passed immediately before migration for `im_prod.sql.gz`, `source.tar.gz`, and `production-compose.tar.gz`;
  - preflight returned `phase6_migration_readiness=ready_for_phase6_migration`;
  - apply command returned `phase6_apply_migrations=applied`;
  - no service restart was performed.
- Post-migration read-only verification was run on 2026-05-20:
  - total tables reported by `information_schema.tables`: `92`;
  - required Phase 6 tables are present: `admin_audit_log`, `user_purge_job`, `user_purge_verification`;
  - maintenance columns are present: `maintenance_enabled`, `maintenance_title`, `maintenance_message`;
  - required Phase 6 indexes are present: `admin_audit_log_target_idx`, `admin_audit_log_operator_idx`, `admin_audit_log_action_idx`, `user_purge_job_job_id_uidx`, `user_purge_job_uid_created_at_idx`, `user_purge_job_operator_created_at_idx`, `user_purge_verification_job_idx`;
  - Phase 6 migration records are present with `applied_at=2026-05-20 21:21:11`: `common-20260520-01.sql`, `user-20260520-01.sql`;
  - readiness gate returned `phase6_migration_readiness=already_migrated`;
  - no production user purge, reason-enforcement mutation probe, or destructive data test was run.
- Production backend Phase 6 source sync, image build, and service switch were run on 2026-05-20:
  - first build attempt after syncing 15 files failed before service switch because `modules/user/user_purge.go` required the newer file deletion interface from `modules/file`;
  - release file set was corrected to include `modules/file/service.go` and `modules/file/service_minio.go`;
  - second sync/build returned `phase6_backend_sync=applied` and `phase6_backend_build=completed`;
  - latest source backup directory: `/opt/wukongim-prod/src/deploy/production/backups/phase6-source-sync/20260520T215140+0800`;
  - built image `wukongim/tsdd-api:production-local` has image id `sha256:f0117ba1bfc6e78c8c5900a97cabeb326e1061fb01628bec40efc5910eb7fa0f`, created `2026-05-20T21:55:54+08:00`;
  - after explicit approval, only `tsdd-api` and `callgateway` were recreated with `docker compose --env-file .env up -d --no-deps --force-recreate tsdd-api callgateway`;
  - both running services now use image id `sha256:f0117ba1bfc6e78c8c5900a97cabeb326e1061fb01628bec40efc5910eb7fa0f` and report healthy;
  - internal probes passed for `tsdd-api` (`{"status":200}`) and `callgateway` (`{"status":"ok"}`);
  - external `https://infoequity.cn/v1/ping` initially returned 502 because nginx had cached the old backend container IP after recreation;
  - nginx was validated with `nginx -t` and reloaded with `nginx -s reload`, after which external `/v1/ping` returned `{"status":200}`;
  - a post-reload read-only check on 2026-05-20 confirmed `phase6_migration_readiness=already_migrated`, external `/v1/ping={"status":200}`, `tsdd-api` and `callgateway` healthy, and no nginx 502 lines in the recent 2-minute window;
  - no production user purge, reason-enforcement mutation probe, or destructive data test was run.
- Production legacy admin cleanup was completed on 2026-05-20:
  - before cleanup, external `/admin/` was served by the orphan container `wukongim_prod-admin-nginx-1`, which mounted `admin-custom/dist` and `admin-custom/nginx.conf`;
  - `/admin/` was cut over to main nginx static assets under `nginx/html/admin`;
  - cutover backup directory: `/opt/wukongim-prod/src/deploy/production/backups/phase6-admin-cleanup/20260520T224005+0800`;
  - old admin archive directory: `/opt/wukongim-prod/src/deploy/production/backups/phase6-admin-cleanup/legacy-archive-20260520T224212+0800`;
  - old directories `admin`, `admin-src`, `admin-custom`, and `manager` were moved into the archive directory after tar archives were created;
  - old container `wukongim_prod-admin-nginx-1` was stopped and removed;
  - post-cleanup checks confirmed `/admin/`, `/admin/login`, `/admin/static/js/index-e353de73.js`, and `/v1/ping` return 200, and main nginx has no `admin_nginx` or `proxy_pass http://admin_nginx` references.
- Current workstation blocker: Docker CLI is not installed or not on `PATH`, so the isolated dependency stack has not been started here.
- Production database has been modified only by the approved additive Phase 6 migration. Production backend source and image have been prepared, but production services have not been restarted or switched to the new image and production has not been destructively probed.

## Open Questions
- Production service manager and compose path are confirmed read-only; production source is not a git checkout, so deployment must archive/copy files carefully and record hashes before changes.
- Production MySQL table set has been inventoried read-only; partition counts for `message`, `message_user_extra`, and `channel_offset` were not reported, which likely means these are sharded physical tables (`message`, `message1`...) rather than MySQL partitions. Migration planning must use the existing sharded-table pattern.
- A retry endpoint for failed `object_delete_errors` is not implemented yet; Phase 6 documents the failure state but does not add a retry UI.
