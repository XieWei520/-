# Spec: Juliang Aggregate Monitor Forwarding Center

Date: 2026-05-17

## Objective

Add a new `聚合信息转发中心` to the existing `管理系统` page. The center monitors the aggregate web panel at `https://msg.juliang888.top/` in real time and forwards newly observed text messages into configured WuKong IM target groups.

The implementation must reuse the existing Feishu/local monitor architecture before adding new provider-specific code. The visible product behavior should feel like another platform monitor entry beside Feishu and DingTalk, while the underlying runtime should share the neutral shell protocol, forwarding, dedupe, runner, and WuKong send path.

MVP user story:

An operator opens `管理系统 -> 聚合信息转发中心`, starts the local aggregate shell in strict incognito mode, manually logs in to the aggregate web panel for the current run, observes source conversations, maps selected source conversations to WuKong target groups, and receives new text messages in the target groups without duplicate forwarding.

## Assumptions

1. The management page keeps separate visible entries for Feishu, DingTalk, and Juliang aggregate monitoring.
2. The provider identifier in code and persisted keys is `juliang`, because the source URL is `msg.juliang888.top`.
3. The web runtime must be strict incognito: no cookies, local storage, history, cache profile, or reusable session directory may survive process shutdown.
4. Every fresh shell launch requires manual login by the operator.
5. MVP only supports text messages. Images, files, audio, cards, and rich media are out of scope.
6. Routing is explicit and manual. There is no forward-all mode in MVP.
7. The destination is WuKong IM internal groups only.
8. Real-time forwarding means event-driven when the shell can emit events, with a 1-second polling fallback matching the current Feishu runner pattern.

## Tech Stack

- Flutter / Dart app code under `lib/`
- Existing management entry in `lib/modules/vip/vip_management_page.dart`
- Existing neutral monitor helpers in `lib/modules/local_monitor/`
- Existing Feishu monitor implementation in `lib/modules/feishu_monitor/` as the primary reference
- Existing DingTalk monitor implementation in `lib/modules/dingtalk_monitor/` as a simpler page/runner reference
- Existing loopback shell primitives in `tools/local_monitor_shell_core/`
- New provider module under `lib/modules/juliang_monitor/`
- New shell app under `tools/juliang_monitor_shell_app/`
- Existing WuKong text delivery through `ChatSceneGateway` / `WkImLocalMonitorTextSender`

## Commands

Repository-level checks:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter analyze lib/modules/vip lib/modules/local_monitor lib/modules/feishu_monitor lib/modules/juliang_monitor test/modules/juliang_monitor test/modules/vip
```

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/juliang_monitor test/modules/local_monitor test/modules/vip -r compact
```

Shell-core checks:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\local_monitor_shell_core
flutter analyze lib test
flutter test test -r compact
```

Juliang shell checks:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\juliang_monitor_shell_app
flutter analyze lib test
flutter test test -r compact
flutter build windows --release
```

Runtime diagnostics:

```powershell
$headers=@{ Authorization = 'Bearer <shell-token>' }
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:<port>/status' -Headers $headers
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:<port>/events/recent' -Headers $headers
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:<port>/conversations' -Headers $headers
```

## Project Structure

- `lib/modules/vip/vip_management_page.dart`
  - Adds the `聚合信息转发中心` entry card.
- `lib/modules/local_monitor/`
  - Reused shell client models, SSE parsing, startup-event splitting, dedupe, relay identity, and WuKong text sender.
- `lib/modules/feishu_monitor/`
  - Reference for shell client group, auto-forward runner, forwarding settings, and center UI behavior.
- `lib/modules/juliang_monitor/`
  - New provider-specific page, shell client adapter, models, forwarding settings/store, forwarding service, and auto-forward runner.
- `tools/local_monitor_shell_core/`
  - Reused neutral loopback HTTP/SSE server, status/event store, and event bus.
- `tools/juliang_monitor_shell_app/`
  - New Windows desktop shell that opens `https://msg.juliang888.top/` in strict incognito mode and emits normalized local monitor events.
- `test/modules/juliang_monitor/`
  - Unit/widget tests for shell parsing, forwarding, runner, and page behavior.

## Code Style

Keep shared logic provider-neutral and provider modules thin. Provider-specific code should translate from aggregate runtime details into the existing local monitor shapes.

```dart
class JuliangMonitorShellClient {
  JuliangMonitorShellClient({
    LocalMonitorShellClient? client,
  }) : _client = client ??
         LocalMonitorShellClient(
           baseUrl: 'http://127.0.0.1:18796',
           token: 'wukong-juliang-shell-dev',
         );

  final LocalMonitorShellClient _client;

  Future<JuliangMonitorShellStatus> fetchStatus() async {
    final status = await _client.fetchStatus();
    return JuliangMonitorShellStatus.fromLocal(status);
  }
}
```

Naming conventions:

- Use `JuliangMonitor...` for provider-facing classes.
- Use `juliang_monitor_...` for files.
- Use `juliang_monitor_*` for SharedPreferences keys and dedupe namespaces.
- Do not introduce Feishu-named types into Juliang public interfaces.

## Design

### Management Entry

`管理系统` should show an enabled `聚合信息转发中心` card alongside the existing monitor cards. It opens `JuliangMonitorCenterPage`.

