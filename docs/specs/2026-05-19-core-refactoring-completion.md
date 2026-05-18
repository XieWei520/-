# Spec: Core Refactoring Completion

## Objective
Finish the cautious God Object split for the IM runtime and chat shell. The goal is not to change user-visible chat behavior; it is to move orchestration out of oversized entry classes so future performance and reliability work lands behind explicit service/controller boundaries.

## Tech Stack
Flutter, Dart, Riverpod, WuKong IM Flutter SDK.

## Commands
Format: `dart format lib/service/im lib/modules/chat test/service/im test/modules/chat docs/specs/2026-05-19-core-refactoring-completion.md`

Focused tests: `flutter test test/service/im/im_runtime_provider_graph_test.dart test/service/im/im_service_structure_test.dart test/modules/chat/chat_page_shell_structure_test.dart`

Analyze: `flutter analyze lib/service/im lib/modules/chat test/service/im/im_runtime_provider_graph_test.dart test/service/im/im_service_structure_test.dart test/modules/chat/chat_page_shell_structure_test.dart`

Runtime smoke: `flutter run -d windows`

## Project Structure
`lib/service/im/` contains extracted IM runtime services, SDK callback binding, and the Riverpod provider graph.

`lib/modules/chat/` contains the production `ChatPageShell`, controller/state services, and pane widgets.

`test/service/im/` and `test/modules/chat/` contain behavior tests plus source-level structure guard tests for the refactor boundaries.

## Code Style
```dart
final controller = ref.watch(chatShellControllerProvider(session));

return ChatHeaderPane(
  session: session,
  state: controller.headerState,
  onOpenDetails: _openChatInfo,
);
```

Entry widgets should assemble layout and route user intents to services. SDK calls, remote hydration, persistence, and message loading should live in services/controllers with explicit constructor dependencies.

## Testing Strategy
- Provider graph tests prove the five IM services are assembled through Riverpod.
- Structure tests prevent the production chat shell from directly depending on SDK/network implementation details.
- Existing unit tests continue to cover extracted service behavior.
- Manual runtime smoke is required after this multi-file refactor.

## Boundaries
- Always: keep public route constructors compatible and preserve existing UI behavior.
- Always: prefer moving code unchanged into services before changing behavior.
- Ask first: deleting deprecated files, changing database schema, or changing SDK dependency versions.
- Never: bypass failing tests by weakening assertions or removing coverage.

## Success Criteria
- `IMService` consumes extracted services and no longer directly registers SDK message/cmd/conversation callbacks.
- The Riverpod Provider Graph composes `ImConnectionService`, `ImSyncOrchestrator`, `AttachmentUploadPipeline`, `MessageDeliveryService`, and `ImNotificationBridge`.
- `ChatPageShell` is a layout container that delegates channel hydration, initial message loading, robot menu loading, pinned state, and conversation restore persistence to a controller/service boundary.
- The production chat shell uses `ChatHeaderPane`, `ChatViewportPane`, `ChatComposerPane`, and `ChatOverlayCoordinator`.
- `ChatPageShell` no longer imports `dio`, `WKIM`, or direct WuKong SDK channel classes except where widget props require SDK message/channel model types.
- Focused tests and analyze pass.

## Open Questions
None for this slice. Further component splitting inside `ChatComposerPane` can continue after the shell/controller boundary is complete.
