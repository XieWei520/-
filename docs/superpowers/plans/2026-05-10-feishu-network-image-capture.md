# Feishu Network Image Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a diagnostics-first WebView2 network capture path that can prove whether Feishu image resources are available before opening a specific Feishu conversation.

**Architecture:** Add a bounded network diagnostics layer inside `tools/feishu_monitor_shell_app`. Dart owns parsing, redaction, ring-buffer state, and shell snapshot integration; Windows native code owns the WebView2/CDP bridge. The first deliverable exposes diagnostics only and leaves production forwarding behavior unchanged.

**Tech Stack:** Flutter/Dart, Windows C++ Flutter plugin/runner code, Microsoft WebView2 `ICoreWebView2` DevTools Protocol APIs, existing `feishu_monitor_shell` models, Flutter tests.

---

## File Map

- Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`
  - Pure Dart models for network diagnostics events, image candidates, quality labels, and redacted status summaries.
- Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart`
  - Pure Dart parser that inspects redacted HTTP/WebSocket/CDP payload shapes and emits candidate image resources.
- Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`
  - Bounded in-memory ring buffer and diagnostics summary builder.
- Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart`
  - Dart `MethodChannel` wrapper for enabling/disabling native network capture and receiving network event callbacks.
- Modify `tools/feishu_monitor_shell_app/lib/main.dart`
  - Initialize diagnostics capture, merge network status into `probeDiagnostics`, and keep current DOM forwarding behavior unchanged.
- Create `tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart`
  - Parser and redaction tests.
- Create `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`
  - Ring-buffer and diagnostics summary tests.
- Create `tools/feishu_monitor_shell_app/test/feishu_network_capture_bridge_test.dart`
  - Dart-side bridge method-channel tests.
- Modify `tools/feishu_monitor_shell_app/windows/CMakeLists.txt`
  - Compile the native bridge files.
- Create `tools/feishu_monitor_shell_app/windows/runner/feishu_network_capture_bridge.h`
  - Native bridge declarations.
- Create `tools/feishu_monitor_shell_app/windows/runner/feishu_network_capture_bridge.cpp`
  - Native bridge implementation using WebView2 DevTools Protocol events where accessible.
- Modify `tools/feishu_monitor_shell_app/windows/runner/flutter_window.cpp`
  - Register the native bridge with the Flutter engine/window lifecycle.
- Modify `tools/feishu_monitor_shell_app/windows/runner/flutter_window.h`
  - Hold bridge lifetime if required by implementation.
- Modify `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`
  - Add the diagnostics test result after live testing.

## Task 1: Pure Dart Network Models

**Files:**
- Create: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart`

- [ ] **Step 1: Write model expectations in a failing test**

Add this test file with the first test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';

void main() {
  test('network event redacts sensitive query values', () {
    final event = FeishuNetworkCaptureEvent(
      id: 'evt_1',
      observedAt: DateTime.utc(2026, 5, 10, 6),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://internal-api.feishu.cn/messenger/resource?token=secret&file_key=image_1',
      method: 'GET',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview: '{"token":"secret","file_key":"image_1"}',
    );

    final json = event.toRedactedJson();

    expect(json['url'], 'https://internal-api.feishu.cn/messenger/resource?token=<redacted>&file_key=<redacted>');
    expect(json['payload_preview'], contains('<redacted>'));
    expect(json['payload_preview'], isNot(contains('secret')));
    expect(json['payload_preview'], isNot(contains('image_1')));
  });

  test('image candidate summary preserves quality label', () {
    final candidate = FeishuNetworkImageCandidate(
      conversationId: 'feed:2e500f14',
      conversationName: '满满正能量',
      messageId: 'msg_1',
      senderName: '橘生淮南',
      resourceUrl: 'https://internal-api.feishu.cn/image/abc',
      resourceKey: 'img_abc',
      width: 231,
      height: 500,
      quality: FeishuNetworkImageQuality.preview,
      observedAt: DateTime.utc(2026, 5, 10, 6),
    );

    expect(candidate.toStatusJson()['quality'], 'preview');
    expect(candidate.toStatusJson()['conversation_name'], '满满正能量');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```powershell
