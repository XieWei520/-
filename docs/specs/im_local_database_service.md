# Spec: IM Local Database Service Extraction

## Assumptions
1. This slice only extracts local database readiness and schema-guard logic from `IMService`.
2. `WKDBHelper.onUpgrade` remains the SDK migration source of truth.
3. Web/non-local-persistence behavior must stay unchanged: readiness returns `false` and callers skip local DB work.
4. `message_outbox` schema creation remains required whenever the IM local database is ready.

## Objective
Move local database readiness responsibilities out of `IMService` into a dedicated `ImLocalDatabaseService`, reducing `IMService` database coupling while preserving startup behavior for Windows and Android.

## Tech Stack
Flutter, Dart, Riverpod, sqflite, sqflite_common_ffi for tests, WuKong IM Flutter SDK.

## Commands
Format: `dart format lib/service/im/im_local_database_service.dart lib/service/im/im_service.dart lib/service/im/im_service_providers.dart test/service/im/im_local_database_service_test.dart test/service/im/im_runtime_provider_graph_test.dart test/service/im/im_service_web_policy_test.dart`

Focused test: `flutter test test/service/im/im_local_database_service_test.dart test/service/im/im_masked_message_refresh_service_test.dart test/service/im/im_sensitive_prohibit_sync_test.dart test/service/im/im_runtime_provider_graph_test.dart test/service/im/im_service_web_policy_test.dart --reporter expanded`

Analyze: `flutter analyze`

Diff check: `git diff --check`

## Project Structure
`lib/service/im/im_local_database_service.dart` owns DB readiness, SDK migration invocation, required-table polling, and outbox schema creation.

`lib/service/im/im_service.dart` keeps the caller policy and uses the new service for readiness checks.

`test/service/im/im_local_database_service_test.dart` covers the extracted service with injected database dependencies.

## Code Style
```dart
final localDatabase = ImLocalDatabaseService(
  usesLocalPersistence: () => shouldUseImLocalPersistence(
    isWeb: kIsWeb,
    sdkAppMode: WKIM.shared.isApp(),
  ),
);

if (!await localDatabase.ensureReady()) {
  return;
}
```

Use explicit constructor dependencies for static SDK seams so tests do not need to mutate global WKDBHelper state.

## Testing Strategy
Unit tests verify:
- Local persistence disabled skips DB open and returns `false`.
- Existing ready DB ensures `message_outbox` schema.
- Missing required tables triggers SDK migration and waits for required tables.
- Migration/outbox schema failures return `false`.

Existing IM tests verify `IMService` still initializes and delegates through the extracted service.

## Boundaries
- Always: preserve the original readiness return values and outbox schema guarantee.
- Ask first: changing SDK migration SQL, changing required-table names, adding a new database dependency.
- Never: delete WKDBHelper migrations or alter chat/message persistence behavior in this slice.

## Success Criteria
- `IMService` no longer imports `sqflite` or `WKDBHelper` directly for readiness.
- `IMService` delegates database readiness to `ImLocalDatabaseService.ensureReady`.
- Focused tests, `flutter analyze`, and `git diff --check` pass.

## Open Questions
- A future slice can move sensitive-word tip insertion persistence behind a dedicated message persistence service.
