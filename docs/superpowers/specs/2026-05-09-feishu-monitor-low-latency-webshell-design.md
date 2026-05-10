# Feishu Monitor Low-Latency WebShell Design

Date: 2026-05-09

## Reader And Goal

This document is for the engineer implementing the next Feishu Monitor upgrade.

After reading it, the engineer should be able to replace the current timer-first forwarding path with a low-latency event-driven path that still works for a normal Feishu user account, without requiring Feishu Open Platform bot permissions or tenant administrator approval.

## Background

The project now uses two Windows desktop programs:

- A Feishu WebShell app that logs into Feishu Web with a normal account and observes the messenger page.
- The WuKongIM desktop app, which owns the Feishu Monitor Center, route settings, dedupe, and delivery to WuKongIM groups.

The current runtime path is polling-based:

- The Feishu WebShell probes the page every 8 seconds.
- WuKongIM polls the shell status every 8 seconds.
- This is reliable enough for unattended testing, but normal end-to-end latency is several seconds.

The user cannot use official Feishu bot event subscriptions. The design must therefore stay inside the normal-account WebShell model.

## Design Summary

Upgrade the normal-account WebShell from timer-first polling to event-first observation:

1. Inject a persistent page-side DOM observer into Feishu Web.
2. When the Feishu feed list changes, debounce briefly and run the existing page probe immediately.
3. Persist the resulting shell snapshot as today.
4. Add a local push channel so WuKongIM can receive a change signal immediately instead of waiting for its next 8-second poll.
5. Keep a 3-second fallback probe and a 3-second WuKongIM fallback poll to protect against missed DOM events, WebView script failures, or Feishu page structure changes.

The target behavior is not guaranteed millisecond-level forwarding. The target is stable low-second forwarding:

- Typical: 0.5 to 2 seconds after Feishu Web renders the feed-list update.
- Fallback: normally within 3 seconds when the event observer misses an update.
- Long-running safety: no duplicate WuKongIM sends after restarts or repeated feed-card observations.

## Non-Goals

- Do not depend on Feishu Open Platform bot events.
- Do not reverse engineer Feishu private WebSocket message payloads as the primary path.
- Do not require administrator permissions.
- Do not remove the existing route settings, dedupe, manual forwarding, or shell HTTP API.
- Do not claim strict millisecond-level end-to-end latency.

## Architecture

### WebShell Page Observer

The WebShell should inject a small persistent JavaScript observer after navigation completes.

Responsibilities:

- Locate the Feishu messenger feed-list root using the existing selectors already proven in runtime tests.
- Attach a `MutationObserver` to the feed-list root.
- On child, subtree, text, or relevant attribute changes, schedule a page probe.
- Debounce bursts to avoid running the probe dozens of times during one Feishu render cycle.
- Expose a small script-level state object so Flutter can inspect whether the observer is installed.

Recommended debounce:

- Minimum delay: 150 ms.
- Maximum coalescing window: 800 ms.

The observer does not parse messages itself in the first implementation. It only acts as a fast trigger for the existing probe/parser. This keeps behavior aligned with the tested parser and reduces implementation risk.

### WebShell Probe Scheduling

The WebShell should centralize probe scheduling:

- `event`: requested by page-side observer.
- `navigation`: requested after navigation completes.
- `fallback`: requested by timer.
- `manual`: requested by future UI/debug action if needed.

Only one probe may run at a time. If a trigger arrives while a probe is running, mark a pending probe and run one more time immediately after the current probe completes.

Fallback interval:

- Change the shell fallback timer from 8 seconds to 3 seconds.

The fallback timer remains important because Web pages can rerender, detach the observed root, or change class names.

### Local Push Channel

Polling the shell status every 8 seconds wastes the speed gained by the page observer. Add a local change notification channel from WebShell to WuKongIM.

Recommended first implementation:

- Server-Sent Events endpoint on the existing localhost shell server.
- Endpoint: `GET /events`.
- Auth: same bearer token as the existing shell API.
- Event types:
  - `snapshot_updated`
  - `capture_state_changed`
  - `shell_error`
