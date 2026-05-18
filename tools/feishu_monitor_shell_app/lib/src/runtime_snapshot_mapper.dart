import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';

import 'feishu_media_extraction_queue.dart';
import 'feishu_network_capture.dart';
import 'feishu_network_forwardable_image_resolver.dart';
import 'feishu_page_probe.dart';

const int _maxStorageProbeDiagnostics = 20;

typedef NetworkImageResolverCallback =
    FeishuNetworkForwardableImageResolution Function({
      required List<FeishuNetworkImageCandidate> candidates,
      required List<FeishuNetworkImageAttribution> attributions,
      required List<NormalizedMessageEvent> recentEvents,
    });

class NetworkImageEnrichmentResult {
  const NetworkImageEnrichmentResult({
    required this.snapshot,
    this.recordableResolution,
    this.error = '',
  });

  final ShellSnapshot snapshot;
  final FeishuNetworkForwardableImageResolution? recordableResolution;
  final String error;
}

String deriveLoginStateFromUrl(String url) {
  final normalized = url.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 'needs_login';
  }
  if (normalized.contains('login') ||
      normalized.contains('passport') ||
      normalized.contains('accounts')) {
    return 'needs_login';
  }
  if (normalized.contains('messenger') || normalized.contains('im')) {
    return 'logged_in';
  }
  return 'unknown';
}

ShellSnapshot applyRuntimeSignal(
  ShellSnapshot snapshot, {
  required String runtimeUrl,
  required String pageTitle,
  required bool webviewAvailable,
  required bool isLoading,
}) {
  return snapshot.copyWith(
    runtimeUrl: runtimeUrl,
    pageTitle: pageTitle,
    webviewAvailable: webviewAvailable,
    shellMode: 'desktop_shell',
    loginState: deriveLoginStateFromUrl(runtimeUrl),
    hookState: isLoading ? 'loading' : 'healthy',
  );
}

ShellSnapshot mergeExternalControlState({
  required ShellSnapshot localSnapshot,
  required ShellSnapshot persistedSnapshot,
}) {
  final persistedIsNewer =
      persistedSnapshot.lastUpdatedAt.compareTo(localSnapshot.lastUpdatedAt) >=
      0;
  return localSnapshot.copyWith(
    captureState: persistedIsNewer
        ? persistedSnapshot.captureState
        : localSnapshot.captureState,
  );
}

ShellSnapshot applyPageProbe(ShellSnapshot snapshot, FeishuPageProbe probe) {
  final mergedProbeDiagnostics = <String, dynamic>{
    ..._persistentProbeDiagnostics(snapshot.probeDiagnostics),
    ...probe.probeDiagnostics,
  };
  final incomingEvents = _dropAlreadyExtractedFeedImagePlaceholders(
    normalizeObservedMessages(
      probe.observedMessages,
      configuredSourceIds: configuredMediaSourceIdsFromDiagnostics(
        mergedProbeDiagnostics,
      ),
      configuredSourceNames: configuredMediaSourceNamesFromDiagnostics(
        mergedProbeDiagnostics,
      ),
    ),
    snapshot.recentEvents,
  );
  final retainedEvents = snapshot.recentEvents
      .where(_shouldRetainRecentEvent)
      .toList(growable: false);
  return snapshot.copyWith(
    pageKind: probe.pageKind,
    probeObservedAt: probe.observedAt,
    probeDiagnostics: <String, dynamic>{
      ...mergedProbeDiagnostics,
      ..._mediaExtractionQueueDiagnosticsForProbe(
        probe: probe,
        recentEvents: snapshot.recentEvents,
      ),
    },
    observedConversations: probe.observedConversations,
    observedMessages: probe.observedMessages,
    recentEvents: _preferResolvedDomImages(
      _keepNewestDomTextPerConversation(
        _keepNewestDomImagePerConversation(
          mergeRecentEvents(retainedEvents, incomingEvents),
          acrossProbeCycles: true,
        ),
        acrossProbeCycles: true,
      ).toList(growable: false),
    ),
    lastUpdatedAt: DateTime.now().toUtc(),
  );
}

