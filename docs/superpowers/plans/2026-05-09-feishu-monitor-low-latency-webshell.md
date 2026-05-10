# Feishu Monitor Low-Latency WebShell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the normal-account Feishu WebShell forwarding path from timer-first polling to event-first low-latency forwarding while preserving 24-hour Windows unattended reliability.

**Architecture:** Keep the existing Feishu WebShell and WuKongIM desktop split. Add a local shell event stream, install a page-side `MutationObserver` that posts WebView messages to Flutter, and make WuKongIM subscribe to shell events while keeping a 3-second fallback poll. The existing route matching and persisted dedupe remain the delivery safety layer.

**Tech Stack:** Flutter Windows desktop, Dart, `webview_windows` `webMessage`, local `HttpServer`, Server-Sent Events, Dio streaming, existing Feishu Monitor forwarding service and tests.

---

## File Structure

- Create `tools/feishu_monitor_shell/lib/src/shell_event_bus.dart`
  - Owns lightweight local events and a broadcast stream used by the shell HTTP server.
- Modify `tools/feishu_monitor_shell/lib/feishu_monitor_shell.dart`
  - Exports the event bus for the shell app.
- Modify `tools/feishu_monitor_shell/lib/src/shell_server.dart`
  - Adds authenticated `GET /events` SSE endpoint and publishes events after shell control mutations.
- Modify `tools/feishu_monitor_shell/test/shell_server_test.dart`
  - Covers SSE auth, event formatting, and capture-state notifications.
- Create `tools/feishu_monitor_shell_app/lib/src/feishu_page_observer.dart`
  - Contains the injected JavaScript observer script and message parsing helpers.
- Create `tools/feishu_monitor_shell_app/lib/src/probe_scheduler.dart`
  - Owns coalescing of page-probe requests so rapid DOM mutations do not create overlapping probes.
- Modify `tools/feishu_monitor_shell_app/lib/main.dart`
  - Installs the observer, listens to WebView messages, uses the scheduler, publishes shell events, and changes fallback probing to 3 seconds.
- Modify `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`
  - Adds observer-script safety tests.
- Create `tools/feishu_monitor_shell_app/test/probe_scheduler_test.dart`
  - Covers coalescing, pending reruns, and non-overlapping probes.
- Modify `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
  - Adds a WuKongIM-side model for shell event-stream payloads.
- Modify `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`
  - Adds `watchEvents()` for authenticated SSE streaming.
- Modify `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`
  - Covers parsing event-stream payloads and ignoring malformed frames.
- Modify `lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart`
  - Subscribes to shell events, triggers immediate forwarding, keeps a 3-second fallback timer, and reconnects on stream errors.
- Modify `test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`
  - Covers event-triggered run, fallback polling, and reconnect-safe startup.
- Modify `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`
  - Adds the final latency test evidence after implementation.

---

### Task 1: Shell Event Bus And SSE Endpoint

**Files:**
- Create: `tools/feishu_monitor_shell/lib/src/shell_event_bus.dart`
- Modify: `tools/feishu_monitor_shell/lib/feishu_monitor_shell.dart`
- Modify: `tools/feishu_monitor_shell/lib/src/shell_server.dart`
- Modify: `tools/feishu_monitor_shell/test/shell_server_test.dart`

- [ ] **Step 1: Write failing SSE tests**

Append these tests to `tools/feishu_monitor_shell/test/shell_server_test.dart` before the final closing brace of `main()`:

```dart
test('GET /events rejects unauthorized clients', () async {
  final request = await client.getUrl(baseUri.resolve('/events'));

  final response = await request.close();
  final body = await utf8.decodeStream(response);
  final json = jsonDecode(body) as Map<String, dynamic>;

  expect(response.statusCode, HttpStatus.unauthorized);
  expect(json['error'], 'unauthorized');
});

