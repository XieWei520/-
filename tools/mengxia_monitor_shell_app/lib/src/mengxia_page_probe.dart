enum MengxiaPageKind {
  login('login'),
  workspace('workspace'),
  unknown('unknown');

  const MengxiaPageKind(this.wireName);

  final String wireName;
}

class MengxiaPageProbe {
  const MengxiaPageProbe({
    required this.runtimeUrl,
    required this.pageTitle,
    required this.pageKind,
    required this.observedAt,
    this.bodyText = '',
    this.conversations = const <MengxiaProbeConversation>[],
    this.events = const <MengxiaProbeMessageEvent>[],
    this.probeDiagnostics = const <String, Object?>{},
  });

  final String runtimeUrl;
  final String pageTitle;
  final String bodyText;
  final MengxiaPageKind pageKind;
  final DateTime observedAt;
  final List<MengxiaProbeConversation> conversations;
  final List<MengxiaProbeMessageEvent> events;
  final Map<String, Object?> probeDiagnostics;
}

class MengxiaProbeConversation {
  const MengxiaProbeConversation({
    required this.id,
    required this.name,
    required this.type,
    required this.lastMessagePreview,
  });

  final String id;
  final String name;
  final String type;
  final String lastMessagePreview;

  Map<String, Object?> toJson({required String observedAt}) {
    return <String, Object?>{
      'id': id,
      'name': name,
      'type': type,
      'last_message_preview': lastMessagePreview,
      'observed_at': observedAt,
    };
  }

  factory MengxiaProbeConversation.fromJson(Map<String, Object?> json) {
    return MengxiaProbeConversation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'unknown').toString(),
      lastMessagePreview: (json['last_message_preview'] ?? '').toString(),
    );
  }
}

class MengxiaProbeMessageEvent {
  const MengxiaProbeMessageEvent({
    required this.eventId,
    required this.dedupeKey,
    required this.conversationId,
    required this.conversationName,
    required this.conversationType,
    required this.messageId,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.captureSource,
    this.accountId = '',
    this.senderId = '',
    this.sentAt = '',
    this.imageAttachments = const <MengxiaProbeImageAttachment>[],
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
  final String captureSource;
  final List<MengxiaProbeImageAttachment> imageAttachments;

  Map<String, Object?> toJson({required String observedAt}) {
    return <String, Object?>{
      'event_id': eventId,
      'dedupe_key': dedupeKey,
      'account_id': accountId,
      'conversation_id': conversationId,
      'conversation_name': conversationName,
      'conversation_type': conversationType,
      'message_id': messageId,
      'sender_id': senderId,
      'sender_name': senderName,
      'message_type': messageType,
      'text': text,
      'sent_at': sentAt,
      'observed_at': observedAt,
      'capture_source': captureSource,
      'image_attachments': imageAttachments
          .map((image) => image.toJson())
          .toList(growable: false),
    };
  }

  factory MengxiaProbeMessageEvent.fromJson(Map<String, Object?> json) {
    return MengxiaProbeMessageEvent(
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
      captureSource: (json['capture_source'] ?? 'dom_probe').toString(),
      imageAttachments: MengxiaProbeImageAttachment.listFromJson(
        json['image_attachments'],
      ),
    );
  }
}

class MengxiaProbeImageAttachment {
  const MengxiaProbeImageAttachment({
    required this.sourceUrl,
    required this.localPath,
    required this.width,
    required this.height,
  });

  final String sourceUrl;
  final String localPath;
  final int width;
  final int height;

  bool get hasUsableSource =>
      sourceUrl.trim().isNotEmpty || localPath.trim().isNotEmpty;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'source_url': sourceUrl,
      'local_path': localPath,
      'width': width,
      'height': height,
    };
  }

  factory MengxiaProbeImageAttachment.fromJson(Map<String, Object?> json) {
    return MengxiaProbeImageAttachment(
      sourceUrl: (json['source_url'] ?? json['sourceUrl'] ?? '').toString(),
      localPath: (json['local_path'] ?? json['localPath'] ?? '').toString(),
      width: _intFromJson(json['width']),
      height: _intFromJson(json['height']),
    );
  }

  static List<MengxiaProbeImageAttachment> listFromJson(Object? value) {
    if (value is! List) {
      return const <MengxiaProbeImageAttachment>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => MengxiaProbeImageAttachment.fromJson(
            item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
          ),
        )
        .where((image) => image.hasUsableSource)
        .toList(growable: false);
  }
}

int _intFromJson(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

MengxiaPageKind deriveMengxiaPageKind({
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
      normalizedUrl.contains('account') ||
      normalizedTitle.contains('login') ||
      normalizedTitle.contains('登录') ||
      normalizedBody.contains('scan qr code') ||
      normalizedBody.contains('扫码') ||
      normalizedBody.contains('登录')) {
    return MengxiaPageKind.login;
  }

  if (hasForwardableContent ||
      normalizedUrl.contains('message') ||
      normalizedUrl.contains('chat') ||
      normalizedUrl.contains('workspace')) {
    return MengxiaPageKind.workspace;
  }

  return MengxiaPageKind.unknown;
}

MengxiaPageProbe mengxiaPageProbeFromJson(Map<String, Object?> json) {
  final bodyText = (json['body_text'] ?? '').toString();
  final pageKind = deriveMengxiaPageKind(
    runtimeUrl: (json['runtime_url'] ?? '').toString(),
    pageTitle: (json['page_title'] ?? '').toString(),
    bodyText: bodyText,
    hasForwardableContent: json['has_forwardable_content'] == true,
  );

  return MengxiaPageProbe(
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

List<MengxiaProbeConversation> _readConversationList(Object? value) {
  if (value is! List) {
    return const <MengxiaProbeConversation>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => MengxiaProbeConversation.fromJson(
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

List<MengxiaProbeMessageEvent> _readEventList(Object? value) {
  if (value is! List) {
    return const <MengxiaProbeMessageEvent>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => MengxiaProbeMessageEvent.fromJson(
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

List<MengxiaProbeConversation> _mergeConversationLists(
  List<MengxiaProbeConversation> primary,
  List<MengxiaProbeConversation> secondary,
) {
  final merged = <MengxiaProbeConversation>[];
  final seen = <String>{};
  for (final conversation in <MengxiaProbeConversation>[
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
  return List<MengxiaProbeConversation>.unmodifiable(merged);
}
