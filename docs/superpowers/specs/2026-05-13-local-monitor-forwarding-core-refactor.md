# Spec: Local Monitor Forwarding Core Refactor

## Objective
Extract provider-neutral WuKong IM forwarding primitives from the Feishu monitor module so DingTalk does not depend on Feishu-named sender, relay identity, or dedupe interfaces. Keep Feishu's existing public API source-compatible while allowing DingTalk to import neutral monitor forwarding types.

## Tech Stack
Flutter/Dart app code under `lib/modules`, using existing `ChatSceneGateway`, WuKong IM SDK content classes, and `shared_preferences`.

## Commands
- Analyze: `flutter analyze lib/modules/local_monitor lib/modules/feishu_monitor lib/modules/dingtalk_monitor test/modules/feishu_monitor test/modules/dingtalk_monitor`
- Feishu forwarding tests: `flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
- DingTalk forwarding tests: `flutter test test/modules/dingtalk_monitor/dingtalk_monitor_forwarding_service_test.dart`

## Project Structure
- `lib/modules/local_monitor/` -> Provider-neutral monitor forwarding primitives
- `lib/modules/feishu_monitor/` -> Feishu-specific route/media logic and compatibility aliases
- `lib/modules/dingtalk_monitor/` -> DingTalk route/text forwarding logic without Feishu imports

## Code Style
```dart
await sender.sendText(
  channelId: route.targetGroupId.trim(),
  channelType: WKChannelType.group,
  text: formatDingTalkMonitorEventForForward(event),
  relayIdentity: route.relayIdentity(),
);
```
Provider-specific modules own route matching and formatting. Shared code owns WuKong IM payload identity and generic text send behavior.

## Testing Strategy
Use existing Feishu and DingTalk forwarding tests as behavioral compatibility coverage. Add/adjust DingTalk structural coverage so its forwarding service no longer imports Feishu forwarding types.

## Boundaries
- Always: Preserve Feishu forwarding behavior, media sending behavior, dedupe persistence keys, and DingTalk text forwarding behavior.
- Ask first: Changing message payload shape, WuKong IM gateway semantics, image upload paths, or persisted preference keys.
- Never: Move Feishu media extraction logic into the generic module in this slice.

## Success Criteria
- DingTalk forwarding service and settings no longer import `feishu_monitor_forwarding_service.dart`.
- Feishu compatibility names remain available for existing tests and callers.
- Existing Feishu and DingTalk forwarding tests pass.
- Analyzer reports no issues for touched modules.

## Open Questions
None for this slice.
