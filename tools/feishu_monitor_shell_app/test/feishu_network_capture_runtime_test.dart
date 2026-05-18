import 'dart:convert';
import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:feishu_monitor_shell_app/main.dart';
import 'package:feishu_monitor_shell_app/src/feishu_browser_image_body_cache.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_probe.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture_store.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_forwardable_image_resolver.dart';
import 'package:feishu_monitor_shell_app/src/feishu_page_observer.dart';
import 'package:feishu_monitor_shell_app/src/feishu_page_probe.dart';
import 'package:feishu_monitor_shell_app/src/runtime_snapshot_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network diagnostics file lives under shell runtime directory', () {
    final supportDirectory = Directory('C:\\app_support');

    final file = networkCaptureDiagnosticsFileFor(supportDirectory);

    expect(
      file.path,
      'C:\\app_support\\feishu_monitor_shell\\.runtime\\feishu-network-capture\\network.jsonl',
    );
  });

  test(
    'network capture retention cleans stale diagnostics and images',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'feishu_network_retention_test_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      final diagnostics = File(
        '${dir.path}${Platform.pathSeparator}feishu_monitor_shell'
        '${Platform.pathSeparator}.runtime${Platform.pathSeparator}'
        'feishu-network-capture${Platform.pathSeparator}network.jsonl',
      );
      final images = Directory(
        '${diagnostics.parent.path}${Platform.pathSeparator}network_images',
      );
      await images.create(recursive: true);
      final staleImage = File(
        '${images.path}${Platform.pathSeparator}old.webp',
      );
      final freshImage = File(
        '${images.path}${Platform.pathSeparator}fresh.webp',
      );
      final invalidImage = File(
        '${images.path}${Platform.pathSeparator}invalid.webp',
      );
      await staleImage.writeAsBytes(<int>[1]);
      await freshImage.writeAsBytes(<int>[2]);
      await invalidImage.writeAsBytes(<int>[3]);
      await diagnostics.parent.create(recursive: true);
      await diagnostics.writeAsString(
        [
          jsonEncode(<String, Object?>{
            'observed_at': '2026-05-09T11:59:59Z',
            'id': 'old',
          }),
          jsonEncode(<String, Object?>{
            'observed_at': '2026-05-09T12:00:00Z',
            'id': 'fresh',
          }),
          'not-json',
        ].join('\n'),
      );

      final result = await cleanupFeishuNetworkCaptureRuntime(
        diagnosticsFile: diagnostics,
        now: DateTime.parse('2026-05-10T12:00:00Z'),
        retention: const Duration(hours: 24),
        imageObservedAt: (file) {
          if (file.path == staleImage.path) {
            return DateTime.parse('2026-05-09T11:59:59Z');
          }
          if (file.path == freshImage.path) {
            return DateTime.parse('2026-05-09T12:00:00Z');
          }
          return null;
        },
      );

      expect(result.deletedImageFiles, 1);
      expect(result.retainedDiagnosticLines, 2);
      expect(await staleImage.exists(), isFalse);
      expect(await freshImage.exists(), isTrue);
      expect(await invalidImage.exists(), isTrue);
      expect(await diagnostics.readAsLines(), <String>[
        jsonEncode(<String, Object?>{
          'observed_at': '2026-05-09T12:00:00Z',
          'id': 'fresh',
        }),
        'not-json',
      ]);
    },
  );

  test('shell installs image attribution hook during startup and fallback', () {
    expect(
      feishuShellDocumentCreatedScripts(),
      contains(feishuNetworkImageAttributionScript),
    );
    expect(
      feishuShellPageObserverScripts(),
      contains(feishuNetworkImageAttributionScript),
    );
  });

  test(
    'shell keeps existing feed observer before diagnostic hook fallback',
    () {
      final scripts = feishuShellPageObserverScripts();

      expect(
        scripts.indexOf(feishuPageObserverScript),
        lessThan(scripts.indexOf(feishuNetworkImageAttributionScript)),
      );
    },
  );

  test('shell installs storage probe with page observer scripts', () {
    expect(
      feishuShellPageObserverScripts(),
      contains(feishuStorageProbeScript),
    );
  });

  test('shell storage probe script is throttled for unattended runtime', () {
    expect(feishuStorageProbeScript, contains('last_probe_epoch_ms'));
    expect(feishuStorageProbeScript, contains('throttled'));
    expect(feishuStorageProbeScript, contains('< 120000'));
    expect(feishuStorageProbeScript, contains('totalRecordBudget'));
    expect(feishuStorageProbeScript, contains('recordBudgetUsed'));
  });

  test('shell allows controlled media conversation opening policy', () {
    expect(feishuMediaConversationOpenEnabled, isTrue);
    expect(feishuLatestFeedAutoOpenEnabled, isFalse);
    expect(
      feishuMediaConversationOpenReason,
      'pending_media_feed_open_enabled',
    );
  });

  test('shell reports latest-feed auto opening disabled for safety', () {
    final diagnostic = feishuLatestFeedAutoOpenDisabledResult();

    expect(diagnostic['attempted'], isFalse);
    expect(diagnostic['opened'], isFalse);
    expect(diagnostic['reason'], 'latest_feed_auto_open_disabled');
  });

  test('latest-feed disabled result is safe for status diagnostics', () {
    final diagnostic = feishuLatestFeedAutoOpenDisabledResult();

    expect(
      diagnostic.keys,
      containsAll(<String>['attempted', 'opened', 'reason']),
    );
    expect(diagnostic, isNot(containsPair('key', anything)));
    expect(diagnostic, isNot(containsPair('text_preview', anything)));
  });

  test(
    'network enrichment records repeated successful image resolution once',
    () {
      final recordedDedupeKeys = <String>{};
      final first = applyNetworkImageEnrichment(
        ShellSnapshot.initial(),
        candidates: <FeishuNetworkImageCandidate>[_candidate()],
        attributions: <FeishuNetworkImageAttribution>[_attribution()],
        recordedNetworkImageDedupeKeys: recordedDedupeKeys,
        resolve: _successfulResolution,
      );

      final second = applyNetworkImageEnrichment(
        first.snapshot,
        candidates: <FeishuNetworkImageCandidate>[_candidate()],
        attributions: <FeishuNetworkImageAttribution>[_attribution()],
        recordedNetworkImageDedupeKeys: recordedDedupeKeys,
        resolve: _successfulResolution,
      );

      expect(first.recordableResolution?.events, hasLength(1));
      expect(second.recordableResolution, isNull);
      expect(second.snapshot.recentEvents, hasLength(1));
      expect(
        second.snapshot.recentEvents.single.captureSource,
        'network_original_image',
      );
      expect(recordedDedupeKeys, <String>{
        'feed:alpha:network_image:sha1alpha',
      });
    },
  );

  test(
    'network enrichment failure returns original snapshot without throwing',
    () {
      final initial = ShellSnapshot.initial();

      final enriched = applyNetworkImageEnrichment(
        initial,
        candidates: <FeishuNetworkImageCandidate>[_candidate()],
        attributions: <FeishuNetworkImageAttribution>[_attribution()],
        recordedNetworkImageDedupeKeys: <String>{},
        resolve:
            ({
              required candidates,
              required attributions,
              required recentEvents,
            }) {
              throw StateError('resolver failed');
            },
      );

      expect(enriched.snapshot, same(initial));
      expect(enriched.recordableResolution, isNull);
      expect(enriched.error, contains('resolver failed'));
    },
  );

  test('gateway protobuf diagnostics expose readable image metadata hints', () {
    final event = FeishuNetworkCaptureEvent(
      id: 'gateway-1',
      observedAt: DateTime.utc(2026, 5, 10, 12, 30),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://internal-api-lark-api.feishu.cn/im/gateway/',
      method: 'POST',
      statusCode: 200,
      mimeType: 'application/x-protobuf',
      payloadPreview:
          'noise image_key: img_v3_abc123 file_key=file_v3_xyz '
          'conversation_id=oc_123 message_id=om_456 '
          'https://s1-imfile.feishucdn.com/static-resource/v1/img_v3_abc123~',
      bodyBase64Encoded: true,
      bodySize: 128,
    );

    final probe = probeFeishuNetworkCaptureEvent(event);

    expect(probe, isNotNull);
    expect(probe!['kind'], 'im_gateway_protobuf');
    expect(probe['has_image_hint'], isTrue);
    expect(probe['has_message_hint'], isTrue);
    expect(probe['tokens'], contains('image_key'));
    expect(probe['tokens'], contains('file_key'));
    expect(probe['tokens'], contains('conversation_id'));
    expect(probe['tokens'], contains('message_id'));
    expect(probe['sample'], contains('<redacted>'));
  });

  test('gateway protobuf diagnostics auto-decodes base64 payload previews', () {
    final payload = base64Encode(
      'binary image_key img_v3_auto conversation_id oc_auto'.codeUnits,
    );
    final event = FeishuNetworkCaptureEvent(
      id: 'gateway-1',
      observedAt: DateTime.utc(2026, 5, 10, 12, 30),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://internal-api-lark-api.feishu.cn/im/gateway/',
      method: 'POST',
      statusCode: 200,
      mimeType: 'application/x-protobuf',
      payloadPreview: payload,
      bodyBase64Encoded: false,
    );

    final probe = probeFeishuNetworkCaptureEvent(event);

    expect(probe, isNotNull);
    expect(probe!['payload_base64_detected'], isTrue);
    expect(probe['tokens'], contains('image_key'));
    expect(probe['tokens'], contains('conversation_id'));
    expect(probe['sample'], contains('image_key=<redacted>'));
  });

  test('gateway protobuf diagnostics summarizes Feishu id-like values', () {
    final event = FeishuNetworkCaptureEvent(
      id: 'gateway-ids',
      observedAt: DateTime.utc(2026, 5, 10, 12, 31),
      source: FeishuNetworkEventSource.httpResponse,
      url: 'https://internal-api-lark-api.feishu.cn/im/gateway/',
      method: 'POST',
      statusCode: 200,
      mimeType: 'application/x-protobuf',
      payloadPreview:
          'oc_abcdef1234567890 om_7638112798311976160 '
          'img_v3_0010q_efe4c060-0bfb-41f4-8f95-6dcf1aa55e1g '
          'file_v3_abc123 ch_42 user_99',
    );

    final probe = probeFeishuNetworkCaptureEvent(event);

    expect(probe, isNotNull);
    expect(probe!['id_like_counts'], isA<Map<String, Object?>>());
    final counts = probe['id_like_counts'] as Map<String, Object?>;
    expect(counts['conversation'], 1);
    expect(counts['message'], 1);
    expect(counts['image_key'], 1);
    expect(counts['file_key'], 1);
    expect(counts['chat'], 1);
    expect(counts['user'], 1);
    expect(probe['id_like_samples'].toString(), contains('<redacted:oc_'));
    expect(
      probe['id_like_samples'].toString(),
      isNot(contains('abcdef1234567890')),
    );
  });

  test(
    'capture store records protobuf probes without creating image events',
    () {
      final store = FeishuNetworkCaptureStore();
      final event = FeishuNetworkCaptureEvent(
        id: 'gateway-1',
        observedAt: DateTime.utc(2026, 5, 10, 12, 30),
        source: FeishuNetworkEventSource.httpResponse,
        url: 'https://internal-api-lark-api.feishu.cn/im/gateway/',
        method: 'POST',
        statusCode: 200,
        mimeType: 'application/x-protobuf',
        payloadPreview: 'image_key img_v3_abc message_id om_123',
      );

      store.addEvent(event);
      store.addProbe(probeFeishuNetworkCaptureEvent(event)!);
      final diagnostics = store.toDiagnosticsJson();

      expect(diagnostics['network_probe_count'], 1);
      expect(diagnostics['network_last_probe'], isA<Map<String, Object?>>());
      expect(diagnostics['network_image_candidate_count'], 0);
      expect(diagnostics['network_forwardable_image_count'], 0);
    },
  );

  test('capture store records request probes without creating image events', () {
    final store = FeishuNetworkCaptureStore();
    final event = FeishuNetworkCaptureEvent(
      id: 'request-1',
      observedAt: DateTime.utc(2026, 5, 10, 12, 30),
      source: FeishuNetworkEventSource.httpRequest,
      url:
          'https://imfile.feishucdn.com/static-resource/v1/img.webp?token=secret',
      method: 'GET',
      statusCode: 0,
      mimeType: '',
      payloadPreview: '',
      resourceType: 'Image',
      documentUrl: 'https://feishu.cn/messenger/?conversation_id=secret',
      initiatorType: 'script',
      initiatorUrl: 'https://lf-package.feishucdn.com/obj/app.js?token=secret',
      initiatorStackUrl:
          'https://lf-package.feishucdn.com/obj/chunk.js?token=secret',
      initiatorLineNumber: 42,
      initiatorColumnNumber: 7,
      frameId: 'frame-1',
    );

    store.addEvent(event);
    store.addProbe(probeFeishuNetworkCaptureEvent(event)!);
    final diagnostics = store.toDiagnosticsJson();
    final probe = diagnostics['network_last_probe'] as Map<String, Object?>;

    expect(diagnostics['network_probe_count'], 1);
    expect(probe['kind'], 'request_will_be_sent');
    expect(probe['resource_type'], 'Image');
    expect(probe['initiator_type'], 'script');
    expect(
      probe['document_url'].toString(),
      contains('conversation_id=<redacted>'),
    );
    expect(
      probe['initiator_stack_url'].toString(),
      contains('token=<redacted>'),
    );
    expect(probe['has_image_hint'], isTrue);
    expect(diagnostics['network_image_candidate_count'], 0);
    expect(diagnostics['network_forwardable_image_count'], 0);
  });

  test(
    'realtime channel diagnostics expose transport hints without creating image events',
    () {
      final store = FeishuNetworkCaptureStore();
      final event = FeishuNetworkCaptureEvent(
        id: 'ws-1',
        observedAt: DateTime.utc(2026, 5, 10, 12, 30),
        source: FeishuNetworkEventSource.webSocketFrameSent,
        url: 'wss://internal-api-lark-api.feishu.cn/push?token=secret',
        method: 'WS_SENT:1',
        statusCode: 0,
        mimeType: 'application/octet-stream',
        payloadPreview:
            'conversation_id=oc_123 message_id=om_456 image_key=img_v3_abc',
      );

      store.addEvent(event);
      store.addProbe(probeFeishuNetworkCaptureEvent(event)!);
      final diagnostics = store.toDiagnosticsJson();
      final probe = diagnostics['network_last_probe'] as Map<String, Object?>;

      expect(diagnostics['network_probe_count'], 1);
      expect(probe['kind'], 'realtime_channel');
      expect(probe['source'], 'webSocketFrameSent');
      expect(probe['url'].toString(), contains('token=<redacted>'));
      expect(probe['has_image_hint'], isTrue);
      expect(probe['has_message_hint'], isTrue);
      expect(diagnostics['network_image_candidate_count'], 0);
      expect(diagnostics['network_forwardable_image_count'], 0);
    },
  );

  test(
    'browser preview image body is saved as a forwardable candidate',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'feishu_browser_image_body_test_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      final saved = await saveFeishuBrowserImageBody(
        FeishuBrowserImageBody(
          sourceUrl: 'blob:https://example.feishu.cn/image-1',
          mimeType: 'image/webp',
          bodyBase64: base64Encode(<int>[1, 2, 3, 4]),
          bodySize: 4,
          width: 805,
          height: 393,
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: 'Alice',
          displayTime: '14:29',
          messageText: '[Image]',
          feedCardId: 'feed_card_1',
          feedCardText: 'Alpha Group 14:29 Alice: [Image]',
          confidence: 0.72,
          confidenceLabel: 'medium',
          reason: 'preview_blob_body',
          observedAt: DateTime.utc(2026, 5, 10, 9, 0),
          evidence: const <String>[
            'browser_preview_blob_body',
            'active_feed_context',
          ],
        ),
        cacheDirectory: dir,
      );

      expect(saved.error, isEmpty);
      expect(saved.candidate, isNotNull);
      expect(saved.attribution, isNotNull);
      expect(saved.candidate!.resourceUrl, saved.attribution!.sourceUrl);
      expect(saved.candidate!.localPath, isNotEmpty);
      expect(await File(saved.candidate!.localPath).readAsBytes(), <int>[
        1,
        2,
        3,
        4,
      ]);
      expect(saved.candidate!.bodySize, 4);
      expect(saved.candidate!.bodyMimeType, 'image/webp');
      expect(saved.candidate!.quality, FeishuNetworkImageQuality.original);
      expect(saved.attribution!.blobSize, 4);
      expect(
        saved.attribution!.evidence,
        contains('browser_preview_blob_body'),
      );
    },
  );

  test('observer message parses browser preview image body payload', () {
    final message = FeishuPageObserverMessage.fromJson(<String, dynamic>{
      'type': 'feishu_monitor_browser_image_body',
      'source_url': 'blob:https://example.feishu.cn/image-1',
      'mime_type': 'image/webp',
      'body_base64': base64Encode(<int>[1, 2, 3, 4]),
      'body_size': 4,
      'width': 805,
      'height': 393,
      'conversation_id': 'feed:alpha',
      'conversation_name': 'Alpha Group',
      'sender_name': 'Alice',
      'display_time': '14:29',
      'message_text': '[Image]',
      'feed_card_id': 'feed_card_1',
      'feed_card_text': 'Alpha Group 14:29 Alice: [Image]',
      'confidence': 0.72,
      'confidence_label': 'medium',
      'reason': 'preview_blob_body',
      'observed_at': '2026-05-10T09:00:00Z',
      'evidence': <String>['browser_preview_blob_body', 'active_feed_context'],
    });

    expect(message.isBrowserImageBody, isTrue);
    expect(message.browserImageBody, isNotNull);
    expect(message.browserImageBody!.sourceUrl, startsWith('blob:'));
    expect(message.browserImageBody!.mimeType, 'image/webp');
    expect(message.browserImageBody!.bodySize, 4);
    expect(message.browserImageBody!.conversationName, 'Alpha Group');
    expect(
      message.browserImageBody!.evidence,
      contains('browser_preview_blob_body'),
    );
  });

  test(
    'browser preview image body resolves against feed placeholder',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'feishu_browser_image_resolver_test_',
      );
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });

      final observedAt = DateTime.utc(2026, 5, 10, 9, 0, 2);
      final saved = await saveFeishuBrowserImageBody(
        FeishuBrowserImageBody(
          sourceUrl: 'blob:https://example.feishu.cn/image-1',
          mimeType: 'image/webp',
          bodyBase64: base64Encode(<int>[1, 2, 3, 4, 5, 6]),
          bodySize: 6,
          width: 805,
          height: 393,
          conversationId: 'feed:alpha',
          conversationName: 'Alpha Group',
          senderName: 'Alice',
          displayTime: '17:00',
          messageText: '[Image]',
          feedCardId: 'alpha',
          feedCardText: 'Alpha Group 17:00 Alice: [Image]',
          confidence: 0.72,
          confidenceLabel: 'medium',
          reason: 'preview_blob_body',
          observedAt: observedAt,
          evidence: const <String>[
            'browser_preview_blob_body',
            'active_feed_context',
          ],
        ),
        cacheDirectory: dir,
      );

      final resolver = FeishuNetworkForwardableImageResolver();
      final result = resolver.resolve(
        candidates: <FeishuNetworkImageCandidate>[saved.candidate!],
        attributions: <FeishuNetworkImageAttribution>[saved.attribution!],
        recentEvents: <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_feed_image',
            dedupeKey: 'feed:alpha:feed_image',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'feed_image',
            senderId: '',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '',
            observedAt: '2026-05-10T09:00:00Z',
            captureSource: 'feed_card_probe',
            imageAttachments: const <MessageImageAttachment>[],
          ),
        ],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(result.events.single.captureSource, 'network_original_image');
      expect(
        result.events.single.imageAttachments.single.localPath,
        isNotEmpty,
      );
    },
  );
}

