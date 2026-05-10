# Feishu Network Original Image Forwarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Forward Feishu image messages to WuKongIM from WebView2 network-captured original image files, without opening source conversations and without DOM fallback media.

**Architecture:** The native WebView2 plugin saves eligible image response bodies to a local cache and emits body metadata to Dart. The shell app parses saved image candidates, resolves them against high-confidence feed-card attribution and recent feed image placeholders, then exposes `network_original_image` events. The WuKongIM forwarding service accepts only routed, unambiguous local-file image events and continues rejecting DOM media.

**Tech Stack:** Flutter/Dart, WebView2 CDP, Windows C++20 plugin, MethodChannel, WuKongIM Flutter SDK image upload.

---

## File Structure

- Modify `tools/vendor/webview_windows_wukong/windows/webview.h`: extend `WebviewNetworkEvent` with saved body metadata.
- Modify `tools/vendor/webview_windows_wukong/windows/webview.cc`: decode `Network.getResponseBody`, save eligible Feishu image bodies, hash bytes, and clean old cache files.
- Modify `tools/vendor/webview_windows_wukong/windows/webview_windows_plugin.cc`: emit saved body metadata through MethodChannel.
- Modify `tools/vendor/webview_windows_wukong/windows/CMakeLists.txt`: link Windows crypto support used by SHA-1 hashing.
- Modify `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`: add Dart network event and image candidate body metadata.
- Modify `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart`: parse body metadata from native MethodChannel maps.
- Modify `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart`: require saved local body for direct image response candidates.
- Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_forwardable_image_resolver.dart`: strict resolver for candidate + attribution + feed-card placeholder.
- Modify `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`: store resolver diagnostics and expose forwardable image events.
- Modify `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`: merge network image events into shell snapshots.
- Modify `tools/feishu_monitor_shell_app/lib/main.dart`: call the resolver during probe refresh and publish updated snapshots.
- Modify `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`: reject ambiguous route matches and explicitly cover `network_original_image`.
- Tests:
  - `tools/feishu_monitor_shell_app/test/feishu_network_capture_bridge_test.dart`
  - `tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart`
  - `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`
  - Create `tools/feishu_monitor_shell_app/test/feishu_network_forwardable_image_resolver_test.dart`
  - `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`
  - `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

## Task 1: Dart Network Body Metadata

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_bridge_test.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart`

- [ ] **Step 1: Write the failing bridge metadata test**

Add this test to `tools/feishu_monitor_shell_app/test/feishu_network_capture_bridge_test.dart`:

```dart
test('bridge parses saved response body metadata', () async {
  final bridge = FeishuNetworkCaptureBridge();
  StreamSubscription<FeishuNetworkCaptureEvent>? subscription;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(bridge.channel, (call) async {
        if (call.method == 'stop') {
          return <String, Object>{'state': 'stopped'};
        }
        return null;
      });
  addTearDown(() async {
    await subscription?.cancel();
    await bridge.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(bridge.channel, null);
  });

  final received = <FeishuNetworkCaptureEvent>[];
  subscription = bridge.events.listen(received.add);

  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        bridge.channel.name,
        bridge.channel.codec.encodeMethodCall(
          const MethodCall('networkEvent', <String, Object>{
            'id': 'evt_image',
            'observed_at': '2026-05-10T06:00:00Z',
            'source': 'httpResponse',
            'url': 'https://internal-api-lark-file.feishu.cn/static-resource/v1/image.webp?token=secret',
            'method': 'GET',
            'status_code': 200,
            'mime_type': 'image/webp',
            'payload_preview': '',
            'body_local_path': r'C:\Users\COLORFUL\AppData\Local\Temp\wukong_feishu_monitor_images\abc.webp',
            'body_sha1': 'abc123',
            'body_size': 12345,
            'body_mime_type': 'image/webp',
            'body_base64_encoded': true,
            'body_saved': true,
            'body_save_error': '',
          }),
        ),
        (_) {},
      );
  await Future<void>.delayed(Duration.zero);

  expect(received, hasLength(1));
  expect(received.single.bodyLocalPath, endsWith('abc.webp'));
  expect(received.single.bodySha1, 'abc123');
  expect(received.single.bodySize, 12345);
  expect(received.single.bodyMimeType, 'image/webp');
  expect(received.single.bodyBase64Encoded, isTrue);
  expect(received.single.bodySaved, isTrue);
  expect(received.single.bodySaveError, isEmpty);
});
```

- [ ] **Step 2: Run the bridge test to verify it fails**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_bridge_test.dart
```

Expected: fail with missing `bodyLocalPath`, `bodySha1`, `bodySize`, `bodyMimeType`, `bodyBase64Encoded`, `bodySaved`, and `bodySaveError` getters.

- [ ] **Step 3: Add metadata fields to `FeishuNetworkCaptureEvent`**

Update the constructor and class in `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`:

```dart
class FeishuNetworkCaptureEvent {
  const FeishuNetworkCaptureEvent({
    required this.id,
    required this.observedAt,
    required this.source,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.mimeType,
    required this.payloadPreview,
    this.bodyLocalPath = '',
    this.bodySha1 = '',
    this.bodySize = 0,
    this.bodyMimeType = '',
    this.bodyBase64Encoded = false,
    this.bodySaved = false,
    this.bodySaveError = '',
  });

  final String id;
  final DateTime observedAt;
  final FeishuNetworkEventSource source;
  final String url;
  final String method;
  final int statusCode;
  final String mimeType;
  final String payloadPreview;
  final String bodyLocalPath;
  final String bodySha1;
  final int bodySize;
  final String bodyMimeType;
  final bool bodyBase64Encoded;
  final bool bodySaved;
  final String bodySaveError;
}
```

Also add redacted diagnostics fields in `toRedactedJson()`:

```dart
'body_local_path': bodyLocalPath.trim().isEmpty ? '' : '<local-cache-file>',
'body_sha1': bodySha1,
'body_size': bodySize,
'body_mime_type': bodyMimeType,
'body_base64_encoded': bodyBase64Encoded,
'body_saved': bodySaved,
'body_save_error': bodySaveError,
```

- [ ] **Step 4: Parse metadata in the MethodChannel bridge**

Update `_eventFromMap` in `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart`:

```dart
return FeishuNetworkCaptureEvent(
  id: _stringValue(map['id']),
  observedAt: _observedAt(map['observed_at']),
  source: _sourceFromString(_stringValue(map['source'])),
  url: _stringValue(map['url']),
  method: _stringValue(map['method']),
  statusCode: _statusCode(map['status_code']),
  mimeType: _stringValue(map['mime_type']),
  payloadPreview: _stringValue(map['payload_preview']),
  bodyLocalPath: _stringValue(map['body_local_path']),
  bodySha1: _stringValue(map['body_sha1']),
  bodySize: _statusCode(map['body_size']),
  bodyMimeType: _stringValue(map['body_mime_type']),
  bodyBase64Encoded: _boolValue(map['body_base64_encoded']),
  bodySaved: _boolValue(map['body_saved']),
  bodySaveError: _stringValue(map['body_save_error']),
);
```

Add the helper:

```dart
bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  final normalized = _stringValue(value).trim().toLowerCase();
  return normalized == 'true' || normalized == '1';
}
```

- [ ] **Step 5: Run the bridge test to verify it passes**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_bridge_test.dart
```

Expected: all tests in the file pass.

- [ ] **Step 6: Commit Task 1**

```powershell
git add -- tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_bridge.dart tools/feishu_monitor_shell_app/test/feishu_network_capture_bridge_test.dart
git commit -m "feat: carry feishu network body metadata"
```

## Task 2: Saved-Body Image Candidate Parsing

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart`

- [ ] **Step 1: Write failing parser tests for saved local bodies**

Replace the existing direct-image parser expectation with two tests in `tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart`:

```dart
test('parser ignores direct image responses without saved local body', () {
  final event = FeishuNetworkCaptureEvent(
    id: 'evt_image_response',
    observedAt: DateTime.utc(2026, 5, 10, 6, 2),
    source: FeishuNetworkEventSource.httpResponse,
    url: 'https://internal-api-lark-file.feishu.cn/static-resource/v1/abc.webp?token=secret',
    method: 'GET',
    statusCode: 200,
    mimeType: 'image/webp',
    payloadPreview: '',
  );

  expect(parseFeishuNetworkImageCandidates(event), isEmpty);
});

test('parser records saved direct image responses as candidates', () {
  final event = FeishuNetworkCaptureEvent(
    id: 'evt_image_response',
    observedAt: DateTime.utc(2026, 5, 10, 6, 2),
    source: FeishuNetworkEventSource.httpResponse,
    url: 'https://internal-api-lark-file.feishu.cn/static-resource/v1/abc.webp?token=secret',
    method: 'GET',
    statusCode: 200,
    mimeType: 'image/webp',
    payloadPreview: '',
    bodyLocalPath: r'C:\tmp\abc.webp',
    bodySha1: 'sha1abc',
    bodySize: 12345,
    bodyMimeType: 'image/webp',
    bodyBase64Encoded: true,
    bodySaved: true,
  );

  final candidates = parseFeishuNetworkImageCandidates(event);

  expect(candidates, hasLength(1));
  expect(candidates.single.resourceUrl, event.url);
  expect(candidates.single.messageId, event.id);
  expect(candidates.single.localPath, r'C:\tmp\abc.webp');
  expect(candidates.single.bodySha1, 'sha1abc');
  expect(candidates.single.bodySize, 12345);
  expect(candidates.single.bodyMimeType, 'image/webp');
});
```

- [ ] **Step 2: Run the parser test to verify it fails**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_parser_test.dart
```

Expected: fail because `FeishuNetworkImageCandidate` has no body metadata and direct image responses are still accepted without saved files.

- [ ] **Step 3: Add candidate body metadata**

Update `FeishuNetworkImageCandidate` in `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart`:

```dart
class FeishuNetworkImageCandidate {
  const FeishuNetworkImageCandidate({
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
    this.localPath = '',
    this.bodySha1 = '',
    this.bodySize = 0,
    this.bodyMimeType = '',
  });

  final String localPath;
  final String bodySha1;
  final int bodySize;
  final String bodyMimeType;
}
```

Add these keys to `toStatusJson()`:

```dart
'local_path': localPath.trim().isEmpty ? '' : '<local-cache-file>',
'body_sha1': bodySha1,
'body_size': bodySize,
'body_mime_type': bodyMimeType,
```

- [ ] **Step 4: Require saved body metadata for direct image candidates**

Update `_candidateFromDirectImageResponse` in `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart`:

```dart
if (!event.bodySaved ||
    event.bodyLocalPath.trim().isEmpty ||
    event.bodySha1.trim().isEmpty ||
    event.bodySize <= 0) {
  return null;
}
return FeishuNetworkImageCandidate(
  conversationId: '',
  conversationName: '',
  messageId: event.id,
  senderName: '',
  resourceUrl: url,
  resourceKey: '',
  width: 0,
  height: 0,
  quality: FeishuNetworkImageQuality.unknown,
  observedAt: event.observedAt,
  localPath: event.bodyLocalPath.trim(),
  bodySha1: event.bodySha1.trim(),
  bodySize: event.bodySize,
  bodyMimeType: event.bodyMimeType.trim().isEmpty
      ? event.mimeType
      : event.bodyMimeType.trim(),
);
```

- [ ] **Step 5: Run the parser test to verify it passes**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_parser_test.dart
```

Expected: all parser tests pass.

- [ ] **Step 6: Commit Task 2**

```powershell
git add -- tools/feishu_monitor_shell_app/lib/src/feishu_network_capture.dart tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_parser.dart tools/feishu_monitor_shell_app/test/feishu_network_capture_parser_test.dart
git commit -m "feat: require saved feishu image bodies"
```

## Task 3: Strict Forwardable Image Resolver

**Files:**
- Create: `tools/feishu_monitor_shell_app/lib/src/feishu_network_forwardable_image_resolver.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_forwardable_image_resolver_test.dart`

- [ ] **Step 1: Write failing resolver tests**

Create `tools/feishu_monitor_shell_app/test/feishu_network_forwardable_image_resolver_test.dart`:

