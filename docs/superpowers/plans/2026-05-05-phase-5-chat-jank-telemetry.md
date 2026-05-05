# Phase 5 Chat Jank Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add lightweight chat-surface frame jank telemetry using Flutter frame timings, threshold-only recording, and the existing realtime telemetry buffer.

**Architecture:** `RealtimeRolloutTelemetry` becomes the single telemetry sink for chat frame jank events through a small `FrameJankTelemetry` interface. A new `ChatFrameJankMonitor` owns `SchedulerBinding.addTimingsCallback` registration, adapts engine `FrameTiming` into testable samples, records only threshold breaches, and is started/stopped by `ChatPageShell` lifecycle through Riverpod providers.

**Tech Stack:** Flutter/Dart, `SchedulerBinding.addTimingsCallback`, Riverpod providers, `flutter_test`, existing `RealtimeRolloutTelemetry` transport.

---

## Worktree and Branch

- Worktree: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-chat-jank-telemetry`
- Branch: `codex/phase-5-chat-jank-telemetry`
- Run every command below from `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-chat-jank-telemetry`.

## Design Spec Coverage Map

- Thresholded build/raster/total events: Task 1 and Task 2.
- Existing telemetry pipeline reuse: Task 1.
- No PII or high-cardinality tags: Task 1 tests assert only `surface=chat` and `reason=build|raster|total`.
- Explicit start/stop lifecycle: Task 2 and Task 3.
- Duplicate registration prevention: Task 2 tests assert idempotence.
- Chat page lifecycle cleanup: Task 3 widget test verifies callback remove on unmount.
- Analyzer/test verification: Task 4.

## File Structure

- Modify `lib/realtime/telemetry/realtime_rollout_telemetry.dart`
  - Add the `FrameJankTelemetry` interface.
  - Add metric/reason constants.
  - Implement `recordChatFrameJank()` with strict reason validation and low-cardinality tags.
- Modify `lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart`
  - Add `frameJankTelemetryProvider` that exposes the existing rollout telemetry instance as `FrameJankTelemetry`.
- Create `lib/modules/chat/chat_frame_jank_monitor.dart`
  - Define `ChatFrameTimingSample`.
  - Define `FrameTimingRegistrar` and `SchedulerFrameTimingRegistrar`.
  - Define Riverpod providers for the registrar and chat monitor factory.
  - Implement threshold-only `ChatFrameJankMonitor.start()` / `stop()` behavior.
- Modify `lib/modules/chat/chat_page_shell.dart`
  - Import the monitor provider.
  - Store a monitor reference in `_ChatPageShellState`.
  - Start monitoring in `initState()` and stop monitoring in `dispose()`.
- Modify `test/realtime/telemetry/realtime_rollout_telemetry_test.dart`
  - Add tests for build/raster/total jank metrics, tags, and invalid reason rejection.
- Create `test/modules/chat/chat_frame_jank_monitor_test.dart`
  - Add tests for threshold decisions and start/stop idempotence.
- Create `test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart`
  - Add a widget lifecycle test proving `ChatPageShell` registers once and unregisters on unmount.

---

### Task 1: Extend RealtimeRolloutTelemetry with FrameJankTelemetry

**Files:**
- Modify: `lib/realtime/telemetry/realtime_rollout_telemetry.dart`
- Modify: `lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart`
- Test: `test/realtime/telemetry/realtime_rollout_telemetry_test.dart`

- [ ] **Step 1: Write failing telemetry tests**

Append these tests inside `main()` in `test/realtime/telemetry/realtime_rollout_telemetry_test.dart`, after the existing `caps buffered events while telemetry uploads are unavailable` test:

```dart
  test('records build chat frame jank with safe low-cardinality tags', () async {
    final batches = <List<RealtimeTelemetryEvent>>[];
    final telemetry = RealtimeRolloutTelemetry(
      transport: (events) async {
        batches.add(List<RealtimeTelemetryEvent>.from(events));
      },
      flushInterval: const Duration(hours: 1),
    );
    addTearDown(telemetry.dispose);

    telemetry.bindSessionId('sess_jank_01');
    telemetry.recordChatFrameJank(
      duration: const Duration(milliseconds: 13),
      reason: FrameJankTelemetry.reasonBuild,
    );

    await telemetry.flush();

    expect(batches, hasLength(1));
    expect(batches.single, hasLength(1));
    final event = batches.single.single;
    expect(event.name, RealtimeRolloutTelemetry.metricChatFrameBuildJankMs);
    expect(event.rawValue, 13);
    expect(event.sessionId, 'sess_jank_01');
    expect(event.tags, <String, String>{
      'surface': 'chat',
      'reason': 'build',
    });
  });

  test('records raster and total chat frame jank metrics', () async {
    final batches = <List<RealtimeTelemetryEvent>>[];
    final telemetry = RealtimeRolloutTelemetry(
      transport: (events) async {
        batches.add(List<RealtimeTelemetryEvent>.from(events));
      },
      flushInterval: const Duration(hours: 1),
    );
    addTearDown(telemetry.dispose);

    telemetry.recordChatFrameJank(
      duration: const Duration(milliseconds: 21),
      reason: FrameJankTelemetry.reasonRaster,
    );
    telemetry.recordChatFrameJank(
      duration: const Duration(milliseconds: 33),
      reason: FrameJankTelemetry.reasonTotal,
    );

    await telemetry.flush();

    expect(batches, hasLength(1));
    expect(
      batches.single.map((event) => event.name),
      <String>[
        RealtimeRolloutTelemetry.metricChatFrameRasterJankMs,
        RealtimeRolloutTelemetry.metricChatFrameTotalJankMs,
      ],
    );
    expect(
      batches.single.map((event) => event.rawValue),
      <int>[21, 33],
    );
    expect(
      batches.single.map((event) => event.tags),
      <Map<String, String>>[
        <String, String>{'surface': 'chat', 'reason': 'raster'},
        <String, String>{'surface': 'chat', 'reason': 'total'},
      ],
    );
  });

  test('ignores unknown chat frame jank reasons to prevent high-cardinality tags', () async {
    final batches = <List<RealtimeTelemetryEvent>>[];
    final telemetry = RealtimeRolloutTelemetry(
      transport: (events) async {
        batches.add(List<RealtimeTelemetryEvent>.from(events));
      },
      flushInterval: const Duration(hours: 1),
    );
    addTearDown(telemetry.dispose);

    telemetry.recordChatFrameJank(
      duration: const Duration(milliseconds: 99),
      reason: 'channel-12345',
    );

    await telemetry.flush();

    expect(batches, isEmpty);
  });
