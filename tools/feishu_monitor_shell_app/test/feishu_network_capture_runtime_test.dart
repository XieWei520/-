import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:feishu_monitor_shell_app/main.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_forwardable_image_resolver.dart';
import 'package:feishu_monitor_shell_app/src/feishu_page_observer.dart';
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

  test('shell exposes strict no-DOM forwarding policy', () {
    expect(feishuStrictNoDomForwardingEnabled, isTrue);
    expect(feishuStrictNoDomForwardingReason, 'strict_no_dom_forwarding');
  });

  test('shell reports media opening disabled by strict no-DOM policy', () {
    final diagnostic = feishuStrictNoDomOpenResult();

    expect(diagnostic['attempted'], isFalse);
    expect(diagnostic['opened'], isFalse);
    expect(diagnostic['reason'], 'strict_no_dom_forwarding');
  });

  test('strict no-DOM open result is safe for status diagnostics', () {
    final diagnostic = feishuStrictNoDomOpenResult();

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