test('GET /events streams published shell events', () async {
  final request = await client.getUrl(baseUri.resolve('/events'));
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');

  final responseFuture = request.close();
  await Future<void>.delayed(const Duration(milliseconds: 50));

  server.events.publish(
    ShellEvent(
      type: ShellEventType.snapshotUpdated,
      reason: 'test_probe',
      updatedAt: DateTime.parse('2026-05-09T13:00:00Z'),
      recentEventsCount: 2,
      observedConversationsCount: 3,
    ),
  );

  final response = await responseFuture;
  expect(response.statusCode, HttpStatus.ok);
  expect(response.headers.contentType?.mimeType, 'text/event-stream');

  final lines = <String>[];
  final subscription = response
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(lines.add);

  await Future<void>.delayed(const Duration(milliseconds: 150));
  await subscription.cancel();

  expect(lines, contains('event: snapshot_updated'));
  expect(
    lines.any(
      (line) =>
          line.startsWith('data: ') &&
          line.contains('"reason":"test_probe"') &&
          line.contains('"recent_events":2') &&
          line.contains('"observed_conversations":3'),
    ),
    isTrue,
  );
});

test('POST /capture/start publishes capture state event', () async {
  final events = <ShellEvent>[];
  final sub = server.events.stream.listen(events.add);

  final request = await client.postUrl(baseUri.resolve('/capture/start'));
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer test-token');
  final response = await request.close();
  await utf8.decodeStream(response);

  await Future<void>.delayed(const Duration(milliseconds: 20));
  await sub.cancel();

  expect(response.statusCode, HttpStatus.ok);
  expect(events, hasLength(1));
  expect(events.single.type, ShellEventType.captureStateChanged);
  expect(events.single.reason, 'capture_start');
});
```

- [ ] **Step 2: Run shell tests and confirm failure**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell
```

Expected: FAIL because `server.events`, `ShellEvent`, and `ShellEventType` do not exist.

- [ ] **Step 3: Implement the event bus**

Create `tools/feishu_monitor_shell/lib/src/shell_event_bus.dart`:

```dart
import 'dart:async';

enum ShellEventType {
  snapshotUpdated('snapshot_updated'),
  captureStateChanged('capture_state_changed'),
  shellError('shell_error');

  const ShellEventType(this.wireName);

  final String wireName;
}

class ShellEvent {
  const ShellEvent({
    required this.type,
    required this.reason,
    required this.updatedAt,
    this.recentEventsCount = 0,
    this.observedConversationsCount = 0,
    this.error = '',
  });

  final ShellEventType type;
  final String reason;
  final DateTime updatedAt;
  final int recentEventsCount;
  final int observedConversationsCount;
  final String error;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type.wireName,
      'reason': reason,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'recent_events': recentEventsCount,
      'observed_conversations': observedConversationsCount,
      'error': error,
    };
  }
}

class ShellEventBus {
  final StreamController<ShellEvent> _controller =
      StreamController<ShellEvent>.broadcast();

  Stream<ShellEvent> get stream => _controller.stream;

  void publish(ShellEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  Future<void> close() => _controller.close();
}
```

Modify `tools/feishu_monitor_shell/lib/feishu_monitor_shell.dart`:

```dart
export 'src/shell_event_bus.dart';
```

- [ ] **Step 4: Add SSE support to the shell server**

Modify `tools/feishu_monitor_shell/lib/src/shell_server.dart`:

```dart
import 'dart:async';
```

Add the import:

```dart
import 'shell_event_bus.dart';
```

Change the constructor and fields:

```dart
class ShellServer {
  ShellServer({
    required this.store,
    required this.host,
    required this.port,
    required this.token,
    ShellEventBus? events,
  }) : events = events ?? ShellEventBus();

  final ShellEventBus events;
```

Add a subscription list field:

```dart
  final List<StreamSubscription<ShellEvent>> _eventSubscriptions =
      <StreamSubscription<ShellEvent>>[];
```

Update `close()`:

```dart
  Future<void> close() async {
    for (final subscription in List<StreamSubscription<ShellEvent>>.from(
      _eventSubscriptions,
    )) {
      await subscription.cancel();
    }
    _eventSubscriptions.clear();
    await events.close();
    await _server?.close(force: true);
  }
```

In `_handleRequest`, after reading `path`, add:

```dart
    if (request.method == 'GET' && path == '/events') {
      await _writeEventStream(request);
      return;
    }
```

Add `_writeEventStream` and `_writeSseEvent`:

