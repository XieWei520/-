# Spec: Feishu 120 Group Low-Latency Forwarding

Date: 2026-05-11

## Objective

Reduce Feishu ordinary-account forwarding latency when the operator configures a large number of Feishu source groups, with 120 groups as the design target.

The current single WebView shell can forward text quickly when Feishu's message list/feed receives the update, but image forwarding is much slower when it depends on serially opening configured groups. With the current 60-second configured-media keepalive cooldown, 120 configured groups can produce roughly 60 minutes average and 120 minutes worst-case image discovery delay if each group must be inspected in turn.

Success means the system no longer blindly rotates through all configured groups for image discovery. It should prioritize real newly observed feed events, open Feishu conversations only when needed for media extraction, expose estimated queue latency in the WuKongIM monitor center, and support first-phase multi-worker mode for 120 configured groups.

## Assumptions

1. The Feishu source account is still an ordinary user account, not an official Feishu bot or event-subscription app.
2. Official Feishu event subscription remains unavailable for this project.
3. The Windows machine may keep the Feishu account logged in for long-running unattended operation.
4. Re-login by QR code is acceptable after Feishu forces session expiration.
5. Correct routing is more important than forwarding every image. If ownership is uncertain, the system should skip or defer rather than misroute.
6. The first implementation should include multi-worker support, while making the operational risk explicit because multiple simultaneous Feishu Web sessions for the same ordinary account may have platform and stability limits.

## Tech Stack

- Flutter/Dart for the WuKongIM desktop client and Feishu Monitor Center.
- Flutter/Dart + WebView2 for `tools/feishu_monitor_shell_app`.
- Existing local shell HTTP/SSE API on `127.0.0.1:18766`.
- Existing WebView2 network capture and page probe infrastructure.
- Existing `FeishuMonitorForwardingService` for WuKongIM text/image delivery.

## Commands

Use these commands for this feature's implementation and verification:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/runtime_snapshot_mapper_test.dart test/feishu_page_probe_test.dart test/probe_scheduler_test.dart -r compact
flutter analyze lib/main.dart lib/src/feishu_page_probe.dart lib/src/runtime_snapshot_mapper.dart
flutter build windows --release
```

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart -r compact
flutter analyze lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart lib/modules/feishu_monitor/feishu_monitor_center_page.dart lib/modules/feishu_monitor/feishu_monitor_shell_models.dart
```

Runtime diagnostics:

```powershell
$headers=@{ Authorization = 'Bearer wukong-feishu-shell-dev' }
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:18766/status' -Headers $headers
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:18766/events/recent' -Headers $headers
```

## Current Project Structure

```text
tools/feishu_monitor_shell_app/lib/main.dart
  Feishu WebView runtime, probe loop, media opening policy, diagnostics.

tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart
  JavaScript probes for feed cards, conversations, media placeholders, and targeted conversation opening.

tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart
  Converts page/network observations into shell snapshots and recent normalized events.

tools/feishu_monitor_shell_app/lib/src/feishu_network_*.dart
  Network capture parsing, storage, attribution, and forwardable image resolution.

lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart
  WuKongIM-side runner that polls/subscribes to shell events and forwards routed events.

lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart
  Route matching, dedupe, text/image sending, relay identity handling.

lib/modules/feishu_monitor/feishu_monitor_center_page.dart
  Operator console for status, routes, groups, images, and settings.

lib/modules/feishu_monitor/feishu_monitor_shell_models.dart
  Client-side shell status/event models.

test/modules/feishu_monitor/*
  WuKongIM Feishu monitor tests.

tools/feishu_monitor_shell_app/test/*
  Shell probe, runtime snapshot, scheduler, and network capture tests.
```

## Code Style

Keep changes in the existing Dart style: immutable value objects, small pure helpers for scheduling decisions, and behavior tests around those helpers before wiring them into runtime code.

Example target style:

```dart
class FeishuMediaExtractionQueueItem {
  const FeishuMediaExtractionQueueItem({
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.feedCardKey,
    required this.feedPreviewText,
    required this.enqueuedAt,
    required this.priority,
  });

  final String sourceConversationId;
  final String sourceConversationName;
  final String feedCardKey;
  final String feedPreviewText;
  final DateTime enqueuedAt;
  final int priority;

  bool matchesSource(String conversationId, String conversationName) {
    return sourceConversationId.trim().isNotEmpty &&
            sourceConversationId.trim() == conversationId.trim() ||
        sourceConversationName.trim().isNotEmpty &&
            sourceConversationName.trim() == conversationName.trim();
  }
}
```