flutter test test/feishu_network_capture_parser_test.dart
```

Expected: fails because `feishu_network_capture.dart` does not exist.

- [ ] **Step 3: Implement the models**

Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`:

```dart
enum FeishuNetworkEventSource {
  httpResponse,
  webSocketFrame,
  imageRequest,
  unknown,
}

enum FeishuNetworkImageQuality {
  original,
  preview,
  thumbnail,
  unknown,
}

class FeishuNetworkCaptureEvent {
  FeishuNetworkCaptureEvent({
    required this.id,
    required this.observedAt,
    required this.source,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.mimeType,
    required this.payloadPreview,
  });

  final String id;
  final DateTime observedAt;
  final FeishuNetworkEventSource source;
  final String url;
  final String method;
  final int statusCode;
  final String mimeType;
  final String payloadPreview;

  Map<String, Object> toRedactedJson() {
    return <String, Object>{
      'id': id,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'source': source.name,
      'url': redactUrl(url),
      'method': method,
      'status_code': statusCode,
      'mime_type': mimeType,
      'payload_preview': redactPayload(payloadPreview),
    };
  }
}

class FeishuNetworkImageCandidate {
  FeishuNetworkImageCandidate({
    required this.conversationId,
    required this.conversationName,
    required this.messageId,
    required this.senderName,
    required this.resourceUrl,
    required this.resourceKey,
    required this.width,
    required this.height,
    required this.quality,
    required this.observedAt,
  });

  final String conversationId;
  final String conversationName;
  final String messageId;
  final String senderName;
  final String resourceUrl;
  final String resourceKey;
  final int width;
  final int height;
  final FeishuNetworkImageQuality quality;
  final DateTime observedAt;

  Map<String, Object> toStatusJson() {
    return <String, Object>{
      'conversation_id': conversationId,
      'conversation_name': conversationName,
      'message_id': messageId,
      'sender_name': senderName,
      'resource_url': redactUrl(resourceUrl),
      'resource_key': resourceKey.isEmpty ? '' : '<redacted>',
      'width': width,
      'height': height,
      'quality': quality.name,
      'observed_at': observedAt.toUtc().toIso8601String(),
    };
  }
}

String redactUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasQuery) {
    return value.trim();
  }
  final redacted = <String, String>{};
  for (final key in uri.queryParameters.keys) {
    redacted[key] = '<redacted>';
  }
  return uri.replace(queryParameters: redacted).toString();
}

String redactPayload(String value) {
  var redacted = value;
  final patterns = <RegExp>[
    RegExp(r'("token"\s*:\s*")[^"]+(")', caseSensitive: false),
    RegExp(r'("file_key"\s*:\s*")[^"]+(")', caseSensitive: false),
    RegExp(r'("image_key"\s*:\s*")[^"]+(")', caseSensitive: false),
    RegExp(r'("resource_key"\s*:\s*")[^"]+(")', caseSensitive: false),
  ];
  for (final pattern in patterns) {
    redacted = redacted.replaceAllMapped(
      pattern,
      (match) => '${match.group(1)}<redacted>${match.group(2)}',
    );
  }
  return redacted;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run:

```powershell
flutter test test/feishu_network_capture_parser_test.dart
```

Expected: all tests in the file pass.

## Task 2: Parser for Redacted Network Payloads

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart`
- Modify: `tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart`

- [ ] **Step 1: Add parser tests**

Append these tests to `feishu_network_capture_parser_test.dart`:

