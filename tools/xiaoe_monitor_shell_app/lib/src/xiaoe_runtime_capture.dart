import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

import 'xiaoe_page_probe.dart';

class XiaoeRuntimeCapture {
  XiaoeRuntimeCapture({required this.store, required this.events});

  final ShellStore store;
  final ShellEventBus events;

  Future<ShellSnapshot> applyProbe(
    XiaoePageProbe probe, {
    DateTime? updatedAt,
  }) async {
    final normalizedEvents = normalizeXiaoeProbeEvents(probe);
    final observedMessages = _observedMessagesFromProbe(probe);
    final observedConversations = _observedConversationsFromProbe(
      probe,
      normalizedEvents,
    );
    final now = updatedAt?.toUtc() ?? DateTime.now().toUtc();
    final isLogin = probe.pageKind == XiaoePageKind.login;
    final hasForwardablePage =
        !isLogin &&
        (normalizedEvents.isNotEmpty ||
            probe.source.id.trim().isNotEmpty ||
            probe.source.name.trim().isNotEmpty);
    final next = await store.update((current) {
      final recentEvents = isLogin
          ? const <NormalizedMessageEvent>[]
          : mergeRecentEvents(current.recentEvents, normalizedEvents);
      return current.copyWith(
        shellState: 'online',
        captureState: hasForwardablePage ? 'running' : 'stopped',
        loginState: isLogin
            ? 'login_required'
            : hasForwardablePage
            ? 'logged_in'
            : 'unknown',
        hookState: 'healthy',
        runtimeUrl: probe.runtimeUrl,
        pageTitle: probe.pageTitle,
        webviewAvailable: true,
        shellMode: 'desktop_shell',
        pageKind: probe.pageKind.wireName,
        probeObservedAt: probe.observedAt,
        probeDiagnostics: <String, dynamic>{
          ...current.probeDiagnostics,
          ...probe.probeDiagnostics,
        },
        observedConversations: observedConversations,
        observedMessages: observedMessages,
        recentEvents: recentEvents,
        messagesToday: recentEvents.length,
        queueDepth: 0,
        lastUpdatedAt: now,
        lastError: '',
      );
    }, preserveCaptureState: false);
    events.publish(
      ShellEvent(
        type: ShellEventType.snapshotUpdated,
        reason: 'xiaoe_probe',
        updatedAt: next.lastUpdatedAt,
        recentEventsCount: next.recentEvents.length,
        observedConversationsCount: next.observedConversations.length,
      ),
    );
    return next;
  }

  Future<void> close() => events.close();
}

List<ObservedConversation> _observedConversationsFromProbe(
  XiaoePageProbe probe,
  List<NormalizedMessageEvent> events,
) {
  final observedAt = probe.observedAt.toUtc().toIso8601String();
  final merged = <String, ObservedConversation>{};
  final sourceId = probe.source.id.trim();
  final sourceName = probe.source.name.trim();
  if (sourceId.isNotEmpty || sourceName.isNotEmpty) {
    final id = sourceId.isNotEmpty
        ? sourceId
        : 'source:${stableXiaoeHash(sourceName)}';
    merged[id] = ObservedConversation(
      id: id,
      name: sourceName.isNotEmpty ? sourceName : id,
      type: probe.source.type.trim().isEmpty ? 'unknown' : probe.source.type,
      lastMessagePreview: events.isEmpty ? '' : events.last.text,
      observedAt: observedAt,
    );
  }
  for (final event in events) {
    final id = event.conversationId.trim();
    if (id.isEmpty || merged.containsKey(id)) {
      continue;
    }
    merged[id] = ObservedConversation(
      id: id,
      name: event.conversationName.trim().isEmpty ? id : event.conversationName,
      type: event.conversationType.trim().isEmpty
          ? 'unknown'
          : event.conversationType,
      lastMessagePreview: event.text,
      observedAt: event.observedAt.trim().isEmpty
          ? observedAt
          : event.observedAt.trim(),
    );
  }
  return List<ObservedConversation>.unmodifiable(merged.values);
}

List<ObservedMessageCandidate> _observedMessagesFromProbe(
  XiaoePageProbe probe,
) {
  final source = probe.source;
  final sourceId = source.id.trim();
  final sourceName = source.name.trim();
  if (sourceId.isEmpty && sourceName.isEmpty) {
    return const <ObservedMessageCandidate>[];
  }
  final conversationId = sourceId.isNotEmpty
      ? sourceId
      : 'source:${stableXiaoeHash(sourceName)}';
  final conversationName = sourceName.isNotEmpty ? sourceName : conversationId;
  final observedAt = probe.observedAt.toUtc().toIso8601String();
  final messages = <ObservedMessageCandidate>[];
  final seen = <String>{};
  for (final candidate in probe.commentCandidates) {
    if (!candidate.isForwardableFor(source)) {
      continue;
    }
    final messageId = candidate.id.trim().isNotEmpty
        ? candidate.id.trim()
        : 'dom:${stableXiaoeHash(candidate.text)}';
    final key = '$conversationId:$messageId';
    if (!seen.add(key)) {
      continue;
    }
    messages.add(
      ObservedMessageCandidate(
        id: messageId,
        conversationId: conversationId,
        conversationName: conversationName,
        senderName: candidate.senderName,
        messageType: candidate.fileAttachments.isNotEmpty
            ? 'file'
            : candidate.imageAttachments.isNotEmpty
            ? 'image'
            : 'text',
        text: candidate.text,
        observedAt: observedAt,
        captureSource: 'xiaoe_dom_probe',
        imageAttachments: candidate.imageAttachments,
        fileAttachments: candidate.fileAttachments,
      ),
    );
  }
  return List<ObservedMessageCandidate>.unmodifiable(messages);
}

String stableXiaoeHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16);
}
