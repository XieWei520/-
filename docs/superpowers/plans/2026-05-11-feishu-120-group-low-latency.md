# Feishu 120 Group Low-Latency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Feishu ordinary-account forwarding usable for 120 configured groups by using event-priority media queues and first-phase visible multi-worker shell support.

**Architecture:** Parameterize the Feishu shell so multiple visible worker instances can run on separate ports and profile directories. Assign each Feishu route to one worker, collect status/events from all workers in WuKongIM, and replace blind media group rotation with event-driven image extraction queues. Text forwarding stays independent from image extraction latency.

**Tech Stack:** Flutter/Dart, WebView2 shell app, existing local ShellServer/SSE API, existing WuKongIM Feishu monitor module, Flutter widget/unit tests.

---

## File Structure

- `tools/feishu_monitor_shell_app/lib/main.dart`
  Add shell worker runtime options: worker id, port, support/profile suffix, title suffix, and diagnostics.

- `tools/feishu_monitor_shell_app/lib/src/feishu_media_extraction_queue.dart`
  New pure Dart queue model for event-driven media extraction scheduling.

- `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`
  Create queue items from configured feed-card image placeholders, expose queue diagnostics, and avoid stale placeholder resend.

- `tools/feishu_monitor_shell_app/lib/src/feishu_page_probe.dart`
  Keep targeted media feed opening scripts intact; only adjust diagnostics if the queue needs additional fields.

- `tools/feishu_monitor_shell_app/test/feishu_media_extraction_queue_test.dart`
  New tests for queue dedupe, priority, retry, timeout, and diagnostics.

- `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`
  Add tests for queue diagnostics and no-placeholder forwarding behavior.

- `lib/modules/feishu_monitor/feishu_monitor_worker_config.dart`
  New WuKongIM-side worker config and route sharding helpers.

- `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`
  Keep single-worker client behavior and add a small `FeishuMonitorShellClientGroup` wrapper for multi-worker status/event collection.

- `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
  Parse worker id, queue diagnostics, and per-worker status data.

- `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
  Add `workerId` to forwarding routes/settings and preserve backward compatibility for existing routes.

- `lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart`
  Collect from all configured worker clients and merge events without duplicate forwarding.

- `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
  Show worker count, per-worker status, queue depth, estimated delay, and 120-group capacity warnings.

- `test/modules/feishu_monitor/feishu_monitor_worker_config_test.dart`
  New tests for deterministic route sharding and worker endpoint generation.

- `test/modules/feishu_monitor/feishu_monitor_shell_models_test.dart`
  New tests for queue diagnostics parsing.

- `test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`
  Add multi-worker fetch/merge/dedupe tests.

- `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
  Add worker panel and warning rendering tests.

## Task 1: Shell Worker Runtime Options

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Test: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests near the existing support-directory and shell-runtime tests:

```dart
test('worker runtime options parse worker id and port from arguments', () {
  final options = parseFeishuShellWorkerOptions(<String>[
    '--worker-id=worker-3',
    '--port=18768',
    '--profile-suffix=worker-3',
  ]);

  expect(options.workerId, 'worker-3');
  expect(options.port, 18768);
  expect(options.profileSuffix, 'worker-3');
  expect(options.titleSuffix, 'worker-3');
});

test('worker support directory is isolated by profile suffix', () {
  final base = Directory(r'C:\tmp\app_support');
  final defaultDir = feishuShellStableSupportDirectoryFor(base);
  final workerDir = feishuShellStableSupportDirectoryFor(
    base,
    profileSuffix: 'worker-3',
  );

  expect(defaultDir.path, isNot(workerDir.path));
  expect(workerDir.path, contains('feishu_monitor_shell_app_worker-3'));
});
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/runtime_snapshot_mapper_test.dart -r compact
```

Expected: FAIL because `parseFeishuShellWorkerOptions`, `workerId`, `port`, `profileSuffix`, or the new overload does not exist.

- [ ] **Step 3: Implement minimal runtime options**

Add a small value object and parser in `main.dart`:

