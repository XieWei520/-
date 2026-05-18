# Spec: Local Monitor Shell Core Refactor

## Objective
Extract the duplicated local monitor Shell implementation shared by Feishu and DingTalk into one provider-neutral Dart package. Feishu and DingTalk shell packages must keep their current public entrypoints and CLI defaults while delegating shared HTTP, SSE, snapshot, and persistence behavior to the common package.

## Tech Stack
Dart packages under `tools/` using SDK `^3.11.1`, `lints`, and `test`.

## Commands
- Core analyze: `dart analyze` from `tools/local_monitor_shell_core`
- Core test: `dart test` from `tools/local_monitor_shell_core`
- Feishu shell analyze: `dart analyze` from `tools/feishu_monitor_shell`
- Feishu shell test: `dart test` from `tools/feishu_monitor_shell`
- DingTalk shell analyze: `dart analyze` from `tools/dingtalk_monitor_shell`
- DingTalk shell test: `dart test` from `tools/dingtalk_monitor_shell`

## Project Structure
- `tools/local_monitor_shell_core/` -> Provider-neutral Shell core package
- `tools/local_monitor_shell_core/lib/src/` -> Shared models, store, server, event bus
- `tools/feishu_monitor_shell/` -> Feishu CLI wrapper and compatibility exports
- `tools/dingtalk_monitor_shell/` -> DingTalk CLI wrapper and compatibility exports

## Code Style
```dart
final server = ShellServer(
  store: ShellStore(File(statePath)),
  host: InternetAddress.loopbackIPv4,
  port: port,
  token: token,
);
```
Keep constructor names and JSON wire fields unchanged. Wrapper packages should not fork shared model or server code.

## Testing Strategy
Use the existing Shell server tests in both provider packages as compatibility tests. Add a core package server test so the shared package is directly guarded.

## Boundaries
- Always: Preserve Feishu and DingTalk CLI defaults, authorization behavior, routes, SSE event format, and snapshot JSON.
- Ask first: Changing Shell HTTP endpoints, JSON field names, auth scheme, or default ports/tokens.
- Never: Rework Feishu media capture, DingTalk WebView probing, or unrelated app modules in this refactor.

## Success Criteria
- `ShellEventBus`, `ShellSnapshot`, `ShellServer`, and `ShellStore` are implemented once in `tools/local_monitor_shell_core`.
- Feishu and DingTalk shell packages expose the same public symbols as before through compatibility exports.
- Existing Feishu and DingTalk shell tests pass.
- New core shell test passes.

## Open Questions
None for this slice.