```dart
  Future<void> _writeEventStream(HttpRequest request) async {
    final response = request.response;
    response.statusCode = HttpStatus.ok;
    response.headers
      ..contentType = ContentType('text', 'event-stream', charset: 'utf-8')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache')
      ..set(HttpHeaders.connectionHeader, 'keep-alive');
    response.write(': connected\n\n');
    await response.flush();

    late final StreamSubscription<ShellEvent> subscription;
    subscription = events.stream.listen(
      (event) {
        _writeSseEvent(response, event);
      },
      onDone: () {
        response.close();
      },
      onError: (_) {
        response.close();
      },
    );
    _eventSubscriptions.add(subscription);
    response.done.whenComplete(() async {
      _eventSubscriptions.remove(subscription);
      await subscription.cancel();
    });
  }

  void _writeSseEvent(HttpResponse response, ShellEvent event) {
    response.write('event: ${event.type.wireName}\n');
    response.write('data: ${jsonEncode(event.toJson())}\n\n');
    response.flush();
  }
```

After `await store.save(next);` in `/capture/start`, publish:

```dart
      events.publish(
        ShellEvent(
          type: ShellEventType.captureStateChanged,
          reason: 'capture_start',
          updatedAt: next.lastUpdatedAt,
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
```

After `await store.save(next);` in `/capture/stop`, publish the same event with `reason: 'capture_stop'`.

After `await store.save(next);` in `/runtime/reload`, publish:

```dart
      events.publish(
        ShellEvent(
          type: ShellEventType.snapshotUpdated,
          reason: 'runtime_reload',
          updatedAt: next.lastUpdatedAt,
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
```

- [ ] **Step 5: Run shell tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell
```

Expected: PASS.

---

### Task 2: Probe Scheduler And Page Observer In WebShell App

**Files:**
- Create: `tools/feishu_monitor_shell_app/lib/src/probe_scheduler.dart`
- Create: `tools/feishu_monitor_shell_app/lib/src/feishu_page_observer.dart`
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Modify: `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`
- Create: `tools/feishu_monitor_shell_app/test/probe_scheduler_test.dart`

- [ ] **Step 1: Write failing scheduler tests**

Create `tools/feishu_monitor_shell_app/test/probe_scheduler_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/src/probe_scheduler.dart';

void main() {
  test('runs one probe for a single request', () async {
    final calls = <String>[];
    final scheduler = ProbeScheduler(
      runProbe: (reason) async {
        calls.add(reason);
      },
    );

    scheduler.request('event');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, <String>['event']);
    expect(scheduler.isRunning, isFalse);
  });

  test('coalesces rapid requests while a probe is running', () async {
    final calls = <String>[];
    final completer = Completer<void>();
    final scheduler = ProbeScheduler(
      runProbe: (reason) async {
        calls.add(reason);
        if (calls.length == 1) {
          await completer.future;
        }
      },
    );

    scheduler.request('event');
    scheduler.request('event');
    scheduler.request('fallback');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, <String>['event']);

    completer.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(calls, <String>['event', 'pending']);
    expect(scheduler.isRunning, isFalse);
  });
}
```

- [ ] **Step 2: Write failing observer script tests**

Append to `tools/feishu_monitor_shell_app/test/feishu_page_probe_test.dart`:

```dart
test('observer script posts Feishu monitor mutation messages', () {
  expect(feishuPageObserverScript, contains('MutationObserver'));
  expect(feishuPageObserverScript, contains('chrome.webview.postMessage'));
  expect(feishuPageObserverScript, contains('feishu_monitor_feed_changed'));
  expect(feishuPageObserverScript, contains('a11y_feed_card_item'));
});

test('parses Feishu monitor observer message', () {
  final message = FeishuPageObserverMessage.fromJson(<String, dynamic>{
    'type': 'feishu_monitor_feed_changed',
    'reason': 'mutation',
    'observed_at': '2026-05-09T13:00:00Z',
  });

  expect(message.isFeedChanged, isTrue);
  expect(message.reason, 'mutation');
  expect(message.observedAt, DateTime.parse('2026-05-09T13:00:00Z'));
});
```

- [ ] **Step 3: Run WebShell app tests and confirm failure**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
```

Expected: FAIL because `ProbeScheduler`, `feishuPageObserverScript`, and `FeishuPageObserverMessage` do not exist.

- [ ] **Step 4: Implement probe scheduler**

Create `tools/feishu_monitor_shell_app/lib/src/probe_scheduler.dart`:

