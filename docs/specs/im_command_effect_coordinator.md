# Spec: IM Command Effect Coordinator

## Assumptions
1. This slice only moves command side-effect execution out of `IMService`.
2. Existing command parsing in `CommandDispatcher` remains unchanged.
3. VIP expiration handlers keep their current register/unregister behavior and snapshot invocation semantics.
4. Message-extra sync still uses the `IMService` device UUID and realtime refresh path through an injected callback.

## Objective
Extract `_handleCmd` side effects from `IMService` into `ImCommandEffectCoordinator` so `IMService` only forwards SDK commands to a dedicated coordinator.

## Tech Stack
Flutter, Dart, Riverpod, WuKong IM Flutter SDK.

## Commands
Focused test: `flutter test test/service/im/im_command_effect_coordinator_test.dart test/service/im/coordinators/command_dispatcher_test.dart test/service/im/im_service_test.dart test/service/im/im_service_web_policy_test.dart --reporter expanded`

Analyze: `flutter analyze`

Diff check: `git diff --check`

## Project Structure
`lib/service/im/im_command_effect_coordinator.dart` owns command side-effect execution:
- VIP expiration handler notification
- conversation activity command forwarding
- contact provider invalidation
- reminder/conversation-extra/message-extra sync scheduling

`lib/service/im/coordinators/command_dispatcher.dart` remains the pure parser/planner.

`lib/service/im/im_service.dart` owns SDK callback registration and delegates command handling.

## Code Style
```dart
void _handleCmd(WKCMD cmd) {
  _commandEffectCoordinator.handleCommand(cmd);
}
```

Keep command execution dependencies injected as functions so the coordinator is testable without connecting SDK, Riverpod containers, or local storage.

## Testing Strategy
Unit tests verify:
- VIP expiration handlers are called from a snapshot and can be unregistered safely.
- Contact refresh commands invalidate the same providers as before.
- Sync commands schedule conversation-extra, message-extra, and reminder sync with the existing `cmd:<raw command>` reason.
- Every handled command is forwarded to the conversation activity bridge with the current UID.

## Boundaries
- Always: preserve command names, reason strings, target extraction, and fire-and-forget scheduling.
- Ask first: changing command names, adding new server command semantics, or changing provider refresh behavior.
- Never: change WebSocket connection, message send/outbox, notification, or local DB behavior in this slice.

## Success Criteria
- `IMService` no longer directly invalidates friend providers or calls `ConversationActivityRegistry.instance.handleCommand` from `_handleCmd`.
- `IMService` delegates command handling to `ImCommandEffectCoordinator`.
- Focused tests, `flutter analyze`, and `git diff --check` pass.