```dart
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_parser.dart';

test('parser extracts image candidate from json payload', () {
  final event = FeishuNetworkCaptureEvent(
    id: 'evt_json',
    observedAt: DateTime.utc(2026, 5, 10, 6, 1),
    source: FeishuNetworkEventSource.httpResponse,
    url: 'https://internal-api.feishu.cn/messenger/messages',
    method: 'POST',
    statusCode: 200,
    mimeType: 'application/json',
    payloadPreview: '''
      {
        "conversation_id": "feed:2e500f14",
        "conversation_name": "满满正能量",
        "message_id": "7638112798311976160",
        "sender_name": "橘生淮南",
        "image_key": "img_v3_abc",
        "image_url": "https://internal-api.feishu.cn/image/preview?token=secret",
        "width": 231,
        "height": 500
      }
    ''',
  );

  final candidates = parseFeishuNetworkImageCandidates(event);

  expect(candidates, hasLength(1));
  expect(candidates.single.conversationName, '满满正能量');
  expect(candidates.single.messageId, '7638112798311976160');
  expect(candidates.single.quality, FeishuNetworkImageQuality.preview);
});

test('parser ignores payload without image resource fields', () {
  final event = FeishuNetworkCaptureEvent(
    id: 'evt_text',
    observedAt: DateTime.utc(2026, 5, 10, 6, 2),
    source: FeishuNetworkEventSource.webSocketFrame,
    url: 'wss://internal-api.feishu.cn/push',
    method: 'WS',
    statusCode: 0,
    mimeType: 'application/octet-stream',
    payloadPreview: '{"conversation_name":"满满正能量","text":"hello"}',
  );

  expect(parseFeishuNetworkImageCandidates(event), isEmpty);
});
```

- [ ] **Step 2: Run the parser tests to verify failure**

Run:

```powershell
flutter test test/feishu_network_capture_parser_test.dart
```

Expected: fails because the parser file/function does not exist.

- [ ] **Step 3: Implement the parser**

Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart`:

```dart
import 'dart:convert';

import 'feishu_network_capture.dart';

List<FeishuNetworkImageCandidate> parseFeishuNetworkImageCandidates(
  FeishuNetworkCaptureEvent event,
) {
  final decoded = _tryDecodeJson(event.payloadPreview);
  if (decoded == null) {
    return const <FeishuNetworkImageCandidate>[];
  }
  final objects = <Map<String, dynamic>>[];
  _collectMaps(decoded, objects);
  return objects
      .map((item) => _candidateFromMap(item, event.observedAt))
      .whereType<FeishuNetworkImageCandidate>()
      .toList(growable: false);
}

Object? _tryDecodeJson(String payload) {
  try {
    return jsonDecode(payload);
  } catch (_) {
    return null;
  }
}

void _collectMaps(Object? value, List<Map<String, dynamic>> output) {
  if (value is Map) {
    final map = value.map((key, item) => MapEntry('$key', item));
    output.add(map);
    for (final child in map.values) {
      _collectMaps(child, output);
    }
  } else if (value is List) {
    for (final child in value) {
      _collectMaps(child, output);
    }
  }
}

FeishuNetworkImageCandidate? _candidateFromMap(
  Map<String, dynamic> map,
  DateTime observedAt,
) {
  final resourceKey = _firstString(map, const <String>[
    'image_key',
    'file_key',
    'resource_key',
    'origin_key',
  ]);
  final resourceUrl = _firstString(map, const <String>[
    'image_url',
    'origin_url',
    'preview_url',
    'download_url',
    'url',
  ]);
  if (resourceKey.isEmpty && resourceUrl.isEmpty) {
    return null;
  }
  final conversationId = _firstString(map, const <String>[
    'conversation_id',
    'chat_id',
    'channel_id',
  ]);
  final conversationName = _firstString(map, const <String>[
    'conversation_name',
    'chat_name',
    'title',
  ]);
  final messageId = _firstString(map, const <String>[
    'message_id',
    'msg_id',
    'id',
  ]);
  final senderName = _firstString(map, const <String>[
    'sender_name',
    'from_name',
    'name',
  ]);
  return FeishuNetworkImageCandidate(
    conversationId: conversationId,
    conversationName: conversationName,
    messageId: messageId,
    senderName: senderName,
    resourceUrl: resourceUrl,
    resourceKey: resourceKey,
    width: _firstInt(map, const <String>['width', 'w']),
    height: _firstInt(map, const <String>['height', 'h']),
    quality: _qualityForMap(map, resourceUrl),
    observedAt: observedAt,
  );
}

String _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
  }
  return '';
}

int _firstInt(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return 0;
}

