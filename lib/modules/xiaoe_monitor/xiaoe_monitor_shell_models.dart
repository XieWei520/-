import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';

typedef XiaoeMonitorObservedConversation = LocalMonitorObservedConversation;

typedef XiaoeMonitorObservedMessage = LocalMonitorObservedMessage;

typedef XiaoeMonitorImageAttachment = LocalMonitorImageAttachment;

typedef XiaoeMonitorFileAttachment = LocalMonitorFileAttachment;

class XiaoeMonitorMessageEvent {
  const XiaoeMonitorMessageEvent._(this._event);

  final LocalMonitorMessageEvent _event;

  String get eventId => _event.eventId;
  String get dedupeKey => _event.dedupeKey;
  String get accountId => _event.accountId;
  String get conversationId => _event.conversationId;
  String get conversationName => _event.conversationName;
  String get conversationType => _event.conversationType;
  String get messageId => _event.messageId;
  String get senderId => _event.senderId;
  String get senderName => _event.senderName;
  String get messageType => _event.messageType;
  String get text => _event.text;
  DateTime? get sentAt => _event.sentAt;
  DateTime? get observedAt => _event.observedAt;
  String get captureSource => _event.captureSource;
  List<XiaoeMonitorImageAttachment> get imageAttachments =>
      _event.imageAttachments;
  List<XiaoeMonitorFileAttachment> get fileAttachments =>
      _event.fileAttachments;

  bool get isForwardableText =>
      messageType.trim().toLowerCase() == 'text' && text.trim().isNotEmpty;

  bool get hasImageAttachments =>
      imageAttachments.any((attachment) => attachment.hasUsableSource);

  bool get hasFileAttachments =>
      fileAttachments.any((attachment) => attachment.hasUsableSource);

  bool get hasForwardablePayload =>
      isForwardableText || hasImageAttachments || hasFileAttachments;

  static XiaoeMonitorMessageEvent fromLocal(LocalMonitorMessageEvent event) {
    return XiaoeMonitorMessageEvent._(event);
  }

  LocalMonitorMessageEvent toLocal() => _event;

  static List<XiaoeMonitorMessageEvent> listFromLocal(
    Iterable<LocalMonitorMessageEvent> events,
  ) {
    return events.map(XiaoeMonitorMessageEvent._).toList(growable: false);
  }
}

class XiaoeMonitorShellEvent {
  const XiaoeMonitorShellEvent._(this._event);

  final LocalMonitorShellEvent _event;

  String get type => _event.type;
  String get reason => _event.reason;
  DateTime? get updatedAt => _event.updatedAt;
  int get recentEvents => _event.recentEvents;
  int get observedConversations => _event.observedConversations;
  String get error => _event.error;

  bool get isSnapshotUpdated => _event.isSnapshotUpdated;
  bool get isShellError => _event.isShellError;

  static XiaoeMonitorShellEvent fromLocal(LocalMonitorShellEvent event) {
    return XiaoeMonitorShellEvent._(event);
  }
}

class XiaoeMonitorShellStatus {
  const XiaoeMonitorShellStatus._(this._status);

  final LocalMonitorShellStatus _status;

  String get shellState => _status.shellState;
  String get captureState => _status.captureState;
  String get loginState => _status.loginState;
  String get hookState => _status.hookState;
  String get runtimeUrl => _status.runtimeUrl;
  String get pageTitle => _status.pageTitle;
  String get pageKind => _status.pageKind;
  bool get webviewAvailable => _status.webviewAvailable;
  String get shellMode => _status.shellMode;
  int get queueDepth => _status.queueDepth;
  int get messagesToday => _status.messagesToday;
  int get deliveriesSucceededToday => _status.deliveriesSucceededToday;
  int get deliveriesFailedToday => _status.deliveriesFailedToday;
  DateTime? get lastUpdatedAt => _status.lastUpdatedAt;
  DateTime? get probeObservedAt => _status.probeObservedAt;
  List<XiaoeMonitorObservedConversation> get observedConversations =>
      _status.observedConversations;
  List<XiaoeMonitorObservedMessage> get observedMessages =>
      _status.observedMessages;
  List<XiaoeMonitorMessageEvent> get recentEvents =>
      XiaoeMonitorMessageEvent.listFromLocal(_status.recentEvents);
  String get workerId => _status.workerId;
  Map<String, dynamic> get probeDiagnostics => _status.probeDiagnostics;
  String get lastError => _status.lastError;

  bool get isOnline => _status.isOnline;
  bool get isCapturing => _status.isCapturing;

  static XiaoeMonitorShellStatus fromLocal(LocalMonitorShellStatus status) {
    return XiaoeMonitorShellStatus._(status);
  }
}
