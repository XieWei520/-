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

  test(
    'includes feed placeholder id in strict network image key for ownership',
    () {
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[_candidate()],
        attributions: <FeishuNetworkImageAttribution>[_attribution()],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(messageId: 'feed:owned-card'),
        ],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(
        result.events.single.messageId,
        'network_image:feed_owned-card:sha1alpha',
      );
      expect(
        result.events.single.dedupeKey,
        'feed:alpha:network_image:feed_owned-card:sha1alpha',
      );
    },
  );

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

  test(
    'resolves one existing file among multiple metadata-valid candidates',
    () {
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
    },
  );

  test('matches saved network body to blob attribution by body size', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate(bodySize: 24680)],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(
          sourceUrl: 'blob:https://example.feishu.cn/preview-image',
          sourceKind: 'blob',
          blobSize: 24680,
        ),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
    expect(result.events.single.captureSource, 'network_original_image');
    expect(result.events.single.imageAttachments.single.localPath, _localPath);
  });

  test(
    'accepts active feed context attribution for the matching placeholder',
    () {
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[_candidate(bodySize: 24680)],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: 'blob:https://example.feishu.cn/preview-image',
            sourceKind: 'blob',
            blobSize: 24680,
            confidence: 0.72,
            confidenceLabel: 'medium',
            evidence: const <String>['exact_dom_node', 'active_feed_context'],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[_feedEvent()],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(result.events.single.conversationId, 'feed:alpha');
    },
  );

  test('resolves one strict match among multiple saved candidates', () {
    const betaUrl = 'https://internal-api-lark-file.feishu.cn/beta.webp';
    const betaPath = r'C:\tmp\beta.webp';

    final result = _resolver(existingPaths: <String>{_localPath, betaPath})
        .resolve(
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
    expect(result.events.single.imageAttachments.single.localPath, betaPath);
  });

  test('prefers the largest matching saved body over preview candidates', () {
    const previewUrl = 'https://internal-api-lark-file.feishu.cn/preview.webp';
    const previewPath = r'C:\tmp\preview.webp';
    const originalUrl =
        'https://internal-api-lark-file.feishu.cn/original.webp';
    const originalPath = r'C:\tmp\original.webp';

    final result = _resolver(existingPaths: <String>{previewPath, originalPath})
        .resolve(
          candidates: <FeishuNetworkImageCandidate>[
            _candidate(
              resourceUrl: previewUrl,
              localPath: previewPath,
              bodySha1: 'sha1preview',
              bodySize: 5120,
            ),
            _candidate(
              resourceUrl: originalUrl,
              localPath: originalPath,
              bodySha1: 'sha1original',
              bodySize: 512000,
            ),
          ],
          attributions: <FeishuNetworkImageAttribution>[
            _attribution(sourceUrl: previewUrl),
            _attribution(sourceUrl: originalUrl),
          ],
          recentEvents: <NormalizedMessageEvent>[_feedEvent()],
        );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
    expect(result.events.single.messageId, 'network_image:sha1original');
    expect(
      result.events.single.imageAttachments.single.localPath,
      originalPath,
    );
  });

  test('dedupes repeated blob candidates with the same saved body', () {
    const firstBlob = 'blob:https://example.feishu.cn/first';
    const secondBlob = 'blob:https://example.feishu.cn/second';

    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(
          resourceUrl: firstBlob,
          requestResourceType: 'browser_preview_blob',
        ),
        _candidate(
          resourceUrl: secondBlob,
          requestResourceType: 'browser_preview_blob',
        ),
      ],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(
          sourceUrl: firstBlob,
          sourceKind: 'blob',
          confidence: 0.72,
          confidenceLabel: 'medium',
          reason: 'preview_blob_body',
          evidence: const <String>[
            'browser_preview_blob_body',
            'active_feed_context',
          ],
        ),
        _attribution(
          sourceUrl: secondBlob,
          sourceKind: 'blob',
          confidence: 0.72,
          confidenceLabel: 'medium',
          reason: 'preview_blob_body',
          evidence: const <String>[
            'browser_preview_blob_body',
            'active_feed_context',
          ],
        ),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
    expect(
      result.events.single.messageId,
      'network_image:feed-msg-1:sha1alpha',
    );
    expect(result.events.single.captureSource, 'network_original_image');
  });

  test(
    'emits trimmed local path when candidate path has surrounding whitespace',
    () {
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(localPath: '  $_localPath  '),
        ],
        attributions: <FeishuNetworkImageAttribution>[_attribution()],
        recentEvents: <NormalizedMessageEvent>[_feedEvent()],
      );

      expect(result.skipReason, isEmpty);
      expect(
        result.events.single.imageAttachments.single.localPath,
        _localPath,
      );
    },
  );

  test(
    'rejects multiple metadata-valid candidates when no local files exist',
    () {
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
    },
  );

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
    const betaUrl = 'https://internal-api-lark-file.feishu.cn/beta.webp';
    const betaPath = r'C:\tmp\beta.webp';

    final result = _resolver(existingPaths: <String>{_localPath, betaPath})
        .resolve(
          candidates: <FeishuNetworkImageCandidate>[
            _candidate(),
            _candidate(
              resourceUrl: betaUrl,
              localPath: betaPath,
              bodySha1: 'sha1beta',
            ),
          ],
          attributions: <FeishuNetworkImageAttribution>[
            _attribution(),
            _attribution(
              sourceUrl: betaUrl,
              conversationId: 'feed:beta',
              conversationName: 'Beta Group',
            ),
          ],
          recentEvents: <NormalizedMessageEvent>[
            _feedEvent(),
            _feedEvent(
              messageId: 'feed-beta',
              conversationId: 'feed:beta',
              conversationName: 'Beta Group',
            ),
          ],
        );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'ambiguous_candidates');
  });

  test('rejects multiple strict attributions as ambiguous candidates', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(),
        _attribution(observedAt: _candidateObservedAt),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'ambiguous_candidates');
  });

  test('rejects feed placeholder outside attribution window', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(
          observedAt: _candidateObservedAt.add(const Duration(seconds: 8)),
        ),
      ],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(observedAt: '2026-05-10T04:29:59Z'),
      ],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'feed_placeholder_missing');
  });

  test('rejects one-sided missing conversation id even when names match', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(conversationId: ''),
      ],
      recentEvents: <NormalizedMessageEvent>[_feedEvent()],
    );

    expect(result.events, isEmpty);
    expect(result.skipReason, 'feed_placeholder_missing');
  });

  test('allows name fallback when both conversation ids are missing', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(conversationId: ''),
      ],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(conversationId: '', conversationName: ' alpha   group '),
      ],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
    expect(result.events.single.conversationName, 'alpha group');
  });

  test(
    'allows name fallback when synthesized feed ids differ for same group',
    () {
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[_candidate()],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            conversationId: 'feed:e43dee61',
            conversationName: 'Alpha Group',
            evidence: const <String>[
              'exact_dom_node',
              'feed_card_context',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(
            conversationId: 'feed:2e500f14',
            conversationName: ' alpha   group ',
          ),
        ],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(result.events.single.conversationId, 'feed:2e500f14');
    },
  );

  test(
    'rejects synthesized feed id name fallback when sender names differ',
    () {
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[_candidate()],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            conversationId: 'feed:e43dee61',
            conversationName: 'Alpha Group',
            senderName: 'Alice',
            evidence: const <String>[
              'exact_dom_node',
              'feed_card_context',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(
            conversationId: 'feed:2e500f14',
            conversationName: ' alpha   group ',
            senderName: 'Bob',
          ),
        ],
      );

      expect(result.events, isEmpty);
      expect(result.skipReason, 'feed_placeholder_missing');
    },
  );

  test(
    'rejects mismatched non-feed conversation ids even when names match',
    () {
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[_candidate()],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(conversationId: 'oc_b', conversationName: 'Alpha Group'),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(conversationId: 'oc_a', conversationName: 'Alpha Group'),
        ],
      );

      expect(result.events, isEmpty);
      expect(result.skipReason, 'feed_placeholder_missing');
    },
  );

  test('accepts uppercase image message type', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(messageType: 'IMAGE', text: ''),
      ],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
  });

  test('accepts feed capture source with surrounding whitespace', () {
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[_candidate()],
      attributions: <FeishuNetworkImageAttribution>[_attribution()],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(captureSource: '  feed_card_probe  '),
      ],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
  });

  test(
    'uses dom image placeholder as anchor while emitting network original image',
    () {
      const blobUrl = 'blob:https://example.feishu.cn/preview-image';
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            resourceUrl: blobUrl,
            bodySize: 11752,
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: blobUrl,
            sourceKind: 'blob',
            blobSize: 11752,
            confidence: 0.72,
            confidenceLabel: 'medium',
            reason: 'preview_blob_body',
            evidence: const <String>[
              'browser_preview_blob_body',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(
            captureSource: 'dom_probe',
            messageType: 'image',
            text: '[图片]',
          ),
        ],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(result.events.single.captureSource, 'network_original_image');
      expect(
        result.events.single.imageAttachments.single.localPath,
        _localPath,
      );
      expect(result.events.single.imageAttachments.single.sourceUrl, blobUrl);
    },
  );

  test('prefers a single feed placeholder over matching dom placeholder', () {
    const blobUrl = 'blob:https://example.feishu.cn/preview-image';
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(
          resourceUrl: blobUrl,
          bodySize: 11752,
          requestResourceType: 'browser_preview_blob',
        ),
      ],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(
          sourceUrl: blobUrl,
          sourceKind: 'blob',
          blobSize: 11752,
          conversationId: 'feed:dom',
          confidence: 0.72,
          confidenceLabel: 'medium',
          reason: 'preview_blob_body',
          evidence: const <String>[
            'browser_preview_blob_body',
            'active_feed_context',
          ],
        ),
      ],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(
          messageId: 'feed-msg',
          conversationId: 'feed:feed',
          captureSource: 'feed_card_probe',
          messageType: 'text',
          text: '[图片]',
        ),
        _feedEvent(
          messageId: 'dom-msg',
          conversationId: 'feed:dom',
          captureSource: 'dom_probe',
          messageType: 'image',
          text: '[图片]',
        ),
      ],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
    expect(result.events.single.captureSource, 'network_original_image');
    expect(result.events.single.conversationId, 'feed:feed');
    expect(
      result.events.single.dedupeKey,
      'feed:feed:network_image:feed-msg:sha1alpha',
    );
  });

  test(
    'uses matching dom placeholder id for repeated preview body key while preserving feed route scope',
    () {
      const blobUrl = 'blob:https://example.feishu.cn/repeated-preview-image';
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            resourceUrl: blobUrl,
            bodySize: 11752,
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: blobUrl,
            sourceKind: 'blob',
            blobSize: 11752,
            conversationId: 'feed:dom',
            confidence: 0.72,
            confidenceLabel: 'medium',
            reason: 'preview_blob_body',
            evidence: const <String>[
              'browser_preview_blob_body',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(
            messageId: 'feed:repeat',
            conversationId: 'feed:route',
            captureSource: 'feed_card_probe',
            messageType: 'text',
            text: '[图片]',
          ),
          _feedEvent(
            messageId: '7638302211604221106',
            conversationId: 'feed:dom',
            captureSource: 'dom_probe',
            messageType: 'image',
            text: '[图片]',
          ),
        ],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(result.events.single.conversationId, 'feed:route');
      expect(
        result.events.single.messageId,
        'network_image:feed_repeat:7638302211604221106:sha1alpha',
      );
      expect(
        result.events.single.dedupeKey,
        'feed:route:network_image:feed_repeat:7638302211604221106:sha1alpha',
      );
    },
  );

  test(
    'keeps feed placeholder id in browser preview key when dom anchor is used',
    () {
      const blobUrl = 'blob:https://example.feishu.cn/repeated-preview-image';
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            resourceUrl: blobUrl,
            bodySize: 11752,
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: blobUrl,
            sourceKind: 'blob',
            blobSize: 11752,
            conversationId: 'feed:dom',
            confidence: 0.72,
            confidenceLabel: 'medium',
            reason: 'preview_blob_body',
            evidence: const <String>[
              'browser_preview_blob_body',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(
            messageId: 'feed:coarse-card',
            conversationId: 'feed:route',
            captureSource: 'feed_card_probe',
            messageType: 'text',
            text: '[Image]',
          ),
          _feedEvent(
            messageId: '7638302211604221106',
            conversationId: 'feed:dom',
            captureSource: 'dom_probe',
            messageType: 'image',
            text: '[Image]',
          ),
        ],
      );

      expect(result.skipReason, isEmpty);
      expect(
        result.events.single.messageId,
        'network_image:feed_coarse-card:7638302211604221106:sha1alpha',
      );
    },
  );

  test(
    'waits for dom placeholder before emitting preview blob for synthetic feed placeholder',
    () {
      const blobUrl = 'blob:https://example.feishu.cn/pending-preview-image';
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            resourceUrl: blobUrl,
            bodySize: 11752,
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: blobUrl,
            sourceKind: 'blob',
            blobSize: 11752,
            conversationId: 'feed:route',
            confidence: 0.72,
            confidenceLabel: 'medium',
            reason: 'preview_blob_body',
            evidence: const <String>[
              'browser_preview_blob_body',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(
            messageId: 'feed:coarse-card',
            conversationId: 'feed:route',
            captureSource: 'feed_card_probe',
            messageType: 'text',
            text: '[图片]',
          ),
        ],
      );

      expect(result.events, isEmpty);
      expect(result.skipReason, 'dom_placeholder_pending');
    },
  );

  test('uses delayed dom placeholder id for browser preview body', () {
    const blobUrl = 'blob:https://example.feishu.cn/delayed-preview-image';
    final result = _resolver().resolve(
      candidates: <FeishuNetworkImageCandidate>[
        _candidate(
          resourceUrl: blobUrl,
          bodySize: 11752,
          requestResourceType: 'browser_preview_blob',
        ),
      ],
      attributions: <FeishuNetworkImageAttribution>[
        _attribution(
          sourceUrl: blobUrl,
          sourceKind: 'blob',
          blobSize: 11752,
          conversationId: 'feed:dom',
          confidence: 0.72,
          confidenceLabel: 'medium',
          reason: 'preview_blob_body',
          evidence: const <String>[
            'browser_preview_blob_body',
            'active_feed_context',
          ],
        ),
      ],
      recentEvents: <NormalizedMessageEvent>[
        _feedEvent(
          messageId: 'feed:coarse-card',
          conversationId: 'feed:route',
          captureSource: 'feed_card_probe',
          messageType: 'text',
          text: '[鍥剧墖]',
        ),
        _feedEvent(
          messageId: '7638506295401663709',
          conversationId: 'feed:dom',
          captureSource: 'dom_probe',
          messageType: 'image',
          text: '[鍥剧墖]',
          observedAt: '2026-05-10T04:38:30Z',
        ),
      ],
    );

    expect(result.skipReason, isEmpty);
    expect(result.events, hasLength(1));
    expect(result.events.single.conversationId, 'feed:route');
    expect(
      result.events.single.messageId,
      'network_image:feed_coarse-card:7638506295401663709:sha1alpha',
    );
    expect(
      result.events.single.dedupeKey,
      'feed:route:network_image:feed_coarse-card:7638506295401663709:sha1alpha',
    );
  });

  test(
    'does not reuse stale delayed dom anchor for newer feed placeholder',
    () {
      const blobUrl = 'blob:https://example.feishu.cn/new-preview-image';
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            resourceUrl: blobUrl,
            bodySize: 11752,
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: blobUrl,
            sourceKind: 'blob',
            blobSize: 11752,
            conversationId: 'feed:alpha',
            confidence: 0.72,
            confidenceLabel: 'medium',
            reason: 'preview_blob_body',
            evidence: const <String>[
              'browser_preview_blob_body',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(
            messageId: 'feed:new-card',
            conversationId: 'feed:alpha',
            captureSource: 'feed_card_probe',
            messageType: 'text',
            text: '[Image]',
            observedAt: '2026-05-10T04:30:02Z',
          ),
          _feedEvent(
            messageId: '7638506295401663709',
            conversationId: 'feed:alpha',
            captureSource: 'dom_probe',
            messageType: 'image',
            text: '[Image]',
            observedAt: '2026-05-10T04:20:30Z',
          ),
        ],
      );

      expect(result.events, isEmpty);
      expect(result.skipReason, 'dom_placeholder_pending');
    },
  );

  test(
    'includes feed placeholder id in network image key for repeated image bodies',
    () {
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            bodySha1: 'same-image-body',
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[_attribution()],
        recentEvents: <NormalizedMessageEvent>[
          _feedEvent(messageId: 'feed-second-send'),
        ],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(
        result.events.single.messageId,
        'network_image:feed-second-send:same-image-body',
      );
      expect(
        result.events.single.dedupeKey,
        'feed:alpha:network_image:feed-second-send:same-image-body',
      );
    },
  );

  test(
    'rejects multiple browser preview body matches for one feed placeholder',
    () {
      const firstBlobUrl = 'blob:https://example.feishu.cn/preview-image-1';
      const secondBlobUrl = 'blob:https://example.feishu.cn/preview-image-2';
      const secondLocalPath = r'C:\tmp\beta.webp';

      final result =
          _resolver(
            existingPaths: <String>{_localPath, secondLocalPath},
          ).resolve(
            candidates: <FeishuNetworkImageCandidate>[
              _candidate(
                resourceUrl: firstBlobUrl,
                bodySize: 11752,
                bodySha1: 'sha1alpha',
                requestResourceType: 'browser_preview_blob',
              ),
              _candidate(
                resourceUrl: secondBlobUrl,
                localPath: secondLocalPath,
                bodySize: 28752,
                bodySha1: 'sha1beta',
                requestResourceType: 'browser_preview_blob',
              ),
            ],
            attributions: <FeishuNetworkImageAttribution>[
              _attribution(
                sourceUrl: firstBlobUrl,
                sourceKind: 'blob',
                blobSize: 11752,
                conversationId: 'feed:alpha',
                confidence: 0.72,
                confidenceLabel: 'medium',
                reason: 'preview_blob_body',
                evidence: const <String>[
                  'browser_preview_blob_body',
                  'active_feed_context',
                ],
              ),
              _attribution(
                sourceUrl: secondBlobUrl,
                sourceKind: 'blob',
                blobSize: 28752,
                conversationId: 'feed:alpha',
                confidence: 0.72,
                confidenceLabel: 'medium',
                reason: 'preview_blob_body',
                evidence: const <String>[
                  'browser_preview_blob_body',
                  'active_feed_context',
                ],
              ),
            ],
            recentEvents: <NormalizedMessageEvent>[
              _feedEvent(messageId: '7638506295401663709'),
            ],
          );

      expect(result.events, isEmpty);
      expect(result.skipReason, 'ambiguous_candidates');
    },
  );

  test(
    'uses active feed preview body when feed placeholder is not present',
    () {
      const blobUrl = 'blob:https://example.feishu.cn/active-preview-image';
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            resourceUrl: blobUrl,
            bodySha1: 'sha1active',
            bodySize: 19148,
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: blobUrl,
            sourceKind: 'blob',
            blobSize: 19148,
            conversationId: 'feed:active',
            conversationName: '泡沫之家 昨天 橘生淮南',
            senderName: '橘生淮南',
            messageId: '',
            feedCardId: '5aaf5967',
            feedCardText: '泡沫之家 昨天 橘生淮南: [图片]',
            confidence: 0.72,
            confidenceLabel: 'medium',
            reason: 'preview_blob_body',
            evidence: const <String>[
              'browser_preview_blob_body',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: const <NormalizedMessageEvent>[],
      );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(result.events.single.captureSource, 'network_original_image');
      expect(result.events.single.conversationId, 'feed:active');
      expect(result.events.single.conversationName, '泡沫之家');
      expect(result.events.single.senderName, '橘生淮南');
      expect(
        result.events.single.messageId,
        'network_image:5aaf5967:sha1active',
      );
      expect(
        result.events.single.dedupeKey,
        'feed:active:network_image:5aaf5967:sha1active',
      );
    },
  );

  test(
    'uses the only matching active feed preview body among older saved candidates',
    () {
      const activeBlobUrl =
          'blob:https://example.feishu.cn/active-preview-image';
      const staleBlobUrl = 'blob:https://example.feishu.cn/stale-preview-image';
      const staleLocalPath = r'C:\tmp\stale.webp';

      final result =
          _resolver(
            existingPaths: <String>{_localPath, staleLocalPath},
          ).resolve(
            candidates: <FeishuNetworkImageCandidate>[
              _candidate(
                resourceUrl: activeBlobUrl,
                bodySha1: 'sha1active',
                bodySize: 19148,
                requestResourceType: 'browser_preview_blob',
              ),
              _candidate(
                resourceUrl: staleBlobUrl,
                localPath: staleLocalPath,
                bodySha1: 'sha1stale',
                bodySize: 99148,
                observedAt: _candidateObservedAt.subtract(
                  const Duration(minutes: 30),
                ),
                requestResourceType: 'browser_preview_blob',
              ),
            ],
            attributions: <FeishuNetworkImageAttribution>[
              _attribution(
                sourceUrl: activeBlobUrl,
                sourceKind: 'blob',
                blobSize: 19148,
                conversationId: 'feed:active',
                conversationName: '泡沫之家 昨天 橘生淮南',
                senderName: '橘生淮南',
                messageId: '',
                feedCardId: '5aaf5967',
                feedCardText: '泡沫之家 昨天 橘生淮南: [图片]',
                confidence: 0.72,
                confidenceLabel: 'medium',
                reason: 'preview_blob_body',
                evidence: const <String>[
                  'browser_preview_blob_body',
                  'active_feed_context',
                ],
              ),
            ],
            recentEvents: const <NormalizedMessageEvent>[],
          );

      expect(result.skipReason, isEmpty);
      expect(result.events, hasLength(1));
      expect(result.events.single.conversationId, 'feed:active');
      expect(result.events.single.conversationName, '泡沫之家');
      expect(
        result.events.single.messageId,
        'network_image:5aaf5967:sha1active',
      );
      expect(
        result.events.single.imageAttachments.single.localPath,
        _localPath,
      );
    },
  );

  test(
    'rejects active feed preview fallback when image body was resolved for another conversation',
    () {
      const blobUrl = 'blob:https://example.feishu.cn/reused-preview-image';
      final result = _resolver().resolve(
        candidates: <FeishuNetworkImageCandidate>[
          _candidate(
            resourceUrl: blobUrl,
            bodySha1: 'sha1reused',
            bodySize: 19148,
            requestResourceType: 'browser_preview_blob',
          ),
        ],
        attributions: <FeishuNetworkImageAttribution>[
          _attribution(
            sourceUrl: blobUrl,
            sourceKind: 'blob',
            blobSize: 19148,
            conversationId: 'feed:beta',
            conversationName: 'Beta Group',
            senderName: 'Bob',
            messageId: '',
            feedCardId: '7639011855205158086',
            feedCardText: 'Beta Group yesterday Bob: [Image]',
            confidence: 0.72,
            confidenceLabel: 'medium',
            reason: 'preview_blob_body',
            evidence: const <String>[
              'browser_preview_blob_body',
              'active_feed_context',
            ],
          ),
        ],
        recentEvents: const <NormalizedMessageEvent>[
          NormalizedMessageEvent(
            eventId: 'event_network_image_alpha',
            dedupeKey: 'feed:alpha:network_image:feed_alpha:sha1reused',
            accountId: '',
            conversationId: 'feed:alpha',
            conversationName: 'Alpha Group',
            conversationType: 'unknown',
            messageId: 'network_image:feed_alpha:sha1reused',
            senderId: '',
            senderName: 'Alice',
            messageType: 'image',
            text: '[Image]',
            sentAt: '',
            observedAt: '2026-05-10T04:29:30Z',
            captureSource: 'network_original_image',
            imageAttachments: <MessageImageAttachment>[
              MessageImageAttachment(
                sourceUrl: 'blob:https://example.feishu.cn/alpha-preview',
                localPath: r'C:\tmp\sha1reused.webp',
                width: 640,
                height: 480,
              ),
            ],
          ),
        ],
      );

      expect(result.events, isEmpty);
      expect(result.skipReason, 'feed_placeholder_missing');
    },
  );

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
  String requestResourceType = '',
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
    requestResourceType: requestResourceType,
  );
}

FeishuNetworkImageAttribution _attribution({
  String sourceUrl = _imageUrl,
  String sourceKind = 'network_body',
  int blobSize = 12345,
  String conversationId = 'feed:alpha',
  String conversationName = 'Alpha Group',
  String senderName = 'Alice',
  String messageId = 'message-alpha',
  String feedCardId = 'feed-card-alpha',
  String feedCardText = '[Image]',
  double confidence = 0.95,
  String confidenceLabel = 'high',
  String reason = 'exact feed card match',
  List<String> evidence = const <String>['exact_dom_node', 'feed_card_context'],
  DateTime? observedAt,
}) {
  return FeishuNetworkImageAttribution(
    sourceUrl: sourceUrl,
    sourceKind: sourceKind,
    blobMimeType: 'image/webp',
    blobSize: blobSize,
    conversationId: conversationId,
    conversationName: conversationName,
    messageId: messageId,
    senderName: senderName,
    displayTime: '',
    messageText: '[Image]',
    feedCardId: feedCardId,
    feedCardText: feedCardText,
    confidence: confidence,
    confidenceLabel: confidenceLabel,
    reason: reason,
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
  String captureSource = 'feed_card_probe',
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
    captureSource: captureSource,
  );
}
