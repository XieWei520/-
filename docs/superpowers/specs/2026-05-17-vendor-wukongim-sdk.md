# Spec: Vendor WuKongIM Flutter SDK

## Objective
Move the local WuKongIM Flutter SDK dependency into this repository so the app can be built without relying on `../TangSengDaoDao/WuKongIMFlutterSDK-master`. Keep the WebSocket compression fix with the SDK source.

## Tech Stack
Flutter app with a path dependency on the `wukongimfluttersdk` Dart/Flutter package.

## Commands
- Refresh dependencies: `flutter pub get`
- SDK transport tests: `flutter test test/transport/connection_transport_test.dart`
- Main app spot test: `flutter test test/modules/home/home_shell_page_test.dart --plain-name "home shell hides connection banner after sync completes"`
- Windows release build: `powershell -ExecutionPolicy Bypass -File .\build_windows_release.ps1`

## Project Structure
- `packages/wukongimfluttersdk/` -> vendored WuKongIM Flutter SDK source.
- `packages/wukongimfluttersdk/lib/` -> SDK Dart source.
- `packages/wukongimfluttersdk/assets/` -> SDK database migration assets.
- `packages/wukongimfluttersdk/test/` -> SDK regression tests.
- `pubspec.yaml` -> app dependency points to `packages/wukongimfluttersdk`.

## Code Style
Use the existing Flutter package layout and path dependency style:

```yaml
wukongimfluttersdk:
  path: packages/wukongimfluttersdk
```

## Testing Strategy
Run the SDK transport regression test from the vendored SDK package, then run the app dependency refresh and a main app connection-banner spot test. Build Windows release to prove the app consumes the vendored package.

## Boundaries
- Always: keep the WebSocket compression fix; copy only SDK source/config/test/assets needed for development; run verification after changing the dependency path.
- Ask first: deleting the old external SDK directory; converting the SDK to a Git submodule; publishing the SDK as a separate package.
- Never: copy build caches such as `.dart_tool` or `build`; copy desktop shortcut files; revert unrelated dirty changes in the main app.

## Success Criteria
- Main app `pubspec.yaml` no longer references `../TangSengDaoDao/WuKongIMFlutterSDK-master`.
- `packages/wukongimfluttersdk/lib/manager/connection_transport_io.dart` contains `CompressionOptions.compressionOff`.
- `flutter pub get` succeeds from the main app.
- SDK transport test passes from `packages/wukongimfluttersdk`.
- Main app connection-banner spot test passes.
- Windows release build succeeds.

## Open Questions
None for this migration. The old external SDK directory is intentionally left untouched.
