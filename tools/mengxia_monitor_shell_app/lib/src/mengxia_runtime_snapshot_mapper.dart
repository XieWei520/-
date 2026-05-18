import 'mengxia_page_probe.dart';

Map<String, Object?> mapMengxiaRuntimeSnapshot(MengxiaPageProbe probe) {
  final isLoginPage = probe.pageKind == MengxiaPageKind.login;
  final observedAt = probe.observedAt.toUtc().toIso8601String();
  final normalizedEvents = _normalizeEvents(probe.events);
  final conversations = _mergeConversations(
    conversations: probe.conversations,
    events: normalizedEvents,
  );
  return <String, Object?>{
    'shell_state': 'online',
    'hook_state': 'healthy',
    'webview_available': true,
    'shell_mode': 'desktop_shell',
    'runtime_url': probe.runtimeUrl,
    'page_title': probe.pageTitle,
    'page_kind': probe.pageKind.wireName,
    'login_state': isLoginPage ? 'login_required' : 'logged_in',
    'capture_state': isLoginPage ? 'stopped' : 'running',
    'probe_observed_at': observedAt,
    'probe_diagnostics': Map<String, Object?>.unmodifiable(
      probe.probeDiagnostics,
    ),
    'observed_conversations': conversations
        .map((conversation) => conversation.toJson(observedAt: observedAt))
        .toList(growable: false),
    'observed_messages': const <Map<String, Object?>>[],
    'recent_events': normalizedEvents
        .map((event) => event.toJson(observedAt: observedAt))
        .toList(growable: false),
    'messages_today': normalizedEvents.length,
    'queue_depth': 0,
    'deliveries_succeeded_today': 0,
    'deliveries_failed_today': 0,
    'last_updated_at': observedAt,
    'last_error': '',
  };
}

List<MengxiaProbeMessageEvent> _normalizeEvents(
  List<MengxiaProbeMessageEvent> events,
) {
  return events.map((event) {
    final conversationId = event.conversationId.trim();
    if (conversationId.isNotEmpty) {
      return event;
    }
    final fallbackId = _fallbackConversationId(event.conversationName);
    if (fallbackId.isEmpty) {
      return event;
    }
    final fallbackDedupeKey = event.dedupeKey.trim().isEmpty
        ? '$fallbackId:${event.messageId}'
        : '$fallbackId:${event.dedupeKey}';
    return MengxiaProbeMessageEvent(
      eventId: event.eventId,
      dedupeKey: fallbackDedupeKey,
      accountId: event.accountId,
      conversationId: fallbackId,
      conversationName: event.conversationName,
      conversationType: event.conversationType,
      messageId: event.messageId,
      senderId: event.senderId,
      senderName: event.senderName,
      messageType: event.messageType,
      text: event.text,
      sentAt: event.sentAt,
      captureSource: event.captureSource,
      imageAttachments: event.imageAttachments,
    );
  }).toList(growable: false);
}

List<MengxiaProbeConversation> _mergeConversations({
  required List<MengxiaProbeConversation> conversations,
  required List<MengxiaProbeMessageEvent> events,
}) {
  final merged = <String, MengxiaProbeConversation>{};
  for (final conversation in conversations) {
    final id = conversation.id.trim().isNotEmpty
        ? conversation.id.trim()
        : _fallbackConversationId(conversation.name);
    if (id.isEmpty) {
      continue;
    }
    merged[id] = MengxiaProbeConversation(
      id: id,
      name: conversation.name,
      type: conversation.type,
      lastMessagePreview: conversation.lastMessagePreview,
    );
  }

  for (final event in events) {
    final id = event.conversationId.trim();
    if (id.isEmpty || merged.containsKey(id)) {
      continue;
    }
    final name = event.conversationName.trim().isNotEmpty
        ? event.conversationName.trim()
        : id;
    merged[id] = MengxiaProbeConversation(
      id: id,
      name: name,
      type: event.conversationType,
      lastMessagePreview: event.text,
    );
  }
  return merged.values.toList(growable: false);
}

String _fallbackConversationId(String name) {
  final normalized = name.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return 'fallback:$normalized';
}
