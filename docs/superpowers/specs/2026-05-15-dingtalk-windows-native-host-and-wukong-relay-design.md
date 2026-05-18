# Spec: DingTalk Windows Native Host And WuKong Relay

## Objective
Build a new DingTalk monitoring direction around a standalone Windows-native host, not a Flutter or WebView shell. The host must embed and supervise the installed DingTalk desktop window, prefer low-latency structured observation sources, normalize captured events, and expose them locally to WuKong IM. WuKong IM remains the relay control plane and continues to send matched messages into target WuKong groups through the existing in-app message send path.

Success means:
- the old Flutter/Dart DingTalk shell direction stays removed
- a new Windows-native PoC can host the DingTalk desktop client in a controlled panel
- the primary capture path targets Feishu-like latency by probing structured sources before OCR
- text and image-like events can be normalized into a stable local event shape
- WuKong IM can later consume those events and relay configured routes to WuKong groups without driving the WuKong desktop UI by automation

## Tech Stack
- Host app: `.NET 8 + WPF`
- Windows automation: `FlaUI` on `UIA3`
- Local persistence: `SQLite`
- Image handling: structured image metadata and local capture first; `ImageSharp` for screenshots; `OpenCV` only if later image heuristics require it
- Logging: `Serilog`
- Loopback control plane: ASP.NET Core minimal API bound to `127.0.0.1`
- WuKong relay: existing Flutter/Dart app path via `LocalMonitorTextSender` and `ApiChatSceneGateway.sendMessageContent(...)`

## Commands
- Restore host solution: `dotnet restore tools/dingtalk_windows_host/DingTalkWindowsHost.sln`
- Build host solution: `dotnet build tools/dingtalk_windows_host/DingTalkWindowsHost.sln -c Debug`
- Run host app: `dotnet run --project tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/DingTalkWindowsHost.App.csproj`
- Run host tests: `dotnet test tools/dingtalk_windows_host/DingTalkWindowsHost.sln -c Debug`
- Analyze WuKong relay touchpoints: `flutter analyze lib/modules/feishu_monitor lib/modules/local_monitor lib/modules/chat`
- Run WuKong relay tests: `flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`

## Project Structure
- `tools/dingtalk_windows_host/` -> new Windows-native solution root
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.App/` -> WPF shell, window host surface, lifecycle supervisor
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Automation/` -> UIA probing, structured-source diagnostics, capture rules, image fallback actions
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Storage/` -> SQLite models, repositories, retention cleanup
- `tools/dingtalk_windows_host/src/DingTalkWindowsHost.Api/` -> loopback HTTP endpoints for status, events, and control actions
- `tools/dingtalk_windows_host/tests/` -> unit and integration tests for event normalization, dedupe, and loopback API
- `lib/modules/local_monitor/` -> existing WuKong-side relay abstractions that remain the app-side send path
- `lib/modules/feishu_monitor/` -> reference implementation for WuKong-side route matching, dedupe, and relay semantics
- `lib/modules/dingtalk_monitor/` -> intentionally absent after cleanup; a fresh WuKong-side DingTalk module is only recreated after the native host contract stabilizes

## Code Style
```csharp
var normalizedEvent = _normalizer.Normalize(captureResult);
if (normalizedEvent is null)
{
    return;
}