FeishuNetworkImageQuality _qualityForMap(
  Map<String, dynamic> map,
  String resourceUrl,
) {
  final rawQuality = _firstString(map, const <String>[
    'quality',
    'image_quality',
    'type',
  ]).toLowerCase();
  final url = resourceUrl.toLowerCase();
  if (rawQuality.contains('origin') || url.contains('origin')) {
    return FeishuNetworkImageQuality.original;
  }
  if (rawQuality.contains('thumb') || url.contains('thumb')) {
    return FeishuNetworkImageQuality.thumbnail;
  }
  if (rawQuality.contains('preview') || url.contains('preview')) {
    return FeishuNetworkImageQuality.preview;
  }
  return FeishuNetworkImageQuality.unknown;
}
```

- [ ] **Step 4: Run parser tests**

Run:

```powershell
flutter test test/feishu_network_capture_parser_test.dart
```

Expected: all parser tests pass.

## Task 3: Diagnostics Store and Snapshot Summary

**Files:**
- Create: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`

- [ ] **Step 1: Write store tests**

Create `feishu_network_capture_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_store.dart';

void main() {
  test('store keeps bounded recent events and image candidates', () {
    final store = FeishuNetworkCaptureStore(maxEvents: 2, maxCandidates: 2);

    store.addEvent(FeishuNetworkCaptureEvent(
      id: 'evt_1',
      observedAt: DateTime.utc(2026, 5, 10, 6),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://a.test/one',
      method: 'GET',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview: '{}',
    ));
    store.addEvent(FeishuNetworkCaptureEvent(
      id: 'evt_2',
      observedAt: DateTime.utc(2026, 5, 10, 6, 1),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://a.test/two',
      method: 'GET',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview: '{}',
    ));
    store.addEvent(FeishuNetworkCaptureEvent(
      id: 'evt_3',
      observedAt: DateTime.utc(2026, 5, 10, 6, 2),
      source: FeishuNetworkEventSource.webSocketFrame,
      url: 'wss://a.test/push',
      method: 'WS',
      statusCode: 0,
      mimeType: 'application/octet-stream',
      payloadPreview: '{}',
    ));

    store.addCandidate(FeishuNetworkImageCandidate(
      conversationId: 'feed:2e500f14',
      conversationName: '满满正能量',
      messageId: 'msg_1',
      senderName: '橘生淮南',
      resourceUrl: 'https://a.test/image?token=secret',
      resourceKey: 'img_1',
      width: 231,
      height: 500,
      quality: FeishuNetworkImageQuality.preview,
      observedAt: DateTime.utc(2026, 5, 10, 6, 3),
    ));

    final summary = store.toDiagnosticsJson();

    expect(summary['network_capture_state'], 'running');
    expect(summary['network_event_count'], 3);
    expect(summary['network_recent_events'], hasLength(2));
    expect(summary['network_image_candidate_count'], 1);
    expect(summary['network_last_image_candidate'], isA<Map<String, Object>>());
  });
}
```

- [ ] **Step 2: Run store tests to verify failure**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: fails because the store file does not exist.

- [ ] **Step 3: Implement store**

Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`:

```dart
import 'feishu_network_capture.dart';

class FeishuNetworkCaptureStore {
  FeishuNetworkCaptureStore({
    this.maxEvents = 50,
    this.maxCandidates = 20,
  });

  final int maxEvents;
  final int maxCandidates;
  final List<FeishuNetworkCaptureEvent> _events = <FeishuNetworkCaptureEvent>[];
  final List<FeishuNetworkImageCandidate> _candidates =
      <FeishuNetworkImageCandidate>[];
  String _state = 'running';
  String _lastError = '';

  void setUnavailable(String error) {
    _state = 'unavailable';
    _lastError = error;
  }

  void addEvent(FeishuNetworkCaptureEvent event) {
    _events.add(event);
    _trim(_events, maxEvents);
  }

  void addCandidate(FeishuNetworkImageCandidate candidate) {
    _candidates.add(candidate);
    _trim(_candidates, maxCandidates);
  }

