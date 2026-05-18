# Spec: Mengxia Monitor Center With Parallel Management Entry

Date: 2026-05-15

## Objective

Add a new `萌侠信息转发中心` to the existing `系统管理` page alongside the current `飞书信息监控中心`, while reusing the existing provider-neutral local monitor and WuKong forwarding infrastructure instead of cloning the Feishu implementation.

This slice is explicitly **not** a top-level navigation redesign. The management page should continue to show parallel platform entries. The unification happens under the hood:

- shared monitor-center page scaffolding and interaction sections,
- shared `local_monitor` shell protocol and event model,
- shared runner / forwarding / dedupe abstractions,
- provider-specific shell apps and provider-specific UI wrappers.

The Mengxia center must support:

- manual source-conversation routing only,
- real-time forwarding into WuKong internal target groups only,
- absolute incognito operation,
- manual login on every launch,
- no reusable persisted Mengxia session state after shutdown.

Success means the user can open `萌侠信息转发中心` from `系统管理`, manually log in to Mengxia for the current run, observe source conversations, configure selected `萌侠源会话 -> 悟空目标群` routes, and forward new Mengxia events in near real time without regressing the existing Feishu center.

## Assumptions

1. The `系统管理` page must keep separate visible entries for Feishu and Mengxia instead of collapsing them into one top-level monitor entry.
2. Mengxia monitoring is scoped to WuKong desktop runtime behavior in this slice, matching the current Windows-local shell architecture used by Feishu.
3. Mengxia login is always manual and must happen again on every fresh monitor launch.
4. Absolute incognito mode takes precedence over login reuse, so no Mengxia cookie, local storage, history, or reusable session directory may survive shutdown.
5. Only explicitly configured Mengxia source conversations may forward. There is no “forward all conversations” mode in this slice.
6. The destination is WuKong internal groups only. No Feishu bot, webhook, or third-party external forwarding is in scope.

## Tech Stack

- Flutter / Dart app code under `lib/`
- Existing `lib/modules/local_monitor/` neutral shell client / runner / forwarding utilities
- Existing `lib/modules/feishu_monitor/` as the reference provider implementation
- Existing `tools/local_monitor_shell_core/` HTTP + SSE shell server/store/event-bus package
- New Mengxia-specific shell runtime under `tools/mengxia_monitor_shell_app/`
- Windows desktop WebView runtime pattern consistent with the current Feishu shell app architecture
- Existing WuKong send path via `ChatSceneGateway` / `ApiChatSceneGateway`

## Commands

Use these commands for implementation and verification of this feature:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter analyze lib/modules/vip lib/modules/local_monitor lib/modules/feishu_monitor lib/modules/mengxia_monitor lib/modules/monitor_center test/modules/feishu_monitor test/modules/mengxia_monitor test/modules/monitor_center
```

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/monitor_center test/modules/mengxia_monitor test/modules/feishu_monitor -r compact
```

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\local_monitor_shell_core
flutter test test -r compact
flutter analyze lib test
```

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\mengxia_monitor_shell_app
flutter test test -r compact
flutter analyze lib test
flutter build windows --release
```

Runtime diagnostics for a local monitor shell instance:

```powershell
$headers=@{ Authorization = 'Bearer <shell-token>' }
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:<port>/status' -Headers $headers
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:<port>/events/recent' -Headers $headers
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:<port>/conversations' -Headers $headers
```

## Project Structure

- `lib/modules/vip/vip_management_page.dart`
  - Keeps the management-page parallel platform entry cards.
- `lib/modules/monitor_center/`
  - New shared monitor-center UI shell and provider-facing page sections.
- `lib/modules/local_monitor/`
  - Neutral runner / shell client / forwarding helpers reused by both providers.
- `lib/modules/feishu_monitor/`
  - Existing Feishu provider, retained as the compatibility reference.
- `lib/modules/mengxia_monitor/`
  - New Mengxia provider-specific page wrapper, shell client, models, runner, and forwarding settings.
- `tools/local_monitor_shell_core/`
  - Neutral loopback HTTP/SSE shell protocol primitives.
- `tools/feishu_monitor_shell_app/`
  - Existing reference shell runtime.
- `tools/mengxia_monitor_shell_app/`
  - New Mengxia-specific shell runtime using the same loopback contract shape.
- `test/modules/monitor_center/`
  - Shared monitor-center UI and interaction tests.
- `test/modules/mengxia_monitor/`
  - Mengxia client / runner / forwarding / widget tests.

## Code Style

Prefer provider-neutral interfaces for shared infrastructure, then thin provider-specific adapters at the edge.

```dart
abstract class MonitorCenterPlatformClient<TStatus, TEvent> {
  Future<TStatus> fetchStatus();
  Future<void> startCapture();
  Future<void> stopCapture();
  Future<void> reloadRuntime();
  Stream<TEvent> watchEvents();
}
```

Platform entry wiring on the management page should stay explicit and simple:

```dart
void _openMengxiaCenter(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MengxiaMonitorCenterPage(),
    ),
  );
}
```

Shared code owns generic monitor-center sections, shell protocol access, and WuKong forwarding primitives. Provider modules own provider naming, route matching, incognito policy, login-state semantics, and runtime-specific event normalization.

## Design

### Management Page Entry Model

The `系统管理` page keeps parallel cards:

- `飞书信息监控中心`
- `萌侠信息转发中心`

This is a deliberate UX choice. The user asked to keep parallel visible entries on the management page, so this slice must not replace them with one top-level unified entry.

What becomes unified is the implementation beneath those cards:

- shared monitor center page sections,
- shared neutral shell contract,
- shared forwarding abstractions,
- provider-specific wrappers for Feishu and Mengxia.

### UI Architecture