Map<String, Object?> _mediaExtractionQueueDiagnosticsForProbe({
  required FeishuPageProbe probe,
  required List<NormalizedMessageEvent> recentEvents,
}) {
  final now = (probe.observedAt ?? DateTime.now().toUtc()).toUtc();
  final queue = FeishuMediaExtractionQueue();
  final hasConfiguredSource =
      configuredMediaSourceIdsFromDiagnostics(
        probe.probeDiagnostics,
      ).isNotEmpty ||
      configuredMediaSourceNamesFromDiagnostics(
        probe.probeDiagnostics,
      ).isNotEmpty;
  if (hasConfiguredSource &&
      pendingMediaFeedNeedsOriginalExtraction(
        probe: probe,
        recentEvents: recentEvents,
      )) {
    final placeholder = _pendingMediaFeedPlaceholderEvent(probe);
    final feedCardKey = probePendingMediaFeedCardKey(probe).trim();
    final feedPreviewText = probePendingMediaFeedCardText(probe).trim();
    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: placeholder?.conversationId ?? '',
        sourceConversationName: placeholder?.conversationName ?? '',
        feedCardKey: feedCardKey.isNotEmpty
            ? feedCardKey
            : placeholder?.messageId ?? '',
        feedPreviewText: feedPreviewText.isNotEmpty
            ? feedPreviewText
            : placeholder?.text ?? '',
        enqueuedAt: now,
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );
  }
  return queue.diagnostics(now);
}

bool pendingMediaFeedNeedsOriginalExtraction({
  required FeishuPageProbe probe,
  required List<NormalizedMessageEvent> recentEvents,
}) {
  if (!probeHasPendingMediaFeedCard(probe)) {
    return false;
  }
  final placeholder = _pendingMediaFeedPlaceholderEvent(probe);
  if (placeholder == null) {
    return true;
  }
  return !_hasExtractedNetworkImageForPlaceholder(placeholder, recentEvents);
}

NormalizedMessageEvent? _pendingMediaFeedPlaceholderEvent(
  FeishuPageProbe probe,
) {
  final pendingKey = probePendingMediaFeedCardKey(probe).trim();
  final pendingText = probePendingMediaFeedCardText(probe).trim();
  for (final message in probe.observedMessages) {
    if (message.captureSource.trim() != 'feed_card_probe') {
      continue;
    }
    if (pendingKey.isNotEmpty && message.id.trim() != pendingKey) {
      continue;
    }
    if (!isFeishuMediaPreviewText(message.text)) {
      continue;
    }
    return _normalizedEventFromObservedMessage(message);
  }
  if (pendingText.isEmpty) {
    return null;
  }
  for (final message in probe.observedMessages) {
    if (message.captureSource.trim() != 'feed_card_probe' ||
        !isFeishuMediaPreviewText(message.text) ||
        message.text.trim() != pendingText) {
      continue;
    }
    return _normalizedEventFromObservedMessage(message);
  }
  return null;
}

NormalizedMessageEvent _normalizedEventFromObservedMessage(
  ObservedMessageCandidate message,
) {
  final conversationId = message.conversationId.trim();
  final messageId = message.id.trim();
  return NormalizedMessageEvent(
    eventId: 'probe_pending:$conversationId:$messageId',
    dedupeKey: '$conversationId:$messageId',
    accountId: '',
    conversationId: message.conversationId,
    conversationName: message.conversationName,
    conversationType: 'unknown',
    messageId: message.id,
    senderId: '',
    senderName: message.senderName,
    messageType: message.messageType,
    text: message.text,
    sentAt: '',
    observedAt: message.observedAt,
    captureSource: message.captureSource,
    imageAttachments: message.imageAttachments,
  );
}

