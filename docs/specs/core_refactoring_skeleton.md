# Spec: IM Core Refactoring Skeleton

## Objective
Prepare a low-risk review scaffold for splitting the current IM runtime and chat page God Objects. This change is additive only: it introduces service and pane boundaries without moving production behavior out of `IMService` or `ChatPageShell` yet.

## Tech Stack
Flutter, Dart, Riverpod, WuKong IM Flutter SDK.

## Commands
Format: `dart format lib/service/im lib/modules/chat/panes lib/modules/chat/chat_page_shell_refactor_preview.dart test/service/im test/modules/chat`

Test: `flutter test test/service/im/im_runtime_provider_graph_test.dart test/modules/chat/chat_page_shell_refactor_preview_test.dart`

Connection migration test: `flutter test test/service/im/im_connection_service_test.dart test/service/im/im_service_test.dart`

Analyze: `flutter analyze lib/service/im/im_connection_service.dart lib/service/im/im_sync_orchestrator.dart lib/service/im/attachment_upload_pipeline.dart lib/service/im/im_notification_bridge.dart lib/service/im/im_service_providers.dart lib/service/im/im_service.dart lib/modules/chat/panes lib/modules/chat/chat_page_shell_refactor_preview.dart test/service/im/im_runtime_provider_graph_test.dart test/service/im/im_connection_service_test.dart test/service/im/im_service_test.dart test/modules/chat/chat_page_shell_refactor_preview_test.dart`

## Project Structure
`lib/service/im/` contains the IM runtime service skeletons and Provider Graph.

`lib/modules/chat/panes/` contains public pane widgets for the future chat page split.

`lib/modules/chat/chat_page_shell_refactor_preview.dart` contains the additive layout-container preview.

`test/service/im/` and `test/modules/chat/` contain compile/provider graph guard tests.

## Code Style
```dart
final imRuntimeServicesProvider = Provider<ImRuntimeServices>((ref) {
  return ImRuntimeServices(
    connection: ref.watch(imConnectionServiceProvider),
    sync: ref.watch(imSyncOrchestratorProvider),
    attachments: ref.watch(attachmentUploadPipelineProvider),
    delivery: ref.watch(messageDeliveryServiceProvider),
    notifications: ref.watch(imNotificationBridgeProvider),
  );
});
```

Use small classes with explicit constructor dependencies. Keep side effects behind method calls, not constructors.

## Testing Strategy
The first stage is a skeleton stage, so tests assert:

- The five IM services are individually available through Riverpod.
- The aggregate Provider Graph reuses the same service instances.
- The chat layout preview builds from the four pane widgets.

Behavioral migration tests come later when production logic moves out of the old God Objects.

## Boundaries
- Always: keep this stage additive and compile-safe.
- Ask first: replacing the existing `imServiceProvider` or exporting the preview shell as production `ChatPageShell`.
- Never: delete or rewrite the current `lib/service/im/im_service.dart` and `lib/modules/chat/chat_page_shell.dart` in this skeleton stage.

## Success Criteria
- New skeleton classes compile.
- Riverpod Provider Graph composes all five services.
- The preview shell builds with `ChatHeaderPane`, `ChatViewportPane`, `ChatComposerPane`, and `ChatOverlayCoordinator`.
- Existing production entry points are unchanged.
- Connection listener registration, SDK setup, route fallback, and connect dispatch can be routed through `ImConnectionService` without moving database readiness, sync callbacks, attachment upload, or notification dispatch.

## Open Questions
- After review, decide whether to migrate `IMService` by connection lifecycle first or by SDK callback group first.
- After review, decide whether `ChatViewportPane` or `ChatComposerPane` should be the first production pane replacement.