- Payload should be small:
  - `updated_at`
  - `reason`
  - counts for `recent_events` and `observed_conversations`

WuKongIM should subscribe when logged in and when routed auto-forwarding has at least one enabled route. On `snapshot_updated`, it should fetch `/status` and run the existing forwarding service.

Why SSE first:

- It is simpler than WebSocket for one-way local notifications.
- It works well for one producer and one or a few local consumers.
- If SSE is unavailable or disconnected, the fallback poll still works.

### WuKongIM Auto Forward Runner

Update the app-level runner from timer-only to event-first:

- Start an SSE subscription to the shell server.
- On `snapshot_updated`, run `runOnce()` immediately.
- Keep a 3-second fallback timer.
- Keep the current `_running` guard.
- Do not start multiple subscriptions if the app restarts the runner.
- If the SSE stream disconnects, retry with backoff and keep fallback polling active.

Recommended reconnect backoff:

- Start at 1 second.
- Cap at 30 seconds.
- Reset after a successful event.

### Dedupe And Delivery

Keep the current stable dedupe behavior:

- Feed-card probe key: capture source, conversation scope, sender, normalized text.
- Persisted dedupe key list in SharedPreferences.
- Maximum persisted keys: 500.

This remains mandatory because Feishu Web can emit multiple transient feed-card IDs for the same visible list item.

## Data Flow

Normal fast path:

1. Feishu Web renders a new feed-list message.
2. Page-side `MutationObserver` fires.
3. WebShell schedules an immediate probe after debounce.
4. Probe updates the shell snapshot and recent event buffer.
5. Shell server emits `snapshot_updated`.
6. WuKongIM receives the event, fetches `/status`, and forwards routed recent events.
7. Forwarding service persists dedupe keys after successful sends.

Fallback path:

1. Observer is not installed, misses a change, or SSE is disconnected.
2. WebShell fallback probe runs within 3 seconds.
3. WuKongIM fallback poll runs within 3 seconds.
4. Existing forwarding logic sends any unmatched, undeduped routed events.

## Error Handling

Observer install failure:

- Save a visible `last_error` entry in shell status.
- Continue fallback probing.

Observed root disappears:

- Reinstall observer on the next fallback probe or navigation-completed event.
- Continue fallback probing.

SSE disconnect:

- WuKongIM logs the disconnect.
- Reconnect with backoff.
- Continue fallback polling.

Probe parse failure:

- Save the error in shell status.
- Do not clear the existing recent-event buffer.
- Let the next fallback or observer trigger retry.

Forwarding failure:

- Keep current delivery behavior.
- Do not mark a dedupe key as forwarded until the WuKongIM send succeeds.

## Test Plan

Unit tests:

- Observer install script reports installed state.
- Probe scheduler coalesces multiple rapid triggers into one probe plus at most one pending rerun.
- Shell server SSE endpoint authenticates requests.
- Shell server emits `snapshot_updated` after snapshot save.
- Auto-forward runner triggers `runOnce()` from an SSE event.
- Auto-forward runner keeps fallback polling when SSE disconnects.

Widget or integration-style tests:

- WebShell navigation completion installs observer and still runs a probe.
- Monitor center still renders status from normal `/status`.

Manual Windows test:

1. Start Feishu WebShell and WuKongIM desktop.
2. Confirm shell state is online, capturing, logged in, and healthy.
3. Configure two Feishu source groups to two different WuKongIM target groups.
4. Send one message in each Feishu group.
5. Record local timestamps for:
   - shell `probe_observed_at`
   - WuKongIM database insertion time
6. Expected result:
   - Each message is forwarded once.
   - Typical delay is low-second after Feishu Web renders the feed card.
   - Repeating the same shell event does not duplicate WuKongIM messages.

## Rollout

Implement in small slices:

1. Shell probe scheduler and 3-second fallback.
2. Page-side observer trigger.
3. Shell SSE endpoint.
4. WuKongIM SSE subscription with 3-second fallback.
5. Runtime report update and manual latency test.

Each slice must keep the existing polling path working so the system remains usable during development.