```dart
class FeishuShellWorkerOptions {
  const FeishuShellWorkerOptions({
    required this.workerId,
    required this.port,
    required this.profileSuffix,
    required this.titleSuffix,
  });

  final String workerId;
  final int port;
  final String profileSuffix;
  final String titleSuffix;

  static const FeishuShellWorkerOptions defaults = FeishuShellWorkerOptions(
    workerId: 'worker-1',
    port: 18766,
    profileSuffix: '',
    titleSuffix: '',
  );
}

FeishuShellWorkerOptions parseFeishuShellWorkerOptions(List<String> args) {
  var workerId = FeishuShellWorkerOptions.defaults.workerId;
  var port = FeishuShellWorkerOptions.defaults.port;
  var profileSuffix = '';
  var titleSuffix = '';

  for (final arg in args) {
    final index = arg.indexOf('=');
    if (!arg.startsWith('--') || index <= 2) {
      continue;
    }
    final key = arg.substring(2, index).trim();
    final value = arg.substring(index + 1).trim();
    if (value.isEmpty) {
      continue;
    }
    switch (key) {
      case 'worker-id':
        workerId = value;
        titleSuffix = value;
      case 'port':
        port = int.tryParse(value) ?? port;
      case 'profile-suffix':
        profileSuffix = value;
    }
  }

  return FeishuShellWorkerOptions(
    workerId: workerId,
    port: port,
    profileSuffix: profileSuffix,
    titleSuffix: titleSuffix.isEmpty ? workerId : titleSuffix,
  );
}
```

Update `main()` to use options:

```dart
final options = parseFeishuShellWorkerOptions(Platform.executableArguments);
...
final supportDirectory = await prepareFeishuShellSupportDirectory(
  await getApplicationSupportDirectory(),
  profileSuffix: options.profileSuffix,
);
...
final server = ShellServer(
  store: store,
  host: InternetAddress.loopbackIPv4,
  port: options.port,
  token: 'wukong-feishu-shell-dev',
  events: events,
);
...
FeishuMonitorShellApp(
  store: store,
  events: events,
  networkDiagnosticsFile: diagnosticsFile,
  workerOptions: options,
)
```

Also update directory helper signatures:

```dart
Directory feishuShellStableSupportDirectoryFor(
  Directory supportDirectory, {
  String profileSuffix = '',
}) {
  final parent = supportDirectory.parent;
  final suffix = profileSuffix.trim().isEmpty ? '' : '_${profileSuffix.trim()}';
  return Directory(
    '${parent.path}${Platform.pathSeparator}'
    '$feishuShellStableSupportDirectoryName$suffix',
  );
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/runtime_snapshot_mapper_test.dart -r compact
```

Expected: PASS.

## Task 2: Media Extraction Queue Core

**Files:**
- Create: `tools/feishu_monitor_shell_app/lib/src/feishu_media_extraction_queue.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_media_extraction_queue_test.dart`

- [ ] **Step 1: Write the failing queue tests**

Create `feishu_media_extraction_queue_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/src/feishu_media_extraction_queue.dart';

void main() {
  test('dedupes repeated feed card placeholders by source and key', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final queue = FeishuMediaExtractionQueue();

    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: 'feed:a',
        sourceConversationName: 'A',
        feedCardKey: 'card-1',
        feedPreviewText: '[图片]',
        enqueuedAt: now,
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );
    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: 'feed:a',
        sourceConversationName: 'A',
        feedCardKey: 'card-1',
        feedPreviewText: '[图片]',
        enqueuedAt: now.add(const Duration(seconds: 5)),
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );

    expect(queue.depth, 1);
    expect(queue.diagnostics(now.add(const Duration(seconds: 5)))['media_queue_depth'], 1);
  });

  test('chooses event-driven placeholder before fallback item', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final queue = FeishuMediaExtractionQueue()
      ..enqueue(
        FeishuMediaExtractionQueueItem(
          sourceConversationId: 'feed:fallback',
          sourceConversationName: 'Fallback',
          feedCardKey: 'fallback',
          feedPreviewText: '',
          enqueuedAt: now,
          priority: FeishuMediaExtractionPriority.fallbackKeepAlive,
        ),
      )
      ..enqueue(
        FeishuMediaExtractionQueueItem(
          sourceConversationId: 'feed:image',
          sourceConversationName: 'Image',
          feedCardKey: 'image-1',
          feedPreviewText: '[图片]',
          enqueuedAt: now,
          priority: FeishuMediaExtractionPriority.feedPlaceholder,
        ),
      );

    expect(queue.nextReady(now)?.sourceConversationId, 'feed:image');
  });

  test('records failure without producing placeholder forwarding request', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final queue = FeishuMediaExtractionQueue();
    final item = FeishuMediaExtractionQueueItem(
      sourceConversationId: 'feed:a',
      sourceConversationName: 'A',
      feedCardKey: 'card-1',
      feedPreviewText: '[图片]',
      enqueuedAt: now,
      priority: FeishuMediaExtractionPriority.feedPlaceholder,
    );

    queue.enqueue(item);
    queue.recordFailure(
      item,
      now: now.add(const Duration(seconds: 30)),
      reason: 'image_extraction_timeout',
    );

    final diagnostics = queue.diagnostics(now.add(const Duration(seconds: 30)));
    expect(diagnostics['media_queue_last_skip_reason'], 'image_extraction_timeout');
    expect(diagnostics['media_queue_forward_placeholder'], isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/feishu_media_extraction_queue_test.dart -r compact
```