```dart
import 'dart:async';

typedef ProbeRunner = Future<void> Function(String reason);

class ProbeScheduler {
  ProbeScheduler({required ProbeRunner runProbe}) : _runProbe = runProbe;

  final ProbeRunner _runProbe;
  bool _running = false;
  bool _pending = false;

  bool get isRunning => _running;

  void request(String reason) {
    if (_running) {
      _pending = true;
      return;
    }
    unawaited(_drain(reason));
  }

  Future<void> _drain(String reason) async {
    _running = true;
    var nextReason = reason;
    try {
      while (true) {
        _pending = false;
        await _runProbe(nextReason);
        if (!_pending) {
          break;
        }
        nextReason = 'pending';
      }
    } finally {
      _running = false;
    }
  }
}
```

- [ ] **Step 5: Implement page observer script and parser**

Create `tools/feishu_monitor_shell_app/lib/src/feishu_page_observer.dart`:

```dart
const String feishuPageObserverScript = r'''
(() => {
  const stateKey = '__wukongFeishuMonitorObserver';
  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  if (window[stateKey] && window[stateKey].installed) {
    return { installed: true, reused: true };
  }
  const selectors = [
    '.lark_feedMainList',
    '.feed-main-list',
    '.a11y_feed_main_list',
    '.scroller.feed-main-list',
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main'
  ];
  let timer = 0;
  let firstObservedAt = 0;
  const notify = (reason) => {
    const now = Date.now();
    if (!firstObservedAt) {
      firstObservedAt = now;
    }
    if (timer) {
      clearTimeout(timer);
    }
    const elapsed = now - firstObservedAt;
    const delay = elapsed >= 800 ? 0 : 150;
    timer = setTimeout(() => {
      timer = 0;
      firstObservedAt = 0;
      post({
        type: 'feishu_monitor_feed_changed',
        reason,
        observed_at: new Date().toISOString()
      });
    }, delay);
  };
  const findRoot = () => {
    for (const selector of selectors) {
      const node = document.querySelector(selector);
      if (node) {
        return node.closest('.lark_feedMainList') || node;
      }
    }
    return document.body;
  };
  const root = findRoot();
  const observer = new MutationObserver((mutations) => {
    if (!mutations || mutations.length === 0) {
      return;
    }
    notify('mutation');
  });
  observer.observe(root, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
    attributeFilter: ['data-feed-active', 'aria-label', 'class']
  });
  window[stateKey] = {
    installed: true,
    installed_at: new Date().toISOString(),
    root: root.tagName || '',
    disconnect: () => observer.disconnect()
  };
  post({
    type: 'feishu_monitor_observer_installed',
    reason: 'installed',
    observed_at: new Date().toISOString()
  });
  return { installed: true, reused: false, root: root.tagName || '' };
})();
''';

class FeishuPageObserverMessage {
  const FeishuPageObserverMessage({
    required this.type,
    required this.reason,
    required this.observedAt,
  });

  final String type;
  final String reason;
  final DateTime? observedAt;

  bool get isFeedChanged => type == 'feishu_monitor_feed_changed';
  bool get isObserverInstalled => type == 'feishu_monitor_observer_installed';

  factory FeishuPageObserverMessage.fromJson(Map<String, dynamic> json) {
    return FeishuPageObserverMessage(
      type: (json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      observedAt: DateTime.tryParse((json['observed_at'] ?? '').toString()),
    );
  }
}
```

- [ ] **Step 6: Wire scheduler and observer into the shell app**

Modify `tools/feishu_monitor_shell_app/lib/main.dart`.

Add imports:

```dart
import 'src/feishu_page_observer.dart';
import 'src/probe_scheduler.dart';
```

Add state fields:

```dart
  StreamSubscription<dynamic>? _webMessageSubscription;
  late final ProbeScheduler _probeScheduler;
```

In `initState()`, after `_controller = WebviewController();`, add:

```dart
    _probeScheduler = ProbeScheduler(runProbe: _refreshPageProbe);
```

In `dispose()`, add:

```dart
    unawaited(_webMessageSubscription?.cancel());
```

After `_controller.initialize();` in `_bootstrap()`, subscribe to web messages:

