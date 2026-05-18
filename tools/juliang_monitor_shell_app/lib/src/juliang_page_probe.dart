enum JuliangPageKind {
  login('login'),
  workspace('workspace'),
  unknown('unknown');

  const JuliangPageKind(this.wireName);

  final String wireName;
}

class JuliangPageProbe {
  const JuliangPageProbe({
    required this.runtimeUrl,
    required this.pageTitle,
    required this.bodyText,
    required this.pageKind,
    required this.observedAt,
    this.conversations = const <JuliangProbeConversation>[],
    this.events = const <JuliangProbeMessageEvent>[],
    this.probeDiagnostics = const <String, Object?>{},
  });

  final String runtimeUrl;
  final String pageTitle;
  final String bodyText;
  final JuliangPageKind pageKind;
  final DateTime observedAt;
  final List<JuliangProbeConversation> conversations;
  final List<JuliangProbeMessageEvent> events;
  final Map<String, Object?> probeDiagnostics;
}

class JuliangProbeConversation {
  const JuliangProbeConversation({
    required this.id,
    required this.name,
    required this.type,
    required this.lastMessagePreview,
  });

  final String id;
  final String name;
  final String type;
  final String lastMessagePreview;

  factory JuliangProbeConversation.fromJson(Map<String, Object?> json) {
    return JuliangProbeConversation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'unknown').toString(),
      lastMessagePreview: (json['last_message_preview'] ?? '').toString(),
    );
  }
}

class JuliangProbeMessageEvent {
  const JuliangProbeMessageEvent({
    required this.eventId,
    required this.dedupeKey,
    required this.conversationId,
    required this.conversationName,
    required this.conversationType,
    required this.messageId,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.observedAt,
    required this.captureSource,
    this.accountId = '',
    this.senderId = '',
    this.sentAt = '',
  });

  final String eventId;
  final String dedupeKey;
  final String accountId;
  final String conversationId;
  final String conversationName;
  final String conversationType;
  final String messageId;
  final String senderId;
  final String senderName;
  final String messageType;
  final String text;
  final String sentAt;
  final String observedAt;
  final String captureSource;

  factory JuliangProbeMessageEvent.fromJson(Map<String, Object?> json) {
    return JuliangProbeMessageEvent(
      eventId: (json['event_id'] ?? '').toString(),
      dedupeKey: (json['dedupe_key'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationName: (json['conversation_name'] ?? '').toString(),
      conversationType: (json['conversation_type'] ?? 'unknown').toString(),
      messageId: (json['message_id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? 'text').toString(),
      text: (json['text'] ?? '').toString(),
      sentAt: (json['sent_at'] ?? '').toString(),
      observedAt: (json['observed_at'] ?? '').toString(),
      captureSource: (json['capture_source'] ?? 'dom_probe').toString(),
    );
  }
}

JuliangPageProbe juliangPageProbeFromJson(Map<String, Object?> json) {
  final bodyText = (json['body_text'] ?? '').toString();
  final pageKind = deriveJuliangPageKind(
    runtimeUrl: (json['runtime_url'] ?? '').toString(),
    pageTitle: (json['page_title'] ?? '').toString(),
    bodyText: bodyText,
    hasForwardableContent: json['has_forwardable_content'] == true,
  );
  return JuliangPageProbe(
    runtimeUrl: (json['runtime_url'] ?? '').toString(),
    pageTitle: (json['page_title'] ?? '').toString(),
    bodyText: bodyText,
    pageKind: pageKind,
    observedAt:
        DateTime.tryParse((json['observed_at'] ?? '').toString()) ??
        DateTime.now().toUtc(),
    conversations: _mergeConversationLists(
      _readConversationList(json['conversations']),
      _readConversationList(json['source_candidates']),
    ),
    events: _readEventList(json['events']),
    probeDiagnostics: _readDiagnostics(json['probe_diagnostics']),
  );
}

JuliangPageKind deriveJuliangPageKind({
  required String runtimeUrl,
  required String pageTitle,
  required String bodyText,
  required bool hasForwardableContent,
}) {
  final normalizedUrl = runtimeUrl.trim().toLowerCase();
  final normalizedTitle = pageTitle.trim().toLowerCase();
  final normalizedBody = bodyText.trim().toLowerCase();

  if (normalizedUrl.contains('login') ||
      normalizedUrl.contains('passport') ||
      normalizedTitle.contains('login') ||
      normalizedTitle.contains('登录') ||
      normalizedBody.contains('login') ||
      normalizedBody.contains('登录') ||
      normalizedBody.contains('扫码')) {
    return JuliangPageKind.login;
  }

  if (hasForwardableContent ||
      normalizedUrl.contains('/user') ||
      normalizedUrl.contains('message') ||
      normalizedUrl.contains('chat')) {
    return JuliangPageKind.workspace;
  }

  return JuliangPageKind.unknown;
}

List<JuliangProbeConversation> _readConversationList(Object? value) {
  if (value is! List) {
    return const <JuliangProbeConversation>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => JuliangProbeConversation.fromJson(
          item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
        ),
      )
      .where(
        (conversation) =>
            conversation.id.trim().isNotEmpty ||
            conversation.name.trim().isNotEmpty,
      )
      .toList(growable: false);
}

List<JuliangProbeMessageEvent> _readEventList(Object? value) {
  if (value is! List) {
    return const <JuliangProbeMessageEvent>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => JuliangProbeMessageEvent.fromJson(
          item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
        ),
      )
      .where(
        (event) =>
            event.text.trim().isNotEmpty &&
            (event.conversationId.trim().isNotEmpty ||
                event.conversationName.trim().isNotEmpty),
      )
      .toList(growable: false);
}

Map<String, Object?> _readDiagnostics(Object? value) {
  if (value is! Map) {
    return const <String, Object?>{};
  }
  return Map<String, Object?>.unmodifiable(
    value.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
  );
}

List<JuliangProbeConversation> _mergeConversationLists(
  List<JuliangProbeConversation> primary,
  List<JuliangProbeConversation> secondary,
) {
  final merged = <JuliangProbeConversation>[];
  final seen = <String>{};
  for (final conversation in <JuliangProbeConversation>[
    ...primary,
    ...secondary,
  ]) {
    final id = conversation.id.trim();
    final name = conversation.name.trim();
    final key = id.isNotEmpty ? id : name;
    if (key.isEmpty || !seen.add(key)) {
      continue;
    }
    merged.add(conversation);
  }
  return List<JuliangProbeConversation>.unmodifiable(merged);
}
