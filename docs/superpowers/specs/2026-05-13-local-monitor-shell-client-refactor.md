# Spec: Local Monitor Shell Client Refactor

## Objective
Extract duplicated app-side Shell HTTP/SSE client behavior and common Shell payload parsing into `lib/modules/local_monitor`. Feishu and DingTalk must keep their existing public client/model class names while delegating shared request handling, SSE parsing, health parsing, source sync, and common status field parsing to the neutral module.

## Tech Stack
Flutter/Dart app code using `dio` for HTTP, `flutter_test` for tests, and existing monitor modules under `lib/modules`.

## Commands
- Analyze: `flutter analyze lib/modules/local_monitor lib/modules/feishu_monitor lib/modules/dingtalk_monitor test/modules/feishu_monitor test/modules/dingtalk_monitor`
- Shared client tests: `flutter test test/modules/local_monitor/local_monitor_shell_client_test.dart`
- Feishu monitor tests: `flutter test test/modules/feishu_monitor`
- DingTalk monitor tests: `flutter test test/modules/dingtalk_monitor`

## Project Structure
- `lib/modules/local_monitor/local_monitor_shell_models.dart` -> Shared Shell status/event/health/conversation/message/image models and parsing helpers
- `lib/modules/local_monitor/local_monitor_shell_client.dart` -> Shared Dio Shell transport, SSE parser, and source sync
- `lib/modules/feishu_monitor/` -> Feishu compatibility models/client and worker sharding
- `lib/modules/dingtalk_monitor/` -> DingTalk compatibility models/client

## Code Style
```dart
final client = LocalMonitorShellClient(
  dio: dio,
  baseUrl: baseUrl,
  token: token,
);
final status = await client.fetchStatus();
```
Provider wrappers convert shared status/events into provider-specific class names where existing code expects them.

## Testing Strategy
Add direct shared client tests for HTTP, source sync, and SSE parsing. Keep Feishu and DingTalk shell client/model tests as compatibility coverage.

## Boundaries
- Always: Preserve Feishu and DingTalk default base URLs/tokens, HTTP endpoints, authorization header, SSE event semantics, and existing public class names.
- Ask first: Changing Shell endpoint paths, route source payload shape, or removing provider compatibility classes.
- Never: Change Feishu worker sharding behavior or DingTalk runner/UI behavior in this slice.

## Success Criteria
- Shared Shell transport and common payload parsing live in `lib/modules/local_monitor`.
- Feishu and DingTalk clients delegate HTTP/SSE/source sync to shared code.
- Existing Feishu and DingTalk tests pass.
- Analyzer reports no issues for touched modules.

## Open Questions
None for this slice.