## Design

### Recommended Architecture

Use an event-priority multi-worker design in the first implementation:

```text
Feishu message list/feed observation
  -> text events forwarded immediately
  -> image placeholder events become media extraction queue items
  -> source group is assigned to one worker
  -> that worker opens only the specific source conversation that has a new image placeholder
  -> network/DOM extraction resolves the real image
  -> WuKongIM forwarding service sends the image
  -> monitor center shows per-worker queue depth and estimated delay
```

This replaces blind group rotation as the primary media strategy.

Configured group keepalive should remain only as a low-frequency liveness fallback. It should not be the normal way to discover images across 120 groups.

Target latency:

- Text: best effort within a few seconds after Feishu Web exposes the feed event.
- Images: optimize for 120 configured groups with delivery within 5 minutes when workers are logged in, queues are healthy, and Feishu Web exposes the relevant placeholder/feed event.

### Why Not Blind Polling

Blind polling scales linearly with configured group count:

```text
worst_case_delay = configured_group_count * per_group_visit_interval
average_delay    = worst_case_delay / 2
```

At 120 groups and 60 seconds per configured group, the worst case is about 120 minutes. Lowering the interval aggressively risks Feishu Web instability, high CPU/network use, repeated image previews, and possible account/session throttling.

### Text Forwarding

Text should remain feed/list-event driven:

- If a feed card exposes a new text event, forward it without opening the group.
- Do not wait for the media queue.
- Deduplicate by existing message/event keys.
- Show `observed_at`, `forwarded_at`, and latency in diagnostics when possible.

### Image Forwarding

Image forwarding should become queue-driven:

1. The page probe sees a configured feed card whose latest preview is an image placeholder, such as `[图片]`.
2. The runtime mapper creates or refreshes one media queue item for that source group and feed-card key.
3. The assigned worker opens that exact source conversation, not the next arbitrary configured group.
4. The worker attempts extraction using the existing safe image paths:
   - already resolved network-original image if available;
   - controlled conversation open for real image extraction when allowed;
   - no broad unrelated DOM image forwarding.
5. The worker records success, retryable failure, timeout, or permanent skip.
6. The shell publishes queue diagnostics and resulting `network_original_image` or allowed image events.

The queue must dedupe repeated placeholders from the same group so a stale old image is not resent when later text arrives.

If extraction fails or times out, the system must not forward a text `[图片]` placeholder. It should record the failure reason and keep normal text forwarding alive.

### Queue Scheduling

Queue item priority:

1. Newly observed image placeholder from a configured routed group.
2. Retryable item whose cooldown expired.
3. Low-frequency liveness fallback item for stale configured groups.

Default timing:

- Active queue worker: process next item as soon as the previous item finishes.
- Same feed-card retry cooldown: keep the current 20-second retry protection unless tests show it needs adjustment.
- Blind configured-group fallback: default 10 to 30 minutes per full cycle per worker, not 60 seconds per group, and only when no event-driven item is pending.

The queue should expose:

- `media_queue_depth`
- `media_queue_active_item`
- `media_queue_oldest_wait_seconds`
- `media_queue_estimated_next_delay_seconds`
- `media_queue_last_result`
- `media_queue_last_skip_reason`

### Multi-Worker Scaling

Multi-worker is required in the first phase. The initial target is deterministic route sharding across visible worker shell instances:

```text
Worker 1: groups 1-20
Worker 2: groups 21-40
Worker 3: groups 41-60
Worker 4: groups 61-80
Worker 5: groups 81-100
Worker 6: groups 101-120
```

Initial worker rules:

- Default worker count for 120 groups: 6 workers.
- Default shard size: 20 source groups per worker.
- Each worker has its own local port and runtime profile directory.
- Each worker window remains visible, because the operator wants to see the running windows.
- Each route maps to exactly one worker.
- WuKongIM reads status/events from all configured workers and forwards events through the same route/dedupe service.
- The monitor center supports assigning routes to workers and displaying per-worker health.
- The first implementation includes `worker_id` in diagnostics and route assignment metadata.

Risks:

- Feishu may not tolerate many simultaneous Web sessions for one ordinary account.
- Multiple WebViews may consume significant memory.
- QR login and session recovery become more complex.

Because of these risks, the monitor center must show worker login state clearly and allow disabling multi-worker if Feishu rejects concurrent sessions.

### Monitor Center UX

The Feishu Monitor Center should make capacity visible:

- Total configured Feishu source groups.
- Enabled route count.
- Current shell worker count, configurable and recommended as `6` for 120 groups.
- Per-worker media queue depth.
- Per-worker oldest waiting image task.
- Per-worker estimated delay under current queue state.
- Last opened Feishu source group.
- Last forwarded text latency and image latency when available.
- Warning when configured group count exceeds current worker capacity.

Suggested warning thresholds:

- 1-20 groups on one worker: normal.
- 21-60 groups: recommend 2 to 3 workers.
- 61-120 groups: recommend 4 to 6 workers.
- >120 groups: require explicit operator acknowledgement and a larger worker plan before enabling all routes.

## Testing Strategy

Follow test-driven development for implementation.

Shell unit tests should cover:

- feed image placeholders create queue items only for configured sources;
- repeated same feed-card placeholder dedupes to one queue item;
- text events are not blocked by the media queue;
- queue chooses event-driven items before fallback keepalive items;
- queue exposes depth, active item, oldest wait, and last result diagnostics;
- stale configured-group fallback does not run while event-driven media items are pending;
- queue cursor remains deterministic across multiple configured sources;
- worker assignment is deterministic and caps each worker at the configured shard size;
- worker-local diagnostics include `worker_id`, port, queue depth, and login state.

WuKongIM tests should cover:

- shell status model parses the new queue diagnostics;
- monitor center renders per-worker queue/latency values;
- forwarding runner still forwards immediate text events while media queue is non-empty;
- image dedupe prevents old extracted images from being resent after later text events;
- multi-worker event collection merges events without duplicate forwarding.

Manual joint tests should cover:

1. Configure two groups and verify existing text/image forwarding still works.
2. Send image to one configured group while the shell is on the message list; verify only that group is opened.
3. Send text to another configured group while an image is queued; verify text is still forwarded.
4. Configure at least 10 test routes; send images to three groups; verify queue order and no duplicate old images.
5. Start multiple worker shells with separate ports and visible windows.
6. Verify each worker reports its own login, queue, and event state.
7. Inspect `/status` and monitor center queue diagnostics.
8. If available, run a 60-120 route dry test with synthetic or observed route data and verify sharding, warning, and estimated delay behavior.

## Boundaries

- Always: prefer feed/list events and event-driven queueing before any blind group rotation.
- Always: skip uncertain image ownership rather than risking wrong-group forwarding.
- Always: keep text forwarding independent from image extraction queue latency.
- Always: keep worker windows visible unless the operator explicitly asks for hidden/background mode.
- Always: redact Feishu URLs and tokens in diagnostics.
- Always: add failing tests before production code changes.
- Ask first: changing Feishu login/session storage layout.
- Ask first: adding new third-party dependencies.
- Never: use official Feishu bot/event APIs because this project cannot use them.
- Never: forward an image from one group to another group based only on timing.
- Never: forward `[图片]` text placeholders when image extraction fails.
- Never: log full authenticated Feishu media URLs.
- Never: clear user sessions or cookies without explicit operator action.

## Success Criteria

- With multiple shell workers, image extraction is driven by new image placeholder events instead of blind 120-group rotation.
- Text forwarding remains near-real-time when Feishu Web exposes the feed event.
- For 120 configured groups, the system is optimized for image delivery within 5 minutes when workers are logged in and Feishu exposes the relevant feed event.
- A stale old image is not resent when a later text message appears.
- `/status` exposes worker id, media queue, and estimated delay diagnostics.
- The monitor center shows per-worker queue health and warns when route count exceeds current worker capacity.
- Failed image extraction records a failure reason and does not forward `[图片]` text placeholders.
- Existing focused shell and WuKongIM Feishu monitor tests pass.
- Windows release build of the Feishu shell succeeds.

## Resolved Decisions

1. 120-group target: text should be as close to a few seconds as Feishu Web allows; image forwarding should be optimized for within 5 minutes.
2. First phase includes multi-worker support.
3. Failed image extraction should not forward `[图片]` placeholders; it should only record failure diagnostics.