List<NormalizedMessageEvent> _dropAlreadyExtractedFeedImagePlaceholders(
  List<NormalizedMessageEvent> incomingEvents,
  List<NormalizedMessageEvent> existingEvents,
) {
  if (incomingEvents.isEmpty || existingEvents.isEmpty) {
    return incomingEvents;
  }
  return incomingEvents
      .where(
        (event) =>
            !_isFeedImagePlaceholderEvent(event) ||
            !_hasExtractedNetworkImageForPlaceholder(event, existingEvents),
      )
      .toList(growable: false);
}

bool _isFeedImagePlaceholderEvent(NormalizedMessageEvent event) {
  return event.captureSource.trim() == 'feed_card_probe' &&
      isFeishuMediaPreviewText(event.text);
}

bool _hasExtractedNetworkImageForPlaceholder(
  NormalizedMessageEvent placeholder,
  List<NormalizedMessageEvent> existingEvents,
) {
  final placeholderMessageId = placeholder.messageId.trim();
  final placeholderObservedAt = DateTime.tryParse(
    placeholder.observedAt.trim(),
  );
  for (final existing in existingEvents) {
    if (existing.captureSource.trim() != 'network_original_image' ||
        existing.imageAttachments.isEmpty ||
        !_sameEventConversation(placeholder, existing)) {
      continue;
    }
    if (_eventSenderName(placeholder).isNotEmpty &&
        _eventSenderName(existing).isNotEmpty &&
        _eventSenderName(placeholder) != _eventSenderName(existing)) {
      continue;
    }
    if (placeholderMessageId.isNotEmpty &&
        _networkImageMessageIdContainsFeedMessageId(
          networkMessageId: existing.messageId,
          feedMessageId: placeholderMessageId,
        )) {
      return true;
    }
    if (placeholderMessageId.isNotEmpty) {
      continue;
    }
    final existingObservedAt = DateTime.tryParse(existing.observedAt.trim());
    if (placeholderObservedAt != null &&
        existingObservedAt != null &&
        existingObservedAt.isBefore(placeholderObservedAt)) {
      continue;
    }
    return true;
  }
  return false;
}

bool _networkImageMessageIdContainsFeedMessageId({
  required String networkMessageId,
  required String feedMessageId,
}) {
  final safeFeedMessageId = _safeNetworkImageMessageIdPart(feedMessageId);
  if (safeFeedMessageId.isEmpty) {
    return false;
  }
  final safeNetworkMessageId = networkMessageId.trim();
  return safeNetworkMessageId.startsWith('network_image:$safeFeedMessageId:');
}

String _safeNetworkImageMessageIdPart(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]+'), '_').trim();
}

bool _sameEventConversation(
  NormalizedMessageEvent left,
  NormalizedMessageEvent right,
) {
  final leftId = left.conversationId.trim();
  final rightId = right.conversationId.trim();
  if (leftId.isNotEmpty && rightId.isNotEmpty && leftId == rightId) {
    return true;
  }
  final leftName = left.conversationName.trim();
  final rightName = right.conversationName.trim();
  return leftName.isNotEmpty && rightName.isNotEmpty && leftName == rightName;
}

String _eventSenderName(NormalizedMessageEvent event) {
  return event.senderName.trim().replaceAll(RegExp(r'\s+'), ' ');
}

ShellSnapshot applyStorageProbeDiagnostic(
  ShellSnapshot snapshot,
  Map<String, Object?> probe,
) {
  if (probe.isEmpty) {
    return snapshot;
  }
  final copiedProbe = _deepJsonCopy(probe) as Map<String, dynamic>;
  final recent = _storageProbeList(
    snapshot.probeDiagnostics['storage_recent_probes'],
  )..add(copiedProbe);
  while (recent.length > _maxStorageProbeDiagnostics) {
    recent.removeAt(0);
  }
  final currentCount = _diagnosticInt(
    snapshot.probeDiagnostics['storage_probe_count'],
  );
  return snapshot.copyWith(
    probeDiagnostics: <String, dynamic>{
      ...snapshot.probeDiagnostics,
      'storage_probe_count': currentCount + 1,
      'storage_recent_probes': recent,
      'storage_last_probe': copiedProbe,
    },
    lastUpdatedAt: DateTime.now().toUtc(),
  );
}

