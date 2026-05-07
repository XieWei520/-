# Phase 5 Chat Jank Telemetry Design

## Context

Phase 5 is focused on visual experience, monitoring, and long-term governance. The previous Phase 5 slices established quality gates, aligned chat motion tokens, and unified outgoing send-state visual semantics. The remaining monitoring gap is that chat smoothness is still subjective: the project does not yet capture frame timing evidence when the chat surface drops frames.

The original optimization plan calls out `SchedulerBinding.instance.addTimingsCallback` and a build-duration threshold above 8ms as the basis for Jank alarms. Current code already has a lightweight telemetry pipeline in `lib/realtime/telemetry/realtime_rollout_telemetry.dart`, with buffered duration/count events and Riverpod providers. Existing metrics cover realtime sessions, control frames, conversation patch duration, and SQLite page query duration. There is no current `FrameTiming` or `addTimingsCallback` integration.

This slice turns chat jank into structured telemetry while keeping scope small enough to preserve the Phase 5 analyzer/test gates.

## Goal

Add a lightweight client-side frame timing monitor for the chat surface:

- capture Flutter `FrameTiming` samples,
- record only threshold breaches,
- emit structured telemetry events through the existing telemetry buffer,
- avoid collecting message content, user IDs, channel IDs, or other private chat data,
- keep the monitor start/stop lifecycle explicit and testable.

## Recommended Approach

Use **lightweight sampling with the existing `RealtimeRolloutTelemetry` pipeline**.

A small `ChatFrameJankMonitor` should own `SchedulerBinding.addTimingsCallback` registration. It receives frame timings, evaluates thresholds, and forwards events to a small telemetry interface. The monitor should be injectable and test-friendly so unit tests can feed synthetic frame timing-like samples without depending on a real engine frame.

Telemetry should extend the current realtime rollout metrics rather than introducing a dashboard, overlay, or a second buffering system.

## Scope

In scope:

1. Add a frame-jank telemetry interface, for example `FrameJankTelemetry`.
2. Extend `RealtimeRolloutTelemetry` to record chat frame jank duration events.
3. Add a chat frame monitor that can start/stop and avoids duplicate callback registration.
4. Wire the chat screen lifecycle to start monitoring while the chat page is mounted and stop on dispose.
5. Add tests for threshold logic, buffer events, start/stop idempotence, and provider wiring if touched.
6. Preserve `flutter analyze` clean output.

Out of scope:

- Building a dashboard or alerting service.
- Adding a visible FPS/Jank overlay.
- Uploading message content, user ID, channel ID, or raw route arguments as telemetry tags.
- Changing chat list layout or optimizing the root cause of every jank event.
- Changing server APIs.
- Adding a second telemetry transport or metrics backend.

## Thresholds and Metrics

Use conservative default thresholds:

| Metric | Threshold | Event name | Tag reason |
| --- | ---: | --- | --- |
| build duration | `> 8ms` | `chat_frame_build_jank_ms` | `build` |
| raster duration | `> 16ms` | `chat_frame_raster_jank_ms` | `raster` |
| total span | `> 24ms` | `chat_frame_total_jank_ms` | `total` |

The total span should represent the combined frame cost used by the monitor. During implementation this can be derived from `FrameTiming.totalSpan` where available, or from an adapter model that keeps the calculation testable.

Each event should include only low-cardinality tags:

```text
surface=chat
reason=build|raster|total
```

Do not include `channelId`, message text, sender IDs, or session-specific identifiers beyond the existing telemetry session ID behavior.

## Components and Boundaries

### `FrameJankTelemetry`

Responsibility: define the minimal contract used by UI/performance code.

Expected shape:

```dart
abstract class FrameJankTelemetry {
  void recordChatFrameJank({
    required Duration duration,
    required String reason,
  });
}
```

The exact API can be refined in the implementation plan, but it should stay small and avoid Flutter UI dependencies.

### `RealtimeRolloutTelemetry`

Responsibility: buffer and flush jank events using the existing telemetry transport.

It should:

- implement `FrameJankTelemetry`,
- expose metric name constants,
- use existing `_recordDuration`,
- attach the low-cardinality tags listed above,
- respect disposal and buffer limits using existing behavior.

### `ChatFrameJankMonitor`

Responsibility: manage frame timing callback registration and threshold evaluation.

It should:

- support `start()` and `stop()`,
- be idempotent when `start()` or `stop()` is called repeatedly,
- avoid retaining callbacks after the chat page is disposed,
- support dependency injection for tests,
- avoid per-frame logging and only emit threshold breaches.

A test-friendly adapter can be used so threshold logic does not require constructing Flutter engine-only `FrameTiming` values directly.

### Chat page lifecycle

Responsibility: start the monitor when the chat page/shell is active and stop it on dispose.

The integration should be minimal. If Riverpod provider wiring is needed, it should expose one monitor instance per chat page lifecycle and reuse the existing telemetry provider. The chat page must not rebuild because frame telemetry events are recorded.

## Failure Modes and Error Handling

1. **Duplicate registration**: repeated `start()` calls must not register multiple callbacks.
2. **Forgotten cleanup**: `dispose`/`stop()` must remove callbacks and prevent stale page telemetry.
3. **Telemetry unavailable**: if telemetry is null or disabled, monitoring should no-op without throwing.
4. **Transport failure**: existing `RealtimeRolloutTelemetry.flush()` already keeps buffered events on transport failure; this behavior should apply to jank events too.
5. **High-frequency jank**: recording must be thresholded and bounded by the existing max buffer. This slice should not log every frame.
6. **Privacy leakage**: tags must remain low-cardinality and free of message/user/channel data.

## Testing Strategy

Use test-first implementation.

Targeted tests:

1. `RealtimeRolloutTelemetry` tests:
   - records `chat_frame_build_jank_ms` with `surface=chat` and `reason=build`,
   - records raster/total metrics with correct names and tags,
   - respects existing buffer/flush behavior.
2. `ChatFrameJankMonitor` tests:
   - below-threshold frame records nothing,
   - build/raster/total threshold breaches record the right events,
   - `start()` is idempotent,
   - `stop()` unregisters callback and prevents later recordings.
3. Chat lifecycle/provider test only if provider wiring is changed.

Verification commands should include:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart
flutter test <new chat frame jank monitor test>
flutter analyze lib/realtime lib/modules/chat <new tests>
flutter analyze
```

Full `flutter test` remains outside this narrow slice unless the broader branch is first cleaned up, because prior Phase 5 work already documented unrelated full-suite failures.

## Acceptance Criteria

- Chat frame jank monitor exists and can be started/stopped safely.
- Monitor records no event below thresholds.
- Monitor records build/raster/total jank events above thresholds.
- `RealtimeRolloutTelemetry` buffers jank events with approved metric names and tags.
- Chat page lifecycle does not leak timing callbacks after dispose.
- No PII or high-cardinality chat identifiers are attached to jank events.
- Targeted telemetry and monitor tests pass.
- `flutter analyze` reports no issues.
