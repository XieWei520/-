import 'dart:convert';

const Object _probeObservedAtUnset = Object();

class ObservedConversation {
  const ObservedConversation({
    required this.id,
    required this.name,
    required this.type,
    required this.lastMessagePreview,
    required this.observedAt,
  });

  final String id;
  final String name;
  final String type;
  final String lastMessagePreview;
  final String observedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'last_message_preview': lastMessagePreview,
      'observed_at': observedAt,
    };
  }

  factory ObservedConversation.fromJson(Map<String, dynamic> json) {
    return ObservedConversation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      lastMessagePreview: (json['last_message_preview'] ?? '').toString(),
      observedAt: (json['observed_at'] ?? '').toString(),
    );
  }
}

class ObservedMessageCandidate {
  const ObservedMessageCandidate({
    required this.id,
    required this.conversationId,
    required this.conversationName,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.observedAt,
    required this.captureSource,
    this.imageAttachments = const <MessageImageAttachment>[],
  });

  final String id;
  final String conversationId;
  final String conversationName;
  final String senderName;
  final String messageType;
  final String text;
  final String observedAt;
  final String captureSource;
  final List<MessageImageAttachment> imageAttachments;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'conversation_id': conversationId,
      'conversation_name': conversationName,
      'sender_name': senderName,
      'message_type': messageType,
      'text': text,
      'observed_at': observedAt,
      'capture_source': captureSource,
      'image_attachments':
          imageAttachments.map((item) => item.toJson()).toList(),
    };
  }

  factory ObservedMessageCandidate.fromJson(Map<String, dynamic> json) {
    return ObservedMessageCandidate(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationName: (json['conversation_name'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      observedAt: (json['observed_at'] ?? '').toString(),
      captureSource: (json['capture_source'] ?? '').toString(),
      imageAttachments: MessageImageAttachment.listFromJson(
        json['image_attachments'],
      ),
    );
  }
}

class MessageImageAttachment {
  const MessageImageAttachment({
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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'source_url': sourceUrl,
      'local_path': localPath,
      'width': width,
      'height': height,
    };
  }

  factory MessageImageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageImageAttachment(
      sourceUrl: (json['source_url'] ?? json['sourceUrl'] ?? '').toString(),
      localPath: (json['local_path'] ?? json['localPath'] ?? '').toString(),
      width: _asInt(json['width']),
      height: _asInt(json['height']),
    );
  }

  static List<MessageImageAttachment> listFromJson(dynamic value) {
    if (value is! List) {
      return const <MessageImageAttachment>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => MessageImageAttachment.fromJson(
            item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
          ),
        )
        .where((item) => item.hasUsableSource)
        .toList(growable: false);
  }
}

class NormalizedMessageEvent {
  const NormalizedMessageEvent({
    required this.eventId,
    required this.dedupeKey,
    required this.accountId,
    required this.conversationId,
    required this.conversationName,
    required this.conversationType,
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.sentAt,
    required this.observedAt,
    required this.captureSource,
    this.imageAttachments = const <MessageImageAttachment>[],
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
  final List<MessageImageAttachment> imageAttachments;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
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
      'image_attachments':
          imageAttachments.map((item) => item.toJson()).toList(),
    };
  }

