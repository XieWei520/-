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
    this.domAnchorWindow = const Duration(minutes: 15),
  }) : _fileExists = fileExists ?? ((path) => File(path).existsSync());

  final FeishuLocalFileExists _fileExists;
  final Duration matchWindow;
  final Duration domAnchorWindow;

  FeishuNetworkForwardableImageResolution resolve({
    required List<FeishuNetworkImageCandidate> candidates,
    required List<FeishuNetworkImageAttribution> attributions,
    required List<NormalizedMessageEvent> recentEvents,
  }) {
    final localBodyCandidates = candidates.where(_hasSavedLocalBody).toList();
    if (localBodyCandidates.isEmpty) {
      return _skip('missing_local_body');
    }

    final existingBodyCandidates = _dedupeSavedBodyCandidates(
      localBodyCandidates
          .map(
            (candidate) =>
                (candidate: candidate, localPath: candidate.localPath.trim()),
          )
          .where((entry) => _fileExists(entry.localPath))
          .toList(),
    );
    if (existingBodyCandidates.isEmpty) {
      return _skip('body_file_missing');
    }
    final completeMatches =
        <
          ({
            FeishuNetworkImageCandidate candidate,
            String localPath,
            FeishuNetworkImageAttribution attribution,
            NormalizedMessageEvent feedEvent,
            NormalizedMessageEvent messageIdEvent,
          })
        >[];
    var sawAnyAttribution = false;
    var sawStrictAttribution = false;
    var sawFreshAttribution = false;
    var sawAmbiguousFeedEvents = false;
    var sawPendingDomPlaceholder = false;
    var sawMatchingFeedPlaceholder = false;

    for (final entry in existingBodyCandidates) {
      final candidate = entry.candidate;
      final matchingAttributions = attributions
          .where(
            (attribution) => _isMatchingAttribution(candidate, attribution),
          )
          .toList();
      sawAnyAttribution |= matchingAttributions.isNotEmpty;

      final strictAttributions = _preferredAttributionsForCandidate(
        candidate,
        matchingAttributions.where(_isStableFeedCardAttribution).toList(),
      );
      sawStrictAttribution |= strictAttributions.isNotEmpty;

      for (final attribution in strictAttributions) {
        if (!_withinWindow(candidate.observedAt, attribution.observedAt)) {
          continue;
        }
        sawFreshAttribution = true;

        final matchingPlaceholderEvents = recentEvents
            .where(
              (event) =>
                  _isMatchingFeedPlaceholder(event, candidate, attribution),
            )
            .toList();
        final feedEvents = _selectMatchingFeedPlaceholders(
          matchingPlaceholderEvents,
        );
        if (feedEvents.isNotEmpty) {
          sawMatchingFeedPlaceholder = true;
        }
        if (feedEvents.length > 1) {
          sawAmbiguousFeedEvents = true;
          continue;
        }
        if (feedEvents.length == 1) {
          final feedEvent = feedEvents.single;
          final messageIdEvent = _selectMessageIdAnchorEvent(
            candidate: candidate,
            attribution: attribution,
            routeEvent: feedEvent,
            matchingEvents: matchingPlaceholderEvents,
            recentEvents: recentEvents,
          );
          if (_requiresDomMessageIdAnchor(candidate, feedEvent) &&
              identical(messageIdEvent, feedEvent)) {
            sawPendingDomPlaceholder = true;
            continue;
          }
          completeMatches.add((
            candidate: candidate,
            localPath: entry.localPath,
            attribution: attribution,
            feedEvent: feedEvent,
            messageIdEvent: messageIdEvent,
          ));
        }
      }
    }

    if (completeMatches.isEmpty) {
      final fallbackMatch = _resolveActiveFeedPreviewFallback(
        existingBodyCandidates,
        attributions,
        recentEvents,
      );
      if (fallbackMatch != null && !sawMatchingFeedPlaceholder) {
        return fallbackMatch;
      }
      if (!sawAnyAttribution) {
        return _skip('attribution_missing');
      }
      if (!sawStrictAttribution) {
        return _skip('attribution_not_high_confidence');
      }
      if (!sawFreshAttribution) {
        return _skip('stale_match');
      }
      if (sawAmbiguousFeedEvents) {
        return _skip('ambiguous_feed_events');
      }
      if (sawPendingDomPlaceholder) {
        return _skip('dom_placeholder_pending');
      }
      return _skip('feed_placeholder_missing');
    }
    if (completeMatches.length > 1) {
      if (completeMatches.any(
        (match) =>
            match.candidate.requestResourceType.trim() ==
            'browser_preview_blob',
      )) {
        return _skip('ambiguous_candidates');
      }
      final largestMatch = _singleLargestMatch(completeMatches);
      if (largestMatch == null) {
        return _skip('ambiguous_candidates');
      }
      completeMatches
        ..clear()
        ..add(largestMatch);
    }

    final selectedMatch = completeMatches.single;
    final candidate = selectedMatch.candidate;
    final localPath = selectedMatch.localPath;
    final attribution = selectedMatch.attribution;
    final feedEvent = selectedMatch.feedEvent;
    final messageId = _networkImageMessageId(
      candidate,
      routeEvent: feedEvent,
      messageIdEvent: selectedMatch.messageIdEvent,
    );
    final conversationScope = _conversationScope(feedEvent);
    final event = NormalizedMessageEvent(
      eventId: 'event_$messageId',
      dedupeKey: '$conversationScope:$messageId',
      accountId: feedEvent.accountId,
      conversationId: feedEvent.conversationId,
      conversationName: _normalizedConversationName(
        feedEvent.conversationName,
        attribution.conversationName,
      ),
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
          localPath: localPath,
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
    if (attribution.isStable &&
        attribution.evidence.any(
          (item) => item.trim() == 'feed_card_context',
        )) {
      return true;
    }
    return attribution.confidence >= 0.7 &&
        attribution.confidenceLabel == 'medium' &&
        attribution.conversationName.trim().isNotEmpty &&
        attribution.evidence.any(
          (item) => item.trim() == 'active_feed_context',
        );
  }

  List<FeishuNetworkImageAttribution> _preferredAttributionsForCandidate(
    FeishuNetworkImageCandidate candidate,
    List<FeishuNetworkImageAttribution> attributions,
  ) {
    if (candidate.requestResourceType.trim() != 'browser_preview_blob') {
      return attributions;
    }
    final exactBrowserBodyAttributions = attributions
        .where(
          (attribution) =>
              attribution.sourceUrl == candidate.resourceUrl &&
              attribution.reason.trim() == 'preview_blob_body' &&
              attribution.blobSize == candidate.bodySize &&
              attribution.evidence.any(
                (item) => item.trim() == 'browser_preview_blob_body',
              ),
        )
        .toList();
    if (exactBrowserBodyAttributions.isNotEmpty) {
      return exactBrowserBodyAttributions;
    }
    final browserBodyAttributions = attributions
        .where(
          (attribution) =>
              attribution.reason.trim() == 'preview_blob_body' &&
              attribution.blobSize == candidate.bodySize &&
              attribution.evidence.any(
                (item) => item.trim() == 'browser_preview_blob_body',
              ),
        )
        .toList();
    return browserBodyAttributions.isEmpty
        ? attributions
        : browserBodyAttributions;
  }

  bool _isMatchingAttribution(
    FeishuNetworkImageCandidate candidate,
    FeishuNetworkImageAttribution attribution,
  ) {
    if (attribution.sourceUrl == candidate.resourceUrl) {
      return true;
    }
    return attribution.sourceKind.trim() == 'blob' &&
        attribution.blobSize > 0 &&
        attribution.blobSize == candidate.bodySize;
  }

  bool _isMatchingFeedPlaceholder(
    NormalizedMessageEvent event,
    FeishuNetworkImageCandidate candidate,
    FeishuNetworkImageAttribution attribution,
  ) {
    if (!_canUsePlaceholderEvent(event, candidate, attribution)) {
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
        _withinWindow(candidate.observedAt, eventObservedAt) &&
        _withinWindow(attribution.observedAt, eventObservedAt);
  }

  List<NormalizedMessageEvent> _selectMatchingFeedPlaceholders(
    List<NormalizedMessageEvent> events,
  ) {
    final feedEvents = events
        .where((event) => event.captureSource.trim() == 'feed_card_probe')
        .toList(growable: false);
    if (feedEvents.length == 1) {
      return feedEvents;
    }
    if (feedEvents.length > 1) {
      return feedEvents;
    }
    return events
        .where((event) => event.captureSource.trim() == 'dom_probe')
        .toList(growable: false);
  }

  bool _canUsePlaceholderEvent(
    NormalizedMessageEvent event,
    FeishuNetworkImageCandidate candidate,
    FeishuNetworkImageAttribution attribution,
  ) {
    final source = event.captureSource.trim();
    if (source == 'feed_card_probe') {
      return true;
    }
    return source == 'dom_probe' &&
        candidate.requestResourceType.trim() == 'browser_preview_blob' &&
        attribution.reason.trim() == 'preview_blob_body' &&
        attribution.evidence.any(
          (item) => item.trim() == 'browser_preview_blob_body',
        ) &&
        attribution.evidence.any(
          (item) => item.trim() == 'active_feed_context',
        );
  }

  bool _isFeedImagePlaceholder(NormalizedMessageEvent event) {
    return event.messageType.trim().toLowerCase() == 'image' ||
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
      if (eventConversationId == attributionConversationId) {
        return true;
      }
      if (!_isSynthesizedFeedId(eventConversationId) ||
          !_isSynthesizedFeedId(attributionConversationId)) {
        return false;
      }
      return _conversationNamesMatch(event, attribution) &&
          _senderNamesCompatible(event, attribution);
    }
    if (eventConversationId.isNotEmpty ||
        attributionConversationId.isNotEmpty) {
      return false;
    }

    return _conversationNamesMatch(event, attribution) &&
        _senderNamesCompatible(event, attribution);
  }

  bool _conversationNamesMatch(
    NormalizedMessageEvent event,
    FeishuNetworkImageAttribution attribution,
  ) {
    final eventConversationName = _normalizedName(event.conversationName);
    final attributionConversationName = _normalizedName(
      attribution.conversationName,
    );
    return eventConversationName.isNotEmpty &&
        attributionConversationName.isNotEmpty &&
        eventConversationName == attributionConversationName;
  }

  bool _isSynthesizedFeedId(String value) {
    return value.trim().startsWith('feed:');
  }

  bool _senderNamesCompatible(
    NormalizedMessageEvent event,
    FeishuNetworkImageAttribution attribution,
  ) {
    final eventSenderName = _normalizedName(event.senderName);
    final attributionSenderName = _normalizedName(attribution.senderName);
    return eventSenderName.isNotEmpty &&
        attributionSenderName.isNotEmpty &&
        eventSenderName == attributionSenderName;
  }

  bool _withinWindow(DateTime left, DateTime right, [Duration? window]) {
    final difference = left.toUtc().difference(right.toUtc()).abs();
    return difference <= (window ?? matchWindow);
  }

  String _conversationScope(NormalizedMessageEvent event) {
    final conversationId = event.conversationId.trim();
    if (conversationId.isNotEmpty) {
      return conversationId;
    }
    final conversationName = _normalizedName(event.conversationName);
    return conversationName.isEmpty ? 'unknown' : conversationName;
  }

  String _networkImageMessageId(
    FeishuNetworkImageCandidate candidate, {
    required NormalizedMessageEvent routeEvent,
    required NormalizedMessageEvent messageIdEvent,
  }) {
    final bodySha1 = _safeMessageIdPart(candidate.bodySha1.trim());
    final rawRouteMessageId = routeEvent.messageId.trim();
    final routeMessageId = _safeMessageIdPart(rawRouteMessageId);
    final rawAnchorMessageId = messageIdEvent.messageId.trim();
    final anchorMessageId = _safeMessageIdPart(rawAnchorMessageId);
    if (anchorMessageId.isEmpty) {
      return 'network_image:$bodySha1';
    }
    if (candidate.requestResourceType.trim() != 'browser_preview_blob' &&
        !rawAnchorMessageId.startsWith('feed:')) {
      return 'network_image:$bodySha1';
    }
    if (rawRouteMessageId.startsWith('feed:') &&
        rawAnchorMessageId != rawRouteMessageId &&
        routeMessageId.isNotEmpty) {
      return 'network_image:$routeMessageId:$anchorMessageId:$bodySha1';
    }
    return 'network_image:$anchorMessageId:$bodySha1';
  }

  NormalizedMessageEvent _selectMessageIdAnchorEvent({
    required FeishuNetworkImageCandidate candidate,
    required FeishuNetworkImageAttribution attribution,
    required NormalizedMessageEvent routeEvent,
    required List<NormalizedMessageEvent> matchingEvents,
    required List<NormalizedMessageEvent> recentEvents,
  }) {
    if (routeEvent.captureSource.trim() != 'feed_card_probe') {
      return routeEvent;
    }
    if (candidate.requestResourceType.trim() != 'browser_preview_blob') {
      return routeEvent;
    }
    final feedMessageId = routeEvent.messageId.trim();
    if (!feedMessageId.startsWith('feed:')) {
      return routeEvent;
    }
    final domMatches = matchingEvents
        .where((event) => event.captureSource.trim() == 'dom_probe')
        .where((event) => _isMatchingDomAnchor(event, attribution))
        .where((event) => _isFeedImagePlaceholder(event))
        .where(
          (event) => _isWithinDomAnchorWindow(candidate, attribution, event),
        )
        .toList(growable: false);
    if (domMatches.length == 1) {
      return domMatches.single;
    }
    if (domMatches.length > 1) {
      return routeEvent;
    }

    final delayedDomMatches = recentEvents
        .where((event) => event.captureSource.trim() == 'dom_probe')
        .where((event) => _isMatchingDomAnchor(event, attribution))
        .where((event) => _isFeedImagePlaceholder(event))
        .where(
          (event) => _isWithinDomAnchorWindow(candidate, attribution, event),
        )
        .where((event) => _isFreshDelayedDomAnchor(routeEvent, event))
        .toList(growable: false);
    return delayedDomMatches.length == 1
        ? delayedDomMatches.single
        : routeEvent;
  }

  bool _isFreshDelayedDomAnchor(
    NormalizedMessageEvent routeEvent,
    NormalizedMessageEvent domEvent,
  ) {
    final routeObservedAt = DateTime.tryParse(routeEvent.observedAt.trim());
    final domObservedAt = DateTime.tryParse(domEvent.observedAt.trim());
    if (routeObservedAt == null || domObservedAt == null) {
      return false;
    }
    return !domObservedAt.toUtc().isBefore(routeObservedAt.toUtc());
  }

  bool _requiresDomMessageIdAnchor(
    FeishuNetworkImageCandidate candidate,
    NormalizedMessageEvent routeEvent,
  ) {
    if (candidate.requestResourceType.trim() != 'browser_preview_blob') {
      return false;
    }
    if (routeEvent.captureSource.trim() != 'feed_card_probe') {
      return false;
    }
    return routeEvent.messageId.trim().startsWith('feed:');
  }

  bool _isMatchingDomAnchor(
    NormalizedMessageEvent event,
    FeishuNetworkImageAttribution attribution,
  ) {
    if (event.captureSource.trim() != 'dom_probe') {
      return false;
    }
    return _matchesAttributionConversation(event, attribution);
  }

  bool _isWithinDomAnchorWindow(
    FeishuNetworkImageCandidate candidate,
    FeishuNetworkImageAttribution attribution,
    NormalizedMessageEvent event,
  ) {
    final eventObservedAt = DateTime.tryParse(event.observedAt.trim());
    return eventObservedAt != null &&
        _withinWindow(candidate.observedAt, eventObservedAt, domAnchorWindow) &&
        _withinWindow(attribution.observedAt, eventObservedAt, domAnchorWindow);
  }

  String _safeMessageIdPart(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_').trim();
  }

  String _normalizedName(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

  String _normalizedConversationName(
    String routeConversationName,
    String attributionConversationName,
  ) {
    final routeName = _trimFeedConversationContext(routeConversationName);
    if (routeName.isNotEmpty) {
      return routeName;
    }
    final attributionName = _trimFeedConversationContext(
      attributionConversationName,
    );
    return attributionName.isNotEmpty
        ? attributionName
        : routeConversationName.trim();
  }

  String _trimFeedConversationContext(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }
    final relativeDatePattern = RegExp(
      r'^(?<name>.+?)\s+(?:昨天|前天|\d{1,2}月\d{1,2}日|周[一二三四五六日天]|星期[一二三四五六日天])(?:\s+.+)?$',
    );
    final timePattern = RegExp(r'^(?<name>.+?)\s+\d{1,2}:\d{2}(?:\s+.+)?$');
    final relativeMatch = relativeDatePattern.firstMatch(normalized);
    if (relativeMatch != null) {
      return relativeMatch.namedGroup('name')?.trim() ?? normalized;
    }
    final timeMatch = timePattern.firstMatch(normalized);
    if (timeMatch != null) {
      return timeMatch.namedGroup('name')?.trim() ?? normalized;
    }
    return normalized;
  }

  FeishuNetworkForwardableImageResolution? _resolveActiveFeedPreviewFallback(
    List<({FeishuNetworkImageCandidate candidate, String localPath})>
    existingBodyCandidates,
    List<FeishuNetworkImageAttribution> attributions,
    List<NormalizedMessageEvent> recentEvents,
  ) {
    final activeFeedAttributions = attributions
        .where(_isActiveFeedPreviewAttribution)
        .toList(growable: false);
    if (activeFeedAttributions.isEmpty) {
      return null;
    }
    final matches =
        <
          ({
            FeishuNetworkImageCandidate candidate,
            String localPath,
            FeishuNetworkImageAttribution attribution,
          })
        >[];
    for (final attribution in activeFeedAttributions) {
      for (final entry in existingBodyCandidates) {
        if (!_isMatchingAttribution(entry.candidate, attribution)) {
          continue;
        }
        if (_hasResolvedNetworkImageForDifferentConversation(
          entry.candidate,
          attribution,
          recentEvents,
        )) {
          continue;
        }
        matches.add((
          candidate: entry.candidate,
          localPath: entry.localPath,
          attribution: attribution,
        ));
      }
    }
    if (matches.length != 1) {
      return null;
    }
    final match = matches.single;
    final candidate = match.candidate;
    final attribution = match.attribution;
    if (!_withinWindow(candidate.observedAt, attribution.observedAt)) {
      return null;
    }
    final conversationId = attribution.conversationId.trim();
    final conversationName = _trimFeedConversationContext(
      attribution.conversationName,
    );
    if (conversationId.isEmpty && conversationName.isEmpty) {
      return null;
    }
    final messageId =
        candidate.requestResourceType.trim() == 'browser_preview_blob'
        ? 'network_image:${_safeMessageIdPart(attribution.feedCardId.trim())}:${_safeMessageIdPart(candidate.bodySha1.trim())}'
        : 'network_image:${_safeMessageIdPart(candidate.bodySha1.trim())}';
    final event = NormalizedMessageEvent(
      eventId: 'event_$messageId',
      dedupeKey:
          '${conversationId.isNotEmpty ? conversationId : conversationName}:$messageId',
      accountId: '',
      conversationId: conversationId,
      conversationName: conversationName,
      conversationType: 'unknown',
      messageId: messageId,
      senderId: '',
      senderName: attribution.senderName.trim(),
      messageType: 'image',
      text: '[Image]',
      sentAt: '',
      observedAt: candidate.observedAt.toUtc().toIso8601String(),
      captureSource: 'network_original_image',
      imageAttachments: <MessageImageAttachment>[
        MessageImageAttachment(
          sourceUrl: candidate.resourceUrl,
          localPath: match.localPath,
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
        'conversation_scope': conversationId.isNotEmpty
            ? conversationId
            : conversationName,
        'reason': 'active_feed_preview_fallback',
      },
    );
  }

  bool _isActiveFeedPreviewAttribution(
    FeishuNetworkImageAttribution attribution,
  ) {
    return attribution.sourceKind.trim() == 'blob' &&
        attribution.reason.trim() == 'preview_blob_body' &&
        attribution.evidence.any(
          (item) => item.trim() == 'browser_preview_blob_body',
        ) &&
        attribution.evidence.any(
          (item) => item.trim() == 'active_feed_context',
        ) &&
        attribution.conversationName.trim().isNotEmpty;
  }

  bool _hasResolvedNetworkImageForDifferentConversation(
    FeishuNetworkImageCandidate candidate,
    FeishuNetworkImageAttribution attribution,
    List<NormalizedMessageEvent> recentEvents,
  ) {
    for (final event in recentEvents) {
      if (event.captureSource.trim() != 'network_original_image' ||
          event.imageAttachments.isEmpty ||
          !_sameResolvedImageBody(candidate, event)) {
        continue;
      }
      if (!_sameConversationAsAttribution(event, attribution)) {
        return true;
      }
    }
    return false;
  }

  bool _sameResolvedImageBody(
    FeishuNetworkImageCandidate candidate,
    NormalizedMessageEvent event,
  ) {
    final bodySha1 = _safeMessageIdPart(candidate.bodySha1.trim());
    if (bodySha1.isNotEmpty && event.messageId.contains(bodySha1)) {
      return true;
    }
    final localPath = candidate.localPath.trim();
    if (localPath.isEmpty) {
      return false;
    }
    return event.imageAttachments.any(
      (attachment) => attachment.localPath.trim() == localPath,
    );
  }

  bool _sameConversationAsAttribution(
    NormalizedMessageEvent event,
    FeishuNetworkImageAttribution attribution,
  ) {
    final eventConversationId = event.conversationId.trim();
    final attributionConversationId = attribution.conversationId.trim();
    if (eventConversationId.isNotEmpty &&
        attributionConversationId.isNotEmpty) {
      return eventConversationId == attributionConversationId;
    }
    final eventConversationName = _normalizedName(
      _trimFeedConversationContext(event.conversationName),
    );
    final attributionConversationName = _normalizedName(
      _trimFeedConversationContext(attribution.conversationName),
    );
    return eventConversationName.isNotEmpty &&
        attributionConversationName.isNotEmpty &&
        eventConversationName == attributionConversationName;
  }
}

List<({FeishuNetworkImageCandidate candidate, String localPath})>
_dedupeSavedBodyCandidates(
  List<({FeishuNetworkImageCandidate candidate, String localPath})> entries,
) {
  final byBody =
      <String, ({FeishuNetworkImageCandidate candidate, String localPath})>{};
  for (final entry in entries) {
    final bodyKey = [
      entry.candidate.bodySha1.trim(),
      entry.candidate.bodySize.toString(),
      entry.localPath,
    ].join('|');
    final current = byBody[bodyKey];
    if (current == null ||
        entry.candidate.observedAt.isAfter(current.candidate.observedAt)) {
      byBody[bodyKey] = entry;
    }
  }
  return byBody.values.toList(growable: false);
}

({
  FeishuNetworkImageCandidate candidate,
  String localPath,
  FeishuNetworkImageAttribution attribution,
  NormalizedMessageEvent feedEvent,
  NormalizedMessageEvent messageIdEvent,
})?
_singleLargestMatch(
  List<
    ({
      FeishuNetworkImageCandidate candidate,
      String localPath,
      FeishuNetworkImageAttribution attribution,
      NormalizedMessageEvent feedEvent,
      NormalizedMessageEvent messageIdEvent,
    })
  >
  matches,
) {
  if (matches.isEmpty) {
    return null;
  }
  final sorted = matches.toList()
    ..sort(
      (left, right) =>
          right.candidate.bodySize.compareTo(left.candidate.bodySize),
    );
  if (sorted.length > 1 &&
      sorted[0].candidate.bodySize == sorted[1].candidate.bodySize) {
    return null;
  }
  return sorted.first;
}

FeishuNetworkForwardableImageResolution _skip(String reason) {
  return FeishuNetworkForwardableImageResolution(
    events: const <NormalizedMessageEvent>[],
    skipReason: reason,
  );
}