```dart
import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_forwardable_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolver creates network_original_image event for one strict match', () {
    final resolver = FeishuNetworkForwardableImageResolver(
      fileExists: (path) => path == r'C:\tmp\alpha.webp',
    );

    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedImageEvent()],
    );

    expect(result.events, hasLength(1));
    expect(result.skipReason, isEmpty);
    expect(result.events.single.captureSource, 'network_original_image');
    expect(result.events.single.conversationId, 'feed:alpha');
    expect(result.events.single.conversationName, 'Alpha Group');
    expect(result.events.single.messageType, 'image');
    expect(result.events.single.imageAttachments.single.localPath, r'C:\tmp\alpha.webp');
    expect(result.events.single.imageAttachments.single.sourceUrl, _imageUrl);
    expect(result.events.single.dedupeKey, 'feed:alpha:network_image:sha1alpha');
  });

  test('resolver rejects candidate without local body', () {
    final resolver = FeishuNetworkForwardableImageResolver(fileExists: (_) => true);
    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(localPath: '', bodySha1: '', bodySize: 0),
      ],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedImageEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'missing_local_body');
  });

  test('resolver rejects missing local file', () {
    final resolver = FeishuNetworkForwardableImageResolver(fileExists: (_) => false);
    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedImageEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'body_file_missing');
  });

  test('resolver rejects medium confidence attribution', () {
    final resolver = FeishuNetworkForwardableImageResolver(fileExists: (_) => true);
    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(confidence: 0.72, confidenceLabel: 'medium'),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedImageEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'attribution_not_high_confidence');
  });

  test('resolver rejects attribution without feed-card evidence', () {
    final resolver = FeishuNetworkForwardableImageResolver(fileExists: (_) => true);
    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(evidence: const <String>['active_feed_context']),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedImageEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'attribution_not_high_confidence');
  });

  test('resolver rejects when feed image placeholder is missing', () {
    final resolver = FeishuNetworkForwardableImageResolver(fileExists: (_) => true);
    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[
        _feedImageEvent(text: 'plain text', messageType: 'text'),
      ],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'feed_placeholder_missing');
  });

  test('resolver rejects ambiguous candidates', () {
    final resolver = FeishuNetworkForwardableImageResolver(fileExists: (_) => true);
    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(),
        _candidate(messageId: 'evt_image_2', bodySha1: 'sha1beta'),
      ],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedImageEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'ambiguous_candidates');
  });

  test('resolver rejects ambiguous feed image events', () {
    final resolver = FeishuNetworkForwardableImageResolver(fileExists: (_) => true);
    final result = resolver.resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[
        _feedImageEvent(messageId: 'feed:image_1'),
        _feedImageEvent(messageId: 'feed:image_2'),
      ],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'ambiguous_feed_events');
  });
}

const _imageUrl =
    'https://internal-api-lark-file.feishu.cn/static-resource/v1/alpha.webp?token=secret';

FeishuNetworkImageCandidate _candidate({
  String messageId = 'evt_image',
  String localPath = r'C:\tmp\alpha.webp',
  String bodySha1 = 'sha1alpha',
  int bodySize = 12345,
}) {
  return FeishuNetworkImageCandidate(
    conversationId: '',
    conversationName: '',
    messageId: messageId,
    senderName: '',
    resourceUrl: _imageUrl,
    resourceKey: '',
    width: 0,
    height: 0,
    quality: FeishuNetworkImageQuality.unknown,
    observedAt: DateTime.utc(2026, 5, 10, 6, 0, 1),
    localPath: localPath,
    bodySha1: bodySha1,
    bodySize: bodySize,
    bodyMimeType: 'image/webp',
  );
}

FeishuNetworkImageAttribution _attribution({
  double confidence = 0.92,
  String confidenceLabel = 'high',
  List<String> evidence = const <String>['exact_dom_node', 'feed_card_context'],
}) {
  return FeishuNetworkImageAttribution(
    sourceUrl: _imageUrl,
    sourceKind: 'http',
    blobMimeType: 'image/webp',
    blobSize: 12345,
    conversationId: 'feed:alpha',
    conversationName: 'Alpha Group',
    messageId: 'feed:image_1',
    senderName: 'Alice',
    displayTime: '14:29',
    messageText: '[Image]',
    feedCardId: 'feed:image_1',
    feedCardText: 'Alpha Group 14:29 Alice: [Image]',
    confidence: confidence,
    confidenceLabel: confidenceLabel,
    reason: 'dom_img_src',
    observedAt: DateTime.utc(2026, 5, 10, 6, 0, 2),
    evidence: evidence,
  );
}

NormalizedMessageEvent _feedImageEvent({
  String messageId = 'feed:image_1',
  String text = '[Image]',
  String messageType = 'image',
}) {
  return NormalizedMessageEvent(
    eventId: 'event_$messageId',
    dedupeKey: 'feed:alpha:$messageId',
    accountId: '',
    conversationId: 'feed:alpha',
    conversationName: 'Alpha Group',
    conversationType: 'unknown',
    messageId: messageId,
    senderId: '',
    senderName: 'Alice',
    messageType: messageType,
    text: text,
    sentAt: '',
    observedAt: '2026-05-10T06:00:03Z',
    captureSource: 'feed_card_probe',
  );
}
```

- [ ] **Step 2: Run the resolver test to verify it fails**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_forwardable_image_resolver_test.dart
```

Expected: fail because the resolver file does not exist.

- [ ] **Step 3: Implement the resolver data types**

Create `tools/feishu_monitor_shell_app/lib/src/feishu_network_forwardable_image_resolver.dart`:

```dart
import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';

import 'feishu_network_capture.dart';

typedef FeishuLocalFileExists = bool Function(String path);

class FeishuNetworkForwardableImageResolution {
  const FeishuNetworkForwardableImageResolution({
    required this.events,
    required this.skipReason,
    this.decision = const <String, Object?>{},
  });

  final List<NormalizedMessageEvent> events;
  final String skipReason;
  final Map<String, Object?> decision;
}

class FeishuNetworkForwardableImageResolver {
  FeishuNetworkForwardableImageResolver({
    Duration matchWindow = const Duration(seconds: 8),
    FeishuLocalFileExists? fileExists,
  }) : matchWindow = matchWindow,
       _fileExists = fileExists ?? ((path) => File(path).existsSync());

  final Duration matchWindow;
  final FeishuLocalFileExists _fileExists;

