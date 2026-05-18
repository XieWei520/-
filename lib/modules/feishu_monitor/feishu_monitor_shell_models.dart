import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';

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
    this.workerId = 'worker-1',
    this.mediaQueueDepth = 0,
    this.mediaQueueOldestWaitSeconds = 0,
    this.mediaQueueEstimatedNextDelaySeconds = 0,
    this.mediaQueueLastSkipReason = '',
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
  final String workerId;
  final int mediaQueueDepth;
  final int mediaQueueOldestWaitSeconds;
  final int mediaQueueEstimatedNextDelaySeconds;
  final String mediaQueueLastSkipReason;
  final String lastError;

  bool get isOnline => shellState.trim().toLowerCase() == 'online';
  bool get isCapturing => captureState.trim().toLowerCase() == 'running';

  factory FeishuMonitorShellStatus.fromJson(Map<String, dynamic> json) {
    final shared = LocalMonitorShellStatus.fromJson(json);
    final diagnostics = shared.probeDiagnostics;
    return FeishuMonitorShellStatus.fromLocal(
      shared,
      mediaQueueDepth: localMonitorInt(
        diagnostics['media_queue_depth'] ?? json['media_queue_depth'],
      ),
      mediaQueueOldestWaitSeconds: localMonitorInt(
        diagnostics['media_queue_oldest_wait_seconds'] ??
            json['media_queue_oldest_wait_seconds'],
      ),
      mediaQueueEstimatedNextDelaySeconds: localMonitorInt(
        diagnostics['media_queue_estimated_next_delay_seconds'] ??
            json['media_queue_estimated_next_delay_seconds'],
      ),
      mediaQueueLastSkipReason:
          (diagnostics['media_queue_last_skip_reason'] ??
                  json['media_queue_last_skip_reason'] ??
                  '')
              .toString(),
    );
  }

  factory FeishuMonitorShellStatus.fromLocal(
    LocalMonitorShellStatus status, {
    int mediaQueueDepth = 0,
    int mediaQueueOldestWaitSeconds = 0,
    int mediaQueueEstimatedNextDelaySeconds = 0,
    String mediaQueueLastSkipReason = '',
  }) {
    return FeishuMonitorShellStatus(
      shellState: status.shellState,
      captureState: status.captureState,
      loginState: status.loginState,
      hookState: status.hookState,
      runtimeUrl: status.runtimeUrl,
      pageTitle: status.pageTitle,
      pageKind: status.pageKind,
      webviewAvailable: status.webviewAvailable,
      shellMode: status.shellMode,
      queueDepth: status.queueDepth,
      messagesToday: status.messagesToday,
      deliveriesSucceededToday: status.deliveriesSucceededToday,
      deliveriesFailedToday: status.deliveriesFailedToday,
      lastUpdatedAt: status.lastUpdatedAt,
      probeObservedAt: status.probeObservedAt,
      observedConversations: status.observedConversations
          .map(FeishuMonitorObservedConversation.fromLocal)
          .toList(growable: false),
      observedMessages: status.observedMessages
          .map(FeishuMonitorObservedMessage.fromLocal)
          .toList(growable: false),
      recentEvents: status.recentEvents
          .map(FeishuMonitorMessageEvent.fromLocal)
          .toList(growable: false),
      workerId: status.workerId,
      mediaQueueDepth: mediaQueueDepth,
      mediaQueueOldestWaitSeconds: mediaQueueOldestWaitSeconds,
      mediaQueueEstimatedNextDelaySeconds: mediaQueueEstimatedNextDelaySeconds,
      mediaQueueLastSkipReason: mediaQueueLastSkipReason,
      lastError: status.lastError,
    );
  }

  static DateTime? asDateTime(Object? value) => localMonitorDateTime(value);
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
    return FeishuMonitorObservedConversation.fromLocal(
      LocalMonitorObservedConversation.fromJson(json),
    );
  }

  factory FeishuMonitorObservedConversation.fromLocal(
    LocalMonitorObservedConversation conversation,
  ) {
    return FeishuMonitorObservedConversation(
      id: conversation.id,
      name: conversation.name,
      type: conversation.type,
      lastMessagePreview: conversation.lastMessagePreview,
      observedAt: conversation.observedAt,
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
    return FeishuMonitorObservedMessage.fromLocal(
      LocalMonitorObservedMessage.fromJson(json),
    );
  }

  factory FeishuMonitorObservedMessage.fromLocal(
    LocalMonitorObservedMessage message,
  ) {
    return FeishuMonitorObservedMessage(
      id: message.id,
      conversationId: message.conversationId,
      conversationName: message.conversationName,
      senderName: message.senderName,
      messageType: message.messageType,
      text: message.text,
      observedAt: message.observedAt,
      captureSource: message.captureSource,
      imageAttachments: message.imageAttachments
          .map(FeishuMonitorImageAttachment.fromLocal)
          .toList(growable: false),
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
    return FeishuMonitorImageAttachment.fromLocal(
      LocalMonitorImageAttachment.fromJson(json),
    );
  }

  factory FeishuMonitorImageAttachment.fromLocal(
    LocalMonitorImageAttachment image,
  ) {
    return FeishuMonitorImageAttachment(
      sourceUrl: image.sourceUrl,
      localPath: image.localPath,
      width: image.width,
      height: image.height,
    );
  }

  static List<FeishuMonitorImageAttachment> listFromJson(Object? value) {
    return LocalMonitorImageAttachment.listFromJson(
      value,
    ).map(FeishuMonitorImageAttachment.fromLocal).toList(growable: false);
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
    return FeishuMonitorMessageEvent.fromLocal(
      LocalMonitorMessageEvent.fromJson(json),
    );
  }

  factory FeishuMonitorMessageEvent.fromLocal(LocalMonitorMessageEvent event) {
    return FeishuMonitorMessageEvent(
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
      text: event.text,
      sentAt: event.sentAt,
      observedAt: event.observedAt,
      captureSource: event.captureSource,
      imageAttachments: event.imageAttachments
          .map(FeishuMonitorImageAttachment.fromLocal)
          .toList(growable: false),
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
    return FeishuMonitorShellEvent.fromLocal(
      LocalMonitorShellEvent.fromJson(json),
    );
  }

  factory FeishuMonitorShellEvent.fromLocal(LocalMonitorShellEvent event) {
    return FeishuMonitorShellEvent(
      type: event.type,
      reason: event.reason,
      updatedAt: event.updatedAt,
      recentEvents: event.recentEvents,
      observedConversations: event.observedConversations,
      error: event.error,
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
    return FeishuMonitorShellHealth.fromLocal(
      LocalMonitorShellHealth.fromJson(json),
    );
  }

  factory FeishuMonitorShellHealth.fromLocal(LocalMonitorShellHealth health) {
    return FeishuMonitorShellHealth(
      status: health.status,
      needsLogin: health.needsLogin,
      hookHealthy: health.hookHealthy,
      captureRunning: health.captureRunning,
      queueDepth: health.queueDepth,
    );
  }
}
