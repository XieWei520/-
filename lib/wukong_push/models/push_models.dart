import 'dart:convert';

/// Lifecycle hook describing how a push message reached the client.
enum PushMessageTrigger {
  foreground,
  tap,
  initial,
  background,
}

enum ApplePushTokenState {
  notApplicable,
  missing,
  available,
}

class PushRegistrationSnapshot {
  const PushRegistrationSnapshot({
    this.deviceToken,
    this.apnsToken,
    this.applePushTokenState = ApplePushTokenState.notApplicable,
  });

  final String? deviceToken;
  final String? apnsToken;
  final ApplePushTokenState applePushTokenState;

  bool get hasDeviceToken => deviceToken != null && deviceToken!.isNotEmpty;

  bool get isApnsReady =>
      applePushTokenState == ApplePushTokenState.available;

  PushRegistrationSnapshot copyWith({
    String? deviceToken,
    String? apnsToken,
    ApplePushTokenState? applePushTokenState,
  }) {
    return PushRegistrationSnapshot(
      deviceToken: deviceToken ?? this.deviceToken,
      apnsToken: apnsToken ?? this.apnsToken,
      applePushTokenState: applePushTokenState ?? this.applePushTokenState,
    );
  }
}

/// Normalized payload extracted from push notifications.
class PushPayload {
  PushPayload({
    required this.raw,
    this.channelId,
    this.channelType,
    this.messageId,
    this.senderUid,
    this.title,
    this.body,
  });

  final Map<String, dynamic> raw;
  final String? channelId;
  final int? channelType;
  final String? messageId;
  final String? senderUid;
  final String? title;
  final String? body;

  bool get hasConversationTarget =>
      (channelId != null && channelId!.isNotEmpty) && channelType != null;

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'channel_type': channelType,
      'message_id': messageId,
      'sender_uid': senderUid,
      'title': title,
      'body': body,
      'raw': raw,
    };
  }

  String encode() => jsonEncode(toJson());

  static PushPayload fromEncoded(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) {
      final rawMap = Map<String, dynamic>.from(
        decoded['raw'] as Map? ?? const {},
      );
      return PushPayload(
        raw: rawMap,
        channelId: decoded['channel_id']?.toString(),
        channelType: _parseChannelType(decoded['channel_type']),
        messageId: decoded['message_id']?.toString(),
        senderUid: decoded['sender_uid']?.toString(),
        title: decoded['title']?.toString(),
        body: decoded['body']?.toString(),
      );
    }
    if (decoded is Map) {
      final normalized = Map<String, dynamic>.from(decoded);
      return PushPayload.fromMap(normalized);
    }
    throw const FormatException('Invalid push payload encoding');
  }

  factory PushPayload.fromMap(Map<String, dynamic>? json) {
    final data = json == null ? <String, dynamic>{} : Map<String, dynamic>.from(json);
    final normalizedChannelId = _resolveAny(
      data,
      const ['channel_id', 'channelId', 'conversation_id'],
    );
    final normalizedChannelType =
        _parseChannelType(_resolveAny(data, const ['channel_type', 'channelType']));
    final normalizedMessageId = _resolveAny(
      data,
      const ['message_id', 'messageId', 'msg_id'],
    );
    final normalizedSenderUid = _resolveAny(
      data,
      const ['sender_uid', 'senderUid', 'from_uid', 'fromUid'],
    );
    final payloadTitle = _resolveAny(
      data,
      const ['title', 'notification_title'],
    );
    final payloadBody = _resolveAny(
      data,
      const ['body', 'notification_body', 'content'],
    );

    return PushPayload(
      raw: data,
      channelId: normalizedChannelId?.toString(),
      channelType: normalizedChannelType,
      messageId: normalizedMessageId?.toString(),
      senderUid: normalizedSenderUid?.toString(),
      title: payloadTitle?.toString(),
      body: payloadBody?.toString(),
    );
  }

  static dynamic _resolveAny(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        return data[key];
      }
    }
    return null;
  }

  static int? _parseChannelType(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}

/// Normalized push event delivered to the Flutter layer.
class PushMessageEvent {
  PushMessageEvent({
    required this.payload,
    required this.data,
    required this.trigger,
    this.title,
    this.body,
  });

  final PushPayload payload;
  final Map<String, dynamic> data;
  final PushMessageTrigger trigger;
  final String? title;
  final String? body;

  bool get openedFromNotification =>
      trigger == PushMessageTrigger.tap || trigger == PushMessageTrigger.initial;
}