```

- [ ] **Step 2: Run the new telemetry tests to verify they fail**

Run:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart --plain-name "records build chat frame jank with safe low-cardinality tags"
```

Expected: FAIL because `RealtimeRolloutTelemetry.recordChatFrameJank`, `FrameJankTelemetry`, and `metricChatFrameBuildJankMs` do not exist yet.

Run:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart --plain-name "records raster and total chat frame jank metrics"
```

Expected: FAIL for the same missing symbols.

Run:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart --plain-name "ignores unknown chat frame jank reasons to prevent high-cardinality tags"
```

Expected: FAIL for the missing `recordChatFrameJank` symbol.

- [ ] **Step 3: Add the FrameJankTelemetry contract**

In `lib/realtime/telemetry/realtime_rollout_telemetry.dart`, insert this interface after `MessageQueryTelemetry`:

```dart
abstract class FrameJankTelemetry {
  static const String reasonBuild = 'build';
  static const String reasonRaster = 'raster';
  static const String reasonTotal = 'total';

  void recordChatFrameJank({
    required Duration duration,
    required String reason,
  });
}
```

- [ ] **Step 4: Add chat jank metric constants and implement the interface**

In `lib/realtime/telemetry/realtime_rollout_telemetry.dart`, update the `RealtimeRolloutTelemetry` class declaration from:

```dart
class RealtimeRolloutTelemetry
    implements
        SessionRuntimeTelemetry,
        SessionEventGatewayTelemetry,
        ConversationPatchTelemetry,
        MessageQueryTelemetry {
```

to:

```dart
class RealtimeRolloutTelemetry
    implements
        SessionRuntimeTelemetry,
        SessionEventGatewayTelemetry,
        ConversationPatchTelemetry,
        MessageQueryTelemetry,
        FrameJankTelemetry {
```

