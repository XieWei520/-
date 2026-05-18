import 'package:wukong_im_app/modules/local_monitor/local_monitor_forwarding.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';

class MengxiaMonitorShellStatus {
  const MengxiaMonitorShellStatus({
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
  final List<MengxiaMonitorObservedConversation> observedConversations;
  final List<MengxiaMonitorObservedMessage> observedMessages;
  final List<MengxiaMonitorMessageEvent> recentEvents;
  final String workerId;
  final String lastError;

  bool get isOnline => shellState.trim().toLowerCase() == 'online';
  bool get isCapturing => captureState.trim().toLowerCase() == 'running';
  bool get needsManualLogin =>
      loginState.trim().toLowerCase() == 'login_required';

  factory MengxiaMonitorShellStatus.fromJson(Map<String, dynamic> json) {
    return MengxiaMonitorShellStatus.fromLocal(
      LocalMonitorShellStatus.fromJson(json),
    );
  }

  factory MengxiaMonitorShellStatus.fromLocal(LocalMonitorShellStatus status) {
    return MengxiaMonitorShellStatus(
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
          .map(MengxiaMonitorObservedConversation.fromLocal)
          .toList(growable: false),
      observedMessages: status.observedMessages
          .map(MengxiaMonitorObservedMessage.fromLocal)
          .toList(growable: false),
      recentEvents: status.recentEvents
          .map(MengxiaMonitorMessageEvent.fromLocal)
          .toList(growable: false),
      workerId: status.workerId,
      lastError: status.lastError,
    );
  }
}

class MengxiaMonitorObservedConversation {
  const MengxiaMonitorObservedConversation({
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

  factory MengxiaMonitorObservedConversation.fromLocal(
    LocalMonitorObservedConversation conversation,
  ) {
    return MengxiaMonitorObservedConversation(
      id: conversation.id,
      name: conversation.name,
      type: conversation.type,
      lastMessagePreview: conversation.lastMessagePreview,
      observedAt: conversation.observedAt,
    );
  }
}

class MengxiaMonitorObservedMessage {
  const MengxiaMonitorObservedMessage({
    required this.id,
    required this.conversationId,
    required this.conversationName,
    required this.senderName,
    required this.messageType,
    required this.text,
    required this.observedAt,
    required this.captureSource,
  });

  final String id;
  final String conversationId;
  final String conversationName;
  final String senderName;
  final String messageType;
  final String text;
  final DateTime? observedAt;
  final String captureSource;

  factory MengxiaMonitorObservedMessage.fromLocal(
    LocalMonitorObservedMessage message,
  ) {
    return MengxiaMonitorObservedMessage(
      id: message.id,
      conversationId: message.conversationId,
      conversationName: message.conversationName,
      senderName: message.senderName,
      messageType: message.messageType,
      text: message.text,
      observedAt: message.observedAt,
      captureSource: message.captureSource,
    );
  }
}

class MengxiaMonitorMessageEvent {
  const MengxiaMonitorMessageEvent({
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
    this.imageAttachments = const <MengxiaMonitorImageAttachment>[],
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
  final List<MengxiaMonitorImageAttachment> imageAttachments;

  bool get isForwardableText =>
      messageType.trim().toLowerCase() == 'text' && text.trim().isNotEmpty;
  bool get hasForwardableImage =>
      imageAttachments.any((image) => image.hasUsableSource);
  bool get isForwardable => isForwardableText || hasForwardableImage;

  factory MengxiaMonitorMessageEvent.fromLocal(LocalMonitorMessageEvent event) {
    return MengxiaMonitorMessageEvent(
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
          .map(MengxiaMonitorImageAttachment.fromLocal)
          .toList(growable: false),
    );
  }
}

class MengxiaMonitorImageAttachment extends LocalMonitorForwardableImage {
  const MengxiaMonitorImageAttachment({
    required super.sourceUrl,
    required super.localPath,
    required super.width,
    required super.height,
  });

  factory MengxiaMonitorImageAttachment.fromLocal(
    LocalMonitorImageAttachment image,
  ) {
    return MengxiaMonitorImageAttachment(
      sourceUrl: image.sourceUrl,
      localPath: image.localPath,
      width: image.width,
      height: image.height,
    );
  }
}

class MengxiaMonitorShellEvent {
  const MengxiaMonitorShellEvent({
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

  factory MengxiaMonitorShellEvent.fromLocal(LocalMonitorShellEvent event) {
    return MengxiaMonitorShellEvent(
      type: event.type,
      reason: event.reason,
      updatedAt: event.updatedAt,
      recentEvents: event.recentEvents,
      observedConversations: event.observedConversations,
      error: event.error,
    );
  }
}