Map<String, dynamic> persistentShellDiagnosticsForProbe(
  Map<String, dynamic> currentDiagnostics,
  Map<String, dynamic> probeDiagnostics,
) {
  return <String, dynamic>{
    ...probeDiagnostics,
    ..._persistentProbeDiagnostics(currentDiagnostics),
  };
}

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

NetworkImageEnrichmentResult applyNetworkImageEnrichment(
  ShellSnapshot snapshot, {
  required List<FeishuNetworkImageCandidate> candidates,
  required List<FeishuNetworkImageAttribution> attributions,
  required Set<String> recordedNetworkImageDedupeKeys,
  required NetworkImageResolverCallback resolve,
}) {
  if (candidates.isEmpty && attributions.isEmpty) {
    return NetworkImageEnrichmentResult(snapshot: snapshot);
  }
  try {
    final imageResolution = resolve(
      candidates: candidates,
      attributions: attributions,
      recentEvents: snapshot.recentEvents,
    );
    final enrichedSnapshot = applyNetworkForwardableImages(
      snapshot,
      imageResolution.events,
    );
    final recordableResolution = _recordableNetworkImageResolution(
      imageResolution,
      recordedNetworkImageDedupeKeys,
    );
    return NetworkImageEnrichmentResult(
      snapshot: enrichedSnapshot,
      recordableResolution: recordableResolution,
    );
  } catch (error) {
    return NetworkImageEnrichmentResult(
      snapshot: snapshot,
      error: error.toString(),
    );
  }
}

FeishuNetworkForwardableImageResolution? _recordableNetworkImageResolution(
  FeishuNetworkForwardableImageResolution resolution,
  Set<String> recordedNetworkImageDedupeKeys,
) {
  if (resolution.events.isEmpty) {
    if (resolution.skipReason.trim().isEmpty) {
      return null;
    }
    return resolution;
  }
  final recordableEvents = <NormalizedMessageEvent>[];
  for (final event in resolution.events) {
    final dedupeKey = event.dedupeKey.trim();
    if (event.captureSource.trim() != 'network_original_image' ||
        dedupeKey.isEmpty ||
        recordedNetworkImageDedupeKeys.contains(dedupeKey)) {
      continue;
    }
    recordedNetworkImageDedupeKeys.add(dedupeKey);
    recordableEvents.add(event);
  }
  if (recordableEvents.isEmpty) {
    return null;
  }
  return FeishuNetworkForwardableImageResolution(
    events: recordableEvents,
    skipReason: resolution.skipReason,
    decision: resolution.decision,
  );
}