  FeishuNetworkForwardableImageResolution resolve({
    required List<FeishuNetworkImageCandidate> candidates,
    required List<FeishuNetworkImageAttribution> attributions,
    required List<NormalizedMessageEvent> recentEvents,
  }) {
    final bodyCandidates = candidates.where(_hasSavedLocalBody).toList();
    if (bodyCandidates.isEmpty) {
      return _skip('missing_local_body');
    }
    if (bodyCandidates.length > 1) {
      return _skip('ambiguous_candidates');
    }

    final candidate = bodyCandidates.single;
    if (!_fileExists(candidate.localPath.trim())) {
      return _skip('body_file_missing');
    }

    final matchingAttributions = attributions
        .where((item) => item.sourceUrl == candidate.resourceUrl)
        .toList();
    if (matchingAttributions.isEmpty) {
      return _skip('attribution_missing');
    }
    final stableAttributions = matchingAttributions
        .where(_isProductionStableAttribution)
        .toList();
    if (stableAttributions.isEmpty) {
      return _skip('attribution_not_high_confidence');
    }
    if (stableAttributions.length > 1) {
      return _skip('ambiguous_candidates');
    }
    final attribution = stableAttributions.single;
    if (_secondsBetween(candidate.observedAt, attribution.observedAt).abs() >
        matchWindow.inSeconds) {
      return _skip('stale_match');
    }

    final matchingFeedEvents = recentEvents
        .where((event) => _matchesFeedPlaceholder(event, attribution))
        .where((event) {
          final observedAt = DateTime.tryParse(event.observedAt)?.toUtc();
          if (observedAt == null) {
            return false;
          }
          return _secondsBetween(candidate.observedAt, observedAt).abs() <=
              matchWindow.inSeconds;
        })
        .toList();
    if (matchingFeedEvents.isEmpty) {
      return _skip('feed_placeholder_missing');
    }
    if (matchingFeedEvents.length > 1) {
      return _skip('ambiguous_feed_events');
    }

    final feedEvent = matchingFeedEvents.single;
    final event = NormalizedMessageEvent(
      eventId: 'event_network_image_${candidate.bodySha1}',
      dedupeKey:
          '${_conversationScope(feedEvent)}:network_image:${candidate.bodySha1}',
      accountId: feedEvent.accountId,
      conversationId: feedEvent.conversationId,
      conversationName: feedEvent.conversationName,
      conversationType: feedEvent.conversationType,
      messageId: 'network_image:${candidate.bodySha1}',
      senderId: feedEvent.senderId,
      senderName: feedEvent.senderName.trim().isNotEmpty
          ? feedEvent.senderName
          : attribution.senderName,
      messageType: 'image',
      text: '[Image]',
      sentAt: feedEvent.sentAt,
      observedAt: candidate.observedAt.toUtc().toIso8601String(),
      captureSource: 'network_original_image',
      imageAttachments: <MessageImageAttachment>[
        MessageImageAttachment(
          sourceUrl: candidate.resourceUrl,
          localPath: candidate.localPath,
          width: candidate.width,
          height: candidate.height,
        ),
      ],
    );
    return FeishuNetworkForwardableImageResolution(
      events: <NormalizedMessageEvent>[event],
      skipReason: '',
      decision: <String, Object?>{
        'reason': 'forwardable',
        'body_sha1': candidate.bodySha1,
        'body_size': candidate.bodySize,
        'conversation_id': feedEvent.conversationId,
        'conversation_name': feedEvent.conversationName,
      },
    );
  }

  bool _hasSavedLocalBody(FeishuNetworkImageCandidate candidate) {
    return candidate.localPath.trim().isNotEmpty &&
        candidate.bodySha1.trim().isNotEmpty &&
        candidate.bodySize > 0;
  }

  bool _isProductionStableAttribution(FeishuNetworkImageAttribution item) {
    return item.isStable && item.evidence.contains('feed_card_context');
  }

  bool _matchesFeedPlaceholder(
    NormalizedMessageEvent event,
    FeishuNetworkImageAttribution attribution,
  ) {
    if (event.captureSource.trim() != 'feed_card_probe') {
      return false;
    }
    if (!_isMediaPlaceholder(event.text) && event.messageType != 'image') {
      return false;
    }
    final eventId = event.conversationId.trim();
    final attributionId = attribution.conversationId.trim();
    if (eventId.isNotEmpty && attributionId.isNotEmpty) {
      return eventId == attributionId;
    }
    return _normalizeName(event.conversationName) ==
        _normalizeName(attribution.conversationName);
  }

  bool _isMediaPlaceholder(String value) {
    final normalized = value.trim();
    return normalized == '[Image]' ||
        normalized == '[Photo]' ||
        normalized == '[File]' ||
        normalized == '[Video]' ||
        normalized == '[图片]' ||
        normalized == '[图⽚]' ||
        normalized == '[鍥剧墖]' ||
        normalized == '[閸ュ墽澧朷';
  }

  String _conversationScope(NormalizedMessageEvent event) {
    final id = event.conversationId.trim();
    if (id.isNotEmpty) {
      return id;
    }
    final name = _normalizeName(event.conversationName);
    return name.isEmpty ? 'unknown' : name;
  }

  String _normalizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  int _secondsBetween(DateTime a, DateTime b) {
    return a.toUtc().difference(b.toUtc()).inSeconds;
  }

  FeishuNetworkForwardableImageResolution _skip(String reason) {
    return FeishuNetworkForwardableImageResolution(
      events: const <NormalizedMessageEvent>[],
      skipReason: reason,
      decision: <String, Object?>{'reason': reason},
    );
  }
}
```

- [ ] **Step 4: Run the resolver test to verify it passes**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_forwardable_image_resolver_test.dart
```

Expected: all resolver tests pass.

- [ ] **Step 5: Commit Task 3**

```powershell
git add -- tools/feishu_monitor_shell_app/lib/src/feishu_network_forwardable_image_resolver.dart tools/feishu_monitor_shell_app/test/feishu_network_forwardable_image_resolver_test.dart
git commit -m "feat: resolve strict feishu network images"
```

## Task 4: Store Resolver Diagnostics

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`

- [ ] **Step 1: Write failing store diagnostics test**

Add this test to `tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart`:

```dart
test('store exposes forwardable image resolver diagnostics', () {
  final store = FeishuNetworkCaptureStore();

  store.recordForwardableImageResolution(
    const FeishuNetworkForwardableImageResolution(
      events: <NormalizedMessageEvent>[],
      skipReason: 'attribution_missing',
      decision: <String, Object?>{'reason': 'attribution_missing'},
    ),
  );

  final summary = store.toDiagnosticsJson();

  expect(summary['network_forwardable_image_count'], 0);
  expect(summary['network_last_image_skip_reason'], 'attribution_missing');
  expect(summary['network_recent_image_resolver_decisions'], hasLength(1));
});
```

Add imports:

```dart
import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_forwardable_image_resolver.dart';
```

- [ ] **Step 2: Run the store test to verify it fails**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: fail because `recordForwardableImageResolution` and diagnostics keys do not exist.

- [ ] **Step 3: Add store getters and resolver diagnostics**

Update `tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart`:

```dart
import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';