```dart
      _webMessageSubscription = _controller.webMessage.listen((message) {
        if (message is! Map) {
          return;
        }
        final observerMessage = FeishuPageObserverMessage.fromJson(
          Map<String, dynamic>.from(
            message.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
        if (observerMessage.isObserverInstalled) {
          unawaited(_persistRuntimeState());
        }
        if (observerMessage.isFeedChanged) {
          _probeScheduler.request('event:${observerMessage.reason}');
        }
      });
```

In the loading-state listener, replace:

```dart
          unawaited(_refreshPageProbe());
```

with:

```dart
          unawaited(_installPageObserver());
          _probeScheduler.request('navigation');
```

Replace the 8-second timer block:

```dart
      _probeTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (_webviewReady && !_loading) {
          unawaited(_refreshPageProbe());
        }
      });
```

with:

```dart
      _probeTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_webviewReady && !_loading) {
          unawaited(_installPageObserver());
          _probeScheduler.request('fallback');
        }
      });
```

Add `_installPageObserver()`:

```dart
  Future<void> _installPageObserver() async {
    try {
      await _controller.executeScript(feishuPageObserverScript);
    } catch (_) {
      // The fallback probe still runs if observer installation fails.
    }
  }
```

In `_refreshPageProbe`, after `await widget.store.save(next);`, publish a shell event:

```dart
      widget.events.publish(
        ShellEvent(
          type: ShellEventType.snapshotUpdated,
          reason: reason,
          updatedAt: next.lastUpdatedAt,
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
```

To support this, update `_refreshPageProbe` signature:

```dart
  Future<void> _refreshPageProbe(String reason) async {
```

Change `FeishuMonitorShellApp` and `FeishuMonitorShellHome` to receive the same `ShellEventBus` created for the server:

```dart
final events = ShellEventBus();
final server = ShellServer(
  store: store,
  host: InternetAddress.loopbackIPv4,
  port: 18766,
  token: 'wukong-feishu-shell-dev',
  events: events,
);
runApp(FeishuMonitorShellApp(store: store, events: events));
```

Add `events` fields to both widgets and pass them through.

After this signature change, replace every direct call to `_refreshPageProbe()` with a scheduler request or a reasoned call. In the current file this means:

```dart
// navigation-completed path
unawaited(_installPageObserver());
_probeScheduler.request('navigation');

// fallback timer path
unawaited(_installPageObserver());
_probeScheduler.request('fallback');
```

In the catch block of `_refreshPageProbe`, after saving the error snapshot, publish:

```dart
      widget.events.publish(
        ShellEvent(
          type: ShellEventType.shellError,
          reason: reason,
          updatedAt: next.lastUpdatedAt,
          error: error.toString(),
          recentEventsCount: next.recentEvents.length,
          observedConversationsCount: next.observedConversations.length,
        ),
      );
```

- [ ] **Step 7: Run WebShell app tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
```

Expected: PASS.

---

### Task 3: WuKongIM Shell Event Client

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`
- Modify: `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`

- [ ] **Step 1: Write failing client event-stream test**

Append to `test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart`:

```dart
test('watchEvents parses shell event stream frames', () async {
  final adapter = _RoutingAdapter((options) {
    expect(options.method, 'GET');
    expect(options.uri.path, '/events');
    expect(options.headers['Authorization'], 'Bearer local-shell-token');
    return ResponseBody.fromString(
      ': connected\n\n'
      'event: snapshot_updated\n'
      'data: {"type":"snapshot_updated","reason":"event:mutation","updated_at":"2026-05-09T13:00:00Z","recent_events":2,"observed_conversations":3,"error":""}\n\n'
      'event: shell_error\n'
      'data: {"type":"shell_error","reason":"fallback","updated_at":"2026-05-09T13:00:02Z","recent_events":2,"observed_conversations":3,"error":"boom"}\n\n',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/event-stream'],
      },
    );
  });
  final dio = Dio()..httpClientAdapter = adapter;
  final client = FeishuMonitorShellClient(
    dio: dio,
    baseUrl: 'http://127.0.0.1:18766',
    token: 'local-shell-token',
  );

  final events = await client.watchEvents().toList();

  expect(events, hasLength(2));
  expect(events.first.type, 'snapshot_updated');
  expect(events.first.reason, 'event:mutation');
  expect(events.first.updatedAt, DateTime.parse('2026-05-09T13:00:00Z'));
  expect(events.first.recentEvents, 2);
  expect(events.first.observedConversations, 3);
  expect(events.last.type, 'shell_error');
  expect(events.last.error, 'boom');
});
```

