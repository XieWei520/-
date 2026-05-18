# Implementation Plan: Juliang Aggregate Monitor Forwarding Center

Date: 2026-05-17
Spec: `docs/superpowers/specs/2026-05-17-juliang-monitor-center-design.md`

## Overview

Build a `聚合信息转发中心` for `https://msg.juliang888.top/` as a new management-system monitor entry. The app side will reuse the neutral `local_monitor` shell client, runner helpers, forwarding dedupe, relay identity, and WuKong IM text sender. The shell side will follow the strict-incognito pattern already started for Mengxia, but target the Juliang aggregate web panel and normalize captured text messages into the existing local monitor shell contract.

## Assumptions For This Plan

1. Default relay display name: `聚合转发助手`.
2. Default shell port: `18796`.
3. Default shell token: `wukong-juliang-shell-dev`.
4. First implementation may use DOM observation if login-time network payloads are not stable enough, but it must keep the normalized local monitor event contract unchanged.
5. The first verified end-to-end path is a single configured source conversation forwarding text into a single WuKong target group.

## Architecture Decisions

- Reuse `LocalMonitorShellClient` instead of creating a provider-specific HTTP client from scratch.
  - Rationale: Feishu already moved toward a provider-neutral loopback contract; Juliang should not fork protocol behavior.
- Implement provider-specific adapters in `lib/modules/juliang_monitor/`.
  - Rationale: settings keys, labels, route type names, and default relay identity must remain isolated from Feishu/DingTalk.
- Base the shell privacy model on `tools/mengxia_monitor_shell_app/lib/src/mengxia_incognito_runtime.dart`.
  - Rationale: Feishu intentionally uses stable profile state, but Juliang requires no reusable browser state.
- Build the app-side forwarding path before full browser capture.
  - Rationale: shell status/events can be tested with neutral payloads before the logged-in web panel parser is known.
- Keep the MVP text-only.
  - Rationale: this avoids copying Feishu image/media machinery and reduces risk while proving real-time forwarding.

## Dependency Graph

```text
local_monitor shell contract
    -> Juliang shell client/models
        -> Juliang forwarding settings/service
            -> Juliang auto-forward runner
                -> app coordinator startup wiring

strict-incognito shell runtime
    -> shell status/event store
        -> login/runtime snapshot mapper
            -> capture parser/observer
                -> real shell events

Juliang center UI
    -> shell client + forwarding settings/service
        -> management page entry
```

## Implementation Order

### Phase 1: App-Side Contract And Forwarding

Create `lib/modules/juliang_monitor/` with thin adapters around `local_monitor`:

- `juliang_monitor_shell_models.dart`
- `juliang_monitor_shell_client.dart`
- `juliang_monitor_forwarding_service.dart`
- `juliang_monitor_auto_forward_runner.dart`

The tests should drive this phase with fake neutral shell payloads and fake WuKong senders. No real browser automation is needed yet.

Verification checkpoint:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/juliang_monitor -r compact
flutter analyze lib/modules/local_monitor lib/modules/juliang_monitor test/modules/juliang_monitor
```

### Phase 2: Management Entry And Center UI

Add `JuliangMonitorCenterPage` and wire it from `VipManagementPage`.

The first UI should cover:

- shell online/offline,
- login required/logged in,
- capture running/stopped,
- manual login hint,
- observed source conversations,
- existing routes,
- recent text events,
- manual forward recent events.

It should follow the DingTalk center's simpler list/card layout unless shared `monitor_center` scaffolding becomes available and stable enough to reuse.

Verification checkpoint:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/vip test/modules/juliang_monitor -r compact
flutter analyze lib/modules/vip lib/modules/juliang_monitor test/modules/vip test/modules/juliang_monitor
```

### Phase 3: App Startup Auto-Forward Wiring

Register `JuliangMonitorAutoForwardRunner` in `WuKongApp` through the existing `LocalMonitorAutoForwardCoordinator`.

The runner should:

- start only after WuKong login,
- stop on logout/dispose,
- prime startup events,
- subscribe to shell SSE events,
- poll every 1 second as fallback,
- forward only enabled text routes,
- skip duplicates.

Verification checkpoint:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/juliang_monitor test/modules/local_monitor -r compact
flutter analyze lib/app lib/modules/local_monitor lib/modules/juliang_monitor test/modules/juliang_monitor
```

### Phase 4: Strict-Incognito Shell Skeleton

Create `tools/juliang_monitor_shell_app/` by reusing the Mengxia strict-incognito pattern and `tools/local_monitor_shell_core/`.

This phase should provide:

- fresh temporary session directory creation,
- recursive cleanup on shutdown,
- no persistent profile/session paths in policy,
- loopback `ShellServer`,
- initial status snapshot,
- manual login notice,
- WebView target URL `https://msg.juliang888.top/`.

