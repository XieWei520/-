import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';

import 'feishu_page_probe.dart';

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
  final incomingEvents = normalizeObservedMessages(probe.observedMessages);
  final retainedEvents = snapshot.recentEvents
      .where(_shouldRetainRecentEvent)
      .toList(growable: false);
  return snapshot.copyWith(
    pageKind: probe.pageKind,
    probeObservedAt: probe.observedAt,
    probeDiagnostics: probe.probeDiagnostics,
    observedConversations: probe.observedConversations,
    observedMessages: probe.observedMessages,
    recentEvents: _preferResolvedDomImages(
      _keepNewestDomImagePerConversation(
        mergeRecentEvents(retainedEvents, incomingEvents),
        acrossProbeCycles: true,
      ).toList(growable: false),
    ),
    lastUpdatedAt: DateTime.now().toUtc(),
  );
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

List<NormalizedMessageEvent> normalizeObservedMessages(
  List<ObservedMessageCandidate> messages,
) {
  final byKey = <String, NormalizedMessageEvent>{};
  for (final message in messages) {
    if (message.id.trim().isEmpty ||
        message.text.trim().isEmpty ||
        _isDomTextNoise(message)) {
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
  final events = _keepNewestDomImagePerConversation(byKey.values).toList()
    ..sort((a, b) => _compareObservedAt(b, a));
  return _preferResolvedDomImages(events);
}

bool _isDomTextNoise(ObservedMessageCandidate message) {
  final captureSource = message.captureSource.trim();
  if (captureSource != 'dom_probe' && captureSource != 'body_text_probe') {
    return false;
  }
  return message.imageAttachments.isEmpty;
}

bool _isDomTextNoiseEvent(NormalizedMessageEvent event) {
  final captureSource = event.captureSource.trim();
  if (captureSource != 'dom_probe' && captureSource != 'body_text_probe') {
    return false;
  }
  return event.imageAttachments.isEmpty;
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

bool _isDomImageEvent(NormalizedMessageEvent event) {
  return event.captureSource.trim() == 'dom_probe' &&
      event.imageAttachments.isNotEmpty;
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