import 'feishu_network_forwardable_image_resolver.dart';
```

Add fields:

```dart
final List<Map<String, Object?>> _resolverDecisions = <Map<String, Object?>>[];
int _forwardableImageCount = 0;
String _lastImageSkipReason = '';
Map<String, Object?>? _lastForwardableImage;

List<FeishuNetworkImageCandidate> get recentCandidates =>
    List<FeishuNetworkImageCandidate>.unmodifiable(_candidates);

List<FeishuNetworkImageAttribution> get recentAttributions =>
    List<FeishuNetworkImageAttribution>.unmodifiable(_attributions);
```

Add method:

```dart
void recordForwardableImageResolution(
  FeishuNetworkForwardableImageResolution resolution,
) {
  if (resolution.events.isNotEmpty) {
    _forwardableImageCount += resolution.events.length;
    _lastForwardableImage = resolution.events.last.toJson();
    _lastImageSkipReason = '';
  } else {
    _lastImageSkipReason = resolution.skipReason;
  }
  _resolverDecisions.add(resolution.decision);
  _trim(_resolverDecisions, 20);
  _appendDiagnosticsLine(<String, Object?>{
    'diagnostic_type': 'image_resolver',
    ...resolution.decision,
  });
}
```

Add diagnostics keys in `toDiagnosticsJson()`:

```dart
'network_saved_image_count': _candidates
    .where((candidate) => candidate.localPath.trim().isNotEmpty)
    .length,
'network_forwardable_image_count': _forwardableImageCount,
'network_last_forwardable_image': _lastForwardableImage,
'network_last_image_skip_reason': _lastImageSkipReason,
'network_recent_image_resolver_decisions':
    List<Map<String, Object?>>.unmodifiable(_resolverDecisions),
```

- [ ] **Step 4: Run the store test to verify it passes**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_store_test.dart
```

Expected: all store tests pass.

- [ ] **Step 5: Commit Task 4**

```powershell
git add -- tools/feishu_monitor_shell_app/lib/src/feishu_network_capture_store.dart tools/feishu_monitor_shell_app/test/feishu_network_capture_store_test.dart
git commit -m "feat: report feishu image resolver diagnostics"
```

## Task 5: Shell Snapshot Integration

**Files:**
- Modify: `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`
- Modify: `tools/feishu_monitor_shell_app/lib/main.dart`
- Test: `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`
- Test: `tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart`

- [ ] **Step 1: Write failing snapshot merge test**

Add this test to `tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart`:

```dart
test('applyNetworkForwardableImages merges network image events into snapshot', () {
  final updated = applyNetworkForwardableImages(
    ShellSnapshot.initial(),
    const <NormalizedMessageEvent>[
      NormalizedMessageEvent(
        eventId: 'event_network_image_sha1alpha',
        dedupeKey: 'feed:alpha:network_image:sha1alpha',
        accountId: '',
        conversationId: 'feed:alpha',
        conversationName: 'Alpha Group',
        conversationType: 'unknown',
        messageId: 'network_image:sha1alpha',
        senderId: '',
        senderName: 'Alice',
        messageType: 'image',
        text: '[Image]',
        sentAt: '',
        observedAt: '2026-05-10T06:00:01Z',
        captureSource: 'network_original_image',
        imageAttachments: <MessageImageAttachment>[
          MessageImageAttachment(
            sourceUrl: 'https://internal-api-lark-file.feishu.cn/static-resource/v1/alpha.webp',
            localPath: r'C:\tmp\alpha.webp',
            width: 0,
            height: 0,
          ),
        ],
      ),
    ],
  );

  expect(updated.recentEvents, hasLength(1));
  expect(updated.recentEvents.single.captureSource, 'network_original_image');
  expect(updated.recentEvents.single.imageAttachments.single.localPath, r'C:\tmp\alpha.webp');
});
```

- [ ] **Step 2: Run the snapshot mapper test to verify it fails**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/runtime_snapshot_mapper_test.dart
```

Expected: fail because `applyNetworkForwardableImages` does not exist.

- [ ] **Step 3: Implement network event merge helper**

Add to `tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart`:

```dart
ShellSnapshot applyNetworkForwardableImages(
  ShellSnapshot snapshot,
  List<NormalizedMessageEvent> events,
) {
  if (events.isEmpty) {
    return snapshot;
  }
  return snapshot.copyWith(
    recentEvents: mergeRecentEvents(snapshot.recentEvents, events),
    lastUpdatedAt: DateTime.now().toUtc(),
  );
}
```

- [ ] **Step 4: Integrate resolver in page probe refresh**

Update `_refreshPageProbe` in `tools/feishu_monitor_shell_app/lib/main.dart` so the snapshot from `applyPageProbe` is enriched before `_withShellDiagnostics`:

```dart
      var probedSnapshot = applyPageProbe(current, probe);
      final imageResolution = _networkImageResolver.resolve(
        candidates: _networkCaptureStore.recentCandidates,
        attributions: _networkCaptureStore.recentAttributions,
        recentEvents: probedSnapshot.recentEvents,
      );
      _networkCaptureStore.recordForwardableImageResolution(imageResolution);
      probedSnapshot = applyNetworkForwardableImages(
        probedSnapshot,
        imageResolution.events,
      );
      final next = _withShellDiagnostics(
        probedSnapshot,
        probe,
        reason: reason,
        runtimeUrl: _runtimeUrl,
        pageTitle: _pageTitle,
        webviewAvailable: _webviewReady,
        isLoading: _loading,
      ).copyWith(lastError: _probeDebugMessage(probe));