List<NormalizedMessageEvent> normalizeObservedMessages(
  List<ObservedMessageCandidate> messages, {
  Set<String> configuredSourceIds = const <String>{},
  Set<String> configuredSourceNames = const <String>{},
}) {
  final byKey = <String, NormalizedMessageEvent>{};
  for (final message in messages) {
    if (message.id.trim().isEmpty ||
        message.text.trim().isEmpty ||
        _shouldDropObservedMessage(
          message,
          configuredSourceIds: configuredSourceIds,
          configuredSourceNames: configuredSourceNames,
        )) {
      continue;
    }
    final conversationId = message.conversationId.trim();
    final messageId = message.id.trim();
    final captureSource = message.captureSource.trim().isEmpty
        ? 'dom_probe'
        : message.captureSource.trim();
    final fallbackKey =
        '${message.senderName}:${message.observedAt}:${message.text.hashCode}';
    final stableBodyProbeKey = captureSource == 'body_text_probe'
        ? _bodyTextProbeDedupeKey(
            conversationId: conversationId,
            senderName: message.senderName,
            text: message.text,
          )
        : '';
    final stableDomImageKey = captureSource == 'dom_probe'
        ? _domImageProbeDedupeKey(
            conversationId: conversationId,
            conversationName: message.conversationName,
            messageId: messageId,
            imageAttachments: message.imageAttachments,
          )
        : '';
    final dedupeKey = stableDomImageKey.isNotEmpty
        ? stableDomImageKey
        : stableBodyProbeKey.isNotEmpty
        ? stableBodyProbeKey
        : conversationId.isNotEmpty && messageId.isNotEmpty
        ? '$conversationId:$messageId'
        : messageId.isNotEmpty
        ? 'message:$messageId'
        : fallbackKey;
    final event = NormalizedMessageEvent(
      eventId: 'event_$messageId',
      dedupeKey: dedupeKey,
      accountId: '',
      conversationId: conversationId,
      conversationName: message.conversationName,
      conversationType: 'unknown',
      messageId: messageId,
      senderId: '',
      senderName: message.senderName,
      messageType: message.messageType.trim().isEmpty
          ? 'text'
          : message.messageType,
      text: stableDomImageKey.isNotEmpty ? '[图片]' : message.text,
      sentAt: '',
      observedAt: message.observedAt,
      captureSource: captureSource,
      imageAttachments: message.imageAttachments,
    );
    final current = byKey[dedupeKey];
    if (current == null || _compareObservedAt(event, current) >= 0) {
      byKey[dedupeKey] = event;
    }
  }
  final events = _keepNewestDomTextPerConversation(
    _keepNewestDomImagePerConversation(byKey.values),
  ).toList()
    ..sort((a, b) => _compareObservedAt(b, a));
  return _preferResolvedDomImages(events);
}

bool _shouldDropObservedMessage(
  ObservedMessageCandidate message, {
  required Set<String> configuredSourceIds,
  required Set<String> configuredSourceNames,
}) {
  final captureSource = message.captureSource.trim();
  if (captureSource != 'dom_probe' && captureSource != 'body_text_probe') {
    return false;
  }
  if (message.imageAttachments.isNotEmpty) {
    return false;
  }
  if (captureSource != 'dom_probe') {
    return true;
  }
  return !_isConfiguredDomTextMessage(
    message,
    configuredSourceIds: configuredSourceIds,
    configuredSourceNames: configuredSourceNames,
  );
}

bool _isDomTextNoiseEvent(NormalizedMessageEvent event) {
  final captureSource = event.captureSource.trim();
  if (captureSource != 'dom_probe' && captureSource != 'body_text_probe') {
    return false;
  }
  if (event.imageAttachments.isNotEmpty) {
    return false;
  }
  if (captureSource != 'dom_probe') {
    return true;
  }
  return !_isForwardableDomTextEvent(event);
}

bool _isConfiguredDomTextMessage(
  ObservedMessageCandidate message, {
  required Set<String> configuredSourceIds,
  required Set<String> configuredSourceNames,
}) {
  if (!_matchesConfiguredSource(
    conversationId: message.conversationId,
    conversationName: message.conversationName,
    configuredSourceIds: configuredSourceIds,
    configuredSourceNames: configuredSourceNames,
  )) {
    return false;
  }
  return _isForwardableDomText(
    text: message.text,
    senderName: message.senderName,
    conversationName: message.conversationName,
  );
}

bool _isForwardableDomTextEvent(NormalizedMessageEvent event) {
  return _isForwardableDomText(
    text: event.text,
    senderName: event.senderName,
    conversationName: event.conversationName,
  );
}

bool _matchesConfiguredSource({
  required String conversationId,
  required String conversationName,
  required Set<String> configuredSourceIds,
  required Set<String> configuredSourceNames,
}) {
  if (configuredSourceIds.isEmpty && configuredSourceNames.isEmpty) {
    return false;
  }
  final normalizedId = conversationId.trim();
  if (normalizedId.isNotEmpty && configuredSourceIds.contains(normalizedId)) {
    return true;
  }
  if (normalizedId.isNotEmpty) {
    return false;
  }
  final normalizedName = _normalizeConfiguredSourceName(conversationName);
  return normalizedName.isNotEmpty &&
      configuredSourceNames.contains(normalizedName);
}

