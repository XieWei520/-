# Implementation Plan: Launch Policy, Forced Upgrade, and Startup Notice

## Overview

Implement a launch policy system for Android and Windows using the existing TangSengDaoDao backend and admin UI. The backend will extend the existing APP upgrade feature, add startup notice management, expose a public launch-policy endpoint, and keep old app-version endpoints compatible. The Flutter client will call the launch-policy endpoint at app startup and display either a non-dismissible forced-upgrade dialog or a startup notice dialog.

Spec: `docs/superpowers/specs/2026-05-16-launch-policy-version-and-startup-notice.md`

## Architecture Decisions

- Reuse the existing `modules/common` backend module because it already owns `app_version`, `/v1/common/appversion`, and admin-facing version APIs.
- Add numeric build fields to version policy instead of comparing semantic strings.
- Keep `/v1/common/appversion/:os/:version` working for old clients, and add `/v1/app/launch-policy` for new Android/Windows clients.
- Reuse existing `modules/file` upload and preview flow for startup notice images.
- Extend the existing admin `工具 > APP升级` page for Android/Windows update policy, and add `工具 > 启动弹窗` for startup notices.
- The Flutter app fails open when the launch-policy endpoint is unavailable, but reacts to `CLIENT_UPGRADE_REQUIRED` or HTTP `426` from normal APIs as a server-side fallback.

## Dependency Graph

```text
Backend database migration
  -> Backend models and DB accessors
  -> Public launch-policy endpoint
  -> Manager endpoints for admin UI
  -> Admin API wrappers
  -> Admin pages
  -> Flutter API client and models
  -> Flutter startup controller
  -> Flutter dialogs and app integration
  -> End-to-end verification
```

## Phase 1: Backend Policy Foundation

Build the server-side contract first so both admin and clients have a stable target.

### Task 1: Extend Version Policy Storage

**Description:** Add migration fields to support Android and Windows launch policy decisions while preserving the current `app_version` table and old endpoints.

**Acceptance criteria:**

- `app_version` supports `build_number`, `minimum_build_number`, `minimum_version`, `title`, `enabled`, and Windows `os`.
- Existing app-version tests still pass.
- Old rows have safe defaults that do not unexpectedly force users to update.

**Verification:**

- `go test ./modules/common`
- Review migration rollback behavior if a down migration is added.

**Dependencies:** None

**Files likely touched:**

- `/opt/wukongim-prod/src/modules/common/sql/common-20260516-01.sql`
- `/opt/wukongim-prod/src/modules/common/db.go`
- `/opt/wukongim-prod/src/modules/common/api.go`
- `/opt/wukongim-prod/src/modules/common/api_test.go`

**Estimated scope:** Medium

### Task 2: Add Startup Notice Storage

**Description:** Add a startup notice table and DB accessors for enabled notices targeted to Android, Windows, or all platforms.

**Acceptance criteria:**

- Notice table stores title, content, image URL, platforms, frequency, enabled, start time, and end time.
- Query returns the currently active notice for a requested platform.
- Expired, future, and disabled notices are excluded.

**Verification:**

- `go test ./modules/common`

**Dependencies:** Task 1

**Files likely touched:**

- `/opt/wukongim-prod/src/modules/common/sql/common-20260516-02.sql`
- `/opt/wukongim-prod/src/modules/common/db_launch_policy.go`
- `/opt/wukongim-prod/src/modules/common/api_launch_policy_test.go`

**Estimated scope:** Medium

### Task 3: Add Public Launch-Policy Endpoint

**Description:** Expose `GET /v1/app/launch-policy` without auth. It returns version policy and startup notice for `platform`, `version`, and `build`.

**Acceptance criteria:**

- Android and Windows requests return platform-specific version policy.
- Forced upgrade suppresses startup notice in the response.
- Missing policy returns a valid no-op response.
- Malformed platform/build input returns a controlled 400 response.

**Verification:**

- `go test ./modules/common`
- Manual curl: `curl 'https://infoequity.cn/v1/app/launch-policy?platform=android&version=1.0.0&build=1'`

**Dependencies:** Tasks 1-2

**Files likely touched:**

- `/opt/wukongim-prod/src/modules/common/api.go`
- `/opt/wukongim-prod/src/modules/common/api_launch_policy.go`
- `/opt/wukongim-prod/src/modules/common/api_launch_policy_test.go`

**Estimated scope:** Medium

### Checkpoint: Backend Foundation

- [ ] `go test ./modules/common` passes.
- [ ] Database changes are reviewable and backward-compatible.
- [ ] Launch-policy response matches the spec JSON shape.

## Phase 2: Admin Management UI

Expose policy controls in the current Vue 3 admin interface.

### Task 4: Extend APP Upgrade Admin Form