```

Add imports and state field in `main.dart`:

```dart
import 'src/feishu_network_forwardable_image_resolver.dart';
```

```dart
late final FeishuNetworkForwardableImageResolver _networkImageResolver;
```

Initialize it in `initState()`:

```dart
_networkImageResolver = FeishuNetworkForwardableImageResolver();
```

- [ ] **Step 5: Keep diagnostics lightweight when no candidate evidence exists**

Guard resolver recording in `main.dart` so empty network state does not spam decisions:

```dart
      if (_networkCaptureStore.recentCandidates.isNotEmpty ||
          _networkCaptureStore.recentAttributions.isNotEmpty) {
        final imageResolution = _networkImageResolver.resolve(
          candidates: _networkCaptureStore.recentCandidates,
          attributions: _networkCaptureStore.recentAttributions,
          recentEvents: probedSnapshot.recentEvents,
        );
        _networkCaptureStore.recordForwardableImageResolution(imageResolution);
        probedSnapshot = applyNetworkForwardableImages(
          probedSnapshot,
          imageResolution.events,
        );
      }
```

- [ ] **Step 6: Run shell app tests**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/runtime_snapshot_mapper_test.dart test/feishu_network_capture_runtime_test.dart
```

Expected: both test files pass.

- [ ] **Step 7: Commit Task 5**

```powershell
git add -- tools/feishu_monitor_shell_app/lib/src/runtime_snapshot_mapper.dart tools/feishu_monitor_shell_app/lib/main.dart tools/feishu_monitor_shell_app/test/runtime_snapshot_mapper_test.dart tools/feishu_monitor_shell_app/test/feishu_network_capture_runtime_test.dart
git commit -m "feat: publish feishu network image events"
```

## Task 6: Forwarding Service Route Safety

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Test: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] **Step 1: Write forwarding tests for network image events and ambiguous routes**

Add these tests to `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`:

```dart
test(
  'forwardRoutedRecentEvents sends network_original_image local files',
  () async {
    final sender = _RecordingSender();
    final service = FeishuMonitorForwardingService(sender: sender);
    final settings = FeishuMonitorForwardingSettings(
      enabled: true,
      routes: <FeishuMonitorForwardingRoute>[
        _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
      ],
    );

    final result = await service.forwardRoutedRecentEvents(
      settings: settings,
      events: <FeishuMonitorMessageEvent>[
        _event(
          messageId: 'network_image:sha1alpha',
          dedupeKey: 'feed:alpha:network_image:sha1alpha',
          conversationId: 'feed:alpha',
          text: '[Image]',
          captureSource: 'network_original_image',
          imageAttachments: const <FeishuMonitorImageAttachment>[
            FeishuMonitorImageAttachment(
              sourceUrl: 'https://internal-api-lark-file.feishu.cn/static-resource/v1/alpha.webp',
              localPath: r'C:\tmp\alpha.webp',
              width: 0,
              height: 0,
            ),
          ],
        ),
      ],
    );

    expect(result.sent, 1);
    expect(result.failed, 0);
    expect(sender.sentImages, hasLength(1));
    expect(sender.sentImages.single.localPath, r'C:\tmp\alpha.webp');
    expect(sender.sentTexts, isEmpty);
  },
);

test('findRouteForEvent rejects ambiguous enabled source names', () {
  final routes = <FeishuMonitorForwardingRoute>[
    _route(
      id: 'route_alpha_1',
      sourceConversationId: '',
      sourceConversationName: 'Alpha Group',
      targetGroupId: 'wk_alpha_1',
    ),
    _route(
      id: 'route_alpha_2',
      sourceConversationId: '',
      sourceConversationName: 'alpha  group',
      targetGroupId: 'wk_alpha_2',
    ),
  ];

  final matched = findFeishuMonitorRouteForEvent(
    routes: routes,
    event: _event(conversationId: '', conversationName: 'Alpha Group'),
  );

  expect(matched, isNull);
});

test('findRouteForEvent rejects duplicate enabled source ids', () {
  final routes = <FeishuMonitorForwardingRoute>[
    _route(
      id: 'route_alpha_1',
      sourceConversationId: 'feed:alpha',
      targetGroupId: 'wk_alpha_1',
    ),
    _route(
      id: 'route_alpha_2',
      sourceConversationId: 'feed:alpha',
      targetGroupId: 'wk_alpha_2',
    ),
  ];

  final matched = findFeishuMonitorRouteForEvent(
    routes: routes,
    event: _event(conversationId: 'feed:alpha'),
  );

  expect(matched, isNull);
});
```

- [ ] **Step 2: Run forwarding tests to verify failures**

Run from repo root:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: route ambiguity tests fail because the matcher currently returns the first route.

- [ ] **Step 3: Make route matching unique**

Update `findFeishuMonitorRouteForEvent` in `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`:

```dart
FeishuMonitorForwardingRoute? findFeishuMonitorRouteForEvent({
  required List<FeishuMonitorForwardingRoute> routes,
  required FeishuMonitorMessageEvent event,
}) {
  final eligibleRoutes = routes
      .where((route) => route.enabled && route.targetGroupId.trim().isNotEmpty)
      .toList(growable: false);
  final conversationId = event.conversationId.trim();
  if (conversationId.isNotEmpty) {
    final idMatches = eligibleRoutes
        .where((route) => route.sourceConversationId.trim() == conversationId)
        .toList(growable: false);
    if (idMatches.length == 1) {
      return idMatches.single;
    }
    if (idMatches.length > 1) {
      return null;
    }
  }

  final conversationName = normalizeFeishuMonitorRouteName(
    event.conversationName,
  );
  if (conversationName.isEmpty) {
    return null;
  }
  final nameMatches = eligibleRoutes.where((route) {
    final sourceConversationName = normalizeFeishuMonitorRouteName(
      route.sourceConversationName,
    );
    return sourceConversationName == conversationName;
  }).toList(growable: false);
  return nameMatches.length == 1 ? nameMatches.single : null;
}
```

Apply the same uniqueness logic to `_findFeishuMonitorRouteCandidateForEvent`, without filtering out disabled routes or empty target groups.

- [ ] **Step 4: Run forwarding tests to verify they pass**

Run from repo root:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: all forwarding service tests pass.

- [ ] **Step 5: Commit Task 6**

```powershell
git add -- lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
git commit -m "fix: require unique feishu forwarding routes"
```

## Task 7: Native WebView2 Image Body Saver

**Files:**
- Modify: `tools/vendor/webview_windows_wukong/windows/webview.h`
- Modify: `tools/vendor/webview_windows_wukong/windows/webview.cc`
- Modify: `tools/vendor/webview_windows_wukong/windows/webview_windows_plugin.cc`
- Modify: `tools/vendor/webview_windows_wukong/windows/CMakeLists.txt`

