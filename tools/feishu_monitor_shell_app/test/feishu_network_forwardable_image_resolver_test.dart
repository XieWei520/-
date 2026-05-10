import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_capture.dart';
import 'package:feishu_monitor_shell_app/src/feishu_network_forwardable_image_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

const _imageUrl =
    'https://internal-api-lark-file.feishu.cn/static-resource/v1/alpha.webp?token=secret';
const _localPath = r'C:\tmp\alpha.webp';
final _candidateObservedAt = DateTime.utc(2026, 5, 10, 4, 30);

void main() {
  test('creates network_original_image event for one strict match', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));

    final event = result.events.single;
    expect(event.captureSource, 'network_original_image');
    expect(event.conversationId, 'feed:alpha');
    expect(event.conversationName, 'Alpha Group');
    expect(event.conversationType, 'group');
    expect(event.accountId, 'account-1');
    expect(event.senderId, 'sender-1');
    expect(event.senderName, 'Alice');
    expect(event.sentAt, '2026-05-10T04:29:59Z');
    expect(event.messageType, 'image');
    expect(event.text, '[Image]');
    expect(event.messageId, 'network_image:sha1alpha');
    expect(event.dedupeKey, 'feed:alpha:network_image:sha1alpha');
    expect(event.imageAttachments, hasLength(1));
    expect(event.imageAttachments.single.sourceUrl, _imageUrl);
    expect(event.imageAttachments.single.localPath, _localPath);
    expect(event.imageAttachments.single.width, 640);
    expect(event.imageAttachments.single.height, 480);
  });

  test('rejects candidate without local body', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(localPath: '', bodySha1: '', bodySize: 0),
      ],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'missing_local_body');
  });

  test('rejects missing local file', () {
    final result = _resolver(existingPaths: <String>{}).resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'body_file_missing');
  });

  test('resolves one existing file among multiple metadata-valid candidates', () {
    const betaUrl = 'https://internal-api-lark-file.feishu.cn/beta.webp';
    const betaPath = r'C:\tmp\beta.webp';

    final result = _resolver(existingPaths: <String>{betaPath}).resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(),
        _candidate(
          resourceUrl: betaUrl,
          localPath: betaPath,
          bodySha1: 'sha1beta',
        ),
      ],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(sourceUrl: betaUrl),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
    expect(result.events.single.messageId, 'network_image:sha1beta');
    expect(result.events.single.imageAttachments.single.sourceUrl, betaUrl);
    expect(result.events.single.imageAttachments.single.localPath, betaPath);
  });

  test('rejects multiple metadata-valid candidates when no local files exist', () {
    final result = _resolver(existingPaths: <String>{}).resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(),
        _candidate(
          resourceUrl: 'https://internal-api-lark-file.feishu.cn/beta.webp',
          localPath: r'C:\tmp\beta.webp',
          bodySha1: 'sha1beta',
        ),
      ],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'body_file_missing');
  });

  test('rejects medium confidence attribution', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(confidence: 0.79, confidenceLabel: 'medium'),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'attribution_not_high_confidence');
  });

  test('rejects attribution without feed_card_context evidence', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(evidence: const <String>['exact_dom_node']),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'attribution_not_high_confidence');
  });

  test('rejects when feed image placeholder is missing', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(messageType: 'text', text: 'ordinary text'),
      ],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'feed_placeholder_missing');
  });

  test('rejects ambiguous candidates', () {
    final result =
        _resolver(
          existingPaths: <String>{_localPath, r'C:\tmp\beta.webp'},
        ).resolve(
          candidates: <FeishuNetworkImageCandidate>[
            _candidate(),
            _candidate(
              resourceUrl: 'https://internal-api-lark-file.feishu.cn/beta.webp',
              localPath: r'C:\tmp\beta.webp',
              bodySha1: 'sha1beta',
            ),
          ],
          attributions: <FeishuNetworkImageAttribution>[_attribution()],
          recentEvents: <NormalizedMessageEvent>[_feedEvent()],
        );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'ambiguous_candidates');
  });

  test('rejects ambiguous feed image events', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(messageId: 'feed-msg-1'),
        _feedEvent(messageId: 'feed-msg-2'),
      ],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'ambiguous_feed_events');
  });
}

FeishuNetworkForwardableImageResolver _resolver({
  Set<String> existingPaths = const <String>{_localPath},
}) {
  return FeishuNetworkForwardableImageResolver(
    fileExists: existingPaths.contains,
  );
}

FeishuNetworkImageCandidate _candidate({
  String resourceUrl = _imageUrl,
  String localPath = _localPath,
  String bodySha1 = 'sha1alpha',
  int bodySize = 12345,
  DateTime? observedAt,
}) {
  return FeishuNetworkImageCandidate(
    conversationId: '',
    conversationName: '',
    messageId: '',
    senderName: '',
    resourceUrl: resourceUrl,
    resourceKey: 'alpha',
    width: 640,
    height: 480,
    quality: FeishuNetworkImageQuality.original,
    observedAt: observedAt ?? _candidateObservedAt,
    localPath: localPath,
    bodySha1: bodySha1,
    bodySize: bodySize,
    bodyMimeType: 'image/webp',
  );
}

FeishuNetworkImageAttribution _attribution({
  String sourceUrl = _imageUrl,
  String conversationId = 'feed:alpha',
  String conversationName = 'Alpha Group',
  String senderName = 'Alice',
  double confidence = 0.95,
  String confidenceLabel = 'high',
  List<String> evidence = const <String>['exact_dom_node', 'feed_card_context'],
  DateTime? observedAt,
}) {
  return FeishuNetworkImageAttribution(
    sourceUrl: sourceUrl,
    sourceKind: 'network_body',
    blobMimeType: 'image/webp',
    blobSize: 12345,
    conversationId: conversationId,
    conversationName: conversationName,
    messageId: 'message-alpha',
    senderName: senderName,
    displayTime: '',
    messageText: '[Image]',
    feedCardId: 'feed-card-alpha',
    feedCardText: '[Image]',
    confidence: confidence,
    confidenceLabel: confidenceLabel,
    reason: 'exact feed card match',
    observedAt:
        observedAt ?? _candidateObservedAt.add(const Duration(seconds: 1)),
    evidence: evidence,
  );
}

NormalizedMessageEvent _feedEvent({
  String messageId = 'feed-msg-1',
  String conversationId = 'feed:alpha',
  String conversationName = 'Alpha Group',
  String messageType = 'image',
  String text = '[Image]',
  String senderName = 'Alice',
  String observedAt = '2026-05-10T04:30:02Z',
}) {
  return NormalizedMessageEvent(
    eventId: 'event_$messageId',
    dedupeKey: '$conversationId:$messageId',
    accountId: 'account-1',
    conversationId: conversationId,
    conversationName: conversationName,
    conversationType: 'group',
    messageId: messageId,
    senderId: 'sender-1',
    senderName: senderName,
    messageType: messageType,
    text: text,
    sentAt: '2026-05-10T04:29:59Z',
    observedAt: observedAt,
    captureSource: 'feed_card_probe',
  );
}
