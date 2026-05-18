# Spec: IM Sensitive Tip Persistence Service Extraction

## Assumptions
1. This slice only extracts local persistence for sensitive-word tip messages from `IMService`.
2. The existing 2-second delayed insertion behavior must be preserved.
3. Database readiness continues to be delegated through the existing `IMService._ensureDatabaseReady` path.
4. The service must not change normal message sending, outbox delivery, or remote sync behavior.

## Objective
Move sensitive-word tip message persistence out of `IMService` into an injectable service so `IMService` only decides when a tip exists and schedules persistence.

## Tech Stack
Flutter, Dart, Riverpod, WuKong IM Flutter SDK.

## Commands
Format: `dart format lib/service/im/im_sensitive_tip_persistence_service.dart lib/service/im/im_service.dart lib/service/im/im_service_providers.dart test/service/im/im_sensitive_tip_persistence_service_test.dart test/service/im/im_runtime_provider_graph_test.dart test/service/im/im_service_web_policy_test.dart`

Focused test: `flutter test test/service/im/im_sensitive_tip_persistence_service_test.dart test/service/im/im_sensitive_prohibit_sync_test.dart test/service/im/im_runtime_provider_graph_test.dart test/service/im/im_service_web_policy_test.dart test/service/im/im_service_test.dart --reporter expanded`

Analyze: `flutter analyze`

Diff check: `git diff --check`

## Project Structure
`lib/service/im/im_sensitive_tip_persistence_service.dart` owns delayed local insertion, order sequence assignment, message save, insert notification, and conversation UI refresh for sensitive-word tip messages.

`lib/service/im/im_service.dart` delegates sensitive tip persistence to the service.

`test/service/im/im_sensitive_tip_persistence_service_test.dart` covers the extracted service with injected SDK seams.

## Code Style
```dart
final persistence = ImSensitiveTipPersistenceService(
  ensureDatabaseReady: _ensureDatabaseReady,
);

unawaited(persistence.insertSensitiveWordTipMessage(tip));
```

Use injected function dependencies for SDK calls so the service is testable without touching global WKIM state.

## Testing Strategy
Unit tests verify:
- The service waits for the configured delay before checking DB readiness.
- DB-not-ready skips all persistence calls.
- Ready DB assigns `orderSeq`, saves the message, assigns `clientSeq`, publishes inserted message, and refreshes conversation UI when available.
- A null conversation UI message still publishes the inserted message and skips UI refresh.

## Boundaries
- Always: preserve current sequence math, including `orderSeq = getMessageOrderSeq(...) + 1`.
- Ask first: changing sensitive-word tip content or red-dot behavior.
- Never: change regular send/outbox/replay paths in this slice.

## Success Criteria
- `IMService` no longer directly calls `getMessageOrderSeq`, `saveMsg`, `saveWithLiMMsg`, `setOnMsgInserted`, or `setRefreshUIMsgs` for sensitive tips.
- Focused tests, `flutter analyze`, and `git diff --check` pass.