- [ ] **Step 1: Add native event metadata fields**

Update `WebviewNetworkEvent` in `tools/vendor/webview_windows_wukong/windows/webview.h`:

```cpp
struct WebviewNetworkEvent {
  std::string id;
  std::string observed_at;
  std::string source;
  std::string url;
  std::string method;
  int status_code = 0;
  std::string mime_type;
  std::string payload_preview;
  std::string body_local_path;
  std::string body_sha1;
  int64_t body_size = 0;
  std::string body_mime_type;
  bool body_base64_encoded = false;
  bool body_saved = false;
  std::string body_save_error;
};
```

- [ ] **Step 2: Emit native metadata through MethodChannel**

Update `EmitNetworkCaptureEvent` in `tools/vendor/webview_windows_wukong/windows/webview_windows_plugin.cc`:

```cpp
      {flutter::EncodableValue("body_local_path"),
       flutter::EncodableValue(event.body_local_path)},
      {flutter::EncodableValue("body_sha1"),
       flutter::EncodableValue(event.body_sha1)},
      {flutter::EncodableValue("body_size"),
       flutter::EncodableValue(event.body_size)},
      {flutter::EncodableValue("body_mime_type"),
       flutter::EncodableValue(event.body_mime_type)},
      {flutter::EncodableValue("body_base64_encoded"),
       flutter::EncodableValue(event.body_base64_encoded)},
      {flutter::EncodableValue("body_saved"),
       flutter::EncodableValue(event.body_saved)},
      {flutter::EncodableValue("body_save_error"),
       flutter::EncodableValue(event.body_save_error)},
```

- [ ] **Step 3: Add native helper includes and constants**

Update includes at the top of `tools/vendor/webview_windows_wukong/windows/webview.cc`:

```cpp
#include <bcrypt.h>

#include <filesystem>
#include <fstream>
#include <vector>
```

Add constants near existing network constants:

```cpp
constexpr size_t kMaxSavedImageBytes = 25 * 1024 * 1024;
constexpr std::chrono::hours kSavedImageTtl = std::chrono::hours(24);
```

- [ ] **Step 4: Add JSON bool, filtering, decode, hash, and save helpers**

Add these helpers inside the anonymous namespace in `webview.cc`:

```cpp
bool JsonBoolValue(const std::string& json, const std::string& key) {
  const auto key_pos = json.find("\"" + key + "\"");
  if (key_pos == std::string::npos) {
    return false;
  }
  const auto colon_pos = json.find(':', key_pos);
  if (colon_pos == std::string::npos) {
    return false;
  }
  const auto start = json.find_first_not_of(" \t\r\n", colon_pos + 1);
  if (start == std::string::npos) {
    return false;
  }
  return json.compare(start, 4, "true") == 0 || json.compare(start, 1, "1") == 0;
}

std::string LowerCopy(std::string value) {
  std::transform(value.begin(), value.end(), value.begin(),
                 [](unsigned char c) {
                   return static_cast<char>(std::tolower(c));
                 });
  return value;
}

bool LooksLikeFeishuMessageImage(const WebviewNetworkEvent& event) {
  if (event.status_code < 200 || event.status_code >= 300) {
    return false;
  }
  const auto mime = LowerCopy(event.mime_type);
  if (mime.rfind("image/", 0) != 0) {
    return false;
  }
  const auto url = LowerCopy(event.url);
  if (url.find("default-avatar") != std::string::npos ||
      url.find("feishu-static") != std::string::npos ||
      url.find("scmcdn") != std::string::npos ||
      url.find("emoji") != std::string::npos ||
      url.find("sprite") != std::string::npos ||
      url.find("favicon") != std::string::npos ||
      url.find("icon") != std::string::npos) {
    return false;
  }
  return url.find("internal-api-lark-file.feishu.cn") != std::string::npos ||
         (url.find("imfile.feishucdn.com") != std::string::npos &&
          url.find("/static-resource/v1/") != std::string::npos);
}

std::string ImageExtensionForMimeType(const std::string& mime_type) {
  const auto mime = LowerCopy(mime_type);
  if (mime == "image/png") {
    return "png";
  }
  if (mime == "image/gif") {
    return "gif";
  }
  if (mime == "image/webp") {
    return "webp";
  }
  return "jpg";
}

std::vector<uint8_t> DecodeBase64(const std::string& encoded) {
  DWORD output_size = 0;
  if (!CryptStringToBinaryA(encoded.c_str(), static_cast<DWORD>(encoded.size()),
                            CRYPT_STRING_BASE64, nullptr, &output_size, nullptr,
                            nullptr)) {
    return {};
  }
  std::vector<uint8_t> output(output_size);
  if (!CryptStringToBinaryA(encoded.c_str(), static_cast<DWORD>(encoded.size()),
                            CRYPT_STRING_BASE64, output.data(), &output_size,
                            nullptr, nullptr)) {
    return {};
  }
  output.resize(output_size);
  return output;
}

std::string HexFromBytes(const uint8_t* bytes, size_t length) {
  std::ostringstream stream;
  stream << std::hex << std::setfill('0');
  for (size_t index = 0; index < length; ++index) {
    stream << std::setw(2) << static_cast<int>(bytes[index]);
  }
  return stream.str();
}

std::string Sha1Hex(const std::vector<uint8_t>& bytes) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  BCRYPT_HASH_HANDLE hash = nullptr;
  std::vector<uint8_t> digest(20);
  if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA1_ALGORITHM, nullptr,
                                  0) != 0) {
    return "";
  }
  if (BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) != 0) {
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return "";
  }
  if (BCryptHashData(hash,
                     const_cast<PUCHAR>(
                         reinterpret_cast<const UCHAR*>(bytes.data())),
                     static_cast<ULONG>(bytes.size()), 0) != 0 ||
      BCryptFinishHash(hash, digest.data(),
                       static_cast<ULONG>(digest.size()), 0) != 0) {
    BCryptDestroyHash(hash);
    BCryptCloseAlgorithmProvider(algorithm, 0);
    return "";
  }
  BCryptDestroyHash(hash);
  BCryptCloseAlgorithmProvider(algorithm, 0);
  return HexFromBytes(digest.data(), digest.size());
}

std::filesystem::path NetworkImageCacheDirectory() {
  return std::filesystem::temp_directory_path() /
         "wukong_feishu_monitor_shell" / "network_images";
}

void CleanupOldNetworkImages(const std::filesystem::path& directory) {
  std::error_code error;
  if (!std::filesystem::exists(directory, error)) {
    return;
  }
  const auto now = std::filesystem::file_time_type::clock::now();
  for (const auto& entry : std::filesystem::directory_iterator(directory, error)) {
    if (error || !entry.is_regular_file(error)) {
      continue;
    }
    const auto modified = entry.last_write_time(error);
    if (!error && now - modified > kSavedImageTtl) {
      std::filesystem::remove(entry.path(), error);
    }
  }
}
```