FeishuNetworkForwardableImageResolution _successfulResolution({
  required List<FeishuNetworkImageCandidate> candidates,
  required List<FeishuNetworkImageAttribution> attributions,
  required List<NormalizedMessageEvent> recentEvents,
}) {
  return FeishuNetworkForwardableImageResolution(
    events: <NormalizedMessageEvent>[_networkImageEvent()],
    skipReason: '',
    decision: const <String, Object?>{'body_sha1': 'sha1alpha'},
  );
}

FeishuNetworkImageCandidate _candidate() {
  return FeishuNetworkImageCandidate(
    conversationId: 'feed:alpha',
    conversationName: 'Alpha Group',
    messageId: 'msg_1',
    senderName: 'Alice',
    resourceUrl: 'https://a.test/image?token=secret',
    resourceKey: 'img_1',
    width: 640,
    height: 480,
    quality: FeishuNetworkImageQuality.original,
    observedAt: DateTime.utc(2026, 5, 10, 4, 30, 2),
    localPath: r'C:\tmp\alpha.webp',
    bodySha1: 'sha1alpha',
    bodySize: 12345,
    bodyMimeType: 'image/webp',
  );
}

FeishuNetworkImageAttribution _attribution() {
  return FeishuNetworkImageAttribution(
    sourceUrl: 'https://a.test/image?token=secret',
    sourceKind: 'blob',
    blobMimeType: 'image/webp',
    blobSize: 12345,
    conversationId: 'feed:alpha',
    conversationName: 'Alpha Group',
    messageId: 'msg_1',
    senderName: 'Alice',
    displayTime: '14:29',
    messageText: '[Image]',
    feedCardId: 'feed_card_1',
    feedCardText: 'Alpha Group 14:29 Alice: [Image]',
    confidence: 0.92,
    confidenceLabel: 'high',
    reason: 'dom_img_src',
    observedAt: DateTime.utc(2026, 5, 10, 4, 30, 1),
    evidence: const <String>['exact_dom_node', 'feed_card_context'],
  );
}

NormalizedMessageEvent _networkImageEvent() {
  return const NormalizedMessageEvent(
    eventId: 'event_network_image_sha1alpha',
    dedupeKey: 'feed:alpha:network_image:sha1alpha',
    accountId: 'account-1',
    conversationId: 'feed:alpha',
    conversationName: 'Alpha Group',
    conversationType: 'group',
    messageId: 'network_image:sha1alpha',
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
