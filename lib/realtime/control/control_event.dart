import '../session/session_event_frame.dart';

abstract class ControlEvent {
  const ControlEvent();
}

class ConversationUpdatedEvent extends ControlEvent {
  const ConversationUpdatedEvent({
    required this.channelId,
    required this.channelType,
    required this.unreadCount,
    required this.lastMessageDigest,
    required this.sortTimestamp,
  });

  final String channelId;
  final int channelType;
  final int unreadCount;
  final String lastMessageDigest;
  final int sortTimestamp;
}

ControlEvent? mapSessionControlEvent(SessionEventFrame frame) {
  if (frame.kind.trim() != 'conversation.updated') {
    return null;
  }

  final payload = frame.payload;
  final aggregate = _parseAggregateConversationIdentity(frame.aggregateId);

  final channelId =
      _readStringValue(payload, 'channel_id', 'channelId') ??
      aggregate?.channelId;
  final channelType =
      _readIntValue(payload, 'channel_type', 'channelType') ??
      aggregate?.channelType;
  if (channelId == null || channelId.isEmpty || channelType == null) {
    return null;
  }

  final unreadCount =
      _readIntValue(payload, 'unread_count', 'unreadCount') ?? 0;
  final lastMessageDigest =
      _readStringValue(payload, 'last_message_digest', 'lastMessageDigest') ??
      '';
  final sortTimestamp =
      _readIntValue(payload, 'sort_timestamp', 'sortTimestamp') ??
      frame.serverTs;

  return ConversationUpdatedEvent(
    channelId: channelId,
    channelType: channelType,
    unreadCount: unreadCount,
    lastMessageDigest: lastMessageDigest,
    sortTimestamp: sortTimestamp,
  );
}

String? _readStringValue(
  Map<String, dynamic> payload,
  String snakeCaseKey,
  String camelCaseKey,
) {
  final snakeCaseValue = payload[snakeCaseKey]?.toString().trim() ?? '';
  if (snakeCaseValue.isNotEmpty) {
    return snakeCaseValue;
  }
  final camelCaseValue = payload[camelCaseKey]?.toString().trim() ?? '';
  if (camelCaseValue.isNotEmpty) {
    return camelCaseValue;
  }
  return null;
}

int? _readIntValue(
  Map<String, dynamic> payload,
  String snakeCaseKey,
  String camelCaseKey,
) {
  final dynamic value = payload.containsKey(snakeCaseKey)
      ? payload[snakeCaseKey]
      : payload[camelCaseKey];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '');
}

_ConversationIdentity? _parseAggregateConversationIdentity(String aggregateId) {
  final normalized = aggregateId.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final colonIndex = normalized.indexOf(':');
  if (colonIndex > 0 && colonIndex < normalized.length - 1) {
    final parsedType = int.tryParse(normalized.substring(0, colonIndex).trim());
    final parsedChannelId = normalized.substring(colonIndex + 1).trim();
    if (parsedType != null && parsedChannelId.isNotEmpty) {
      return _ConversationIdentity(
        channelId: parsedChannelId,
        channelType: parsedType,
      );
    }
  }

  final separatorIndex = normalized.indexOf('_');
  if (separatorIndex > 0 && separatorIndex < normalized.length - 1) {
    final parsedType = int.tryParse(
      normalized.substring(0, separatorIndex).trim(),
    );
    final parsedChannelId = normalized.substring(separatorIndex + 1).trim();
    if (parsedType != null && parsedChannelId.isNotEmpty) {
      return _ConversationIdentity(
        channelId: parsedChannelId,
        channelType: parsedType,
      );
    }
  }

  return _ConversationIdentity(channelId: normalized);
}

class _ConversationIdentity {
  const _ConversationIdentity({required this.channelId, this.channelType});

  final String channelId;
  final int? channelType;
}
