class FeishuMonitorShellStatus {
  const FeishuMonitorShellStatus({
    required this.shellState,
    required this.captureState,
    required this.loginState,
    required this.hookState,
    required this.runtimeUrl,
    required this.pageTitle,
    required this.pageKind,
    required this.webviewAvailable,
    required this.shellMode,
    required this.queueDepth,
    required this.messagesToday,
    required this.deliveriesSucceededToday,
    required this.deliveriesFailedToday,
    required this.lastUpdatedAt,
    required this.probeObservedAt,
    required this.observedConversations,
    this.observedMessages = const <FeishuMonitorObservedMessage>[],
    this.recentEvents = const <FeishuMonitorMessageEvent>[],
    required this.lastError,
  });

  final String shellState;
  final String captureState;
  final String loginState;
  final String hookState;
  final String runtimeUrl;
  final String pageTitle;
  final String pageKind;
  final bool webviewAvailable;
  final String shellMode;
  final int queueDepth;
  final int messagesToday;
  final int deliveriesSucceededToday;
  final int deliveriesFailedToday;
  final DateTime? lastUpdatedAt;
  final DateTime? probeObservedAt;
  final List<FeishuMonitorObservedConversation> observedConversations;
  final List<FeishuMonitorObservedMessage> observedMessages;
  final List<FeishuMonitorMessageEvent> recentEvents;
  final String lastError;

  bool get isOnline => shellState.trim().toLowerCase() == 'online';
  bool get isCapturing => captureState.trim().toLowerCase() == 'running';

