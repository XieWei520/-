# Spec: Home Bootstrap IM Degraded Startup

## Objective
Allow an authenticated Windows desktop user to enter the main chat shell when the IM WebSocket connection is temporarily unavailable. Startup should not get stuck on the retry-only page while the SDK continues reconnecting in the background.

## Tech Stack
- Flutter / Dart SDK `^3.11.1`
- Riverpod home bootstrap provider
- WuKongIM SDK connection state

## Commands
- Focused tests: `flutter test test/modules/home/home_shell_page_test.dart`
- Analyze: `flutter analyze`
- Desktop run: `D:\Apps\flutter\bin\flutter.bat run -d windows --dart-define=WK_DEV_BASE_URL=https://infoequity.cn --dart-define=WK_PROD_BASE_URL=https://infoequity.cn --dart-define=WK_DEV_WS_ADDR=wss://infoequity.cn/ws --dart-define=WK_PROD_WS_ADDR=wss://infoequity.cn/ws`

## Project Structure
- `lib/modules/home/home_surface_kernel.dart` -> Home bootstrap readiness policy.
- `lib/modules/home/home_shell_page.dart` -> Main shell retry state and connection banner.
- `test/modules/home/home_shell_page_test.dart` -> Bootstrap and shell behavior tests.

## Code Style
Keep the degraded startup decision explicit at the bootstrap boundary.

```dart
if (!ok && StorageUtils.isLoggedIn()) {
  await ref.read(homeConversationBootstrapRefresherProvider).call();
  await ref.read(homeContactsBootstrapRefresherProvider).call();
  state = const HomeBootstrapState.ready();
  return;
}
```

## Testing Strategy
- Unit test the bootstrap controller path where IM initialization returns `false` for an authenticated session.
- Widget test the shell path to ensure it renders tabs and a connection banner instead of the retry-only state.
- Keep existing retry behavior for real bootstrap exceptions.

## Boundaries
- Always: keep IM reconnecting in the existing service; show the main shell for authenticated degraded sessions.
- Ask first: changing IM SDK connection protocol, device identity binding, or backend WebSocket endpoints.
- Never: clear user login state just because the WebSocket is temporarily unavailable.

## Success Criteria
- Authenticated desktop startup can render the main shell when IM initialization returns `false`.
- The retry-only page is reserved for true bootstrap exceptions.
- A connection banner is shown when IM has an error or is reconnecting.
- Existing home shell tests continue to pass.

## Open Questions
None for this fix. The backend WebSocket availability should still be investigated separately if reconnects continue indefinitely.