- [ ] **Step 2: Run the client test and confirm failure**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test\modules\feishu_monitor\feishu_monitor_shell_client_test.dart
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong
```

Expected: FAIL because `watchEvents()` and `FeishuMonitorShellEvent` do not exist.

- [ ] **Step 3: Add the shell event model**

Append to `lib/modules/feishu_monitor/feishu_monitor_shell_models.dart`:

```dart
class FeishuMonitorShellEvent {
  const FeishuMonitorShellEvent({
    required this.type,
    required this.reason,
    required this.updatedAt,
    required this.recentEvents,
    required this.observedConversations,
    required this.error,
  });

  final String type;
  final String reason;
  final DateTime? updatedAt;
  final int recentEvents;
  final int observedConversations;
  final String error;

  bool get isSnapshotUpdated => type == 'snapshot_updated';
  bool get isShellError => type == 'shell_error';

  factory FeishuMonitorShellEvent.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorShellEvent(
      type: (json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      updatedAt: FeishuMonitorShellStatus.asDateTime(json['updated_at']),
      recentEvents: FeishuMonitorShellStatus._asInt(json['recent_events']),
      observedConversations:
          FeishuMonitorShellStatus._asInt(json['observed_conversations']),
      error: (json['error'] ?? '').toString(),
    );
  }
}
```

- [ ] **Step 4: Add `watchEvents()` to the shell client**

Modify `lib/modules/feishu_monitor/feishu_monitor_shell_client.dart`.

Add:

```dart
  Stream<FeishuMonitorShellEvent> watchEvents() async* {
    final response = await _dio.get<ResponseBody>(
      '$_baseUrl/events',
      options: Options(
        headers: <String, String>{'Authorization': 'Bearer $_token'},
        responseType: ResponseType.stream,
      ),
    );
    final stream = response.data?.stream;
    if (stream == null) {
      return;
    }

    var eventName = '';
    final dataLines = <String>[];
    await for (final line in stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.trim().isEmpty) {
        final rawData = dataLines.join('\n').trim();
        if (rawData.isNotEmpty) {
          final decoded = jsonDecode(rawData);
          if (decoded is Map) {
            final json = Map<String, dynamic>.from(decoded);
            json.putIfAbsent('type', () => eventName);
            yield FeishuMonitorShellEvent.fromJson(json);
          }
        }
        eventName = '';
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) {
        continue;
      }
      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        dataLines.add(line.substring('data:'.length).trim());
      }
    }
  }
```

- [ ] **Step 5: Run the client tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test\modules\feishu_monitor\feishu_monitor_shell_client_test.dart
```

Expected: PASS.

---