bool _isForwardableDomText({
  required String text,
  required String senderName,
  required String conversationName,
}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty || isFeishuMediaPreviewText(normalized)) {
    return false;
  }
  if (_isTimestampText(normalized)) {
    return false;
  }
  final normalizedSender = senderName.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalizedSender.isNotEmpty && normalized == normalizedSender) {
    return false;
  }
  final normalizedConversation = conversationName
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (normalizedConversation.isNotEmpty &&
      normalized == normalizedConversation) {
    return false;
  }
  return true;
}

bool _isTimestampText(String value) {
  return RegExp(
    r'^(?:\d{1,2}:\d{2}|昨天|前天|\d{1,2}月\d{1,2}日)$',
  ).hasMatch(value.trim());
}

String _normalizeConfiguredSourceName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

Iterable<NormalizedMessageEvent> _keepNewestDomImagePerConversation(
  Iterable<NormalizedMessageEvent> events, {
  bool acrossProbeCycles = false,
}) {
  final newestDomImageByScope = <String, NormalizedMessageEvent>{};
  final retained = <NormalizedMessageEvent>[];
  for (final event in events) {
    if (!_isDomImageEvent(event)) {
      retained.add(event);
      continue;
    }
    final scope = acrossProbeCycles
        ? _eventConversationScope(event)
        : '${_eventConversationScope(event)}:${event.observedAt.trim()}';
    final current = newestDomImageByScope[scope];
    if (current == null || _compareDomImageRecency(event, current) >= 0) {
      newestDomImageByScope[scope] = event;
    }
  }
  return <NormalizedMessageEvent>[...retained, ...newestDomImageByScope.values];
}

Iterable<NormalizedMessageEvent> _keepNewestDomTextPerConversation(
  Iterable<NormalizedMessageEvent> events, {
  bool acrossProbeCycles = false,
}) {
  final newestDomTextByScope = <String, NormalizedMessageEvent>{};
  final retained = <NormalizedMessageEvent>[];
  for (final event in events) {
    if (!_isDomTextEvent(event)) {
      retained.add(event);
      continue;
    }
    final normalized = _normalizedDomTextEvent(event);
    final scope = acrossProbeCycles
        ? _eventConversationScope(normalized)
        : '${_eventConversationScope(normalized)}:${normalized.observedAt.trim()}';
    final current = newestDomTextByScope[scope];
    if (current == null || _compareDomTextRecency(normalized, current) >= 0) {
      newestDomTextByScope[scope] = normalized;
    }
  }
  return <NormalizedMessageEvent>[...retained, ...newestDomTextByScope.values];
}

bool _isDomImageEvent(NormalizedMessageEvent event) {
  return event.captureSource.trim() == 'dom_probe' &&
      event.imageAttachments.isNotEmpty;
}

bool _isDomTextEvent(NormalizedMessageEvent event) {
  return event.captureSource.trim() == 'dom_probe' &&
      event.imageAttachments.isEmpty;
}

NormalizedMessageEvent _normalizedDomTextEvent(NormalizedMessageEvent event) {
  final normalizedText = _stripDomTextSenderPrefix(
    text: event.text,
    senderName: event.senderName,
  );
  if (normalizedText == event.text) {
    return event;
  }
  return NormalizedMessageEvent(
    eventId: event.eventId,
    dedupeKey: event.dedupeKey,
    accountId: event.accountId,
    conversationId: event.conversationId,
    conversationName: event.conversationName,
    conversationType: event.conversationType,
    messageId: event.messageId,
    senderId: event.senderId,
    senderName: event.senderName,
    messageType: event.messageType,
    text: normalizedText,
    sentAt: event.sentAt,
    observedAt: event.observedAt,
    captureSource: event.captureSource,
    imageAttachments: event.imageAttachments,
  );
}