  factory FeishuMonitorShellStatus.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorShellStatus(
      shellState: (json['shell_state'] ?? 'offline').toString(),
      captureState: (json['capture_state'] ?? 'stopped').toString(),
      loginState: (json['login_state'] ?? 'unknown').toString(),
      hookState: (json['hook_state'] ?? 'unknown').toString(),
      runtimeUrl: (json['runtime_url'] ?? '').toString(),
      pageTitle: (json['page_title'] ?? '').toString(),
      pageKind: (json['page_kind'] ?? '').toString(),
      webviewAvailable: json['webview_available'] == true,
      shellMode: (json['shell_mode'] ?? 'service').toString(),
      queueDepth: _asInt(json['queue_depth']),
      messagesToday: _asInt(json['messages_today']),
      deliveriesSucceededToday: _asInt(json['deliveries_succeeded_today']),
      deliveriesFailedToday: _asInt(json['deliveries_failed_today']),
      lastUpdatedAt: _asDateTime(json['last_updated_at']),
      probeObservedAt: _asDateTime(json['probe_observed_at']),
      observedConversations: _asObservedConversations(
        json['observed_conversations'],
      ),
      observedMessages: _asObservedMessages(json['observed_messages']),
      recentEvents: _asRecentEvents(json['recent_events']),
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

  static DateTime? asDateTime(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static DateTime? _asDateTime(dynamic value) => asDateTime(value);

  static List<FeishuMonitorObservedConversation> _asObservedConversations(
    dynamic value,
  ) {
    if (value is! List) {
      return const <FeishuMonitorObservedConversation>[];
    }

    return value
        .whereType<Object?>()
        .map((item) {
          if (item is Map<String, dynamic>) {
            return FeishuMonitorObservedConversation.fromJson(item);
          }
          if (item is Map) {
            return FeishuMonitorObservedConversation.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<FeishuMonitorObservedConversation>()
        .toList(growable: false);
  }

  static List<FeishuMonitorObservedMessage> _asObservedMessages(dynamic value) {
    if (value is! List) {
      return const <FeishuMonitorObservedMessage>[];
    }

    return value
        .whereType<Object?>()
        .map((item) {
          if (item is Map<String, dynamic>) {
            return FeishuMonitorObservedMessage.fromJson(item);
          }
          if (item is Map) {
            return FeishuMonitorObservedMessage.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<FeishuMonitorObservedMessage>()
        .toList(growable: false);
  }

  static List<FeishuMonitorMessageEvent> _asRecentEvents(dynamic value) {
    if (value is! List) {
      return const <FeishuMonitorMessageEvent>[];
    }

    return value
        .whereType<Object?>()
        .map((item) {
          if (item is Map<String, dynamic>) {
            return FeishuMonitorMessageEvent.fromJson(item);
          }
          if (item is Map) {
            return FeishuMonitorMessageEvent.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<FeishuMonitorMessageEvent>()
        .toList(growable: false);
  }
}

class FeishuMonitorObservedConversation {
  const FeishuMonitorObservedConversation({
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
  final DateTime? observedAt;

  factory FeishuMonitorObservedConversation.fromJson(
    Map<String, dynamic> json,
  ) {
    return FeishuMonitorObservedConversation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      lastMessagePreview: (json['last_message_preview'] ?? '').toString(),
      observedAt: FeishuMonitorShellStatus._asDateTime(json['observed_at']),
    );
  }
}

class FeishuMonitorObservedMessage {
  const FeishuMonitorObservedMessage({
    required this.id,
    required this.conversationId,
    required this.conversationName,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.observedAt,
    required this.captureSource,
    this.imageAttachments = const <FeishuMonitorImageAttachment>[],
  });

  final String id;
  final String conversationId;
  final String conversationName;
  final String senderName;
  final String messageType;
  final String text;
  final DateTime? observedAt;
  final String captureSource;
  final List<FeishuMonitorImageAttachment> imageAttachments;

  factory FeishuMonitorObservedMessage.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorObservedMessage(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationName: (json['conversation_name'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      observedAt: FeishuMonitorShellStatus.asDateTime(json['observed_at']),
      captureSource: (json['capture_source'] ?? '').toString(),
      imageAttachments: FeishuMonitorImageAttachment.listFromJson(
        json['image_attachments'],
      ),
    );
  }
}

class FeishuMonitorImageAttachment {
  const FeishuMonitorImageAttachment({
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

  factory FeishuMonitorImageAttachment.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorImageAttachment(
      sourceUrl: (json['source_url'] ?? json['sourceUrl'] ?? '').toString(),
      localPath: (json['local_path'] ?? json['localPath'] ?? '').toString(),
      width: FeishuMonitorShellStatus._asInt(json['width']),
      height: FeishuMonitorShellStatus._asInt(json['height']),
    );
  }

  static List<FeishuMonitorImageAttachment> listFromJson(dynamic value) {
    if (value is! List) {
      return const <FeishuMonitorImageAttachment>[];
    }
    return value
        .whereType<Object?>()
        .map((item) {
          if (item is Map<String, dynamic>) {
            return FeishuMonitorImageAttachment.fromJson(item);
          }
          if (item is Map) {
            return FeishuMonitorImageAttachment.fromJson(
              Map<String, dynamic>.from(item),
            );
          }
          return null;
        })
        .whereType<FeishuMonitorImageAttachment>()
        .where((item) => item.hasUsableSource)
        .toList(growable: false);
  }
}

class FeishuMonitorMessageEvent {
  const FeishuMonitorMessageEvent({
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
    this.imageAttachments = const <FeishuMonitorImageAttachment>[],
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
  final DateTime? sentAt;
  final DateTime? observedAt;
  final String captureSource;
  final List<FeishuMonitorImageAttachment> imageAttachments;

  factory FeishuMonitorMessageEvent.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorMessageEvent(
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
      sentAt: FeishuMonitorShellStatus.asDateTime(json['sent_at']),
      observedAt: FeishuMonitorShellStatus.asDateTime(json['observed_at']),
      captureSource: (json['capture_source'] ?? '').toString(),
      imageAttachments: FeishuMonitorImageAttachment.listFromJson(
        json['image_attachments'],
      ),
    );
  }
}

class FeishuMonitorShellEvent {
  const FeishuMonitorShellEvent({
    required this.type,
    required this.reason,
    required this.updatedAt,
    required this.recentEvents,
    required this.observedConversations,
    required this.error,
  });

  final String type;
  final String reason;
  final DateTime? updatedAt;
  final int recentEvents;
  final int observedConversations;
  final String error;

  bool get isSnapshotUpdated => type == 'snapshot_updated';
  bool get isShellError => type == 'shell_error';

  factory FeishuMonitorShellEvent.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorShellEvent(
      type: (json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      updatedAt: FeishuMonitorShellStatus.asDateTime(json['updated_at']),
      recentEvents: FeishuMonitorShellStatus._asInt(json['recent_events']),
      observedConversations: FeishuMonitorShellStatus._asInt(
        json['observed_conversations'],
      ),
      error: (json['error'] ?? '').toString(),
    );
  }
}

class FeishuMonitorShellHealth {
  const FeishuMonitorShellHealth({
    required this.status,
    required this.needsLogin,
    required this.hookHealthy,
    required this.captureRunning,
    required this.queueDepth,
  });

  final String status;
  final bool needsLogin;
  final bool hookHealthy;
  final bool captureRunning;
  final int queueDepth;

  factory FeishuMonitorShellHealth.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorShellHealth(
      status: (json['status'] ?? 'unknown').toString(),
      needsLogin: json['needs_login'] == true,
      hookHealthy: json['hook_healthy'] == true,
      captureRunning: json['capture_running'] == true,
      queueDepth: FeishuMonitorShellStatus._asInt(json['queue_depth']),
    );
  }
}
