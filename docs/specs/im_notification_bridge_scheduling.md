# Spec: IM Notification Bridge Scheduling

## Assumptions
1. This slice only moves message alert scheduling and failure handling out of `IMService`.
2. Existing alert planning, Android red-dot exception, desktop alerts, and web notifications remain unchanged.
3. `IMService` should keep passing the current UID and lifecycle state, but should not own fire-and-forget notification error handling.
4. No new notification dependency or platform implementation is introduced in this slice.

## Objective
Make `ImNotificationBridge` the single owner of message alert scheduling. `IMService` should call one platform-neutral bridge method and continue processing messages even when a platform notification backend fails asynchronously.

## Tech Stack
Flutter, Dart, Riverpod, WuKong IM Flutter SDK.

## Commands
Focused test: `flutter test test/service/im/im_notification_bridge_test.dart test/service/im/im_service_web_policy_test.dart test/wukong_push/android_local_notification_integration_test.dart test/wukong_push/web_notification_integration_policy_test.dart test/wukong_push/windows_notification_integration_policy_test.dart --reporter expanded`

Analyze: `flutter analyze`

Diff check: `git diff --check`

## Project Structure
`lib/service/im/im_notification_bridge.dart` owns fire-and-forget alert scheduling, alert dispatch, and scheduling error reporting.

`lib/service/im/im_service.dart` delegates notification scheduling to the bridge.

`test/service/im/im_notification_bridge_test.dart` covers scheduling behavior with injected alert managers.

## Code Style
```dart
_notificationBridge.scheduleMessageAlert(
  message,
  currentUid: currentUid,
  lifecycleState: _appLifecycleState,
);
```

Use an injected error reporter for tests instead of relying on global Flutter logs.

## Testing Strategy
Unit tests verify:
- Eligible alerts still dispatch through the existing bridge path.
- Asynchronous platform alert failures are reported and do not throw synchronously from the scheduler.
- Source-policy tests ensure `IMService` calls `scheduleMessageAlert` and does not own platform notification managers.

## Boundaries
- Always: preserve existing message alert eligibility and platform dispatch policy.
- Ask first: changing notification permission prompts, sound assets, desktop/web behavior, or Android foreground/background policy.
- Never: modify message sending, outbox replay, sync, or local database behavior in this slice.

## Success Criteria
- `IMService` no longer contains a private message-alert scheduling wrapper.
- `ImNotificationBridge` exposes a fire-and-forget `scheduleMessageAlert` API with async error reporting.
- Focused tests, `flutter analyze`, and `git diff --check` pass.
