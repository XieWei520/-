import 'dart:io';

import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';

import 'feishu_network_capture.dart';
import 'feishu_page_probe.dart';

typedef FeishuLocalFileExists = bool Function(String path);

class FeishuNetworkForwardableImageResolution {
  const FeishuNetworkForwardableImageResolution({
    required this.events,
    required this.skipReason,
    this.decision,
  });

  final List<NormalizedMessageEvent> events;
  final String skipReason;
  final Map<String, Object?>? decision;
}

class FeishuNetworkForwardableImageResolver {
  FeishuNetworkForwardableImageResolver({
    FeishuLocalFileExists? fileExists,
    this.matchWindow = const Duration(seconds: 8),
  }) : _fileExists = fileExists ?? ((path) => File(path).existsSync());

  final FeishuLocalFileExists _fileExists;
  final Duration matchWindow;

  FeishuNetworkForwardableImageResolution resolve({
    required List<FeishuNetworkImageCandidate> candidates,
    required List<FeishuNetworkImageAttribution> attributions,
    required List<NormalizedMessageEvent> recentEvents,
  }) {
    final localBodyCandidates = candidates.where(_hasSavedLocalBody).toList();
    if (localBodyCandidates.isEmpty) {
      return _skip('missing_local_body');
    }
    if (localBodyCandidates.length > 1) {
      return _skip('ambiguous_candidates');
    }

    final candidate = localBodyCandidates.single;
    if (!_fileExists(candidate.localPath.trim())) {
      return _skip('body_file_missing');
    }

    final matchingAttributions = attributions
        .where((attribution) => attribution.sourceUrl == candidate.resourceUrl)
        .toList();
    if (matchingAttributions.isEmpty) {
      return _skip('attribution_missing');
    }

    final strictAttributions = matchingAttributions
        .where(_isStableFeedCardAttribution)
        .toList();
    if (strictAttributions.isEmpty) {
      return _skip('attribution_not_high_confidence');
    }
    if (strictAttributions.length > 1) {
      return _skip('ambiguous_candidates');
    }

    final attribution = strictAttributions.single;
    if (!_withinWindow(candidate.observedAt, attribution.observedAt)) {
      return _skip('stale_match');
    }

    final feedEvents = recentEvents
        .where(
          (event) => _isMatchingFeedPlaceholder(event, candidate, attribution),
        )
        .toList();
    if (feedEvents.isEmpty) {
      return _skip('feed_placeholder_missing');
    }
    if (feedEvents.length > 1) {
      return _skip('ambiguous_feed_events');
    }

    final feedEvent = feedEvents.single;
    final messageId = 'network_image:${candidate.bodySha1.trim()}';
    final conversationScope = _conversationScope(feedEvent);
    final event = NormalizedMessageEvent(
      eventId: 'event_$messageId',
      dedupeKey: '$conversationScope:$messageId',
      accountId: feedEvent.accountId,
      conversationId: feedEvent.conversationId,
      conversationName: feedEvent.conversationName,
      conversationType: feedEvent.conversationType,
      messageId: messageId,
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
        'candidate_sha1': candidate.bodySha1.trim(),
        'conversation_scope': conversationScope,
      },
    );
  }

  bool _hasSavedLocalBody(FeishuNetworkImageCandidate candidate) {
    return candidate.localPath.trim().isNotEmpty &&
        candidate.bodySha1.trim().isNotEmpty &&
        candidate.bodySize > 0;
  }

  bool _isStableFeedCardAttribution(FeishuNetworkImageAttribution attribution) {
    return attribution.isStable &&
        attribution.evidence.any((item) => item.trim() == 'feed_card_context');
  }

  bool _isMatchingFeedPlaceholder(
    NormalizedMessageEvent event,
    FeishuNetworkImageCandidate candidate,
    FeishuNetworkImageAttribution attribution,
  ) {
    if (event.captureSource.trim() != 'feed_card_probe') {
      return false;
    }
    if (!_isFeedImagePlaceholder(event)) {
      return false;
    }
    if (!_matchesAttributionConversation(event, attribution)) {
      return false;
    }
    final eventObservedAt = DateTime.tryParse(event.observedAt.trim());
    return eventObservedAt != null &&
        _withinWindow(candidate.observedAt, eventObservedAt);
  }

  bool _isFeedImagePlaceholder(NormalizedMessageEvent event) {
    return event.messageType.trim() == 'image' ||
        isFeishuMediaPreviewText(event.text);
  }

  bool _matchesAttributionConversation(
    NormalizedMessageEvent event,
    FeishuNetworkImageAttribution attribution,
  ) {
    final eventConversationId = event.conversationId.trim();
    final attributionConversationId = attribution.conversationId.trim();
    if (eventConversationId.isNotEmpty &&
        attributionConversationId.isNotEmpty) {
      return eventConversationId == attributionConversationId;
    }

    return _normalizedName(event.conversationName) ==
        _normalizedName(attribution.conversationName);
  }

  bool _withinWindow(DateTime left, DateTime right) {
    final difference = left.toUtc().difference(right.toUtc()).abs();
    return difference <= matchWindow;
  }

  String _conversationScope(NormalizedMessageEvent event) {
    final conversationId = event.conversationId.trim();
    if (conversationId.isNotEmpty) {
      return conversationId;
    }
    final conversationName = _normalizedName(event.conversationName);
    return conversationName.isEmpty ? 'unknown' : conversationName;
  }

  String _normalizedName(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }
}

FeishuNetworkForwardableImageResolution _skip(String reason) {
  return FeishuNetworkForwardableImageResolution(
    events: const <NormalizedMessageEvent>[],
    skipReason: reason,
  );
}
