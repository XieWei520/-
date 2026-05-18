class LocalMonitorShellStatus {
  const LocalMonitorShellStatus({
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
    required this.observedMessages,
    required this.recentEvents,
    required this.workerId,
    required this.probeDiagnostics,
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
  final List<LocalMonitorObservedConversation> observedConversations;
  final List<LocalMonitorObservedMessage> observedMessages;
  final List<LocalMonitorMessageEvent> recentEvents;
  final String workerId;
  final Map<String, dynamic> probeDiagnostics;
  final String lastError;

  bool get isOnline => shellState.trim().toLowerCase() == 'online';
  bool get isCapturing => captureState.trim().toLowerCase() == 'running';

  factory LocalMonitorShellStatus.fromJson(Map<String, dynamic> json) {
    final diagnostics = localMonitorObject(json['probe_diagnostics']);
    return LocalMonitorShellStatus(
      shellState: (json['shell_state'] ?? 'offline').toString(),
      captureState: (json['capture_state'] ?? 'stopped').toString(),
      loginState: (json['login_state'] ?? 'unknown').toString(),
      hookState: (json['hook_state'] ?? 'unknown').toString(),
      runtimeUrl: (json['runtime_url'] ?? '').toString(),
      pageTitle: (json['page_title'] ?? '').toString(),
      pageKind: (json['page_kind'] ?? '').toString(),
      webviewAvailable: json['webview_available'] == true,
      shellMode: (json['shell_mode'] ?? 'service').toString(),
      queueDepth: localMonitorInt(json['queue_depth']),
      messagesToday: localMonitorInt(json['messages_today']),
      deliveriesSucceededToday: localMonitorInt(
        json['deliveries_succeeded_today'],
      ),
      deliveriesFailedToday: localMonitorInt(json['deliveries_failed_today']),
      lastUpdatedAt: localMonitorDateTime(json['last_updated_at']),
      probeObservedAt: localMonitorDateTime(json['probe_observed_at']),
      observedConversations: localMonitorList(
        json['observed_conversations'],
        LocalMonitorObservedConversation.fromJson,
      ),
      observedMessages: localMonitorList(
        json['observed_messages'],
        LocalMonitorObservedMessage.fromJson,
      ),
      recentEvents: localMonitorList(
        json['recent_events'],
        LocalMonitorMessageEvent.fromJson,
      ),
      workerId: (json['worker_id'] ?? diagnostics['worker_id'] ?? 'worker-1')
          .toString(),
      probeDiagnostics: diagnostics,
      lastError: (json['last_error'] ?? '').toString(),
    );
  }
}

class LocalMonitorObservedConversation {
  const LocalMonitorObservedConversation({
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

  factory LocalMonitorObservedConversation.fromJson(Map<String, dynamic> json) {
    return LocalMonitorObservedConversation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      lastMessagePreview: (json['last_message_preview'] ?? '').toString(),
      observedAt: localMonitorDateTime(json['observed_at']),
    );
  }
}

class LocalMonitorObservedMessage {
  const LocalMonitorObservedMessage({
    required this.id,
    required this.conversationId,
    required this.conversationName,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.observedAt,
    required this.captureSource,
    this.imageAttachments = const <LocalMonitorImageAttachment>[],
    this.fileAttachments = const <LocalMonitorFileAttachment>[],
  });

  final String id;
  final String conversationId;
  final String conversationName;
  final String senderName;
  final String messageType;
  final String text;
  final DateTime? observedAt;
  final String captureSource;
  final List<LocalMonitorImageAttachment> imageAttachments;
  final List<LocalMonitorFileAttachment> fileAttachments;

  factory LocalMonitorObservedMessage.fromJson(Map<String, dynamic> json) {
    return LocalMonitorObservedMessage(
      id: (json['id'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationName: (json['conversation_name'] ?? '').toString(),
      senderName: (json['sender_name'] ?? '').toString(),
      messageType: (json['message_type'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      observedAt: localMonitorDateTime(json['observed_at']),
      captureSource: (json['capture_source'] ?? '').toString(),
      imageAttachments: LocalMonitorImageAttachment.listFromJson(
        json['image_attachments'],
      ),
      fileAttachments: LocalMonitorFileAttachment.listFromJson(
        json['file_attachments'],
      ),
    );
  }
}

class LocalMonitorImageAttachment {
  const LocalMonitorImageAttachment({
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

  factory LocalMonitorImageAttachment.fromJson(Map<String, dynamic> json) {
    return LocalMonitorImageAttachment(
      sourceUrl: (json['source_url'] ?? json['sourceUrl'] ?? '').toString(),
      localPath: (json['local_path'] ?? json['localPath'] ?? '').toString(),
      width: localMonitorInt(json['width']),
      height: localMonitorInt(json['height']),
    );
  }

  static List<LocalMonitorImageAttachment> listFromJson(Object? value) {
    return localMonitorList(
      value,
      LocalMonitorImageAttachment.fromJson,
    ).where((item) => item.hasUsableSource).toList(growable: false);
  }
}

class LocalMonitorFileAttachment {
  const LocalMonitorFileAttachment({
    required this.sourceUrl,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String sourceUrl;
  final String localPath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  bool get hasUsableSource =>
      sourceUrl.trim().isNotEmpty || localPath.trim().isNotEmpty;

  factory LocalMonitorFileAttachment.fromJson(Map<String, dynamic> json) {
    return LocalMonitorFileAttachment(
      sourceUrl: (json['source_url'] ?? json['sourceUrl'] ?? '').toString(),
      localPath: (json['local_path'] ?? json['localPath'] ?? '').toString(),
      fileName: (json['file_name'] ?? json['fileName'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? json['mimeType'] ?? '').toString(),
      sizeBytes: localMonitorInt(json['size_bytes'] ?? json['sizeBytes']),
    );
  }

  static List<LocalMonitorFileAttachment> listFromJson(Object? value) {
    return localMonitorList(
      value,
      LocalMonitorFileAttachment.fromJson,
    ).where((item) => item.hasUsableSource).toList(growable: false);
  }
}

class LocalMonitorMessageEvent {
  const LocalMonitorMessageEvent({
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
    this.imageAttachments = const <LocalMonitorImageAttachment>[],
    this.fileAttachments = const <LocalMonitorFileAttachment>[],
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
  final List<LocalMonitorImageAttachment> imageAttachments;
  final List<LocalMonitorFileAttachment> fileAttachments;

  factory LocalMonitorMessageEvent.fromJson(Map<String, dynamic> json) {
    return LocalMonitorMessageEvent(
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
      sentAt: localMonitorDateTime(json['sent_at']),
      observedAt: localMonitorDateTime(json['observed_at']),
      captureSource: (json['capture_source'] ?? '').toString(),
      imageAttachments: LocalMonitorImageAttachment.listFromJson(
        json['image_attachments'],
      ),
      fileAttachments: LocalMonitorFileAttachment.listFromJson(
        json['file_attachments'],
      ),
    );
  }
}

class LocalMonitorShellEvent {
  const LocalMonitorShellEvent({
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

  bool get isSnapshotUpdated => type.trim() == 'snapshot_updated';
  bool get isShellError => type.trim() == 'shell_error';

  factory LocalMonitorShellEvent.fromJson(Map<String, dynamic> json) {
    return LocalMonitorShellEvent(
      type: (json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      updatedAt: localMonitorDateTime(json['updated_at']),
      recentEvents: localMonitorInt(json['recent_events']),
      observedConversations: localMonitorInt(json['observed_conversations']),
      error: (json['error'] ?? '').toString(),
    );
  }
}

class LocalMonitorShellHealth {
  const LocalMonitorShellHealth({
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

  factory LocalMonitorShellHealth.fromJson(Map<String, dynamic> json) {
    return LocalMonitorShellHealth(
      status: (json['status'] ?? 'unknown').toString(),
      needsLogin: json['needs_login'] == true,
      hookHealthy: json['hook_healthy'] == true,
      captureRunning: json['capture_running'] == true,
      queueDepth: localMonitorInt(json['queue_depth']),
    );
  }
}

Map<String, dynamic> localMonitorObject(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

List<T> localMonitorList<T>(
  Object? value,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (value is! List) {
    return <T>[];
  }
  return value
      .whereType<Object?>()
      .map((item) {
        if (item is Map<String, dynamic>) {
          return fromJson(item);
        }
        if (item is Map) {
          return fromJson(Map<String, dynamic>.from(item));
        }
        return null;
      })
      .whereType<T>()
      .toList(growable: false);
}

int localMonitorInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? localMonitorDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  final timestamp = int.tryParse(raw);
  if (timestamp != null) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
  return DateTime.tryParse(raw);
}