Expected: FAIL because the queue file and classes do not exist.

- [ ] **Step 3: Implement queue model**

Create `feishu_media_extraction_queue.dart`:

```dart
enum FeishuMediaExtractionPriority {
  feedPlaceholder,
  retry,
  fallbackKeepAlive,
}

class FeishuMediaExtractionQueueItem {
  const FeishuMediaExtractionQueueItem({
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.feedCardKey,
    required this.feedPreviewText,
    required this.enqueuedAt,
    required this.priority,
    this.retryAfter,
  });

  final String sourceConversationId;
  final String sourceConversationName;
  final String feedCardKey;
  final String feedPreviewText;
  final DateTime enqueuedAt;
  final FeishuMediaExtractionPriority priority;
  final DateTime? retryAfter;

  String get dedupeKey =>
      '${sourceConversationId.trim()}\n${sourceConversationName.trim()}\n${feedCardKey.trim()}';

  bool get isReady {
    final retryAt = retryAfter;
    return retryAt == null || DateTime.now().toUtc().isAfter(retryAt.toUtc());
  }

  int get priorityRank {
    switch (priority) {
      case FeishuMediaExtractionPriority.feedPlaceholder:
        return 0;
      case FeishuMediaExtractionPriority.retry:
        return 1;
      case FeishuMediaExtractionPriority.fallbackKeepAlive:
        return 2;
    }
  }
}

class FeishuMediaExtractionQueue {
  final Map<String, FeishuMediaExtractionQueueItem> _items =
      <String, FeishuMediaExtractionQueueItem>{};
  FeishuMediaExtractionQueueItem? _activeItem;
  String _lastResult = '';
  String _lastSkipReason = '';

  int get depth => _items.length;

  void enqueue(FeishuMediaExtractionQueueItem item) {
    final key = item.dedupeKey;
    final existing = _items[key];
    if (existing == null || item.enqueuedAt.isAfter(existing.enqueuedAt)) {
      _items[key] = item;
    }
  }

  FeishuMediaExtractionQueueItem? nextReady(DateTime now) {
    final ready = _items.values
        .where((item) {
          final retryAt = item.retryAfter;
          return retryAt == null || !retryAt.toUtc().isAfter(now.toUtc());
        })
        .toList(growable: false)
      ..sort((a, b) {
        final byPriority = a.priorityRank.compareTo(b.priorityRank);
        if (byPriority != 0) {
          return byPriority;
        }
        return a.enqueuedAt.compareTo(b.enqueuedAt);
      });
    if (ready.isEmpty) {
      return null;
    }
    _activeItem = ready.first;
    return ready.first;
  }

  void recordSuccess(FeishuMediaExtractionQueueItem item, {required DateTime now}) {
    _items.remove(item.dedupeKey);
    _activeItem = null;
    _lastResult = 'success';
    _lastSkipReason = '';
  }

  void recordFailure(
    FeishuMediaExtractionQueueItem item, {
    required DateTime now,
    required String reason,
  }) {
    _items.remove(item.dedupeKey);
    _activeItem = null;
    _lastResult = 'failed';
    _lastSkipReason = reason;
  }

  Map<String, Object?> diagnostics(DateTime now) {
    final oldest = _items.values.fold<DateTime?>(null, (current, item) {
      if (current == null || item.enqueuedAt.isBefore(current)) {
        return item.enqueuedAt;
      }
      return current;
    });
    return <String, Object?>{
      'media_queue_depth': _items.length,
      'media_queue_active_item': _activeItem?.dedupeKey ?? '',
      'media_queue_oldest_wait_seconds': oldest == null
          ? 0
          : now.toUtc().difference(oldest.toUtc()).inSeconds,
      'media_queue_estimated_next_delay_seconds': _items.length * 20,
      'media_queue_last_result': _lastResult,
      'media_queue_last_skip_reason': _lastSkipReason,
      'media_queue_forward_placeholder': false,
    };
  }
}
```