Verification checkpoint:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\juliang_monitor_shell_app
flutter test test -r compact
flutter analyze lib test
```

### Phase 5: Logged-In Runtime Capture

Inspect the logged-in aggregate panel and implement the least fragile text-event capture path:

1. Prefer network/API payload parsing if stable message data is visible.
2. Use DOM observation only if network payloads are unstable or unavailable.
3. Normalize every text message into `NormalizedMessageEvent`.
4. Publish shell snapshot update events through `ShellEventBus`.

This phase must not persist captured credentials or session artifacts. Any diagnostics should store only structural metadata, not message secrets beyond recent events already exposed to the local app.

Verification checkpoint:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\juliang_monitor_shell_app
flutter test test -r compact
flutter analyze lib test
flutter build windows --release
```

Manual checkpoint:

- launch shell,
- confirm manual login is required,
- log in,
- observe at least one source conversation,
- send one new text message,
- confirm `/events/recent` contains one normalized text event,
- close and relaunch shell,
- confirm login is required again.

### Task 11 Runtime Inspection Notes

Inspection was performed on 2026-05-17 with a temporary Chrome profile and CDP port only for structural runtime discovery. The temporary state file and profile directory were deleted after inspection.

Privacy boundary observed:

- No cookies, localStorage, sessionStorage, request headers, credentials, tokens, or reusable browser state were read or saved.
- No raw response bodies or real message contents are stored in this plan.
- Any fixtures for parser tests must be sanitized structural DOM/probe payloads, not captured user messages.

Observed runtime contract:

- Logged-in target path: `/user`.
- Passive reload/wait did not reveal a stable same-origin JSON message API, SSE stream, or WebSocket frame carrying text messages.
- Worker targets were present, including `/service-worker.js` and a shared worker asset with `feipanel-bridge`, but they did not provide a stable MVP parser contract during passive inspection.
- React/MUI DOM structures expose the source/session list and message panel. The MVP capture path will therefore use a localized DOM observation fallback and normalize sanitized probe snapshots into the existing `NormalizedMessageEvent` shell contract.

Initial DOM probe contract for Task 12:

- source/session candidates come from MUI list item/button structures and provide a display name plus optional source id,
- message candidates provide optional message id, optional sender, text body, observed time, and source display name/id from the active conversation,
- non-text candidates must be ignored,
- when no stable source id is available, the mapper creates a deterministic fallback conversation id from the source display name.

### Phase 6: End-To-End Verification

Run the app with the shell, configure one route, and verify real forwarding.

Manual checkpoint:

- open `管理系统 -> 聚合信息转发中心`,
- configure one source conversation to one WuKong test group,
- enable auto forwarding,
- send a new text message from the aggregate panel,
- confirm exactly one WuKong relay text arrives,
- send the same event/update again or trigger a refresh,
- confirm duplicate forwarding is skipped.

## Risks And Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Aggregate panel message payload shape is unknown until login | High | Build app-side forwarding against neutral events first; isolate capture parser behind shell tests after runtime inspection |
| WebView package may not expose a true no-profile mode | High | Use fresh temp session directories and destroy them on startup/shutdown; do not edit vendor code without separate approval |
| DOM selectors may change | Medium | Prefer network/API capture; if DOM is required, keep selectors localized in shell parser tests |
| SSE and polling may see the same event | Medium | Use existing dedupe key priority: `dedupe_key`, `event_id`, `message_id` |
| Startup snapshot may contain old messages | Medium | Reuse `splitLocalMonitorStartupEvents` and prime before live forwarding |
| Existing worktree is heavily dirty | Medium | Keep edits scoped to Juliang files plus explicit wiring files; do not revert unrelated changes |

## Sequential vs Parallel Work

Sequential:

- app-side models/client -> forwarding service -> runner,
- shell incognito skeleton -> capture parser -> end-to-end runtime,
- management page entry after `JuliangMonitorCenterPage` exists.

Can be parallel after contracts are fixed:

- UI widget tests and forwarding service tests,
- shell incognito policy tests and app-side route/settings tests,
- runtime capture parser tests once sample payloads are available.

## Human Review Checkpoints

1. Review this plan before task breakdown.
2. Review task list before implementation.
3. Review after Phase 3 before shell/browser capture, because that is where unknown runtime behavior starts.
4. Review before any vendor WebView change or new dependency.

## Remaining Open Decisions

These are non-blocking defaults unless changed before implementation:

- Relay display name: `聚合转发助手`.
- Shell port: `18796`.
- Capture source: network first, DOM fallback after logged-in inspection.
