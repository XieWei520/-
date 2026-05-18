# Spec: Message Render Registry and Desktop Shell

## Objective
Move chat message content rendering behind a registry so new IM message types can be added without editing `MessageBubble` switch branches. Add a cross-platform `DesktopShellService` boundary for desktop/web shell actions and composer keyboard policy.

## Tech Stack
Flutter, Dart, Riverpod, conditional imports, WuKong IM Flutter SDK.

## Commands
Format: `dart format lib/widgets lib/platform lib/modules/chat test/widgets test/platform`

Focused tests: `flutter test test/widgets/message_render_registry_test.dart test/platform/desktop_shell_service_test.dart`

Analyze: `flutter analyze lib/widgets lib/platform lib/modules/chat/panes/chat_composer_pane.dart test/widgets/message_render_registry_test.dart test/platform/desktop_shell_service_test.dart`

## Project Structure
`lib/widgets/message_render_registry.dart` owns renderer interfaces, registry, default registrations, and custom renderer examples.

`lib/widgets/message_renderers/` contains concrete media renderers extracted from the legacy bubble methods.

`lib/platform/desktop_shell_service.dart` exposes a stable shell service API with conditional implementation files for native IO, JS interop web, and stub platforms.

`test/widgets/` and `test/platform/` hold behavior and structure tests for the new extension points.

## Code Style
```dart
final registry = MessageRenderRegistry.defaults()
  ..register(
    MessageRendererRegistration(
      contentType: redPacketType,
      renderer: RedPacketMessageRenderer(),
    ),
  );

MessageBubble(model: model, renderRegistry: registry);
```

Renderers should be small stateless classes. Platform APIs should be hidden behind services and injected through Riverpod.

## Testing Strategy
- Unit/widget tests prove custom message types render through the registry.
- Structure tests guard against image/video rendering returning to private `_build*Content` methods.
- Platform service tests prove conditional service defaults are safe and keyboard policy is deterministic.

## Boundaries
- Always: preserve existing visual behavior for built-in image and video bubbles.
- Always: keep platform-specific code behind conditional imports, using `dart.library.js_interop` for web implementations.
- Ask first: adding native dependencies such as `window_manager`, `bitsdojo_window`, `tray_manager`, or editing native Windows runner code.
- Never: remove existing message types or weaken message bubble tests to make the refactor pass.

## Success Criteria
- `MessageBubble` content dispatch uses `MessageRenderRegistry`, not a switch over content type.
- Image and video renderers are independent `MessageRenderer` implementations.
- Custom renderer registration is demonstrated in code for red packet, card, and location-style types.
- `DesktopShellService` has Windows/Web/stub implementations and a Riverpod provider.
- Composer keyboard handling uses a shell keyboard policy for Enter send and Shift+Enter newline.
- Focused tests and analyze pass.