- [ ] **Step 4: Run tests to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/feishu_media_extraction_queue_test.dart -r compact
```

Expected: PASS.

## Task 3: Queue Runtime Wiring In Shell

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Modify: `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`
- Modify: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`
- Modify: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`

- [ ] **Step 1: Write failing shell behavior tests**

Add tests that prove queue diagnostics are persisted and placeholder text is not forwarded after extraction failure:

```dart
test('applyPageProbe exposes media queue diagnostics for pending image feed', () {
  final probe = FeishuPageProbe.fromDiagnostics(
    observedAt: DateTime.utc(2026, 5, 11, 10),
    diagnostics: <String, dynamic>{
      'configured_media_sources': <Map<String, String>>[
        <String, String>{
          'conversation_id': 'feed:a',
          'conversation_name': 'A',
        },
      ],
      'top_feed_card_summaries': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'feed:a',
          'name': 'A',
          'text': 'A\nAlice: [图片]',
          'active': false,
        },
      ],
    },
  );

  final updated = applyPageProbe(ShellSnapshot.initial(), probe);

  expect(updated.probeDiagnostics['media_queue_depth'], 1);
  expect(updated.probeDiagnostics['media_queue_forward_placeholder'], isFalse);
});
```

If `FeishuPageProbe.fromDiagnostics` is not available, use the existing helper pattern in `runtime_snapshot_mapper_test.dart` for constructing `FeishuPageProbe`.

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/runtime_snapshot_mapper_test.dart -r compact
```

Expected: FAIL because queue diagnostics are not produced.

- [ ] **Step 3: Implement queue diagnostics and runtime gating**

Import the queue:

```dart
import 'feishu_media_extraction_queue.dart';
```

Add pure helpers in `runtime_snapshot_mapper.dart`:

```dart
Map<String, Object?> mediaQueueDiagnosticsForProbe({
  required FeishuPageProbe probe,
  required DateTime now,
}) {
  final queue = FeishuMediaExtractionQueue();
  if (probeHasPendingMediaFeedCard(probe)) {
    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: probe.pendingMediaFeedCardKey,
        sourceConversationName: probe.pendingMediaFeedCardText,
        feedCardKey: probe.pendingMediaFeedCardKey,
        feedPreviewText: probe.pendingMediaFeedCardText,
        enqueuedAt: now,
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );
  }
  return queue.diagnostics(now);
}
```

Merge diagnostics in `applyPageProbe`:

```dart
final queueDiagnostics = mediaQueueDiagnosticsForProbe(
  probe: probe,
  now: DateTime.now().toUtc(),
);
...
probeDiagnostics: <String, dynamic>{
  ..._persistentProbeDiagnostics(snapshot.probeDiagnostics),
  ...probe.probeDiagnostics,
  ...queueDiagnostics,
},
```

Update `_dropAlreadyExtractedFeedImagePlaceholders` or the forwarding-service filter so unresolved `[图片]` placeholder events are not forwarded as text when extraction fails. The minimal acceptable rule is:

```dart
bool _isUnresolvedImagePlaceholder(NormalizedMessageEvent event) {
  return event.imageAttachments.isEmpty && isFeishuMediaPreviewText(event.text);
}
```

and exclude those placeholder-only events from `recentEvents` unless they are needed only for internal queue diagnostics.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/feishu_media_extraction_queue_test.dart test/runtime_snapshot_mapper_test.dart -r compact
```

Expected: PASS.

## Task 4: Worker Config And Route Sharding

**Files:**
- Create: `lib/modules/feishu_monitor/feishu_monitor_worker_config.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_worker_config_test.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] **Step 1: Write failing worker config tests**

