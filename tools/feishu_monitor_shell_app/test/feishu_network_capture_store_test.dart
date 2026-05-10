import 'dart:convert';
import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_forwardable_image_resolver.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'image attribution preserves raw source url and redacts status json',
    () {
      final attribution = FeishuNetworkImageAttribution.fromJson(
        <String, Object?>{
          'type': 'feishu_monitor_image_attribution',
          'source_url': 'blob:https://example.feishu.cn/abc?token=secret',
          'source_kind': 'blob',
          'blob_mime_type': 'image/webp',
          'blob_size': 12345,
          'conversation_id': 'feed:abc',
          'conversation_name': '婊℃弧姝ｈ兘閲?',
          'message_id': 'msg_1',
          'sender_name': '姗樼敓娣崡',
          'display_time': '14:29',
          'message_text': '[鍥剧墖]',
          'feed_card_id': 'feed_card_1',
          'feed_card_text': '婊℃弧姝ｈ兘閲?14:29 姗樼敓娣崡: [鍥剧墖]',
          'confidence': 0.92,
          'confidence_label': 'high',
          'reason': 'dom_img_src',
          'observed_at': '2026-05-10T06:29:00Z',
          'evidence': <String>['exact_dom_node', 'feed_card_context'],
        },
      );

      expect(attribution.conversationName, '婊℃弧姝ｈ兘閲?');
      expect(
        attribution.sourceUrl,
        'blob:https://example.feishu.cn/abc?token=secret',
      );

      final status = attribution.toStatusJson();
      expect(
        status['source_url'],
        'blob:https://example.feishu.cn/abc?token=<redacted>',
      );
      expect(status['stable'], isTrue);
    },
  );

  test('store keeps bounded recent events and image candidates', () {
    final store = FeishuNetworkCaptureStore(maxEvents: 2, maxCandidates: 2);

    store.addEvent(
      FeishuNetworkCaptureEvent(
        id: 'evt_1',
        observedAt: DateTime.utc(2026, 5, 10, 6),
        source: FeishuNetworkEventSource.httpResponse,
        url: 'https://a.test/one',
        method: 'GET',
        statusCode: 200,
        mimeType: 'application/json',
        payloadPreview: '{}',
      ),
    );
    store.addEvent(
      FeishuNetworkCaptureEvent(
        id: 'evt_2',
        observedAt: DateTime.utc(2026, 5, 10, 6, 1),
        source: FeishuNetworkEventSource.httpResponse,
        url: 'https://a.test/two?token=secret&file_key=image_2',
        method: 'GET',
        statusCode: 200,
        mimeType: 'application/json',
        payloadPreview: '{}',
      ),
    );
    store.addEvent(
      FeishuNetworkCaptureEvent(
        id: 'evt_3',
        observedAt: DateTime.utc(2026, 5, 10, 6, 2),
        source: FeishuNetworkEventSource.webSocketFrame,
        url: 'wss://a.test/push',
        method: 'WS',
        statusCode: 0,
        mimeType: 'application/octet-stream',
        payloadPreview: '{}',
      ),
    );

    store.addCandidate(
      FeishuNetworkImageCandidate(
        conversationId: 'feed:2e500f14',
        conversationName: 'conversation',
        messageId: 'msg_1',
        senderName: 'sender',
        resourceUrl: 'https://a.test/image?token=secret',
        resourceKey: 'img_1',
        width: 231,
        height: 500,
        quality: FeishuNetworkImageQuality.preview,
        observedAt: DateTime.utc(2026, 5, 10, 6, 3),
      ),
    );

    final summary = store.toDiagnosticsJson();

    expect(summary['network_capture_state'], 'running');
    expect(summary['network_event_count'], 3);
    expect(summary['network_recent_events'], hasLength(2));
    expect(summary['network_image_candidate_count'], 1);

    final recentEvents = summary['network_recent_events']! as List<Object?>;
    expect(
      recentEvents.map((event) => (event! as Map<String, Object?>)['id']),
      <String>['evt_2', 'evt_3'],
    );
    expect(
      (recentEvents.first! as Map<String, Object?>)['url'],
      'https://a.test/two?token=<redacted>&file_key=<redacted>',
    );

    final lastCandidate =
        summary['network_last_image_candidate']! as Map<String, Object?>;
    expect(
      lastCandidate['resource_url'],
      'https://a.test/image?token=<redacted>',
    );
    expect(lastCandidate['resource_key'], '<redacted>');
  });

  test('store accepts zero bounds while preserving total counts', () {
    final store = FeishuNetworkCaptureStore(maxEvents: 0, maxCandidates: 0);

    expect(() => store.addEvent(_event('evt_1')), returnsNormally);
    expect(() => store.addCandidate(_candidate()), returnsNormally);

    final summary = store.toDiagnosticsJson();

    expect(summary['network_event_count'], 1);
    expect(summary['network_recent_events'], isEmpty);
    expect(summary['network_image_candidate_count'], 1);
    expect(summary['network_last_image_candidate'], isNull);
  });

  test('store counts and bounds recent image attributions separately', () {
    final store = FeishuNetworkCaptureStore(maxAttributions: 2);

    store.addCandidate(_candidate());
    store.addAttribution(_attribution('https://a.test/image-1?token=secret'));
    store.addAttribution(_attribution('https://a.test/image-2?token=secret'));
    store.addAttribution(_attribution('https://a.test/image-3?token=secret'));

    final summary = store.toDiagnosticsJson();

    expect(summary['network_image_candidate_count'], 1);
    expect(summary['network_image_attribution_count'], 3);
    expect(summary['network_recent_image_attributions'], hasLength(2));

    final recentAttributions =
        summary['network_recent_image_attributions']! as List<Object?>;
    expect(
      recentAttributions.map(
        (attribution) => (attribution! as Map<String, Object?>)['source_url'],
      ),
      <String>[
        'https://a.test/image-2?token=<redacted>',
        'https://a.test/image-3?token=<redacted>',
      ],
    );
  });

  test(
    'store exposes latest attribution and exact raw url candidate match',
    () {
      final store = FeishuNetworkCaptureStore();

      store.addCandidate(
        _candidate(resourceUrl: 'https://a.test/exact?token=secret'),
      );
      store.addAttribution(_attribution('https://a.test/exact?token=secret'));

      final summary = store.toDiagnosticsJson();

      final lastAttribution =
          summary['network_last_image_attribution']! as Map<String, Object?>;
      expect(
        lastAttribution['source_url'],
        'https://a.test/exact?token=<redacted>',
      );

      final attributedCandidate =
          summary['network_last_attributed_image_candidate']!
              as Map<String, Object?>;
      expect(attributedCandidate['stable'], isTrue);
      expect(
        (attributedCandidate['candidate']!
            as Map<String, Object?>)['resource_url'],
        'https://a.test/exact?token=<redacted>',
      );
      expect(
        (attributedCandidate['attribution']!
            as Map<String, Object?>)['source_url'],
        'https://a.test/exact?token=<redacted>',
      );
    },
  );

  test('store exact attribution match does not normalize redacted urls', () {
    final store = FeishuNetworkCaptureStore();

    store.addCandidate(
      _candidate(resourceUrl: 'https://a.test/exact?token=first'),
    );
    store.addAttribution(_attribution('https://a.test/exact?token=second'));

    final summary = store.toDiagnosticsJson();

    expect(summary['network_last_attributed_image_candidate'], isNull);
  });

  test('redacts common credential keys from urls and payload previews', () {
    final event = FeishuNetworkCaptureEvent(
      id: 'evt_sensitive',
      observedAt: DateTime.utc(2026, 5, 10, 6),
      source: FeishuNetworkEventSource.httpResponse,
      url:
          'https://a.test/event?access_token=a&authorization=b&cookie=c&session=d&sign=e&signature=f',
      method: 'GET',
      statusCode: 200,
      mimeType: 'application/json',
      payloadPreview:
          '{"access_token":"a","authorization":"b","cookie":"c","session":"d","sign":"e","signature":"f"}',
    );

    final redacted = event.toRedactedJson();

    expect(
      redacted['url'],
      'https://a.test/event?access_token=<redacted>&authorization=<redacted>&cookie=<redacted>&session=<redacted>&sign=<redacted>&signature=<redacted>',
    );
    expect(
      redacted['payload_preview'],
      '{"access_token":"<redacted>","authorization":"<redacted>","cookie":"<redacted>","session":"<redacted>","sign":"<redacted>","signature":"<redacted>"}',
    );
  });

  test('redacts credential headers and form-style payload previews', () {
    final redacted = redactPayload(
      'Authorization: Bearer abc.def.ghi\n'
      'Authorization: Basic dXNlcjpwYXNz\n'
      'Cookie: session=s1; csrf=c1\n'
      'Set-Cookie: ticket=t1; Path=/\n'
      'session=s2&sign=sig&secret=sec&jwt=jwt1&credential=cred\n'
      'token: raw-token\n'
      'x-csrf-token: csrf-token\n'
      'x-auth-token=auth-token',
    );

    expect(redacted, contains('Authorization: <redacted>'));
    expect(redacted, contains('Cookie: <redacted>'));
    expect(redacted, contains('Set-Cookie: <redacted>'));
    expect(redacted, contains('session=<redacted>'));
    expect(redacted, contains('sign=<redacted>'));
    expect(redacted, contains('secret=<redacted>'));
    expect(redacted, contains('jwt=<redacted>'));
    expect(redacted, contains('credential=<redacted>'));
    expect(redacted, contains('token: <redacted>'));
    expect(redacted, contains('x-csrf-token: <redacted>'));
    expect(redacted, contains('x-auth-token=<redacted>'));
    expect(redacted, isNot(contains('abc.def.ghi')));
    expect(redacted, isNot(contains('dXNlcjpwYXNz')));
    expect(redacted, isNot(contains('raw-token')));
    expect(redacted, isNot(contains('=auth-token')));
  });

  test('store records unavailable diagnostics', () {
    final store = FeishuNetworkCaptureStore();

    store.setUnavailable('WebView2 CDP Network.enable failed.');

    final summary = store.toDiagnosticsJson();
    expect(summary['network_capture_state'], 'unavailable');
    expect(
      summary['network_last_error'],
      'WebView2 CDP Network.enable failed.',
    );
  });

  test('store writes redacted diagnostics lines', () async {
    final dir = await Directory.systemTemp.createTemp(
      'feishu_network_capture_test_',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final file = File('${dir.path}${Platform.pathSeparator}network.jsonl');
    final store = FeishuNetworkCaptureStore(diagnosticsFile: file);

    store.addEvent(
      FeishuNetworkCaptureEvent(
        id: 'evt_1',
        observedAt: DateTime.utc(2026, 5, 10, 6),
        source: FeishuNetworkEventSource.httpResponse,
        url: 'https://a.test/image?token=secret&signature=sig',
        method: 'GET',
        statusCode: 200,
        mimeType: 'application/json',
        payloadPreview: 'Authorization: Bearer secret\n{"token":"secret"}',
      ),
    );

    final text = await file.readAsString();

    expect(text, contains('"id":"evt_1"'));
    expect(text, contains('<redacted>'));
    expect(text, isNot(contains('secret')));
    expect(text.trim().split('\n'), hasLength(1));
  });

  test('store writes redacted attribution diagnostics lines', () async {
    final dir = await Directory.systemTemp.createTemp(
      'feishu_network_capture_test_',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final file = File('${dir.path}${Platform.pathSeparator}network.jsonl');
    final store = FeishuNetworkCaptureStore(diagnosticsFile: file);

    store.addAttribution(
      _attribution('blob:https://a.test/image?token=secret'),
    );

    final text = await file.readAsString();

    expect(text, contains('"diagnostic_type":"image_attribution"'));
    expect(text, contains('token=<redacted>'));
    expect(text, isNot(contains('token=secret')));
    expect(text.trim().split('\n'), hasLength(1));
  });

  test('store exposes forwardable image resolver diagnostics', () async {
    final dir = await Directory.systemTemp.createTemp(
      'feishu_network_capture_test_',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final file = File('${dir.path}${Platform.pathSeparator}network.jsonl');
    final store = FeishuNetworkCaptureStore(diagnosticsFile: file);

    store.recordForwardableImageResolution(
      const FeishuNetworkForwardableImageResolution(
        events: <NormalizedMessageEvent>[],
        skipReason: 'attribution_missing',
        decision: <String, Object?>{
          'reason': 'attribution_missing',
          'body_sha1': 'sha1alpha',
        },
      ),
    );

    var summary = store.toDiagnosticsJson();
    expect(summary['network_forwardable_image_count'], 0);
    expect(summary['network_last_image_skip_reason'], 'attribution_missing');
    expect(summary['network_recent_image_resolver_decisions'], hasLength(1));
    expect(
      (summary['network_recent_image_resolver_decisions']! as List<Object?>)
          .single,
      <String, Object?>{
        'reason': 'attribution_missing',
        'body_sha1': 'sha1alpha',
      },
    );

    store.recordForwardableImageResolution(
      FeishuNetworkForwardableImageResolution(
        events: <NormalizedMessageEvent>[_networkImageEvent()],
        skipReason: '',
        decision: const <String, Object?>{'body_sha1': 'sha1beta'},
      ),
    );

    summary = store.toDiagnosticsJson();
    expect(summary['network_forwardable_image_count'], 1);
    expect(summary['network_last_image_skip_reason'], '');

    final lastForwardable =
        summary['network_last_forwardable_image']! as Map<String, Object?>;
    expect(lastForwardable['capture_source'], 'network_original_image');

    for (var index = 0; index < 25; index += 1) {
      store.recordForwardableImageResolution(
        FeishuNetworkForwardableImageResolution(
          events: const <NormalizedMessageEvent>[],
          skipReason: 'bounded_$index',
          decision: <String, Object?>{'reason': 'bounded_$index'},
        ),
      );
    }

    summary = store.toDiagnosticsJson();
    final decisions =
        summary['network_recent_image_resolver_decisions']! as List<Object?>;
    expect(decisions, hasLength(20));
    expect((decisions.first! as Map<String, Object?>)['reason'], 'bounded_5');
    expect((decisions.last! as Map<String, Object?>)['reason'], 'bounded_24');

    final lines = (await file.readAsLines())
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .toList(growable: false);
    final resolverLines = lines
        .where((line) => line['diagnostic_type'] == 'image_resolver')
        .toList(growable: false);

    expect(resolverLines, hasLength(27));
    expect(resolverLines.first['reason'], 'attribution_missing');
    expect(resolverLines.first['body_sha1'], 'sha1alpha');

    final diagnosticsText = await file.readAsString();
    expect(diagnosticsText, isNot(contains(r'C:\tmp\alpha.webp')));
    expect(diagnosticsText, isNot(contains('token=secret')));
  });

  test('store redacts data image attribution payloads', () async {
    final dir = await Directory.systemTemp.createTemp(
      'feishu_network_capture_test_',
    );
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final file = File('${dir.path}${Platform.pathSeparator}network.jsonl');
    final store = FeishuNetworkCaptureStore(diagnosticsFile: file);

    store.addAttribution(
      _attribution('data:image/png;base64,SECRET_IMAGE_BYTES'),
    );

    final summary = store.toDiagnosticsJson();
    final lastAttribution =
        summary['network_last_image_attribution']! as Map<String, Object?>;
    expect(lastAttribution['source_url'], 'data:image/png;base64,<redacted>');

    final text = await file.readAsString();
    expect(text, contains('data:image/png;base64,<redacted>'));
    expect(text, isNot(contains('SECRET_IMAGE_BYTES')));
  });

  test('store clamps negative bounds while preserving total counts', () {
    final store = FeishuNetworkCaptureStore(maxEvents: -1, maxCandidates: -1);

    expect(() => store.addEvent(_event('evt_1')), returnsNormally);
    expect(() => store.addCandidate(_candidate()), returnsNormally);

    final summary = store.toDiagnosticsJson();

    expect(summary['network_event_count'], 1);
    expect(summary['network_recent_events'], isEmpty);
    expect(summary['network_image_candidate_count'], 1);
    expect(summary['network_last_image_candidate'], isNull);
  });

  test('diagnostics summary can be merged into probe diagnostics', () {
    final store = FeishuNetworkCaptureStore();
    store.addCandidate(
      FeishuNetworkImageCandidate(
        conversationId: 'feed:2e500f14',
        conversationName: 'conversation',
        messageId: 'msg_1',
        senderName: 'sender',
        resourceUrl: 'https://a.test/image?token=secret',
        resourceKey: 'img_1',
        width: 231,
        height: 500,
        quality: FeishuNetworkImageQuality.preview,
        observedAt: DateTime.utc(2026, 5, 10, 6),
      ),
    );

    final diagnostics = <String, Object?>{
      'existing': 'value',
      ...store.toDiagnosticsJson(),
    };

    expect(diagnostics['existing'], 'value');
    expect(diagnostics['network_capture_state'], 'running');
    expect(diagnostics['network_image_candidate_count'], 1);
  });
}

FeishuNetworkCaptureEvent _event(String id) {
  return FeishuNetworkCaptureEvent(
    id: id,
    observedAt: DateTime.utc(2026, 5, 10, 6),
    source: FeishuNetworkEventSource.httpResponse,
    url: 'https://a.test/event?token=secret',
    method: 'GET',
    statusCode: 200,
    mimeType: 'application/json',
    payloadPreview: '{}',
  );
}

FeishuNetworkImageCandidate _candidate({
  String resourceUrl = 'https://a.test/image?token=secret',
}) {
  return FeishuNetworkImageCandidate(
    conversationId: 'feed:2e500f14',
    conversationName: 'conversation',
    messageId: 'msg_1',
    senderName: 'sender',
    resourceUrl: resourceUrl,
    resourceKey: 'img_1',
    width: 231,
    height: 500,
    quality: FeishuNetworkImageQuality.preview,
    observedAt: DateTime.utc(2026, 5, 10, 6, 3),
  );
}

FeishuNetworkImageAttribution _attribution(String sourceUrl) {
  return FeishuNetworkImageAttribution(
    sourceUrl: sourceUrl,
    sourceKind: 'blob',
    blobMimeType: 'image/webp',
    blobSize: 12345,
    conversationId: 'feed:abc',
    conversationName: 'conversation',
    messageId: 'msg_1',
    senderName: 'sender',
    displayTime: '14:29',
    messageText: '[image]',
    feedCardId: 'feed_card_1',
    feedCardText: 'conversation 14:29 sender: [image]',
    confidence: 0.92,
    confidenceLabel: 'high',
    reason: 'dom_img_src',
    observedAt: DateTime.utc(2026, 5, 10, 6, 29),
    evidence: const <String>['exact_dom_node', 'feed_card_context'],
  );
}

NormalizedMessageEvent _networkImageEvent() {
  return const NormalizedMessageEvent(
    eventId: 'event_network_image',
    dedupeKey: 'feed:alpha:network_image:sha1beta',
    accountId: 'account-1',
    conversationId: 'feed:alpha',
    conversationName: 'Alpha Group',
    conversationType: 'group',
    messageId: 'network_image:sha1beta',
    senderId: 'sender-1',
    senderName: 'Alice',
    messageType: 'image',
    text: '[Image]',
    sentAt: '2026-05-10T04:29:59Z',
    observedAt: '2026-05-10T04:30:02Z',
    captureSource: 'network_original_image',
    imageAttachments: <MessageImageAttachment>[
      MessageImageAttachment(
        sourceUrl: 'https://a.test/image?token=secret',
        localPath: r'C:\tmp\alpha.webp',
        width: 640,
        height: 480,
      ),
    ],
  );
}
