# Spec: Launch Policy, Forced Upgrade, and Startup Notice

## Assumptions

1. The client is the Flutter app in this repository and must support Android and Windows first.
2. The server/admin side is TangSengDaoDao-style backend management and may live on the cloud server rather than in this repository.
3. The client can call an unauthenticated startup policy endpoint before login because forced upgrade and public notices must work for logged-out users too.
4. Version comparison should use numeric build numbers, not display version strings.
5. Forced upgrade blocks normal app usage until the user opens the configured download/update URL.
6. A startup notice is lower priority than forced upgrade and is shown only when the current version is allowed to continue.

Correct these assumptions before implementation if any are wrong.

## Objective

Add a remotely configurable launch policy system for the TangSengDaoDao/WuKong desktop and mobile clients.

The system lets an administrator:

- Force Android and Windows users below a configured minimum build to update.
- Publish an optional startup notice shown when users open the app.
- Include notice text and an optional image.
- Target policies by platform.

The user experience must be:

- Android and Windows call the launch policy endpoint every app start.
- Forced upgrade appears first and cannot be dismissed.
- Startup notice appears after the upgrade check only when the app version is still supported.
- Notice content is managed from the backend/admin UI.

## Tech Stack

Client:

- Flutter app: `wukong_im_app`
- Dart SDK: `^3.11.1`
- State management: `flutter_riverpod`
- Routing: `go_router`
- HTTP client: `dio`
- Version info: `package_info_plus`
- URL opening: `url_launcher`
- Local persistence: `shared_preferences`

Backend/admin:

- Existing TangSengDaoDao backend/admin stack on the cloud server.
- Reuse existing database, auth, upload, and admin UI conventions after inspection.
- Production server source/runtime path observed on 2026-05-16: `/opt/wukongim-prod/src`.
- Production Compose files: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml` and `/opt/wukongim-prod/src/deploy/production/docker-compose.admin-local.yaml`.
- Backend service: `wukongim_prod-tsdd-api-1`, built from `deploy/production/Dockerfile.tsdd`.
- Admin UI source: `/opt/wukongim-prod/src/deploy/production/admin-src`.
- Admin UI deployed assets: `/opt/wukongim-prod/src/deploy/production/admin-custom/dist`.

## Commands

Client commands:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d android
flutter run -d windows
flutter build apk --release
flutter build windows --release
```

Windows package helper already present:

```powershell
.\build_windows_release.ps1
```

Backend/admin commands discovered from production layout:

```bash
cd /opt/wukongim-prod/src
go test ./modules/common ./modules/file
docker compose -f deploy/production/docker-compose.yaml -f deploy/production/docker-compose.admin-local.yaml build tsdd-api callgateway
docker compose -f deploy/production/docker-compose.yaml -f deploy/production/docker-compose.admin-local.yaml up -d tsdd-api callgateway

cd /opt/wukongim-prod/src/deploy/production/admin-src
pnpm install --frozen-lockfile
pnpm run build
rsync -a --delete dist/ ../admin-custom/dist/
docker compose -f ../docker-compose.yaml -f ../docker-compose.admin-local.yaml up -d admin-nginx
```

## Project Structure

Client:

```text
lib/app/
  app.dart                         App root and startup UI integration point

lib/core/config/
  api_config.dart                  API path constants and URL resolution

lib/service/api/
  launch_policy_api.dart           Startup policy HTTP client

lib/modules/launch_policy/
  launch_policy_models.dart        Version policy and notice models
  launch_policy_controller.dart    Startup check orchestration
  launch_policy_dialogs.dart       Forced upgrade and notice dialogs

test/modules/launch_policy/
  launch_policy_models_test.dart
  launch_policy_controller_test.dart
  launch_policy_dialogs_test.dart
```

Backend/admin:

```text
modules/common/                       Existing app-version API and new launch-policy API
modules/common/sql/                   Existing app_version migrations and new startup notice migration
deploy/production/admin-src/src/      Existing Vue 3 admin UI source
deploy/production/admin-custom/dist/  Built admin UI served by admin-nginx
modules/file/                         Existing upload/preview service reused for notice images
```

## Code Style

Dart client code should follow existing repository style: small immutable models, explicit parsing, and simple UI widgets.

Example shape:

```dart
enum LaunchPlatform {
  android,
  windows;

  String get wireName => name;
}

class VersionPolicy {
  const VersionPolicy({
    required this.platform,
    required this.latestBuild,
    required this.minimumBuild,
    required this.forceUpgrade,
    required this.updateUrl,
    required this.message,
  });

  final LaunchPlatform platform;
  final int latestBuild;
  final int minimumBuild;
  final bool forceUpgrade;
  final String updateUrl;
  final String message;

  bool requiresForcedUpgrade(int currentBuild) {
    return forceUpgrade && currentBuild < minimumBuild;
  }
}
```

Conventions:

- Use `int` build numbers for comparisons.
- Treat all server JSON as untrusted and validate required fields.
- Keep platform-specific branching behind a small adapter.
- Keep dialogs dumb; controller decides what to show.
- Do not add new dependencies unless existing Flutter packages cannot solve the problem.

## API Contract

Client request:

