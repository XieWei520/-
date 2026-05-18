# Spec: Local Monitor Runner Logic Refactor

## Objective
Extract duplicated pure runner logic shared by Feishu and DingTalk monitor auto-forwarding into `lib/modules/local_monitor`, without changing either provider's lifecycle orchestration. The shared slice covers event merge/dedupe, optional event filtering, and startup event splitting. Provider-specific code keeps Shell subscriptions, route loading, multi-worker selection, status publishing, and Feishu media-specific behavior.

## Tech Stack
Flutter/Dart app code using existing monitor modules and `flutter_test`.

## Commands
- Shared runner tests: `flutter test test/modules/local_monitor/local_monitor_runner_test.dart`
- DingTalk runner tests: `flutter test test/modules/dingtalk_monitor/dingtalk_monitor_runner_test.dart`
- Feishu runner tests: `flutter test test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`
- Analyze: `flutter analyze lib/modules/local_monitor lib/modules/feishu_monitor lib/modules/dingtalk_monitor test/modules/local_monitor test/modules/feishu_monitor test/modules/dingtalk_monitor`

## Project Structure
- `lib/modules/local_monitor/local_monitor_runner.dart` -> Provider-neutral pure runner helpers.
- `lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart` -> Feishu lifecycle and multi-worker orchestration using shared pure helpers.
- `lib/modules/dingtalk_monitor/dingtalk_monitor_runner.dart` -> DingTalk lifecycle and status publishing using shared pure helpers.
- `test/modules/local_monitor/local_monitor_runner_test.dart` -> Direct shared helper coverage.

## Code Style
```dart
final split = splitLocalMonitorStartupEvents(
  events: recentEvents,
  startedAt: _startedAt,
  observedAtForEvent: (event) => event.observedAt,
);
```
Keep the shared API functional and small. Do not introduce a lifecycle base class in this slice.

## Testing Strategy
Add direct shared helper tests first, then keep existing Feishu and DingTalk runner tests as compatibility coverage.

## Boundaries
- Always: Preserve Feishu multi-worker behavior, DingTalk `statusListenable`, startup priming semantics, duplicate suppression, and event reconnect handling.
- Ask first: Replacing provider runners with a generic base runner or changing forwarding service interfaces.
- Never: Move Feishu media forwarding rules, DingTalk settings storage, or Shell lifecycle code into the generic helper in this slice.

## Success Criteria
- Event merge/dedupe and startup splitting live in `lib/modules/local_monitor`.
- Feishu and DingTalk runners call shared helpers for those pure operations.
- Existing Feishu and DingTalk runner tests pass.
- Analyzer reports no issues for touched modules.

## Open Questions
None for this slice.
