# Spec: Desktop IM Reconnect Device Identity

## Objective
Fix the Windows desktop app staying in "reconnecting" after the home page opens. The IM route and WSS handshake are reachable, so startup must align the WuKongIM SDK CONNECT credentials with the authenticated device session before connecting.

## Tech Stack
Flutter/Dart app with the local `packages/wukongimfluttersdk` package and WuKongIM protocol connections over WSS.

## Commands
- Focused tests: `D:\Apps\flutter\bin\flutter.bat test test/service/im/im_connection_service_test.dart test/realtime/device/device_identity_login_flow_test.dart packages/wukongimfluttersdk/test/manager/connect_device_id_test.dart`
- Analyze: `D:\Apps\flutter\bin\flutter.bat analyze`
- Run Windows: `D:\Apps\flutter\bin\flutter.bat run -d windows --dart-define=WK_DEV_BASE_URL=https://infoequity.cn --dart-define=WK_PROD_BASE_URL=https://infoequity.cn --dart-define=WK_DEV_WS_ADDR=wss://infoequity.cn/ws --dart-define=WK_PROD_WS_ADDR=wss://infoequity.cn/ws`

## Project Structure
- `lib/service/im/` -> app IM bootstrap and SDK setup.
- `lib/data/providers/auth_provider.dart` -> restored-session device binding refresh.
- `packages/wukongimfluttersdk/lib/` -> WuKongIM SDK options and CONNECT packet construction.
- `test/service/im/` and `packages/wukongimfluttersdk/test/manager/` -> regression tests.

## Code Style
```dart
final deviceId = (StorageUtils.getDeviceId() ?? '').trim();
await connection.setupSdk(
  credentials: credentials,
  deviceId: deviceId,
);
```

Keep credentials masked in logs and tests. Prefer explicit setup fields over SDK-local hidden state.

## Testing Strategy
Use focused unit tests for option propagation and SDK device ID resolution, plus restored-login tests for device binding refresh. Runtime verification is a Windows desktop launch and observing that the reconnect banner clears.

## Boundaries
- Always: keep tokens out of logs, preserve existing SDK fallback behavior, run focused tests before claiming fixed.
- Ask first: changing server API contracts or login token semantics.
- Never: print stored auth tokens, clear user data as a workaround, or revert unrelated workspace changes.

## Success Criteria
- SDK CONNECT packet uses the app-provided device ID when present.
- Restored authenticated sessions refresh device binding before exposing logged-in state.
- Windows app no longer stays permanently in reconnecting state after launch.

## Open Questions
- If production WuKongIM still rejects a freshly refreshed binding, inspect server-side connack or close diagnostics next.