- [ ] **Step 5: Save eligible image bodies inside `HandleNetworkLoadingFinished` callback**

Update the callback in `HandleNetworkLoadingFinished` after parsing `response_json`:

```cpp
            const std::string body = JsonStringValue(response_json, "body");
            const bool base64_encoded =
                JsonBoolValue(response_json, "base64Encoded");
            event_with_body.payload_preview = TruncatePreview(body);
            event_with_body.body_base64_encoded = base64_encoded;
            event_with_body.body_mime_type = event.mime_type;

            if (LooksLikeFeishuMessageImage(event)) {
              std::vector<uint8_t> bytes;
              if (base64_encoded) {
                bytes = DecodeBase64(body);
              } else {
                bytes.assign(body.begin(), body.end());
              }
              if (bytes.empty()) {
                event_with_body.body_save_error = "empty_body";
              } else if (bytes.size() > kMaxSavedImageBytes) {
                event_with_body.body_save_error = "body_too_large";
              } else {
                const auto sha1 = Sha1Hex(bytes);
                if (sha1.empty()) {
                  event_with_body.body_save_error = "hash_failed";
                } else {
                  std::error_code fs_error;
                  const auto directory = NetworkImageCacheDirectory();
                  std::filesystem::create_directories(directory, fs_error);
                  CleanupOldNetworkImages(directory);
                  const auto extension = ImageExtensionForMimeType(event.mime_type);
                  const auto file_path = directory / (sha1 + "." + extension);
                  std::ofstream output(file_path, std::ios::binary);
                  output.write(reinterpret_cast<const char*>(bytes.data()),
                               static_cast<std::streamsize>(bytes.size()));
                  output.close();
                  if (!output) {
                    event_with_body.body_save_error = "write_failed";
                  } else {
                    event_with_body.body_saved = true;
                    event_with_body.body_local_path = file_path.string();
                    event_with_body.body_sha1 = sha1;
                    event_with_body.body_size =
                        static_cast<int64_t>(bytes.size());
                  }
                }
              }
            }
```

- [ ] **Step 6: Link native crypto library**

Update `tools/vendor/webview_windows_wukong/windows/CMakeLists.txt`:

```cmake
target_link_libraries(${PLUGIN_NAME} PRIVATE bcrypt)
```

Place it near the other `target_link_libraries(${PLUGIN_NAME} PRIVATE ...)` lines.

- [ ] **Step 7: Build the shell app for Windows**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter build windows
```

Expected: Windows build succeeds. If the build reports a missing Windows symbol, add the specific Windows header for that symbol and rerun the build.

- [ ] **Step 8: Commit Task 7**

```powershell
git add -- tools/vendor/webview_windows_wukong/windows/webview.h tools/vendor/webview_windows_wukong/windows/webview.cc tools/vendor/webview_windows_wukong/windows/webview_windows_plugin.cc tools/vendor/webview_windows_wukong/windows/CMakeLists.txt
git commit -m "feat: save feishu network image bodies"
```

## Task 8: Full Verification

**Files:**
- Read/verify all modified files from Tasks 1-7.

- [ ] **Step 1: Run shell unit tests**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter test test/feishu_network_capture_bridge_test.dart test/feishu_network_capture_parser_test.dart test/feishu_network_capture_store_test.dart test/feishu_network_forwardable_image_resolver_test.dart test/feishu_network_capture_runtime_test.dart test/runtime_snapshot_mapper_test.dart test/feishu_page_probe_test.dart
```

Expected: all selected shell app tests pass.

- [ ] **Step 2: Run shell analysis**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter analyze lib test
```

Expected: no issues.

- [ ] **Step 3: Run WuKongIM forwarding tests**

Run from repo root:

```powershell
flutter test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_auto_forward_runner_test.dart test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart
```

Expected: all selected WuKongIM tests pass.

- [ ] **Step 4: Run root analysis**

Run from repo root:

```powershell
flutter analyze lib test
```

Expected: no issues.

- [ ] **Step 5: Rebuild shell Windows binary**

Run from `tools/feishu_monitor_shell_app`:

```powershell
flutter build windows
```

Expected: build succeeds and produces the updated shell executable.

- [ ] **Step 6: Manual joint test**

Use the live environment:

1. Start WuKongIM Windows desktop.
2. Start the Feishu shell.
3. Keep the Feishu shell on the message list.
4. Confirm `/status` shows `capture_state: running` and `login_state: logged_in`.
5. Send one text message to a configured Feishu group.
6. Confirm WuKongIM receives the text.
7. Send one image to the same configured Feishu group.
8. Confirm the shell does not enter the group conversation.
9. Confirm `/status` diagnostics include `network_saved_image_count > 0`.
10. Confirm `/status` either exposes a `network_original_image` recent event or records a conservative skip reason.
11. If a `network_original_image` event appears, confirm WuKongIM receives the image.
12. Send images to two configured Feishu groups within 8 seconds.
13. Confirm ambiguous resolver cases are skipped instead of misrouted.

- [ ] **Step 7: Write test result note**

Append a short section to `docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md` with:

```markdown
## 2026-05-10 Network Original Image Forwarding

- Shell stayed on Feishu message list: yes/no
- Text forwarding passed: yes/no
- Network image body saved: yes/no
- `network_original_image` event emitted: yes/no
- WuKongIM image received: yes/no
- Ambiguous two-group image test skipped safely: yes/no
- Remaining issue:
```

- [ ] **Step 8: Commit verification note**

```powershell
git add -- docs/superpowers/artifacts/2026-05-09-feishu-monitor-center-test-report.md
git commit -m "test: record feishu network image forwarding verification"
```