**Description:** Update existing `工具 > APP升级` to support Windows, build numbers, minimum supported version/build, title, enabled flag, and download URL entry.

**Acceptance criteria:**

- Admin can create Android and Windows version policies.
- Existing Android APK upload path still works.
- Windows can use a normal download URL without uploading an APK.
- Table shows build and minimum build fields.

**Verification:**

- `cd /opt/wukongim-prod/src/deploy/production/admin-src && pnpm run build`
- Manual admin check after deploy.

**Dependencies:** Tasks 1 and 3

**Files likely touched:**

- `/opt/wukongim-prod/src/deploy/production/admin-src/src/pages/tool/appupdate.vue`
- `/opt/wukongim-prod/src/deploy/production/admin-src/src/components/BdAppVersion/index.vue`
- `/opt/wukongim-prod/src/deploy/production/admin-src/src/api/tool.ts`

**Estimated scope:** Medium

### Task 5: Add Startup Notice Admin Page

**Description:** Add `工具 > 启动弹窗` page to create, list, enable/disable, and edit startup notices with text and optional image.

**Acceptance criteria:**

- Admin can configure title, text, image, target platforms, frequency, start/end time, and enabled status.
- Notice image uses existing `/file/upload` flow.
- Menu entry appears under `工具`.

**Verification:**

- `cd /opt/wukongim-prod/src/deploy/production/admin-src && pnpm run build`
- Manual create notice and confirm `/v1/app/launch-policy` returns it.

**Dependencies:** Task 2

**Files likely touched:**

- `/opt/wukongim-prod/src/deploy/production/admin-src/src/pages/tool/startupnotice.vue`
- `/opt/wukongim-prod/src/deploy/production/admin-src/src/api/tool.ts`
- `/opt/wukongim-prod/src/deploy/production/admin-src/src/menu/modules/tool.ts`

**Estimated scope:** Medium

### Checkpoint: Admin Ready

- [ ] Admin build passes.
- [ ] Version policy can be created for Android and Windows.
- [ ] Startup notice can be created and returned by the public endpoint.

## Phase 3: Flutter Client Startup Flow

Add the client-side launch-policy check and dialogs after the backend contract is stable.

### Task 6: Add Flutter Launch-Policy Models and API Client

**Description:** Add typed Dart models and an API client for `/v1/app/launch-policy`.

**Acceptance criteria:**

- Models parse valid response JSON.
- Malformed optional notice data does not crash startup.
- API client sends `platform`, `version`, and numeric `build`.

**Verification:**

- `flutter test test/modules/launch_policy/launch_policy_models_test.dart`
- `flutter test test/modules/launch_policy/launch_policy_api_test.dart`

**Dependencies:** Task 3

**Files likely touched:**

- `C:/Users/COLORFUL/Desktop/WuKong/lib/core/config/api_config.dart`
- `C:/Users/COLORFUL/Desktop/WuKong/lib/service/api/launch_policy_api.dart`
- `C:/Users/COLORFUL/Desktop/WuKong/lib/modules/launch_policy/launch_policy_models.dart`
- `C:/Users/COLORFUL/Desktop/WuKong/test/modules/launch_policy/launch_policy_models_test.dart`

**Estimated scope:** Medium

### Task 7: Add Startup Controller and Frequency Logic

**Description:** Add a controller that requests policy once per app launch, computes forced upgrade, and applies notice frequency rules.

**Acceptance criteria:**

- Forced upgrade wins over startup notice.
- `every_start`, `daily`, and `once` notice frequencies are handled.
- Network failure does not block normal startup.

**Verification:**

- `flutter test test/modules/launch_policy/launch_policy_controller_test.dart`

**Dependencies:** Task 6

**Files likely touched:**

- `C:/Users/COLORFUL/Desktop/WuKong/lib/modules/launch_policy/launch_policy_controller.dart`
- `C:/Users/COLORFUL/Desktop/WuKong/test/modules/launch_policy/launch_policy_controller_test.dart`

**Estimated scope:** Medium

### Task 8: Add Forced Upgrade and Notice Dialogs

**Description:** Build Flutter dialogs for forced upgrade and startup notice, using existing app styling and `url_launcher`.

**Acceptance criteria:**

- Forced upgrade dialog cannot be dismissed by outside tap or back/escape.
- Forced upgrade exposes only an update action.
- Startup notice supports text-only and text-plus-image.
- URLs are validated before launching.

**Verification:**

- `flutter test test/modules/launch_policy/launch_policy_dialogs_test.dart`

**Dependencies:** Task 7

**Files likely touched:**

- `C:/Users/COLORFUL/Desktop/WuKong/lib/modules/launch_policy/launch_policy_dialogs.dart`
- `C:/Users/COLORFUL/Desktop/WuKong/test/modules/launch_policy/launch_policy_dialogs_test.dart`