Create `feishu_monitor_worker_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_worker_config.dart';

void main() {
  test('builds six visible workers for 120 groups by default', () {
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(120);

    expect(workers, hasLength(6));
    expect(workers.first.workerId, 'worker-1');
    expect(workers.first.baseUrl, 'http://127.0.0.1:18766');
    expect(workers.last.workerId, 'worker-6');
    expect(workers.last.baseUrl, 'http://127.0.0.1:18771');
    expect(workers.every((worker) => worker.visible), isTrue);
  });

  test('assigns route index to deterministic worker shard', () {
    final workers = FeishuMonitorWorkerConfig.recommendedForRouteCount(120);

    expect(workerIdForRouteIndex(0, workers), 'worker-1');
    expect(workerIdForRouteIndex(19, workers), 'worker-1');
    expect(workerIdForRouteIndex(20, workers), 'worker-2');
    expect(workerIdForRouteIndex(119, workers), 'worker-6');
  });
}
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_worker_config_test.dart -r compact
```

Expected: FAIL because the worker config file does not exist.

- [ ] **Step 3: Implement worker config**

Create `feishu_monitor_worker_config.dart`:

```dart
class FeishuMonitorWorkerConfig {
  const FeishuMonitorWorkerConfig({
    required this.workerId,
    required this.baseUrl,
    required this.port,
    required this.profileSuffix,
    required this.visible,
    this.maxRoutes = 20,
  });

  final String workerId;
  final String baseUrl;
  final int port;
  final String profileSuffix;
  final bool visible;
  final int maxRoutes;

  static List<FeishuMonitorWorkerConfig> recommendedForRouteCount(
    int routeCount, {
    int shardSize = 20,
    int firstPort = 18766,
  }) {
    final normalizedRouteCount = routeCount <= 0 ? 1 : routeCount;
    final count = ((normalizedRouteCount + shardSize - 1) ~/ shardSize)
        .clamp(1, 6);
    return List<FeishuMonitorWorkerConfig>.generate(count, (index) {
      final id = 'worker-${index + 1}';
      final port = firstPort + index;
      return FeishuMonitorWorkerConfig(
        workerId: id,
        baseUrl: 'http://127.0.0.1:$port',
        port: port,
        profileSuffix: id,
        visible: true,
        maxRoutes: shardSize,
      );
    });
  }
}

String workerIdForRouteIndex(
  int routeIndex,
  List<FeishuMonitorWorkerConfig> workers,
) {
  if (workers.isEmpty) {
    return 'worker-1';
  }
  final safeIndex = routeIndex < 0 ? 0 : routeIndex;
  var start = 0;
  for (final worker in workers) {
    final end = start + worker.maxRoutes;
    if (safeIndex < end) {
      return worker.workerId;
    }
    start = end;
  }
  return workers.last.workerId;
}
```

Add `workerId` to `FeishuMonitorForwardingRoute` with backward-compatible default:

```dart
final String workerId;
...
workerId: (json['worker_id'] ?? json['workerId'] ?? '').toString(),
...
'worker_id': workerId,
```

- [ ] **Step 4: Run route and config tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_worker_config_test.dart test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart -r compact
```

Expected: PASS.

## Task 5: Multi-Worker Shell Client Group And Runner

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`

- [ ] **Step 1: Write failing multi-worker runner test**

Add a test:

```dart
test('runOnce merges events from all configured workers without duplicate forwarding', () async {
  final workerA = _FakeShellClient(
    status: _status(
      recentEvents: <FeishuMonitorMessageEvent>[
        _event(conversationId: 'feed:a', text: 'from A', dedupeKey: 'same'),
      ],
    ),
  );
  final workerB = _FakeShellClient(
    status: _status(
      recentEvents: <FeishuMonitorMessageEvent>[
        _event(conversationId: 'feed:b', text: 'from B', dedupeKey: 'same'),
      ],
    ),
  );
  final service = _FakeForwardingService();
  final runner = FeishuMonitorAutoForwardRunner(
    clientGroup: FeishuMonitorShellClientGroup.forTesting(<FeishuMonitorShellClient>[
      workerA,
      workerB,
    ]),
    forwardingService: service,
    forwardingSettingsStore: _MemoryForwardingSettingsStore(
      FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:a', targetGroupId: 'wk_a'),
          _route(sourceConversationId: 'feed:b', targetGroupId: 'wk_b'),
        ],
      ),
    ),
  );

  await runner.runOnce();

  expect(workerA.fetchCount, 1);
  expect(workerB.fetchCount, 1);
  expect(service.lastEvents, hasLength(1));
  expect(service.lastEvents.single.dedupeKey, 'same');
});
```