  Map<String, Object?> toDiagnosticsJson() {
    return <String, Object?>{
      'network_capture_state': _state,
      'network_event_count': _events.length,
      'network_image_candidate_count': _candidates.length,
      'network_last_image_candidate': _candidates.isEmpty
          ? null
          : _candidates.last.toStatusJson(),
      'network_recent_events': _events
          .map((event) => event.toRedactedJson())
          .toList(growable: false),
      'network_last_error': _lastError,
    };
  }
}

void _trim<T>(List<T> items, int maxItems) {
  while (items.length > maxItems) {
    items.removeAt(0);
  }
}
```

- [ ] **Step 4: Run store tests**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: all store tests pass.

## Task 4: Dart MethodChannel Bridge

**Files:**
- Create: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_bridge_test.dart`

- [ ] **Step 1: Write bridge tests**

Create `feishu_network_capture_bridge_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bridge starts native capture and emits parsed events', () async {
    final calls = <MethodCall>[];
    final bridge = FeishuNetworkCaptureBridge();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      bridge.channel,
      (call) async {
        calls.add(call);
        if (call.method == 'start') {
          return <String, Object>{'state': 'running'};
        }
        return null;
      },
    );

    final received = <FeishuNetworkCaptureEvent>[];
    final sub = bridge.events.listen(received.add);

    await bridge.start();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      bridge.channel.name,
      bridge.channel.codec.encodeMethodCall(MethodCall('networkEvent', <String, Object>{
        'id': 'evt_1',
        'observed_at': '2026-05-10T06:00:00Z',
        'source': 'httpResponse',
        'url': 'https://a.test/messages',
        'method': 'GET',
        'status_code': 200,
        'mime_type': 'application/json',
        'payload_preview': '{}',
      })),
      (_) {},
    );

    await Future<void>.delayed(Duration.zero);

    expect(calls.single.method, 'start');
    expect(received.single.id, 'evt_1');
    expect(received.single.source, FeishuNetworkEventSource.httpResponse);

    await sub.cancel();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge.channel, null);
  });
}
```

- [ ] **Step 2: Run bridge test to verify failure**

Run:

```powershell
flutter test test/feishu_network_capture_bridge_test.dart
```

Expected: fails because the bridge file does not exist.

- [ ] **Step 3: Implement Dart bridge**

Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart`:

```dart
import 'dart:async';

import 'package:flutter/services.dart';

import 'feishu_network_capture.dart';

class FeishuNetworkCaptureBridge {
  FeishuNetworkCaptureBridge({
    MethodChannel? channel,
  }) : channel = channel ?? const MethodChannel('wukong/feishu_network_capture') {
    this.channel.setMethodCallHandler(_handleMethodCall);
  }

  final MethodChannel channel;
  final StreamController<FeishuNetworkCaptureEvent> _events =
      StreamController<FeishuNetworkCaptureEvent>.broadcast();

  Stream<FeishuNetworkCaptureEvent> get events => _events.stream;

  Future<void> start() async {
    await channel.invokeMethod<Object?>('start');
  }

  Future<void> stop() async {
    await channel.invokeMethod<Object?>('stop');
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    channel.setMethodCallHandler(null);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'networkEvent') {
      return;
    }
    final args = Map<String, Object?>.from(call.arguments as Map);
    _events.add(_eventFromJson(args));
  }
}

FeishuNetworkCaptureEvent _eventFromJson(Map<String, Object?> json) {
  return FeishuNetworkCaptureEvent(
    id: '${json['id'] ?? ''}',
    observedAt:
        DateTime.tryParse('${json['observed_at'] ?? ''}')?.toUtc() ??
        DateTime.now().toUtc(),
    source: _sourceFromString('${json['source'] ?? ''}'),
    url: '${json['url'] ?? ''}',
    method: '${json['method'] ?? ''}',
    statusCode: json['status_code'] is num
        ? (json['status_code'] as num).round()
        : int.tryParse('${json['status_code'] ?? ''}') ?? 0,
    mimeType: '${json['mime_type'] ?? ''}',
    payloadPreview: '${json['payload_preview'] ?? ''}',
  );
}