Then add these constants after `metricConversationListPatchApplyP95Ms`:

```dart
  static const String metricChatFrameBuildJankMs = 'chat_frame_build_jank_ms';
  static const String metricChatFrameRasterJankMs =
      'chat_frame_raster_jank_ms';
  static const String metricChatFrameTotalJankMs = 'chat_frame_total_jank_ms';
```

Then add this method after `recordSqlitePageQuery()`:

```dart
  @override
  void recordChatFrameJank({
    required Duration duration,
    required String reason,
  }) {
    final metricName = switch (reason.trim()) {
      FrameJankTelemetry.reasonBuild => metricChatFrameBuildJankMs,
      FrameJankTelemetry.reasonRaster => metricChatFrameRasterJankMs,
      FrameJankTelemetry.reasonTotal => metricChatFrameTotalJankMs,
      _ => null,
    };
    if (metricName == null) {
      return;
    }
    _recordDuration(
      metricName,
      duration,
      tags: <String, String>{
        'surface': 'chat',
        'reason': reason.trim(),
      },
    );
  }
```

- [ ] **Step 5: Add the Riverpod telemetry interface provider**

In `lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart`, append this provider after `messageQueryTelemetryProvider`:

```dart
final frameJankTelemetryProvider = Provider<FrameJankTelemetry>((ref) {
  return ref.watch(realtimeRolloutTelemetryProvider);
});
```

- [ ] **Step 6: Run the telemetry test file**

Run:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart
```

Expected: PASS with all tests in `test/realtime/telemetry/realtime_rollout_telemetry_test.dart` passing.

- [ ] **Step 7: Commit telemetry changes**

Run:

```powershell
git add lib/realtime/telemetry/realtime_rollout_telemetry.dart lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart test/realtime/telemetry/realtime_rollout_telemetry_test.dart
git commit -m "feat: add chat frame jank telemetry sink"
```

Expected: commit succeeds and `git status --short` does not show the three files from this task.

---

### Task 2: Add ChatFrameJankMonitor Threshold Logic and Registrar Safety

**Files:**
- Create: `lib/modules/chat/chat_frame_jank_monitor.dart`
- Create: `test/modules/chat/chat_frame_jank_monitor_test.dart`

- [ ] **Step 1: Write failing monitor tests**

Create `test/modules/chat/chat_frame_jank_monitor_test.dart` with this complete content:

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_frame_jank_monitor.dart';
import 'package:wukong_im_app/realtime/telemetry/realtime_rollout_telemetry.dart';

void main() {
  group('ChatFrameJankMonitor thresholds', () {
    test('records nothing below all thresholds', () {
      final telemetry = _SpyFrameJankTelemetry();
      final monitor = ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: _FakeFrameTimingRegistrar(),
      );

      monitor.recordSample(
        const ChatFrameTimingSample(
          buildDuration: Duration(milliseconds: 8),
          rasterDuration: Duration(milliseconds: 16),
          totalSpan: Duration(milliseconds: 24),
        ),
      );

      expect(telemetry.records, isEmpty);
    });

    test('records build raster and total threshold breaches', () {
      final telemetry = _SpyFrameJankTelemetry();
      final monitor = ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: _FakeFrameTimingRegistrar(),
      );

      monitor.recordSample(
        const ChatFrameTimingSample(
          buildDuration: Duration(milliseconds: 9),
          rasterDuration: Duration(milliseconds: 17),
          totalSpan: Duration(milliseconds: 25),
        ),
      );

      expect(
        telemetry.records,
        <_JankRecord>[
          const _JankRecord(
            duration: Duration(milliseconds: 9),
            reason: FrameJankTelemetry.reasonBuild,
          ),
          const _JankRecord(
            duration: Duration(milliseconds: 17),
            reason: FrameJankTelemetry.reasonRaster,
          ),
          const _JankRecord(
            duration: Duration(milliseconds: 25),
            reason: FrameJankTelemetry.reasonTotal,
          ),
        ],
      );
    });
  });

  group('ChatFrameJankMonitor lifecycle', () {
    test('start is idempotent and stop unregisters once', () {
      final registrar = _FakeFrameTimingRegistrar();
      final monitor = ChatFrameJankMonitor(
        telemetry: _SpyFrameJankTelemetry(),
        registrar: registrar,
      );

      monitor.start();
      monitor.start();
      monitor.stop();
      monitor.stop();

      expect(registrar.addCount, 1);
      expect(registrar.removeCount, 1);
      expect(registrar.activeCallbackCount, 0);
    });

    test('callback records while started and ignores frames after stop', () {
      final telemetry = _SpyFrameJankTelemetry();
      final registrar = _FakeFrameTimingRegistrar();
      final monitor = ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: registrar,
        sampleReader: (_) => const ChatFrameTimingSample(
          buildDuration: Duration(milliseconds: 10),
          rasterDuration: Duration(milliseconds: 1),
          totalSpan: Duration(milliseconds: 1),
        ),
      );

      monitor.start();
      registrar.fire(const <FrameTiming>[]);
      monitor.stop();
      registrar.fire(const <FrameTiming>[]);

      expect(
        telemetry.records,
        <_JankRecord>[
          const _JankRecord(
            duration: Duration(milliseconds: 10),
            reason: FrameJankTelemetry.reasonBuild,
          ),
        ],
      );
    });
  });
}

class _FakeFrameTimingRegistrar implements FrameTimingRegistrar {
  final Set<TimingsCallback> _callbacks = <TimingsCallback>{};
  int addCount = 0;
  int removeCount = 0;

  int get activeCallbackCount => _callbacks.length;

  @override
  void addTimingsCallback(TimingsCallback callback) {
    addCount += 1;
    _callbacks.add(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    removeCount += 1;
    _callbacks.remove(callback);
  }

  void fire(List<FrameTiming> timings) {
    for (final callback in List<TimingsCallback>.of(_callbacks)) {
      callback(timings);
    }
  }
}

class _SpyFrameJankTelemetry implements FrameJankTelemetry {
  final List<_JankRecord> records = <_JankRecord>[];

  @override
  void recordChatFrameJank({
    required Duration duration,
    required String reason,
  }) {
    records.add(_JankRecord(duration: duration, reason: reason));
  }
}

class _JankRecord {
  const _JankRecord({required this.duration, required this.reason});

  final Duration duration;
  final String reason;

  @override
  bool operator ==(Object other) {
    return other is _JankRecord &&
        other.duration == duration &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(duration, reason);

  @override
  String toString() {
    return '_JankRecord(duration: $duration, reason: $reason)';
  }
}
```