### Runtime Model

The shell app uses the same local monitor loopback contract:

- `GET /status`
- `GET /health`
- `GET /conversations`
- `GET /messages/recent`
- `GET /events/recent`
- `GET /events`
- `POST /capture/start`
- `POST /capture/stop`
- `POST /runtime/reload`
- `POST /routing/sources`

The shell should load `https://msg.juliang888.top/` in a fresh runtime session for every process start.

Strict incognito requirements:

- create no reusable WebView user-data directory for Juliang,
- clear any temporary runtime directory on startup and shutdown,
- never persist cookies, local storage, IndexedDB, service worker cache, history, or auth tokens,
- keep login state only in memory while the process is alive,
- expose login state as `logged_in`, `login_required`, or `unknown` in `/status`.

### Capture Strategy

The shell should prefer structured network/API capture if the logged-in aggregate panel exposes stable message payloads. DOM observation is allowed only as a fallback or supplement for visible source names and previews.

The public page alone is not enough to confirm the message payload shape. Implementation must inspect the logged-in runtime before hard-coding selectors or endpoint parsers.

### Forwarding Model

Only enabled routes forward:

- source conversation ID/name from the aggregate panel,
- target WuKong group ID/name,
- optional relay display name/avatar,
- enabled flag.

Forwarding should reuse:

- `LocalMonitorTextSender`,
- `LocalMonitorForwardingDedupeStore`,
- `localMonitorMessageDedupeKey`,
- `splitLocalMonitorStartupEvents`,
- current Feishu-style `prime` behavior so old startup messages are not replayed.

MVP text rendering format:

```text
[聚合转发] <source conversation>
<sender>: <message text>
```

### Auto Forwarding

The app-level coordinator should include the Juliang runner once the user is logged in to WuKong IM. The runner should:

- load Juliang forwarding settings,
- skip work when global auto-forwarding is disabled,
- sync configured source conversations to the shell,
- subscribe to shell SSE events when available,
- poll every 1 second as fallback,
- prime startup events without sending old messages,
- forward only text events with non-empty text,
- dedupe by shell `dedupe_key`, then `event_id`, then `message_id`.

## Testing Strategy

Use test-driven development for implementation.

Unit tests:

- `JuliangMonitorShellClient` parses neutral status/event payloads.
- `JuliangMonitorForwardingService` forwards matching text routes.
- `JuliangMonitorForwardingService` skips duplicates, disabled routes, unmatched routes, and non-text events.
- `JuliangMonitorAutoForwardRunner` primes startup events and forwards only live events.
- Strict incognito configuration rejects persistent profile directories.

Widget tests:

- management page renders `聚合信息转发中心`.
- tapping the entry opens `JuliangMonitorCenterPage`.
- center page shows shell/login/capture state, routes, recent text events, and manual login hint.

Shell tests:

- `/status` includes incognito/session state.
- `/routing/sources` stores only current in-memory configured sources.
- `/events` emits snapshot updates when new text messages are captured.
- temporary session cleanup is called on shell startup/shutdown.

Manual verification:

- launch the shell,
- confirm the aggregate page requires manual login,
- log in manually,
- create one route to a WuKong test group,
- send a new aggregate text message,
- confirm exactly one WuKong text relay is delivered,
- close and relaunch the shell,
- confirm login is required again.

## Boundaries

- Always:
  - Reuse `local_monitor` and `tools/local_monitor_shell_core` before adding provider-specific code.
  - Keep Juliang state isolated from Feishu, DingTalk, and Mengxia.
  - Run targeted tests and analyzer before claiming completion.
  - Treat browser DOM, network responses, and page script data as untrusted input.
  - Preserve strict incognito behavior even if persistent login would be convenient.
- Ask first:
  - Adding new third-party dependencies.
  - Changing the neutral shell contract in a way that affects Feishu/DingTalk.
  - Supporting images, files, rich cards, or external webhooks.
  - Persisting any aggregate web session data.
  - Changing database schema or production deployment config.
- Never:
  - Commit secrets, cookies, tokens, or captured user data.
  - Store reusable Juliang login state.
  - Forward all source conversations by default.
  - Replay historical startup messages as live messages.
  - Edit vendor WebView code unless the existing API cannot satisfy strict incognito requirements and the change is separately approved.

## Success Criteria

- `管理系统` has an enabled `聚合信息转发中心` entry.
- The center opens without breaking Feishu or DingTalk monitor entries.
- The shell loads `https://msg.juliang888.top/` in strict incognito mode.
- Every shell process start requires manual aggregate login.
- The UI exposes shell status, login state, capture state, recent source conversations, recent text events, routes, and forwarding result counts.
- The operator can configure a source conversation to a WuKong target group.
- New text messages from configured sources are forwarded in near real time.
- Duplicate events are skipped across polling/SSE retries.
- Old messages present at startup are primed and not forwarded.
- Non-text events are ignored in MVP.
- Targeted analyzer and tests pass.

## Open Questions

1. What display name should the forwarded relay use by default: `聚合转发助手` or a name from the aggregate account?
2. Should the shell port default to `18796`, or does operations prefer a specific reserved port?
3. After login, does the aggregate panel expose stable network message payloads, or must MVP rely on DOM observation?