Recommended page structure:

```text
系统管理页
  -> 飞书信息监控中心 (existing entry retained)
  -> 萌侠信息转发中心 (new entry)

Each center page
  -> shared monitor center scaffold
      -> status overview
      -> source conversation list
      -> routing rules
      -> logs / images / diagnostics
      -> runtime controls
  -> provider-specific data adapter
```

Feishu should be migrated only as far as needed to consume the shared scaffold without changing its outward operator behavior.

Mengxia should get its own page wrapper, for example `MengxiaMonitorCenterPage`, but should reuse the same shared page sections where possible.

### Runtime Architecture

The Mengxia runtime should follow the local shell pattern already established by Feishu:

```text
Mengxia shell app
  -> fresh incognito runtime
  -> manual user login
  -> provider-specific page observer + network capture
  -> normalized local_monitor shell status/events
  -> loopback HTTP/SSE endpoints
  -> WuKong desktop client polls/subscribes and forwards
```

Core contract reuse:

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

The Mengxia shell app may extend diagnostics internally, but the primary shell contract must remain compatible with the neutral `local_monitor` client model rather than introducing Feishu-specific response semantics.

### Mengxia Capture Strategy

Mengxia capture should prefer:

1. network/API event extraction when the web runtime exposes stable structured message data,
2. DOM observation as a supplement for visible conversation metadata and fallback signal recovery,
3. explicit normalization into provider-neutral recent events.

This is preferred over a DOM-only monitor because the inspected login/runtime behavior already showed Mengxia using `/3/api/...` requests, which suggests structured runtime signals may be available and more robust than pure selector scraping.

### Routing Model

Routing is manual and explicit:

- the operator observes available Mengxia source conversations,
- chooses which source conversations should forward,
- maps each selected source conversation to a WuKong target group,
- only configured enabled routes forward.

There is no automatic “all conversations forward” mode in this slice.

### Absolute Incognito Model

Mengxia must run in strict incognito mode.

Required behavior:

- every monitor launch starts from a fresh web session,
- the operator manually logs in during that run,
- the shell may keep in-memory session state only while the process is alive,
- no reusable cookies, history, local storage, or persisted session directory survive shutdown,
- after closing and relaunching the Mengxia shell, the operator must log in again.

This requirement overrides the earlier idea of login-state reuse.

Implementation consequence:

- do not reuse the Feishu long-lived profile-directory model for Mengxia,
- do not silently persist session storage “for convenience,”
- expose explicit login state in the UI so the operator knows when manual login is required.

### Provider Isolation

Even with shared infrastructure, provider-specific state must remain isolated:

- separate preference keys for Feishu and Mengxia forwarding settings,
- separate dedupe namespaces / storage keys per provider,
- separate shell port / token / worker config per provider,
- no Feishu-named types in Mengxia public interfaces.

This avoids cross-provider leakage and keeps absolute-incognito Mengxia behavior independent from long-running Feishu sessions.

## Testing Strategy

Use a mix of unit, widget, shell, and runtime verification.

### Shared monitor-center tests

- management page still shows parallel Feishu and Mengxia cards
- shared scaffold renders status, routes, and controls for both providers
- provider switching at the implementation level does not leak state between providers

### Mengxia module tests

- route matching forwards only configured source conversations
- settings storage uses Mengxia-specific keys
- dedupe keys are isolated from Feishu keys
- login-required UI state is shown when the shell reports unauthenticated / offline
- shell client parses `/status`, `/events`, and `/routing/sources` responses using the neutral model

### Mengxia shell runtime tests

- startup creates a fresh session
- shutdown destroys or clears reusable session artifacts
- relaunch requires manual login again
- network/API parsing yields normalized events
- DOM fallback enriches conversation metadata without inventing false messages

### Regression coverage

- existing Feishu forwarding and center tests remain green
- existing local monitor shell core tests remain green

### Manual verification

1. Open `系统管理`.
2. Confirm Feishu and Mengxia entries are both visible.
3. Open `萌侠信息转发中心`.
4. Start the Mengxia runtime and confirm manual login is required.
5. Log in manually, observe detected source conversations, and configure one route.
6. Send a new Mengxia message in that source conversation and confirm forwarding into the configured WuKong group.
7. Close the Mengxia runtime completely.
8. Relaunch and confirm the operator must log in again.

## Boundaries

- Always: Keep Feishu visible on the management page, add Mengxia as a parallel entry, reuse neutral local monitor infrastructure, isolate provider storage keys, and enforce absolute incognito for Mengxia.
- Ask first: Changing management-page information architecture beyond adding the new card, adding new third-party dependencies, changing the neutral shell HTTP contract, or expanding destinations beyond WuKong internal groups.
- Never: Persist reusable Mengxia login state, silently downgrade incognito behavior, forward all Mengxia conversations by default, or couple Mengxia public APIs to Feishu-named types.

## Success Criteria

- `系统管理` shows both `飞书信息监控中心` and `萌侠信息转发中心`.
- The Feishu entry still works with no user-visible regression.
- The Mengxia center opens from the management page and shows monitor runtime status.
- Mengxia requires manual login on every fresh launch.
- Closing and relaunching the Mengxia shell requires login again, proving no reusable session state persisted.
- Mengxia source conversations can be manually selected and routed to WuKong target groups.
- Only configured Mengxia routes forward.
- New Mengxia events can be forwarded into WuKong target groups in near real time.
- Feishu and Mengxia settings / dedupe state remain provider-isolated.
- Analyzer and targeted tests pass for touched app and shell modules.

## Open Questions

1. This spec assumes Windows desktop is the required Mengxia monitor runtime for the first slice. If cross-platform monitor-runtime support is needed immediately, the implementation plan will need to change.