### Task 4: Event-Driven Auto Forward Runner

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`

- [ ] **Step 1: Write failing runner tests**

Append to `test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart`:

```dart
test('start forwards immediately when shell event arrives', () async {
  final eventController = StreamController<FeishuMonitorShellEvent>.broadcast();
  final client = _FakeShellClient(
    status: _status(
      recentEvents: <FeishuMonitorMessageEvent>[
        _event(conversationId: 'feed:alpha', text: 'fast'),
      ],
    ),
    events: eventController.stream,
  );
  final service = _FakeForwardingService();
  final runner = FeishuMonitorAutoForwardRunner(
    client: client,
    forwardingService: service,
    forwardingSettingsStore: _MemoryForwardingSettingsStore(
      FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      ),
    ),
    interval: const Duration(days: 1),
    eventReconnectDelay: const Duration(milliseconds: 20),
  );

  runner.start();
  await Future<void>.delayed(const Duration(milliseconds: 20));
  final initialFetchCount = client.fetchCount;

  eventController.add(
    FeishuMonitorShellEvent(
      type: 'snapshot_updated',
      reason: 'event:mutation',
      updatedAt: DateTime.parse('2026-05-09T13:00:00Z'),
      recentEvents: 1,
      observedConversations: 1,
      error: '',
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  runner.dispose();
  await eventController.close();

  expect(client.watchCount, 1);
  expect(client.fetchCount, greaterThan(initialFetchCount));
  expect(service.lastEvents.single.text, 'fast');
});

test('start keeps fallback polling when no shell event arrives', () async {
  final client = _FakeShellClient(
    status: _status(
      recentEvents: <FeishuMonitorMessageEvent>[
        _event(conversationId: 'feed:alpha', text: 'fallback'),
      ],
    ),
    events: const Stream<FeishuMonitorShellEvent>.empty(),
  );
  final service = _FakeForwardingService();
  final runner = FeishuMonitorAutoForwardRunner(
    client: client,
    forwardingService: service,
    forwardingSettingsStore: _MemoryForwardingSettingsStore(
      FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      ),
    ),
    interval: const Duration(milliseconds: 25),
    eventReconnectDelay: const Duration(days: 1),
  );

  runner.start();
  await Future<void>.delayed(const Duration(milliseconds: 80));
  runner.dispose();

  expect(client.fetchCount, greaterThanOrEqualTo(2));
  expect(service.callCount, greaterThanOrEqualTo(2));
});
```

Add imports:

```dart
import 'dart:async';
```

Update `_FakeShellClient`:

```dart
  _FakeShellClient({
    required this.status,
    Stream<FeishuMonitorShellEvent>? events,
  }) : events = events ?? const Stream<FeishuMonitorShellEvent>.empty();

  final Stream<FeishuMonitorShellEvent> events;
  int watchCount = 0;

  @override
  Stream<FeishuMonitorShellEvent> watchEvents() {
    watchCount += 1;
    return events;
  }
```

- [ ] **Step 2: Run runner tests and confirm failure**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test\modules\feishu_monitor\feishu_monitor_auto_forward_runner_test.dart
```

Expected: FAIL because `eventReconnectDelay` and event subscription behavior do not exist.

- [ ] **Step 3: Implement event-driven runner**

Modify `lib/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart`.

Add fields:

```dart
  final Duration _eventReconnectDelay;
  StreamSubscription<FeishuMonitorShellEvent>? _eventSubscription;
  Timer? _eventReconnectTimer;
```

Update constructor:

```dart
    Duration interval = const Duration(seconds: 3),
    Duration eventReconnectDelay = const Duration(seconds: 1),
```

and initializer:

```dart
       _interval = interval,
       _eventReconnectDelay = eventReconnectDelay;
```

Update `start()`:

```dart
  void start() {
    if (_timer != null) {
      return;
    }
    _subscribeToEvents();
    unawaited(runOnce());
    _timer = Timer.periodic(_interval, (_) {
      unawaited(runOnce());
    });
  }
```

Update `stop()`:

```dart
  void stop() {
    _timer?.cancel();
    _timer = null;
    _eventReconnectTimer?.cancel();
    _eventReconnectTimer = null;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
  }
```

Add:

```dart
  void _subscribeToEvents() {
    if (_eventSubscription != null) {
      return;
    }
    _eventSubscription = _client.watchEvents().listen(
      (event) {
        if (event.isSnapshotUpdated) {
          unawaited(runOnce());
        }
      },
      onError: (_) => _scheduleEventReconnect(),
      onDone: _scheduleEventReconnect,
      cancelOnError: true,
    );
  }

  void _scheduleEventReconnect() {
    _eventSubscription = null;
    if (_timer == null || _eventReconnectTimer != null) {
      return;
    }
    _eventReconnectTimer = Timer(_eventReconnectDelay, () {
      _eventReconnectTimer = null;
      if (_timer != null) {
        _subscribeToEvents();
      }
    });
  }
```

Make sure the file imports shell models if needed:

```dart
import 'feishu_monitor_shell_models.dart';
```

- [ ] **Step 4: Run runner tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test\modules\feishu_monitor\feishu_monitor_auto_forward_runner_test.dart
```

Expected: PASS.

---

### Task 5: Full Verification, Build, And Runtime Latency Report

**Files:**
- Modify: `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`

- [ ] **Step 1: Run all focused tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell
```

Expected: all shell package tests pass.

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
```

Expected: all shell app tests pass.

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test\modules\feishu_monitor\feishu_monitor_auto_forward_runner_test.dart test\modules\feishu_monitor\feishu_monitor_center_page_test.dart test\modules\feishu_monitor\feishu_monitor_forwarding_service_test.dart test\modules\feishu_monitor\feishu_monitor_shell_client_test.dart
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong
```