FeishuNetworkEventSource _sourceFromString(String value) {
  for (final source in FeishuNetworkEventSource.values) {
    if (source.name == value) {
      return source;
    }
  }
  return FeishuNetworkEventSource.unknown;
}
```

- [ ] **Step 4: Run bridge test**

Run:

```powershell
flutter test test/feishu_network_capture_bridge_test.dart
```

Expected: bridge test passes.

## Task 5: Integrate Diagnostics Into Shell Snapshot

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Test: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`

- [ ] **Step 1: Add an integration expectation**

Add a test to `feishu_network_capture_store_test.dart`:

```dart
test('diagnostics summary can be merged into probe diagnostics', () {
  final store = FeishuNetworkCaptureStore();
  store.addCandidate(FeishuNetworkImageCandidate(
    conversationId: 'feed:2e500f14',
    conversationName: '满满正能量',
    messageId: 'msg_1',
    senderName: '橘生淮南',
    resourceUrl: 'https://a.test/image?token=secret',
    resourceKey: 'img_1',
    width: 231,
    height: 500,
    quality: FeishuNetworkImageQuality.preview,
    observedAt: DateTime.utc(2026, 5, 10, 6),
  ));

  final diagnostics = <String, Object?>{
    'existing': 'value',
    ...store.toDiagnosticsJson(),
  };

  expect(diagnostics['existing'], 'value');
  expect(diagnostics['network_capture_state'], 'running');
  expect(diagnostics['network_image_candidate_count'], 1);
});
```

- [ ] **Step 2: Run tests**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart test/runtime_snapshot_mapper_test.dart
```

Expected: store tests pass; runtime tests remain unchanged.

- [ ] **Step 3: Wire bridge and store into `main.dart`**

In `_FeishuMonitorShellAppState`, add fields:

```dart
late final FeishuNetworkCaptureBridge _networkCaptureBridge;
late final FeishuNetworkCaptureStore _networkCaptureStore;
StreamSubscription<FeishuNetworkCaptureEvent>? _networkCaptureSubscription;
```

In `initState`, initialize:

```dart
_networkCaptureBridge = FeishuNetworkCaptureBridge();
_networkCaptureStore = FeishuNetworkCaptureStore();
_networkCaptureSubscription = _networkCaptureBridge.events.listen(
  _handleNetworkCaptureEvent,
);
unawaited(_networkCaptureBridge.start().catchError((Object error) {
  _networkCaptureStore.setUnavailable('$error');
}));
```

Add handler:

```dart
void _handleNetworkCaptureEvent(FeishuNetworkCaptureEvent event) {
  _networkCaptureStore.addEvent(event);
  for (final candidate in parseFeishuNetworkImageCandidates(event)) {
    _networkCaptureStore.addCandidate(candidate);
  }
  _probeScheduler.request('network_capture');
}
```

In `dispose`, cancel and dispose:

```dart
unawaited(_networkCaptureSubscription?.cancel());
unawaited(_networkCaptureBridge.dispose());
```

In `_snapshotFromProbe`, merge diagnostics:

```dart
'network_capture': _networkCaptureStore.toDiagnosticsJson(),
```

If current diagnostics are flat rather than nested, use:

```dart
..._networkCaptureStore.toDiagnosticsJson(),
```

Keep all existing DOM probe and feed-opening logic unchanged.

- [ ] **Step 4: Run focused tests**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart test/feishu_network_capture_bridge_test.dart test/runtime_snapshot_mapper_test.dart
```

Expected: all listed tests pass.

## Task 6: Native WebView2/CDP Bridge

**Files:**
- Create: `tools/feishu_monitor_shell_app/windows/runner/feishu_network_capture_bridge.h`
- Create: `tools/feishu_monitor_shell_app/windows/runner/feishu_network_capture_bridge.cpp`
- Modify: `tools/feishu_monitor_shell_app/windows/CMakeLists.txt`
- Modify: `tools/feishu_monitor_shell_app/windows/runner/flutter_window.cpp`
- Modify: `tools/feishu_monitor_shell_app/windows/runner/flutter_window.h`

- [ ] **Step 1: Add bridge skeleton and compile it**

Create `feishu_network_capture_bridge.h`:

```cpp
#pragma once

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

class FeishuNetworkCaptureBridge {
 public:
  explicit FeishuNetworkCaptureBridge(flutter::BinaryMessenger* messenger);
  ~FeishuNetworkCaptureBridge();

  FeishuNetworkCaptureBridge(const FeishuNetworkCaptureBridge&) = delete;
  FeishuNetworkCaptureBridge& operator=(const FeishuNetworkCaptureBridge&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  bool running_ = false;
};
```

Create `feishu_network_capture_bridge.cpp`:

```cpp
#include "feishu_network_capture_bridge.h"

#include <flutter/encodable_value.h>

FeishuNetworkCaptureBridge::FeishuNetworkCaptureBridge(
    flutter::BinaryMessenger* messenger) {
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "wukong/feishu_network_capture",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });
}

FeishuNetworkCaptureBridge::~FeishuNetworkCaptureBridge() {
  if (channel_) {
    channel_->SetMethodCallHandler(nullptr);
  }
}

void FeishuNetworkCaptureBridge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "start") {
    running_ = true;
    result->Success(flutter::EncodableMap{
        {flutter::EncodableValue("state"), flutter::EncodableValue("running")},
    });
    return;
  }
  if (call.method_name() == "stop") {
    running_ = false;
    result->Success(flutter::EncodableMap{
        {flutter::EncodableValue("state"), flutter::EncodableValue("stopped")},
    });
    return;
  }
  result->NotImplemented();
}
```

Modify `windows/CMakeLists.txt` so the runner includes:

```cmake
"runner/feishu_network_capture_bridge.cpp"
```

Modify `flutter_window.h` to include and own the bridge:

```cpp
#include "feishu_network_capture_bridge.h"
```

and add:

```cpp
std::unique_ptr<FeishuNetworkCaptureBridge> feishu_network_capture_bridge_;
```

Modify `flutter_window.cpp` after `RegisterPlugins(flutter_controller_->engine());`:

```cpp
feishu_network_capture_bridge_ =
    std::make_unique<FeishuNetworkCaptureBridge>(
        flutter_controller_->engine()->messenger());
```

- [ ] **Step 2: Build Windows shell to verify skeleton**

Run:

```powershell
flutter build windows --debug
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

Expected: build succeeds.

- [ ] **Step 3: Extend native bridge to obtain WebView2 CDP access**

Inspect the `webview_windows` plugin native implementation under:

```text
tools\feishu_monitor_shell_app\windows\flutter\ephemeral\.plugin_symlinks\webview_windows\windows\
```

Use the smallest viable path:

- If the plugin exposes `ICoreWebView2` or a host accessor, call it directly.
- If it does not, add a narrow patch/fork to the plugin wrapper used by this app that emits CDP events through the same `wukong/feishu_network_capture` channel.

The CDP setup should call:

```text
Network.enable
```

and subscribe to:

```text
Network.responseReceived
Network.loadingFinished
Network.webSocketFrameReceived
```

For HTTP responses, capture only:

- request id
- URL
- method if available
- status
- MIME type
- a bounded response preview from `Network.getResponseBody` when MIME type looks like JSON/text or URL/path suggests messenger resources

For WebSocket frames, capture only:

- URL/request id when available
- opcode/type if available
- payload preview, bounded to 16 KB

- [ ] **Step 4: Build Windows shell after CDP extension**

Run:

```powershell
flutter build windows --debug
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

Expected: build succeeds. If CDP access cannot be reached through the current plugin, stop and document the exact blocker in the plan before trying a larger plugin fork.