- [ ] **Step 2: Run the monitor tests to verify they fail**

Run:

```powershell
flutter test test/modules/chat/chat_frame_jank_monitor_test.dart
```

Expected: FAIL because `lib/modules/chat/chat_frame_jank_monitor.dart`, `ChatFrameJankMonitor`, `ChatFrameTimingSample`, and `FrameTimingRegistrar` do not exist yet.

- [ ] **Step 3: Create the monitor implementation**

Create `lib/modules/chat/chat_frame_jank_monitor.dart` with this complete content:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../realtime/telemetry/realtime_rollout_telemetry.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry_provider.dart';

typedef ChatFrameTimingSampleReader = ChatFrameTimingSample Function(
  FrameTiming timing,
);

class ChatFrameTimingSample {
  const ChatFrameTimingSample({
    required this.buildDuration,
    required this.rasterDuration,
    required this.totalSpan,
  });

  factory ChatFrameTimingSample.fromFrameTiming(FrameTiming timing) {
    return ChatFrameTimingSample(
      buildDuration: timing.buildDuration,
      rasterDuration: timing.rasterDuration,
      totalSpan: timing.totalSpan,
    );
  }

  final Duration buildDuration;
  final Duration rasterDuration;
  final Duration totalSpan;
}

abstract class FrameTimingRegistrar {
  void addTimingsCallback(TimingsCallback callback);

  void removeTimingsCallback(TimingsCallback callback);
}

class SchedulerFrameTimingRegistrar implements FrameTimingRegistrar {
  const SchedulerFrameTimingRegistrar();