Expected: all Feishu monitor app tests pass.

- [ ] **Step 2: Run static analysis**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat analyze
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell
```

Expected: `No issues found`.

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat analyze
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
```

Expected: `No issues found`.

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat analyze lib\app\app.dart lib\modules\feishu_monitor test\modules\feishu_monitor
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong
```

Expected: `No issues found`.

- [ ] **Step 3: Build Windows debug apps**

Stop running debug processes if the build output is locked:

```powershell
Get-Process -Name 'InfoEquity','feishu_monitor_shell_app' -ErrorAction SilentlyContinue | Stop-Process
```

Build WuKongIM:

```powershell
D:\Apps\flutter\bin\flutter.bat build windows --debug
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong
```

Expected: `build\windows\x64\runner\Debug\InfoEquity.exe` is rebuilt.

Build Feishu WebShell:

```powershell
D:\Apps\flutter\bin\flutter.bat build windows --debug
```

Working directory:

```powershell
C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app
```

Expected: `build\windows\x64\runner\Debug\feishu_monitor_shell_app.exe` is rebuilt.

- [ ] **Step 4: Run manual latency test**

Start both apps:

```powershell
Start-Process -FilePath 'C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app\build\windows\x64\runner\Debug\feishu_monitor_shell_app.exe' -WindowStyle Hidden
Start-Process -FilePath 'C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Debug\InfoEquity.exe' -WindowStyle Hidden
```

Confirm shell health:

```powershell
$headers=@{Authorization='Bearer wukong-feishu-shell-dev'}
Invoke-RestMethod -Uri 'http://127.0.0.1:18766/status' -Headers $headers |
  Select-Object shell_state,capture_state,login_state,hook_state,page_kind,probe_observed_at,last_error
```

Expected:

```text
shell_state   online
capture_state running
login_state   logged_in
hook_state    healthy
page_kind     messenger
last_error    empty
```

Ask the user to send one fresh test message in each configured Feishu source group. Then query the active rebuilt desktop database:

```powershell
& sqlite3 'C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Debug\.dart_tool\sqflite_common_ffi\databases\wk_b0c09d2a42ba4bb8a573edb51a961e4e.db' "SELECT channel_id, message_seq, datetime(timestamp,'unixepoch','localtime'), content FROM message WHERE content LIKE '%飞书群：%' ORDER BY timestamp DESC, message_seq DESC LIMIT 10;"
```

Expected:

- Each new Feishu message appears once in its configured WuKongIM target group.
- No duplicate rows for the same source group, sender, and text.
- The shell `probe_observed_at` and database insertion time show low-second behavior after Feishu Web renders the feed-card update.

- [ ] **Step 5: Update the test report**

Append a short section to `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`:

```markdown
## Low-Latency WebShell Upgrade Test

Status: passed/blocked.

Changes verified:

- WebShell uses a page-side `MutationObserver` to trigger immediate probes.
- WebShell exposes authenticated `GET /events` SSE notifications.
- WuKongIM subscribes to shell events and still keeps a 3-second fallback poll.
- Persisted forwarding dedupe still prevents repeated feed-card observations from producing duplicate WuKongIM messages.

Runtime evidence:

- Shell status:
- Test messages:
- Database rows:
- Observed delay:
```

Replace `passed/blocked` and evidence bullets with actual runtime evidence from the manual test.

---

## Self-Review Checklist

- [ ] Spec requirement: normal-account only. Covered by WebShell `MutationObserver`, no bot dependency.
- [ ] Spec requirement: event-first observation. Covered by Task 2.
- [ ] Spec requirement: local push channel. Covered by Task 1 and Task 3.
- [ ] Spec requirement: event-driven WuKongIM runner with fallback. Covered by Task 4.
- [ ] Spec requirement: dedupe preserved. Covered by keeping existing forwarding service unchanged and verifying manual database rows in Task 5.
- [ ] Spec requirement: no millisecond-level promise. Covered by Task 5 report wording.
- [ ] Placeholder scan: no `TBD`, `TODO`, or unspecified implementation steps should remain.