## Task 7: Diagnostics File Output

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`

- [ ] **Step 1: Add diagnostics file test**

Append:

```dart
test('store writes redacted diagnostics lines', () async {
  final dir = await Directory.systemTemp.createTemp('feishu_network_capture_test_');
  addTearDown(() async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  });
  final file = File('${dir.path}/network.jsonl');
  final store = FeishuNetworkCaptureStore(diagnosticsFile: file);

  store.addEvent(FeishuNetworkCaptureEvent(
    id: 'evt_1',
    observedAt: DateTime.utc(2026, 5, 10, 6),
    source: FeishuNetworkEventSource.httpResponse,
    url: 'https://a.test/image?token=secret',
    method: 'GET',
    statusCode: 200,
    mimeType: 'application/json',
    payloadPreview: '{"token":"secret"}',
  ));

  final text = await file.readAsString();
  expect(text, contains('<redacted>'));
  expect(text, isNot(contains('secret')));
});
```

Also add imports:

```dart
import 'dart:io';
```

- [ ] **Step 2: Run test to verify failure**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: fails because `diagnosticsFile` is not supported yet.

- [ ] **Step 3: Implement JSONL diagnostics output**

Modify store constructor:

```dart
FeishuNetworkCaptureStore({
  this.maxEvents = 50,
  this.maxCandidates = 20,
  this.diagnosticsFile,
});

final File? diagnosticsFile;
```

Import:

```dart
import 'dart:convert';
import 'dart:io';
```

At the end of `addEvent`, append:

```dart
_appendDiagnosticsLine(event.toRedactedJson());
```

Add:

```dart
void _appendDiagnosticsLine(Map<String, Object> json) {
  final file = diagnosticsFile;
  if (file == null) {
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('${jsonEncode(json)}\n', mode: FileMode.append);
}
```

- [ ] **Step 4: Run store tests**

Run:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: all store tests pass.

## Task 8: End-to-End Verification and Report Update

**Files:**
- Modify: `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md`

- [ ] **Step 1: Run focused shell tests**

Run:

```powershell
flutter test test/feishu_network_capture_parser_test.dart test/feishu_network_capture_store_test.dart test/feishu_network_capture_bridge_test.dart test/runtime_snapshot_mapper_test.dart
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

Expected: all focused tests pass.

- [ ] **Step 2: Run shell analyze**

Run:

```powershell
flutter analyze lib test
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

Expected: no issues found.

- [ ] **Step 3: Build shell app**

Stop any running shell process first:

```powershell
Get-Process feishu_monitor_shell_app -ErrorAction SilentlyContinue | Stop-Process -Force
```

Then run:

```powershell
flutter build windows --debug
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

Expected: `build\windows\x64\runner\Debug\feishu_monitor_shell_app.exe` builds successfully.

- [ ] **Step 4: Manual diagnostics test with user**

Start the rebuilt shell app:

```powershell
Start-Process -FilePath 'C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app\build\windows\x64\runner\Debug\feishu_monitor_shell_app.exe' -WorkingDirectory 'C:\Users\COLORFUL\Desktop\WuKong\tools\feishu_monitor_shell_app\build\windows\x64\runner\Debug' -WindowStyle Hidden
```

Check status:

```powershell
$h=@{Authorization='Bearer wukong-feishu-shell-dev'}
Invoke-RestMethod -Uri 'http://127.0.0.1:18766/status' -Headers $h | ConvertTo-Json -Depth 10
```

Ask the user to stay on the Feishu message list page, send a new image to `满满正能量`, and not click/open that Feishu conversation.

Expected status evidence:

- `network_capture_state` is `running`, or `unavailable` with a specific native bridge error.
- `network_event_count` increases after the user sends an image.
- If Feishu exposes usable resources, `network_image_candidate_count` increases and `network_last_image_candidate.conversation_name` is `满满正能量`.
- If no candidate appears, the report says the no-open original-image path is not proven.

- [ ] **Step 5: Update the report**

Append a section named `Network Image Capture Diagnostics` to:

```text
docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md
```

Include:

- build/test commands and results
- whether CDP bridge was available
- whether network events were observed
- whether image candidates appeared without opening the conversation
- quality label if an image was found
- next decision: proceed to production network forwarding or keep DOM fallback

## Final Verification

Run all of these before claiming completion:

```powershell
flutter test test/feishu_network_capture_parser_test.dart test/feishu_network_capture_store_test.dart test/feishu_network_capture_bridge_test.dart test/runtime_snapshot_mapper_test.dart
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

```powershell
flutter analyze lib test
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

```powershell
flutter build windows --debug
```

Working directory:

```powershell
tools\feishu_monitor_shell_app
```

The manual diagnostics test is required before deciding whether no-open image forwarding is feasible.