String _stripDomTextSenderPrefix({
  required String text,
  required String senderName,
}) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length <= 1) {
    return text.trim();
  }
  final firstLine = lines.first;
  final normalizedSender = senderName.replaceAll(RegExp(r'\s+'), ' ').trim();
  if ((normalizedSender.isNotEmpty && firstLine == normalizedSender) ||
      _looksLikeDomSenderName(firstLine)) {
    return lines.skip(1).join('\n').trim();
  }
  return text.trim();
}

bool _looksLikeDomSenderName(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 24) {
    return false;
  }
  if (RegExp(r'[\s:：,，。.!?？；;]').hasMatch(normalized)) {
    return false;
  }
  return !RegExp(r'\d').hasMatch(normalized);
}

String _eventConversationScope(NormalizedMessageEvent event) {
  final conversationId = event.conversationId.trim();
  if (conversationId.isNotEmpty) {
    return conversationId;
  }
  final conversationName = event.conversationName.trim();
  return conversationName.isEmpty ? 'unknown' : conversationName;
}

int _compareDomImageRecency(
  NormalizedMessageEvent a,
  NormalizedMessageEvent b,
) {
  final observedAtComparison = _compareObservedAt(a, b);
  if (observedAtComparison != 0) {
    return observedAtComparison;
  }
  return _compareMessageId(a.messageId, b.messageId);
}

int _compareDomTextRecency(
  NormalizedMessageEvent a,
  NormalizedMessageEvent b,
) {
  final observedAtComparison = _compareObservedAt(a, b);
  if (observedAtComparison != 0) {
    return observedAtComparison;
  }
  return _compareMessageId(a.messageId, b.messageId);
}

int _compareMessageId(String a, String b) {
  final normalizedA = a.trim();
  final normalizedB = b.trim();
  final numberA = int.tryParse(normalizedA);
  final numberB = int.tryParse(normalizedB);
  if (numberA != null && numberB != null) {
    return numberA.compareTo(numberB);
  }
  return normalizedA.compareTo(normalizedB);
}

bool _shouldRetainRecentEvent(NormalizedMessageEvent event) {
  if (_isDomTextNoiseEvent(event)) {
    return false;
  }
  final captureSource = event.captureSource.trim();
  if (captureSource != 'dom_probe' || event.imageAttachments.isEmpty) {
    return true;
  }
  return event.dedupeKey.contains(':dom_image:');
}

String _bodyTextProbeDedupeKey({
  required String conversationId,
  required String senderName,
  required String text,
}) {
  final normalizedText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalizedText.isEmpty) {
    return '';
  }
  final scope = conversationId.trim().isNotEmpty
      ? conversationId.trim()
      : senderName.trim();
  final normalizedScope = scope.isEmpty ? 'unknown' : scope;
  return 'body_text_probe:$normalizedScope:${normalizedText.hashCode}';
}

String _domImageProbeDedupeKey({
  required String conversationId,
  required String conversationName,
  required String messageId,
  required List<MessageImageAttachment> imageAttachments,
}) {
  if (imageAttachments.isEmpty) {
    return '';
  }
  final image = imageAttachments.first;
  final imageKey = _imageAttachmentStableKey(image);
  if (imageKey.isEmpty) {
    return '';
  }
  final scope = conversationId.trim().isNotEmpty
      ? conversationId.trim()
      : conversationName.trim();
  final normalizedScope = scope.isEmpty ? 'unknown' : scope;
  final normalizedMessageId = messageId.trim();
  if (normalizedMessageId.isNotEmpty &&
      !normalizedMessageId.startsWith('dom:')) {
    return '$normalizedScope:$normalizedMessageId';
  }
  final dimensions = image.width > 0 && image.height > 0
      ? '${image.width}x${image.height}'
      : 'unknown_size';
  return '$normalizedScope:dom_image:$dimensions:$imageKey';
}