**Estimated scope:** Medium

### Task 9: Integrate Launch Policy Into App Startup

**Description:** Wire the controller into `WuKongApp` so Android and Windows check launch policy every app start.

**Acceptance criteria:**

- Android and Windows run launch-policy check after the first frame.
- Unsupported platforms skip without errors.
- Dialogs appear above the normal router UI.

**Verification:**

- `flutter test test/app/app_startup_launch_policy_test.dart`
- `flutter analyze`

**Dependencies:** Tasks 6-8

**Files likely touched:**

- `C:/Users/COLORFUL/Desktop/WuKong/lib/app/app.dart`
- `C:/Users/COLORFUL/Desktop/WuKong/test/app/app_startup_launch_policy_test.dart`

**Estimated scope:** Small

### Checkpoint: Client Ready

- [ ] Launch policy model/controller/dialog tests pass.
- [ ] `flutter analyze` passes or only unrelated pre-existing issues remain documented.
- [ ] Android and Windows manual startup checks are possible.

## Phase 4: Server Fallback and Deployment

Add server-side protection and deploy in a controlled order.

### Task 10: Add Protected API Version Fallback

**Description:** Add a reusable backend guard for protected APIs to return `CLIENT_UPGRADE_REQUIRED` or HTTP `426` when client headers indicate an unsupported Android/Windows build.

**Acceptance criteria:**

- New clients can send platform/build headers.
- Below-minimum clients receive a consistent upgrade-required response.
- Existing clients without headers are not unexpectedly blocked until a policy explicitly requires it.

**Verification:**

- `go test ./modules/common`
- Manual curl with forced-low build headers.

**Dependencies:** Task 3

**Files likely touched:**

- `/opt/wukongim-prod/src/modules/common/api_launch_policy.go`
- Backend middleware location after final inspection
- `/opt/wukongim-prod/src/modules/common/api_launch_policy_test.go`

**Estimated scope:** Medium

### Task 11: Deploy Backend and Admin

**Description:** Apply migration, rebuild backend image, rebuild admin UI, and restart only the required services.

**Acceptance criteria:**

- MySQL backup exists before migration.
- `tsdd-api` is healthy after restart.
- `admin-nginx` serves the updated admin bundle.
- Public launch-policy endpoint responds through the production domain.

**Verification:**

```bash
cd /opt/wukongim-prod/src/deploy/production
./scripts/backup_mysql.sh
docker compose -f docker-compose.yaml -f docker-compose.admin-local.yaml build tsdd-api callgateway
docker compose -f docker-compose.yaml -f docker-compose.admin-local.yaml up -d tsdd-api callgateway admin-nginx
docker compose -f docker-compose.yaml -f docker-compose.admin-local.yaml ps
curl -fsS 'https://infoequity.cn/v1/app/launch-policy?platform=android&version=1.0.0&build=1'
```

**Dependencies:** Tasks 1-5 and 10

**Files likely touched:** Production runtime only

**Estimated scope:** Medium

### Task 12: Final Client Builds and Manual Verification

**Description:** Build Android and Windows clients and verify forced upgrade and startup notice flows.

**Acceptance criteria:**

- Android supported build can see startup notice.
- Android below minimum build is blocked by forced upgrade.
- Windows supported build can see startup notice.
- Windows below minimum build is blocked by forced upgrade.

**Verification:**

```powershell
flutter test
flutter analyze
flutter build apk --release
flutter build windows --release
.\build_windows_release.ps1
```

**Dependencies:** Tasks 6-11

**Files likely touched:** Build outputs only

**Estimated scope:** Medium

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Production source is not a git checkout | High | Keep local docs in this repo, create backups before server edits, and record exact changed server files. |
| Existing `app_version` compares strings incorrectly | Medium | Introduce numeric build fields and keep old endpoints compatible. |
| Applying DB migration on production | High | Take MySQL backup first and avoid destructive schema changes. |
| Old clients lack launch-policy code | Medium | Keep current `/v1/common/appversion` compatible and add server fallback only for clients that send build headers unless explicitly enabled later. |
| Admin build dependencies missing on server | Medium | Use `pnpm install --frozen-lockfile`; if Node/pnpm are unavailable, install only after approval. |
| Launch-policy endpoint outage | Low | Client fails open for startup checks to avoid locking out supported users. |

## Open Questions Before Implementation

1. Approve applying database migrations on the production server during this work, or stage migrations for a maintenance window?
2. Confirm the first Android update URL and Windows download URL values, or allow placeholder URLs during implementation and configure real URLs later in admin.

## Review Gate

Do not start implementation until this plan is approved.