  @override
  void addTimingsCallback(TimingsCallback callback) {
    SchedulerBinding.instance.addTimingsCallback(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    SchedulerBinding.instance.removeTimingsCallback(callback);
  }
}

final chatFrameTimingRegistrarProvider = Provider<FrameTimingRegistrar>((ref) {
  return const SchedulerFrameTimingRegistrar();
});

typedef ChatFrameJankMonitorFactory = ChatFrameJankMonitor Function();

final chatFrameJankMonitorFactoryProvider =
    Provider<ChatFrameJankMonitorFactory>((ref) {
      final telemetry = ref.watch(frameJankTelemetryProvider);
      final registrar = ref.watch(chatFrameTimingRegistrarProvider);
      return () => ChatFrameJankMonitor(
        telemetry: telemetry,
        registrar: registrar,
      );
    });

class ChatFrameJankMonitor {
  ChatFrameJankMonitor({
    required FrameJankTelemetry telemetry,
    required FrameTimingRegistrar registrar,
    ChatFrameTimingSampleReader sampleReader =
        ChatFrameTimingSample.fromFrameTiming,
    this.buildJankThreshold = const Duration(milliseconds: 8),
    this.rasterJankThreshold = const Duration(milliseconds: 16),
    this.totalJankThreshold = const Duration(milliseconds: 24),
  }) : _telemetry = telemetry,
       _registrar = registrar,
       _sampleReader = sampleReader;

  final FrameJankTelemetry _telemetry;
  final FrameTimingRegistrar _registrar;
  final ChatFrameTimingSampleReader _sampleReader;

  final Duration buildJankThreshold;
  final Duration rasterJankThreshold;
  final Duration totalJankThreshold;

  late final TimingsCallback _timingsCallback = _handleFrameTimings;
  bool _isStarted = false;

  void start() {
    if (_isStarted) {
      return;
    }
    _registrar.addTimingsCallback(_timingsCallback);
    _isStarted = true;
  }

  void stop() {
    if (!_isStarted) {
      return;
    }
    _registrar.removeTimingsCallback(_timingsCallback);
    _isStarted = false;
  }

  @visibleForTesting
  void recordSample(ChatFrameTimingSample sample) {
    _recordSample(sample);
  }

  void _handleFrameTimings(List<FrameTiming> timings) {
    if (!_isStarted) {
      return;
    }
    for (final timing in timings) {
      _recordSample(_sampleReader(timing));
    }
  }

  void _recordSample(ChatFrameTimingSample sample) {
    if (sample.buildDuration > buildJankThreshold) {
      _telemetry.recordChatFrameJank(
        duration: sample.buildDuration,
        reason: FrameJankTelemetry.reasonBuild,
      );
    }
    if (sample.rasterDuration > rasterJankThreshold) {
      _telemetry.recordChatFrameJank(
        duration: sample.rasterDuration,
        reason: FrameJankTelemetry.reasonRaster,
      );
    }
    if (sample.totalSpan > totalJankThreshold) {
      _telemetry.recordChatFrameJank(
        duration: sample.totalSpan,
        reason: FrameJankTelemetry.reasonTotal,
      );
    }
  }
}
```

- [ ] **Step 4: Run the monitor tests**

Run:

```powershell
flutter test test/modules/chat/chat_frame_jank_monitor_test.dart
```

Expected: PASS with all tests in `test/modules/chat/chat_frame_jank_monitor_test.dart` passing.

- [ ] **Step 5: Run telemetry and monitor tests together**

Run:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart
```

Expected: PASS with both test files passing.

- [ ] **Step 6: Commit monitor changes**

Run:

```powershell
git add lib/modules/chat/chat_frame_jank_monitor.dart test/modules/chat/chat_frame_jank_monitor_test.dart
git commit -m "feat: monitor chat frame jank thresholds"
```

Expected: commit succeeds and `git status --short` does not show the two files from this task.

---

### Task 3: Wire ChatPageShell Lifecycle and Add Lifecycle Test

**Files:**
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Create: `test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart`

- [ ] **Step 1: Write failing lifecycle test**

Create `test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart` with this complete content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_frame_jank_monitor.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';

void main() {
  testWidgets('ChatPageShell starts and stops chat frame jank monitor', (
    tester,
  ) async {
    final registrar = _FakeFrameTimingRegistrar();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatFrameTimingRegistrarProvider.overrideWithValue(registrar),
          messageListProvider.overrideWith(
            (ref, session) => _EmptyMessageListNotifier(
              session.channelId,
              session.channelType,
            ),
          ),
          chatSceneGatewayProvider.overrideWith(
            (ref, session) => _CompileSafeChatSceneGateway(),
          ),
        ],
        child: const MaterialApp(
          home: ChatPageShell(channelId: 'u_monitor', channelType: 1),
        ),
      ),
    );
    await tester.pump();

