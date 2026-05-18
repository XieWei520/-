import 'dart:convert';

import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

import 'mengxia_network_capture.dart';

const _maxTraversalDepth = 32;
const _maxVisitedMaps = 1000;
const _maxVisitedNodes = 5000;

List<NormalizedMessageEvent> parseMengxiaNetworkMessageEvents(
  MengxiaNetworkCaptureEvent event,
) {
  if (!_isMengxiaRuntimeUrl(event.url) || _isDiagnosticOnlySource(event)) {
    return const <NormalizedMessageEvent>[];
  }
  final decoded = _tryDecodeJson(event.payloadPreview);
  if (decoded == null) {
    return const <NormalizedMessageEvent>[];
  }

  final maps = <Map<String, Object?>>[];
  _collectMaps(decoded, maps, _TraversalBudget());
  final events = <NormalizedMessageEvent>[];
  final seen = <String>{};
  for (final map in maps) {
    final parsed = _eventFromMap(map, event);
    if (parsed == null) {
      continue;
    }
    final key = parsed.dedupeKey.trim().isEmpty
        ? parsed.eventId.trim()
        : parsed.dedupeKey.trim();
    if (key.isEmpty || !seen.add(key)) {
      continue;
    }
    events.add(parsed);
  }
  return List<NormalizedMessageEvent>.unmodifiable(events);
}

bool _isMengxiaRuntimeUrl(String url) {
  final normalized = url.trim().toLowerCase();
  return normalized.contains('mx.2026.naaifu.cn') ||
      normalized.contains('naaifu.cn/3/api') ||
      normalized.contains('/3/api/');
}

bool _isDiagnosticOnlySource(MengxiaNetworkCaptureEvent event) {
  if (event.source == MengxiaNetworkEventSource.httpRequest ||
      event.source == MengxiaNetworkEventSource.dataReceived ||
      event.source == MengxiaNetworkEventSource.webSocketCreated ||
      event.source == MengxiaNetworkEventSource.webSocketFrameSent ||
      event.source == MengxiaNetworkEventSource.webSocketClosed) {
    return true;
  }
  if (event.source == MengxiaNetworkEventSource.httpResponse &&
      event.statusCode != 0 &&
      (event.statusCode < 200 || event.statusCode >= 300)) {
    return true;
  }
  return false;
}

Object? _tryDecodeJson(String payload) {
  try {
    return jsonDecode(payload);
  } catch (_) {
    return null;
  }
}

void _collectMaps(
  Object? value,
  List<Map<String, Object?>> output,
  _TraversalBudget budget, [
  int depth = 0,
]) {
  if (depth > _maxTraversalDepth || !budget.visitNode()) {
    return;
  }
  if (value is Map) {
    if (!budget.visitMap()) {
      return;
    }
    final map = value.map((key, itemValue) => MapEntry('$key', itemValue));
    output.add(map);
    for (final child in map.values) {
      _collectMaps(child, output, budget, depth + 1);
    }
    return;
  }
  if (value is List) {
    for (final child in value) {
      _collectMaps(child, output, budget, depth + 1);
    }
  }
}

NormalizedMessageEvent? _eventFromMap(
  Map<String, Object?> map,
  MengxiaNetworkCaptureEvent event,
) {
  final conversationId = _firstString(map, const <String>[
    'conversation_id',
    'conversationId',
    'chat_id',
    'chatId',
    'group_id',
    'groupId',
    'room_id',
    'roomId',
    'circle_id',
    'circleId',
    'topic_id',
    'topicId',
  ]);
  final conversationName = _firstString(map, const <String>[
    'conversation_name',
    'conversationName',
    'chat_name',
    'chatName',
    'group_name',
    'groupName',
    'room_name',
    'roomName',
    'circle_name',
    'circleName',
    'topic_name',
    'topicName',
    'title',
  ]);
  final messageId = _firstString(map, const <String>[
    'message_id',
    'messageId',
    'msg_id',
    'msgId',
    'mid',
    'id',
  ]);
  final text = _messageText(map);
  if ((conversationId.isEmpty && conversationName.isEmpty) ||
      messageId.isEmpty ||
      text.isEmpty) {
    return null;
  }
  final senderId = _firstString(map, const <String>[
    'sender_id',
    'senderId',
    'user_id',
    'userId',
    'uid',
    'from_id',
    'fromId',
  ]);
  final senderName = _firstString(map, const <String>[
    'sender_name',
    'senderName',
    'nickname',
    'nick_name',
    'username',
    'user_name',
    'from_name',
    'fromName',
    'name',
  ]);
  final sentAt = _firstString(map, const <String>[
    'sent_at',
    'sentAt',
    'created_at',
    'createdAt',
    'create_time',
    'createTime',
    'timestamp',
    'time',
  ]);
  final normalizedConversationId = conversationId.isNotEmpty
      ? conversationId
      : 'fallback:$conversationName';
  final eventId = 'network:$normalizedConversationId:$messageId';
  final dedupeKey = '$eventId:${_shortStableHash(text)}';
  return NormalizedMessageEvent(
    eventId: eventId,
    dedupeKey: dedupeKey,
    accountId: '',
    conversationId: normalizedConversationId,
    conversationName: conversationName,
    conversationType: 'group',
    messageId: messageId,
    senderId: senderId,
    senderName: senderName,
    messageType: 'text',
    text: text,
    sentAt: sentAt,
    observedAt: event.observedAt.toUtc().toIso8601String(),
    captureSource: 'network_api',
  );
}

String _messageText(Map<String, Object?> map) {
  final direct = _firstString(map, const <String>[
    'content',
    'text',
    'message',
    'msg',
    'body',
    'desc',
  ]);
  if (direct.isNotEmpty && !_looksLikeJsonObject(direct)) {
    return direct;
  }
  for (final key in const <String>['content', 'message', 'msg', 'body']) {
    final value = map[key];
    if (value is Map) {
      final nested = _firstString(
        value.map((key, itemValue) => MapEntry('$key', itemValue)),
        const <String>['text', 'content', 'message', 'value'],
      );
      if (nested.isNotEmpty) {
        return nested;
      }
    }
  }
  return direct;
}

bool _looksLikeJsonObject(String value) {
  final normalized = value.trim();
  return normalized.startsWith('{') || normalized.startsWith('[');
}

String _firstString(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
  }
  return '';
}

String _shortStableHash(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = 0x1fffffff & ((hash << 5) - hash + codeUnit);
  }
  return hash.toRadixString(36);
}

class _TraversalBudget {
  int _visitedMaps = 0;
  int _visitedNodes = 0;

  bool visitMap() {
    _visitedMaps += 1;
    return _visitedMaps <= _maxVisitedMaps;
  }

  bool visitNode() {
    _visitedNodes += 1;
    return _visitedNodes <= _maxVisitedNodes;
  }
}