Adjust helper constructors if the current fake client type hierarchy needs an interface extraction.

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart -r compact
```

Expected: FAIL because `clientGroup` and `FeishuMonitorShellClientGroup` do not exist.

- [ ] **Step 3: Implement client group and runner merge**

Add in `feishu_monitor_shell_client.dart`:

```dart
class FeishuMonitorShellClientGroup {
  FeishuMonitorShellClientGroup(this.clients);

  final List<FeishuMonitorShellClient> clients;

  factory FeishuMonitorShellClientGroup.single(FeishuMonitorShellClient client) {
    return FeishuMonitorShellClientGroup(<FeishuMonitorShellClient>[client]);
  }

  factory FeishuMonitorShellClientGroup.forTesting(
    List<FeishuMonitorShellClient> clients,
  ) {
    return FeishuMonitorShellClientGroup(clients);
  }

  Future<List<FeishuMonitorShellStatus>> fetchStatuses() {
    return Future.wait(clients.map((client) => client.fetchStatus()));
  }
}
```

Update `FeishuMonitorAutoForwardRunner` constructor:

```dart
FeishuMonitorAutoForwardRunner({
  FeishuMonitorShellClient? client,
  FeishuMonitorShellClientGroup? clientGroup,
  ...
}) : _clientGroup = clientGroup ??
          FeishuMonitorShellClientGroup.single(client ?? FeishuMonitorShellClient()),
     ...
```

In `_runOnce`, fetch all statuses, flatten events, and dedupe by `dedupeKey`:

```dart
final statuses = await _clientGroup.fetchStatuses();
final eventsByKey = <String, FeishuMonitorMessageEvent>{};
for (final status in statuses) {
  for (final event in status.recentEvents) {
    final key = event.dedupeKey.trim().isEmpty ? event.eventId : event.dedupeKey;
    eventsByKey.putIfAbsent(key, () => event);
  }
}
final mergedEvents = eventsByKey.values.toList(growable: false);
```

Keep the existing single-client constructor behavior so current runtime still works.

- [ ] **Step 4: Run tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart -r compact
```

Expected: PASS.

## Task 6: Monitor Center Worker Diagnostics UI

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_shell_models_test.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing model and UI tests**

Create model parsing test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart';

void main() {
  test('parses worker and media queue diagnostics from status json', () {
    final status = FeishuMonitorShellStatus.fromJson(<String, dynamic>{
      'shell_state': 'online',
      'capture_state': 'running',
      'login_state': 'logged_in',
      'hook_state': 'healthy',
      'runtime_url': 'https://www.feishu.cn/messenger/',
      'page_title': 'Feishu',
      'page_kind': 'messenger',
      'webview_available': true,
      'shell_mode': 'desktop_shell',
      'queue_depth': 0,
      'messages_today': 0,
      'deliveries_succeeded_today': 0,
      'deliveries_failed_today': 0,
      'last_error': '',
      'worker_id': 'worker-2',
      'probe_diagnostics': <String, dynamic>{
        'media_queue_depth': 3,
        'media_queue_oldest_wait_seconds': 45,
        'media_queue_estimated_next_delay_seconds': 60,
        'media_queue_last_skip_reason': 'image_extraction_timeout',
      },
    });

    expect(status.workerId, 'worker-2');
    expect(status.mediaQueueDepth, 3);
    expect(status.mediaQueueOldestWaitSeconds, 45);
    expect(status.mediaQueueEstimatedNextDelaySeconds, 60);
    expect(status.mediaQueueLastSkipReason, 'image_extraction_timeout');
  });
}
```

Add UI assertion in `feishu_monitor_center_page_test.dart`:

```dart
expect(find.textContaining('worker-2'), findsWidgets);
expect(find.textContaining('队列'), findsWidgets);
expect(find.textContaining('45'), findsWidgets);
```

Use the existing mojibake labels in current tests if the app strings are currently encoded that way.

- [ ] **Step 2: Run tests to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_shell_models_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart -r compact
```

Expected: FAIL because the fields/UI do not exist.

- [ ] **Step 3: Implement model fields and UI surface**

Add fields to `FeishuMonitorShellStatus`:

```dart
final String workerId;
final int mediaQueueDepth;
final int mediaQueueOldestWaitSeconds;
final int mediaQueueEstimatedNextDelaySeconds;
final String mediaQueueLastSkipReason;
```

Parse them from top-level or `probe_diagnostics`:

```dart
final diagnostics = _asObject(json['probe_diagnostics']);
workerId: (json['worker_id'] ?? diagnostics['worker_id'] ?? 'worker-1').toString(),
mediaQueueDepth: _asInt(diagnostics['media_queue_depth']),
mediaQueueOldestWaitSeconds: _asInt(diagnostics['media_queue_oldest_wait_seconds']),
mediaQueueEstimatedNextDelaySeconds: _asInt(diagnostics['media_queue_estimated_next_delay_seconds']),
mediaQueueLastSkipReason: (diagnostics['media_queue_last_skip_reason'] ?? '').toString(),
```

In `feishu_monitor_center_page.dart`, add a worker/queue summary band near the status overview:

```dart
_MetricTile(
  label: 'Worker',
  value: status.workerId,
),
_MetricTile(
  label: '图片队列',
  value: '${status.mediaQueueDepth}',
),
_MetricTile(
  label: '最久等待',
  value: '${status.mediaQueueOldestWaitSeconds}s',
),
_MetricTile(
  label: '预计延迟',
  value: '${status.mediaQueueEstimatedNextDelaySeconds}s',
),
```

Add route-count warning:

```dart
String _workerCapacityWarning(int routeCount, int workerCount) {
  final capacity = workerCount * 20;
  if (routeCount <= capacity) {
    return '';
  }
  return '当前 $workerCount 个 worker 建议最多 $capacity 个群，已配置 $routeCount 个群';
}
```

- [ ] **Step 4: Run model/UI tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_shell_models_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart -r compact
```

Expected: PASS.

## Task 7: Final Verification And Windows Runtime

**Files:**
- No new source files unless prior tasks reveal a test-only gap.

- [ ] **Step 1: Run focused shell tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter test test/feishu_media_extraction_queue_test.dart test/runtime_snapshot_mapper_test.dart test/feishu_page_probe_test.dart test/probe_scheduler_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 2: Run shell analyzer**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter analyze lib/main.dart lib/src/feishu_media_extraction_queue.dart lib/src/feishu_page_probe.dart lib/src/runtime_snapshot_mapper.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Run WuKongIM Feishu monitor tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_worker_config_test.dart test/modules/feishu_monitor/feishu_monitor_shell_models_test.dart test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 4: Run WuKongIM analyzer**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter analyze lib/modules/feishu_monitor/feishu_monitor_worker_config.dart lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart lib/modules/feishu_monitor/feishu_monitor_center_page.dart lib/modules/feishu_monitor/feishu_monitor_shell_client.dart lib/modules/feishu_monitor/feishu_monitor_shell_models.dart lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart
```

Expected: `No issues found!`

- [ ] **Step 5: Build shell Windows release**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
flutter build windows --release
```

Expected: build succeeds.

- [ ] **Step 6: Manual multi-worker launch smoke test**

Run worker windows visibly:

```powershell
$exe='C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app\build\windows\x64\runner\Release\feishu_monitor_shell_app.exe'
Start-Process -FilePath $exe -ArgumentList '--worker-id=worker-1 --port=18766 --profile-suffix=worker-1'
Start-Process -FilePath $exe -ArgumentList '--worker-id=worker-2 --port=18767 --profile-suffix=worker-2'
```

Check status:

```powershell
$headers=@{ Authorization = 'Bearer wukong-feishu-shell-dev' }
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:18766/status' -Headers $headers
Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:18767/status' -Headers $headers
```

Expected: both return shell status and distinct `worker_id` / queue diagnostics.

- [ ] **Step 7: Manual joint test**

1. Log in to each visible Feishu worker window if Feishu asks for QR login.
2. Configure at least two Feishu source groups mapped to different workers.
3. Send text in both groups; verify WuKongIM receives text within a few seconds after Feishu feed updates.
4. Send one image in each group; verify the assigned worker opens only its target source and WuKongIM receives images.
5. Send a later text after image forwarding; verify old images are not resent.
6. Force one image extraction failure if possible; verify no `[图片]` placeholder is forwarded and the monitor center shows a failure reason.

Expected: no duplicate old images, no placeholder-only image messages, visible per-worker health.

## Self-Review

- Spec coverage: covered multi-worker first phase, 120-group target, event-priority queue, no placeholder forwarding, diagnostics, UI, and verification.
- Placeholder scan: no implementation placeholders remain in task acceptance criteria.
- Type consistency: worker ids use `worker-1` format; worker status fields use `workerId` in Dart and `worker_id` in JSON; queue diagnostics use `media_queue_*` keys consistently.