    expect(registrar.addCount, 1);
    expect(registrar.activeCallbackCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(registrar.removeCount, 1);
    expect(registrar.activeCallbackCount, 0);
  });
}

class _FakeFrameTimingRegistrar implements FrameTimingRegistrar {
  final Set<TimingsCallback> _callbacks = <TimingsCallback>{};
  int addCount = 0;
  int removeCount = 0;

  int get activeCallbackCount => _callbacks.length;

  @override
  void addTimingsCallback(TimingsCallback callback) {
    addCount += 1;
    _callbacks.add(callback);
  }

  @override
  void removeTimingsCallback(TimingsCallback callback) {
    removeCount += 1;
    _callbacks.remove(callback);
  }
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}

class _CompileSafeChatSceneGateway extends ChatSceneGateway {
  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {}

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}
}
```
- [ ] **Step 2: Run the lifecycle test to verify it fails before wiring**

Run:

```powershell
flutter test test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart
```

Expected: FAIL because `ChatPageShell` has not imported `chat_frame_jank_monitor.dart`, does not store a `ChatFrameJankMonitor`, and does not call `start()` / `stop()` yet; `registrar.addCount` remains `0`.

- [ ] **Step 3: Wire monitor lifecycle in ChatPageShell**

In `lib/modules/chat/chat_page_shell.dart`, add this import next to the other local chat imports:

```dart
import 'chat_frame_jank_monitor.dart';
```

Inside `_ChatPageShellState`, add this field after `_pinnedMessages`:

```dart
  ChatFrameJankMonitor? _frameJankMonitor;
```

In `_ChatPageShellState.initState()`, immediately after `super.initState();`, add:

```dart
    _frameJankMonitor = ref.read(chatFrameJankMonitorFactoryProvider)()..start();
```

In `_ChatPageShellState.dispose()`, before `_unbindConversationActivity();`, add:

```dart
    _frameJankMonitor?.stop();
    _frameJankMonitor = null;
```

The resulting lifecycle block must be:

```dart
  @override
  void initState() {
    super.initState();
    _frameJankMonitor = ref.read(chatFrameJankMonitorFactoryProvider)()..start();
    _canPinMessages = _supportsPinnedMessages();
    _bindConversationActivity();
    unawaited(_loadChannel());
    unawaited(_loadRobotMenus());
    unawaited(_refreshPinnedUiState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_hydrateRemoteFlameSettings());
      });
    });
  }
```

The resulting dispose block must be:

```dart
  @override
  void dispose() {
    _frameJankMonitor?.stop();
    _frameJankMonitor = null;
    _unbindConversationActivity();
    _remoteFlameCancelToken?.cancel();
    _remoteFlameCancelToken = null;
    unawaited(_persistConversationExtra());
    super.dispose();
  }
```

- [ ] **Step 4: Run the lifecycle test**

Run:

```powershell
flutter test test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart
```

Expected: PASS with `ChatPageShell starts and stops chat frame jank monitor` passing.

- [ ] **Step 5: Run all targeted chat jank tests**

Run:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart
```

Expected: PASS with all targeted telemetry, monitor, and lifecycle tests passing.

- [ ] **Step 6: Commit lifecycle wiring**

Run:

```powershell
git add lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart
git commit -m "feat: wire chat frame jank monitor lifecycle"
```

Expected: commit succeeds and `git status --short` does not show the two files from this task.

---

### Task 4: Analyzer Verification, Privacy Check, and Final Review