```http
GET /v1/app/launch-policy?platform=android&version=1.0.0&build=1
GET /v1/app/launch-policy?platform=windows&version=1.0.0&build=1
```

Recommended response when a forced upgrade is required:

```json
{
  "serverTime": "2026-05-16T00:00:00Z",
  "versionPolicy": {
    "platform": "android",
    "latestVersion": "1.3.0",
    "latestBuild": 130,
    "minimumVersion": "1.2.5",
    "minimumBuild": 125,
    "forceUpgrade": true,
    "updateUrl": "https://example.com/download/android",
    "title": "New version required",
    "message": "Your current version is no longer supported. Please update to continue."
  },
  "startupNotice": null
}
```

Recommended response when normal startup notice should show:

```json
{
  "serverTime": "2026-05-16T00:00:00Z",
  "versionPolicy": {
    "platform": "windows",
    "latestVersion": "1.3.0",
    "latestBuild": 130,
    "minimumVersion": "1.0.0",
    "minimumBuild": 1,
    "forceUpgrade": false,
    "updateUrl": "https://example.com/download/windows",
    "title": "Update available",
    "message": "A new version is available."
  },
  "startupNotice": {
    "id": "notice-20260516",
    "title": "System notice",
    "content": "New features are available.",
    "imageUrl": "https://example.com/minio/notices/notice.png",
    "frequency": "every_start",
    "startAt": "2026-05-16T00:00:00Z",
    "endAt": "2026-05-30T23:59:59Z"
  }
}
```

Failure behavior:

- If the launch policy request fails, the client must not block startup by default.
- If any normal authenticated API later receives `CLIENT_UPGRADE_REQUIRED` or HTTP `426`, the client must show the forced upgrade dialog and block continued use.

## Admin Management Requirements

Version policy fields:

- Platform: `android`, `windows`
- Latest display version
- Latest build number
- Minimum supported display version
- Minimum supported build number
- Force upgrade enabled
- Update URL
- Dialog title
- Dialog message
- Enabled status

Startup notice fields:

- Title
- Text content
- Optional image
- Target platforms: Android, Windows, or all
- Frequency: every start, once per day, once per notice
- Start time
- End time
- Enabled status

Priority:

1. Forced upgrade
2. Startup notice
3. Normal app startup

## Resolved Decisions

- Android updates use the configured URL, which may point to an APK or app market page.
- Windows updates open a configured download page. No automatic installer is part of this scope.
- Startup notices are public before login and can be shown immediately on app start.
- Notice images reuse the existing file upload and preview capability.
- The existing backend/admin APP upgrade feature should be extended instead of replaced.
- Existing `/v1/common/appversion` support remains for backward compatibility.

## Testing Strategy

Client unit tests:

- Version comparison uses build numbers.
- Forced upgrade is true when current build is below minimum build.
- Startup notice is suppressed when forced upgrade is required.
- Startup notice frequency handling supports every start, daily, and once per notice.
- Malformed launch policy JSON fails closed for the malformed item without crashing the app.

Client widget tests:

- Forced upgrade dialog cannot be dismissed by tapping outside or pressing a close button.
- Forced upgrade dialog exposes only the update action.
- Startup notice dialog can render text-only content.
- Startup notice dialog can render text plus image.

Backend tests:

- Public launch policy endpoint returns the active policy for the requested platform.
- Disabled, expired, and future notices are not returned.
- Admin create/update validation rejects invalid build ranges and invalid URLs.
- Old client guard returns `CLIENT_UPGRADE_REQUIRED` or HTTP `426` for protected APIs when below minimum build.

Manual verification:

- Android app start below minimum build shows forced upgrade.
- Windows app start below minimum build shows forced upgrade.
- Android app start at supported build shows notice.
- Windows app start at supported build shows notice.
- Notice image loads from configured URL.

## Boundaries

Always:

- Add or update tests before behavior changes.
- Validate server-provided URLs before launching them.
- Use build numbers for forced-upgrade decisions.
- Keep forced upgrade higher priority than startup notices.
- Leave unrelated dirty files untouched.

Ask first:

- Database schema changes on the production server.
- Adding new client or backend dependencies.
- Changing existing authentication or login flow.
- Restarting production services.
- Deleting old server code or old admin pages.

Never:

- Commit secrets, tokens, server passwords, or `.env` values.
- Disable existing failing tests to make this change pass.
- Force update users when the policy endpoint is unreachable.
- Trust HTML or rich text from notices without sanitization.
- Silently delete user or administrator data.

## Success Criteria

1. Android and Windows clients call a launch policy endpoint on every app start.
2. An admin can configure platform-specific forced upgrade settings.
3. Users below the minimum build cannot continue using the app after policy is received.
4. Users on supported builds can see a configured startup notice every time the app opens.
5. Startup notice supports text-only and text-plus-image content.
6. Forced upgrade suppresses startup notice on the same launch.
7. Protected backend APIs can reject unsupported clients as a server-side fallback.
8. Client and backend tests cover the policy rules.
9. Build and test commands pass after implementation.

## Remaining Operational Questions

1. Confirm the final public Android download URL before forcing Android users to update.
2. Confirm the final public Windows download URL before forcing Windows users to update.
3. Confirm whether production database migrations should be applied immediately after implementation or staged for a maintenance window.