  factory NormalizedMessageEvent.fromJson(Map<String, dynamic> json) {
    return NormalizedMessageEvent(
      eventId: (json['event_id'] ?? '').toString(),
      dedupeKey: (json['dedupe_key'] ?? '').toString(),
      accountId: (json['account_id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationName: (json['conversation_name'] ?? '').toString(),
      conversationType: (json['conversation_type'] ?? '').toString(),
      messageId: (json['message_id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      sentAt: (json['sent_at'] ?? '').toString(),
      observedAt: (json['observed_at'] ?? '').toString(),
      captureSource: (json['capture_source'] ?? '').toString(),
      imageAttachments: MessageImageAttachment.listFromJson(
        json['image_attachments'],
      ),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<NormalizedMessageEvent> mergeRecentEvents(
  List<NormalizedMessageEvent> existing,
  List<NormalizedMessageEvent> incoming, {
  int limit = 50,
}) {
  final byKey = <String, NormalizedMessageEvent>{};
  for (final event in <NormalizedMessageEvent>[...existing, ...incoming]) {
    final key =
        event.dedupeKey.trim().isEmpty
            ? event.eventId.trim()
            : event.dedupeKey.trim();
    if (key.isEmpty) {
      continue;
    }
    final current = byKey[key];
    if (current == null || _compareObservedAt(event, current) >= 0) {
      byKey[key] = event;
    }
  }
  final merged = byKey.values.toList()
    ..sort((a, b) => _compareObservedAt(b, a));
  return merged.take(limit).toList(growable: false);
}

int _compareObservedAt(NormalizedMessageEvent a, NormalizedMessageEvent b) {
  final parsedA = DateTime.tryParse(a.observedAt);
  final parsedB = DateTime.tryParse(b.observedAt);
  if (parsedA != null && parsedB != null) {
    return parsedA.compareTo(parsedB);
  }
  return a.observedAt.compareTo(b.observedAt);
}

class ShellSnapshot {
  const ShellSnapshot({
    required this.shellState,
    required this.captureState,
    required this.loginState,
    required this.hookState,
    required this.runtimeUrl,
    required this.pageTitle,
    required this.webviewAvailable,
    required this.shellMode,
    required this.pageKind,
    required this.probeObservedAt,
    required this.probeDiagnostics,
    required this.observedConversations,
    required this.observedMessages,
    required this.recentEvents,
    required this.queueDepth,
    required this.messagesToday,
    required this.deliveriesSucceededToday,
    required this.deliveriesFailedToday,
    required this.lastUpdatedAt,
    required this.lastError,
  });

  final String shellState;
  final String captureState;
  final String loginState;
  final String hookState;
  final String runtimeUrl;
  final String pageTitle;
  final bool webviewAvailable;
  final String shellMode;
  final String pageKind;
  final DateTime? probeObservedAt;
  final Map<String, dynamic> probeDiagnostics;
  final List<ObservedConversation> observedConversations;
  final List<ObservedMessageCandidate> observedMessages;
  final List<NormalizedMessageEvent> recentEvents;
  final int queueDepth;
  final int messagesToday;
  final int deliveriesSucceededToday;
  final int deliveriesFailedToday;
  final DateTime lastUpdatedAt;
  final String lastError;

  factory ShellSnapshot.initial() {
    return ShellSnapshot(
      shellState: 'online',
      captureState: 'stopped',
      loginState: 'needs_login',
      hookState: 'idle',
      runtimeUrl: '',
      pageTitle: '',
      webviewAvailable: false,
      shellMode: 'service',
      pageKind: 'unknown',
      probeObservedAt: null,
      probeDiagnostics: const <String, dynamic>{},
      observedConversations: const <ObservedConversation>[],
      observedMessages: const <ObservedMessageCandidate>[],
      recentEvents: const <NormalizedMessageEvent>[],
      queueDepth: 0,
      messagesToday: 0,
      deliveriesSucceededToday: 0,
      deliveriesFailedToday: 0,
      lastUpdatedAt: DateTime.now().toUtc(),
      lastError: '',
    );
  }

  ShellSnapshot copyWith({
    String? shellState,
    String? captureState,
    String? loginState,
    String? hookState,
    String? runtimeUrl,
    String? pageTitle,
    bool? webviewAvailable,
    String? shellMode,
    String? pageKind,
    Object? probeObservedAt = _probeObservedAtUnset,
    Map<String, dynamic>? probeDiagnostics,
    List<ObservedConversation>? observedConversations,
    List<ObservedMessageCandidate>? observedMessages,
    List<NormalizedMessageEvent>? recentEvents,
    int? queueDepth,
    int? messagesToday,
    int? deliveriesSucceededToday,
    int? deliveriesFailedToday,
    DateTime? lastUpdatedAt,
    String? lastError,
  }) {
    return ShellSnapshot(
      shellState: shellState ?? this.shellState,
      captureState: captureState ?? this.captureState,
      loginState: loginState ?? this.loginState,
      hookState: hookState ?? this.hookState,
      runtimeUrl: runtimeUrl ?? this.runtimeUrl,
      pageTitle: pageTitle ?? this.pageTitle,
      webviewAvailable: webviewAvailable ?? this.webviewAvailable,
      shellMode: shellMode ?? this.shellMode,
      pageKind: pageKind ?? this.pageKind,
      probeObservedAt:
          identical(probeObservedAt, _probeObservedAtUnset)
              ? this.probeObservedAt
              : probeObservedAt as DateTime?,
      probeDiagnostics: probeDiagnostics ?? this.probeDiagnostics,
      observedConversations:
          observedConversations ?? this.observedConversations,
      observedMessages: observedMessages ?? this.observedMessages,
      recentEvents: recentEvents ?? this.recentEvents,
      queueDepth: queueDepth ?? this.queueDepth,
      messagesToday: messagesToday ?? this.messagesToday,
      deliveriesSucceededToday:
          deliveriesSucceededToday ?? this.deliveriesSucceededToday,
      deliveriesFailedToday:
          deliveriesFailedToday ?? this.deliveriesFailedToday,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'shell_state': shellState,
      'capture_state': captureState,
      'login_state': loginState,
      'hook_state': hookState,
      'runtime_url': runtimeUrl,
      'page_title': pageTitle,
      'webview_available': webviewAvailable,
      'shell_mode': shellMode,
      'page_kind': pageKind,
      'probe_observed_at': probeObservedAt?.toUtc().toIso8601String() ?? '',
      'probe_diagnostics': probeDiagnostics,
      'observed_conversations':
          observedConversations.map((item) => item.toJson()).toList(),
      'observed_messages':
          observedMessages.map((item) => item.toJson()).toList(),
      'recent_events': recentEvents.map((item) => item.toJson()).toList(),
      'queue_depth': queueDepth,
      'messages_today': messagesToday,
      'deliveries_succeeded_today': deliveriesSucceededToday,
      'deliveries_failed_today': deliveriesFailedToday,
      'last_updated_at': lastUpdatedAt.toUtc().toIso8601String(),
      'last_error': lastError,
    };
  }

  Map<String, dynamic> toHealthJson() {
    return <String, dynamic>{
      'status': shellState == 'online' ? 'ok' : 'down',
      'needs_login': loginState != 'logged_in',
      'hook_healthy': hookState == 'healthy',
      'capture_running': captureState == 'running',
      'queue_depth': queueDepth,
    };
  }

  static ShellSnapshot fromJsonString(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return ShellSnapshot.initial();
    }
    if (decoded is! Map) {
      return ShellSnapshot.initial();
    }
    final json = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return ShellSnapshot(
      shellState: (json['shell_state'] ?? 'offline').toString(),
      captureState: (json['capture_state'] ?? 'stopped').toString(),
      loginState: (json['login_state'] ?? 'unknown').toString(),
      hookState: (json['hook_state'] ?? 'unknown').toString(),
      runtimeUrl: (json['runtime_url'] ?? '').toString(),
      pageTitle: (json['page_title'] ?? '').toString(),
      webviewAvailable: json['webview_available'] == true,
      shellMode: (json['shell_mode'] ?? 'service').toString(),
      pageKind: (json['page_kind'] ?? 'unknown').toString(),
      probeObservedAt: _asDateTime(json['probe_observed_at']),
      probeDiagnostics: _asMap(json['probe_diagnostics']),
      observedConversations: _asConversationList(
        json['observed_conversations'],
      ),
      observedMessages: _asMessageList(json['observed_messages']),
      recentEvents: _asEventList(json['recent_events']),
      queueDepth: _asInt(json['queue_depth']),
      messagesToday: _asInt(json['messages_today']),
      deliveriesSucceededToday: _asInt(json['deliveries_succeeded_today']),
      deliveriesFailedToday: _asInt(json['deliveries_failed_today']),
      lastUpdatedAt:
          DateTime.tryParse(json['last_updated_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      lastError: (json['last_error'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is! Map) {
      return const <String, dynamic>{};
    }
    return Map<String, dynamic>.unmodifiable(
      value.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
    );
  }

  static List<ObservedConversation> _asConversationList(dynamic value) {
    if (value is! List) {
      return const <ObservedConversation>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => ObservedConversation.fromJson(
            item.map(
              (key, itemValue) =>
                  MapEntry(key.toString(), itemValue),
            ),
          ),
        )
        .toList(growable: false);
  }

  static List<ObservedMessageCandidate> _asMessageList(dynamic value) {
    if (value is! List) {
      return const <ObservedMessageCandidate>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => ObservedMessageCandidate.fromJson(
            item.map(
              (key, itemValue) =>
                  MapEntry(key.toString(), itemValue),
            ),
          ),
        )
        .toList(growable: false);
  }

  static List<NormalizedMessageEvent> _asEventList(dynamic value) {
    if (value is! List) {
      return const <NormalizedMessageEvent>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => NormalizedMessageEvent.fromJson(
            item.map(
              (key, itemValue) =>
                  MapEntry(key.toString(), itemValue),
            ),
          ),
        )
        .toList(growable: false);
  }
}