await _rawEvents.UpsertAsync(normalizedEvent, cancellationToken);
await _jobQueue.EnqueueForwardJobAsync(normalizedEvent.EventId, cancellationToken);
```

Keep window hosting, structured-source probing, UI automation, OCR fallback, storage, and loopback API in separate modules. Treat all captured UI text, OCR output, and image-derived metadata as untrusted input. Prefer deterministic selectors and explicit failure states over hidden retries.

## Testing Strategy
- Unit tests for HWND discovery, window-state guards, structured-source probe ranking, UIA selector matching, embedded-source extraction, image metadata parsing, and event dedupe keys
- Repository tests for `raw_events`, `forward_jobs`, and `delivery_logs`
- Loopback API integration tests for `/status`, `/events/recent`, `/control/start`, `/control/stop`, and `/control/reload`
- Host acceptance checks on a fixed-resolution Windows session: attach DingTalk window, lock size, capture a latest text message, capture an image event fallback, and persist both into SQLite
- WuKong relay tests stay in Flutter and verify that replayed recent events are deduped before `ApiChatSceneGateway.sendMessageContent(...)`

## Boundaries
- Always: keep the host as a separate Windows process; bind control APIs only to `127.0.0.1`; prefer structured sources over OCR; persist normalized events locally before exposing them; make capture limitations visible; keep DingTalk credentials, cookies, local database rows, local cache values, and log lines off-limits unless explicitly approved; allow metadata-only file discovery for diagnostics
- Ask first: enabling OCR as a production path, adding new external OCR services, reading DingTalk local storage, introducing background Windows service packaging, or moving final relay responsibility out of WuKong IM
- Never: revive the old Flutter/WebView DingTalk shell direction, automate WuKong IM desktop UI as the primary send path, claim full passive capture guarantees, or silently mix native-host code into the main WuKong app process

## Success Criteria
- The repository no longer contains the old Flutter/Dart DingTalk monitor shell direction
- The new design source of truth is this Windows-native host spec
- The future host project path is `tools/dingtalk_windows_host/`
- The host can supervise one installed DingTalk desktop window in a fixed WPF container
- The host can explicitly invoke a configured DingTalk launcher path through an operator action or loopback control endpoint, but must not auto-restart DingTalk without an explicit request
- The host exposes launcher readiness diagnostics so operators can verify `DINGTALK_HOST_LAUNCHER` before invoking a launch
- The host can explicitly request foreground/restore for the best non-tool DingTalk window candidate, but must not run that recovery automatically
- The host exposes `/diagnostics/structured-sources` to rank UIA, embedded Chromium/DevTools, network, local cache/log, and OCR fallback candidates
- The host exposes `/diagnostics/local-structured-sources` to report DingTalk local file candidates by redacted path hint, type, size, and last-write time only; it must not read or output message content, SQLite rows, LevelDB values, log lines, cookies, or credentials
- The host exposes `/diagnostics/local-structured-source-inspection` to inspect only source structure: SQLite table/column names, JSON key paths, and LevelDB file groups. It must skip logs/media content and must not output row values, JSON scalar values, LevelDB key/value data, cookies, or credentials
- The host exposes `/diagnostics/window-state` to classify DingTalk window attach readiness, per-candidate accept/reject reasons, rejection-reason counts, and operator-facing recovery guidance
- The host exposes `/diagnostics/conversations` to report UIA-visible conversation-list triggers and blocking dialogs
- The WPF operator panel shows structured-source status, window-state diagnostics, and conversation diagnostics so runtime blockers are visible without calling the API manually
- The default recommendation keeps OCR disabled unless structured sources cannot produce message content
- The target steady-state forwarding latency for structured paths is under 1 second after the host observes a message change; cropped OCR fallback is allowed to be slower and must not block structured capture
- The host can emit normalized local events with enough data for WuKong-side route matching:
  - source conversation identity
  - embedded source-group marker when present
  - sender
  - observed timestamp
  - text body
  - image attachment placeholder or local screenshot path
  - capture source
- The host stores events in SQLite tables:
  - `raw_events`
  - `forward_jobs`
  - `delivery_logs`
- Recommended dedupe key is `source_chat + sender + timestamp_bucket + content_hash`, with stronger source IDs used whenever the host can extract them
- WuKong IM remains responsible for final routing and sending to target groups using the existing relay/send path

## Capture Priority
1. Embedded Chromium/DevTools or DOM-like source if DingTalk exposes one safely
2. UI Automation as a low-latency trigger and metadata source
3. Passive network/event candidates if they can be observed without credentials interception or traffic decryption
4. Local cache/log metadata discovery and schema/key-only inspection after approval for this direction; parsing row values or message contents only after separate explicit approval
5. Cropped screenshot/OCR only as fallback, never as the default low-latency path

DevTools probing is intentionally limited in the PoC: it may inspect loopback listening ports, Windows TCP listener owning PID, and `/json/version` metadata, but it must not fetch page target lists, cookies, storage, local databases, or DOM content until ownership and safety are proven.

UIA conversation diagnostics are intentionally trigger-oriented: the host may use conversation list changes, unread hints, and blocking-dialog status to decide when to probe other sources, but it must not treat conversation-list UIA data as proof that chat body capture is complete.

## Open Questions
- Whether the host loopback API should expose paged historical event queries or only recent-event polling in phase 1
- Whether DingTalk exposes a safe Chromium DevTools, DOM, or network-level source comparable to the Feishu monitor path
- Whether local OCR is needed at all after structured-source probing, or can stay manual fallback only
- Whether image fallback should prefer preview-window save, local screenshot, or both depending on selector confidence
- Whether the later WuKong-side DingTalk control page should live under a recreated `lib/modules/dingtalk_monitor/` or under a more general monitor-center module

## Migration Note
On May 15, 2026, the previous DingTalk Flutter/Dart monitor-shell direction was intentionally removed. This document replaces `2026-05-13-dingtalk-monitor-center-design.md` as the active DingTalk monitoring design.
