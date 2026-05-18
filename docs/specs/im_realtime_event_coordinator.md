# Spec: IM Realtime Event Coordinator

## Assumptions
1. This slice only extracts realtime/session event handling currently embedded in `IMService`.
2. Session frame parsing remains delegated to `mapSessionControlEvent`.
3. Conversation patch application keeps using the existing `ConversationPatch.unreadAndDigest` contract.
4. Video-call frame handling still runs for every session frame.
5. Recovered calling state behavior stays identical: apply current calling rows and clear stale calling conversations.

## Objective
Move realtime session frame side effects and recovered calling state reconciliation into `ImRealtimeEventCoordinator`, reducing `IMService` to wiring and delegation.

## Tech Stack
Flutter, Dart, Riverpod, WuKong IM Flutter SDK.

## Commands
Focused test: `flutter test test/service/im/im_realtime_event_coordinator_test.dart test/service/im/im_service_test.dart test/service/im/im_service_web_policy_test.dart --reporter expanded`

Analyze: `flutter analyze`

Diff check: `git diff --check`

## Project Structure
`lib/service/im/im_realtime_event_coordinator.dart` owns:
- mapping `SessionEventFrame` control events
- applying conversation patches
- forwarding every frame to the call coordinator
- reconciling recovered calling states from `WKChannelState`

`lib/service/im/im_service.dart` delegates session frame and recovered calling state handling to the coordinator.

## Code Style
```dart
Future<void> _handleSessionFrame(SessionEventFrame frame) {
  return _realtimeEventCoordinator.handleSessionFrame(frame);
}
```

Use injected callbacks for patch application, call frame handling, and activity state mutation so the coordinator is testable without Riverpod containers or singleton state.

## Testing Strategy
Unit tests verify:
- `conversation.updated` frames produce the expected `ConversationPatch.unreadAndDigest`.
- every frame is forwarded to the call handler.
- recovered calling state returns active keys and clears stale calling conversations.

## Boundaries
- Always: preserve control event mapping, patch fields, call handler forwarding, and stale calling cleanup.
- Ask first: changing realtime frame payload schema or call recovery semantics.
- Never: change websocket connection lifecycle, sync orchestration, outbox, or notification behavior in this slice.

## Success Criteria
- `IMService` no longer directly calls `mapSessionControlEvent` or directly applies conversation patches for session frames.
- `IMService.applyRecoveredCallingStates` delegates to `ImRealtimeEventCoordinator`.
- Focused tests, `flutter analyze`, and `git diff --check` pass.