**Files:**
- Verify: `lib/realtime/telemetry/realtime_rollout_telemetry.dart`
- Verify: `lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart`
- Verify: `lib/modules/chat/chat_frame_jank_monitor.dart`
- Verify: `lib/modules/chat/chat_page_shell.dart`
- Verify: `test/realtime/telemetry/realtime_rollout_telemetry_test.dart`
- Verify: `test/modules/chat/chat_frame_jank_monitor_test.dart`
- Verify: `test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart`

- [ ] **Step 1: Run targeted tests**

Run:

```powershell
flutter test test/realtime/telemetry/realtime_rollout_telemetry_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart
```

Expected: PASS with all three targeted test files passing.

- [ ] **Step 2: Run targeted analyzer**

Run:

```powershell
flutter analyze lib/realtime lib/modules/chat test/realtime test/modules/chat
```

Expected: analyzer completes with `No issues found!`.

- [ ] **Step 3: Run full analyzer gate**

Run:

```powershell
flutter analyze
```

Expected: analyzer completes with `No issues found!`.

- [ ] **Step 4: Verify privacy and cardinality constraints by source scan**

Run:

```powershell
Select-String -Path lib/realtime/telemetry/realtime_rollout_telemetry.dart,lib/modules/chat/chat_frame_jank_monitor.dart,lib/modules/chat/chat_page_shell.dart -Pattern 'channelId|channelType|message|sender|uid|user|content|text'
```

Expected: no matches in `lib/modules/chat/chat_frame_jank_monitor.dart`; in `lib/modules/chat/chat_page_shell.dart`, matches are pre-existing chat business logic and not inside the jank monitor start/stop lines; in `lib/realtime/telemetry/realtime_rollout_telemetry.dart`, no jank tag includes these identifiers.

Run:

```powershell
Select-String -Path lib/realtime/telemetry/realtime_rollout_telemetry.dart -Pattern "'surface': 'chat'|'reason': reason.trim\(\)"
```

Expected: both safe tag assignments are present in `recordChatFrameJank()`.

- [ ] **Step 5: Review final diff**

Run:

```powershell
git diff --stat HEAD~3..HEAD
git diff HEAD~3..HEAD -- lib/realtime/telemetry/realtime_rollout_telemetry.dart lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart lib/modules/chat/chat_frame_jank_monitor.dart lib/modules/chat/chat_page_shell.dart test/realtime/telemetry/realtime_rollout_telemetry_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart
```

Expected: diff contains only chat jank telemetry, monitor, lifecycle wiring, and tests. It must not include dashboard UI, FPS overlay, server API changes, message content telemetry, user/channel tags, or unrelated chat layout optimization.

- [ ] **Step 6: Final commit only if verification produced uncommitted adjustments**

Run:

```powershell
git status --short
```

Expected after Task 1-3 commits: no uncommitted source/test files. If Step 2 or Step 3 required analyzer-only edits, run:

```powershell
git add lib/realtime/telemetry/realtime_rollout_telemetry.dart lib/realtime/telemetry/realtime_rollout_telemetry_provider.dart lib/modules/chat/chat_frame_jank_monitor.dart lib/modules/chat/chat_page_shell.dart test/realtime/telemetry/realtime_rollout_telemetry_test.dart test/modules/chat/chat_frame_jank_monitor_test.dart test/modules/chat/chat_frame_jank_monitor_lifecycle_test.dart
git commit -m "chore: verify chat frame jank telemetry"
```

Expected: either no commit is needed because the tree is clean, or the verification adjustment commit succeeds.

---

## Completion Criteria

- `FrameJankTelemetry` exists and is implemented by `RealtimeRolloutTelemetry`.
- Metrics are exactly:
  - `chat_frame_build_jank_ms`
  - `chat_frame_raster_jank_ms`
  - `chat_frame_total_jank_ms`
- Tags are exactly low-cardinality `surface=chat` and `reason=build|raster|total`.
- Unknown reasons are ignored and do not enter telemetry.
- `ChatFrameJankMonitor` records only `>` threshold breaches:
  - build > 8ms
  - raster > 16ms
  - total > 24ms
- `ChatFrameJankMonitor.start()` and `stop()` are idempotent.
- `ChatPageShell` starts the monitor on mount and stops it on dispose.
- Targeted tests pass.
- `flutter analyze lib/realtime lib/modules/chat test/realtime test/modules/chat` passes.
- `flutter analyze` passes.