String _imageAttachmentStableKey(MessageImageAttachment image) {
  final localPath = image.localPath.trim();
  if (localPath.isNotEmpty) {
    return 'local:${_stableHash(localPath)}';
  }
  final sourceUrl = image.sourceUrl.trim();
  if (sourceUrl.isEmpty) {
    return '';
  }
  if (sourceUrl.startsWith('data:image/')) {
    return 'data:${_stableHash(sourceUrl)}';
  }
  if (sourceUrl.startsWith('blob:')) {
    return 'blob:${_stableHash(sourceUrl)}';
  }
  return 'url:${_stableHash(sourceUrl)}';
}

List<NormalizedMessageEvent> _preferResolvedDomImages(
  List<NormalizedMessageEvent> events,
) {
  final resolvedDomImageGroups = events
      .where(_isResolvedDomImageEvent)
      .map(_domImageResolutionGroupKey)
      .where((key) => key.isNotEmpty)
      .toSet();
  return events
      .where((event) {
        if (!_isBlobDomImageEvent(event)) {
          return true;
        }
        final key = _domImageResolutionGroupKey(event);
        return key.isEmpty || !resolvedDomImageGroups.contains(key);
      })
      .toList(growable: false);
}

bool _isBlobDomImageEvent(NormalizedMessageEvent event) {
  if (event.captureSource.trim() != 'dom_probe') {
    return false;
  }
  if (event.imageAttachments.isEmpty) {
    return false;
  }
  return event.imageAttachments.first.sourceUrl.trim().startsWith('blob:');
}

bool _isResolvedDomImageEvent(NormalizedMessageEvent event) {
  if (event.captureSource.trim() != 'dom_probe') {
    return false;
  }
  if (event.imageAttachments.isEmpty) {
    return false;
  }
  return event.imageAttachments.first.sourceUrl.trim().startsWith(
    'data:image/',
  );
}

String _domImageResolutionGroupKey(NormalizedMessageEvent event) {
  if (event.captureSource.trim() != 'dom_probe' ||
      event.imageAttachments.isEmpty) {
    return '';
  }
  final image = event.imageAttachments.first;
  final scope = event.conversationId.trim().isNotEmpty
      ? event.conversationId.trim()
      : event.conversationName.trim();
  final dimensions = image.width > 0 && image.height > 0
      ? '${image.width}x${image.height}'
      : 'unknown_size';
  return '$scope:$dimensions';
}

Map<String, dynamic> _persistentProbeDiagnostics(
  Map<String, dynamic> diagnostics,
) {
  final persistent = <String, dynamic>{};
  for (final entry in diagnostics.entries) {
    if (entry.key.startsWith('storage_') ||
        entry.key.startsWith('configured_media_') ||
        entry.key.startsWith('media_queue_')) {
      persistent[entry.key] = _deepJsonCopy(entry.value);
    }
  }
  return persistent;
}

List<Map<String, dynamic>> _storageProbeList(Object? value) {
  if (value is! List) {
    return <Map<String, dynamic>>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) =>
            _deepJsonCopy(
                  item.map(
                    (key, itemValue) => MapEntry(key.toString(), itemValue),
                  ),
                )
                as Map<String, dynamic>,
      )
      .toList(growable: true);
}

int _diagnosticInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Object? _deepJsonCopy(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _deepJsonCopy(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_deepJsonCopy).toList(growable: true);
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  return value.toString();
}

int _compareObservedAt(NormalizedMessageEvent a, NormalizedMessageEvent b) {
  final parsedA = DateTime.tryParse(a.observedAt);
  final parsedB = DateTime.tryParse(b.observedAt);
  if (parsedA != null && parsedB != null) {
    return parsedA.compareTo(parsedB);
  }
  return a.observedAt.compareTo(b.observedAt);
}

String _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}
