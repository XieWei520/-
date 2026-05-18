import 'package:dio/dio.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../core/config/api_config.dart';
import '../im/im_word_sync_models.dart';
import 'api_client.dart';
import 'file_api.dart';

class MessageApi {
  MessageApi._();

  static const String _clearUnreadPath = '/v1/conversation/clearUnread';
  static const String _legacyClearUnreadPath = '/v1/coversation/clearUnread';

  static final MessageApi _instance = MessageApi._();
  static MessageApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final FileApi _fileApi = FileApi.instance;

  Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _resolveBody(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? fallback).toString();
    final hasErrorCode =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }

  bool _isNotFoundResponse(Response<dynamic> response) {
    final body = _resolveBody(response.data);
    final code = body['code'];
    final status = body['status'];
    return response.statusCode == 404 ||
        (code is num && code.toInt() == 404) ||
        (status is num && status.toInt() == 404);
  }

  bool _isNotFoundError(DioException error) {
    final response = error.response;
    return response != null && _isNotFoundResponse(response);
  }

  bool _isMissingMessageReadResponse(Response<dynamic> response) {
    final body = _resolveBody(response.data);
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? '').toString();
    final isBadRequest =
        response.statusCode == 400 ||
        (code is num && code.toInt() == 400) ||
        (status is num && status.toInt() == 400);
    return isBadRequest &&
        (message.contains('没有读取到消息') ||
            message.toLowerCase().contains('message not found'));
  }

  bool _isMissingMessageReadError(DioException error) {
    final response = error.response;
    return response != null && _isMissingMessageReadResponse(response);
  }

  Future<SyncMessagesResp> syncMessages({
    required int lastSeq,
    int limit = 50,
  }) {
    return syncCommandMessages(maxMessageSeq: lastSeq, limit: limit);
  }

  Future<SyncMessagesResp> syncCommandMessages({
    required int maxMessageSeq,
    int limit = 50,
  }) async {
    final response = await _client.post(
      ApiConfig.messageSync,
      data: {'max_message_seq': maxMessageSeq, 'limit': limit},
    );
    return SyncMessagesResp.fromDynamic(response.data);
  }

  Future<List<dynamic>> syncChannelMessages({
    required String channelId,
    required int channelType,
    required int startSeq,
    required int endSeq,
    int limit = 50,
    int pullMode = 0,
  }) async {
    final response = await _client.post(
      '/v1/message/channel/sync',
      data: {
        'channel_id': channelId,
        'channel_type': channelType,
        'start_seq': startSeq,
        'end_seq': endSeq,
        'limit': limit,
        'pull_mode': pullMode,
      },
    );
    return response.data['data'] ?? [];
  }

  Future<void> revokeMessage({
    required String clientMsgNo,
    required String channelId,
    required int channelType,
    String? messageId,
  }) async {
    final response = await _client.post(
      ApiConfig.messageRevoke,
      queryParameters: <String, dynamic>{
        'client_msg_no': clientMsgNo,
        'channel_id': channelId,
        'channel_type': channelType,
        if (messageId != null && messageId.trim().isNotEmpty)
          'message_id': messageId.trim(),
      },
    );
    _ensureSuccess(response, fallback: '鎾ゅ洖娑堟伅澶辫触');
  }

  Future<void> editMessage({
    required String messageId,
    required int messageSeq,
    required String channelId,
    required int channelType,
    required String contentEdit,
  }) async {
    final response = await _client.post(
      '/v1/message/edit',
      data: {
        'message_id': messageId,
        'message_seq': messageSeq,
        'channel_id': channelId,
        'channel_type': channelType,
        'content_edit': contentEdit,
      },
    );
    _ensureSuccess(response, fallback: 'message edit failed');
  }

  Future<void> deleteMessage({
    required String messageId,
    required int messageSeq,
    required String channelId,
    required int channelType,
  }) async {
    final response = await _client.delete(
      ApiConfig.messageDelete,
      data: <Map<String, dynamic>>[
        <String, dynamic>{
          'message_id': messageId,
          'message_seq': messageSeq,
          'channel_id': channelId,
          'channel_type': channelType,
        },
      ],
    );
    _ensureSuccess(response, fallback: '鍒犻櫎娑堟伅澶辫触');
  }

  Future<void> mutualDeleteMessage({
    required String clientMsgNo,
    required String channelId,
    required int channelType,
  }) async {
    final response = await _client.delete(
      '/v1/message/mutual',
      data: {
        'client_msg_no': clientMsgNo,
        'channel_id': channelId,
        'channel_type': channelType,
      },
    );
    _ensureSuccess(response, fallback: '鍙屽悜鍒犻櫎娑堟伅澶辫触');
  }

  Future<List<dynamic>> searchMessages({
    required String keyword,
    String? channelId,
    int? channelType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final data = <String, dynamic>{
      'keyword': keyword,
      'page': page,
      'page_size': pageSize,
    };
    if (channelId != null) {
      data['channel_id'] = channelId;
    }
    if (channelType != null) {
      data['channel_type'] = channelType;
    }

    final response = await _client.post(ApiConfig.messageSearch, data: data);
    _ensureSuccess(response, fallback: '鎼滅储娑堟伅澶辫触');
    if (response.data is List) {
      return response.data as List<dynamic>;
    }
    if (response.data is Map && response.data['data'] is List) {
      return response.data['data'] as List<dynamic>;
    }
    if (response.data is Map && response.data['messages'] is List) {
      return response.data['messages'] as List<dynamic>;
    }
    return [];
  }

  Future<void> sendTyping({
    required String channelId,
    required int channelType,
  }) async {
    final response = await _client.post(
      '/v1/message/typing',
      data: {'channel_id': channelId, 'channel_type': channelType},
    );
    _ensureSuccess(response, fallback: '鍙戦€?typing 澶辫触');
  }

  Future<SensitiveWordsSnapshot> syncSensitiveWords({
    required int version,
  }) async {
    final response = await _client.get(
      '/v1/message/sync/sensitivewords',
      queryParameters: <String, dynamic>{'version': version < 0 ? 0 : version},
    );
    _ensureSuccess(response, fallback: 'sensitive words sync failed');

    final raw = response.data;
    final body = _resolveBody(raw);
    final payload = body['data'] ?? raw;
    return SensitiveWordsSnapshot.fromDynamic(payload);
  }

  Future<List<ProhibitWordEntry>> syncProhibitWords({
    required int version,
  }) async {
    final response = await _client.get(
      '/v1/message/prohibit_words/sync',
      queryParameters: <String, dynamic>{'version': version < 0 ? 0 : version},
    );
    _ensureSuccess(response, fallback: 'prohibit words sync failed');

    final raw = response.data;
    final List<dynamic> items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map && raw['data'] is List) {
      items = raw['data'] as List<dynamic>;
    } else {
      items = const <dynamic>[];
    }

    return items
        .map(ProhibitWordEntry.fromDynamic)
        .where((item) => item.sid > 0 && item.content.trim().isNotEmpty)
        .toList(growable: false);
  }

  Future<void> markAsRead({
    required String channelId,
    required int channelType,
    required List<String> messageIds,
  }) async {
    final normalizedMessageIds = messageIds
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalizedMessageIds.isEmpty) {
      return;
    }

    try {
      final response = await _client.post(
        '/v1/message/readed',
        data: {
          'channel_id': channelId,
          'channel_type': channelType,
          'message_ids': normalizedMessageIds,
        },
      );
      if (_isMissingMessageReadResponse(response)) {
        return;
      }
      _ensureSuccess(response, fallback: 'message read receipt failed');
    } on DioException catch (error) {
      if (_isMissingMessageReadError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> clearUnread({
    required String channelId,
    required int channelType,
    required int unread,
  }) async {
    final payload = {
      'channel_id': channelId,
      'channel_type': channelType,
      'unread': unread < 0 ? 0 : unread,
    };
    final options = Options(
      validateStatus: (status) =>
          status != null && status >= 200 && status < 500,
    );
    try {
      final response = await _client.put(
        _clearUnreadPath,
        data: payload,
        options: options,
      );
      if (_isNotFoundResponse(response)) {
        final legacyResponse = await _client.put(
          _legacyClearUnreadPath,
          data: payload,
          options: options,
        );
        _ensureSuccess(legacyResponse, fallback: '娓呯┖浼氳瘽鏈澶辫触');
        return;
      }

      _ensureSuccess(response, fallback: '娓呯┖浼氳瘽鏈澶辫触');
      return;
    } on DioException catch (error) {
      if (!_isNotFoundError(error)) {
        rethrow;
      }

      final legacyResponse = await _client.put(
        _legacyClearUnreadPath,
        data: payload,
        options: options,
      );
      _ensureSuccess(legacyResponse, fallback: '娓呯┖浼氳瘽鏈澶辫触');
    }
  }

  Future<void> deleteConversation({
    required String channelId,
    required int channelType,
  }) async {
    final encodedChannelId = Uri.encodeComponent(channelId.trim());
    if (encodedChannelId.isEmpty) {
      return;
    }
    final response = await _client.delete(
      '${ApiConfig.conversations}/$encodedChannelId/$channelType',
    );
    _ensureSuccess(response, fallback: 'delete conversation failed');
  }

  Future<void> markVoiceRead({
    required String messageId,
    required int messageSeq,
    required String channelId,
    required int channelType,
  }) async {
    final response = await _client.put(
      '/v1/message/voicereaded',
      data: {
        'message_id': messageId,
        'message_seq': messageSeq,
        'channel_id': channelId,
        'channel_type': channelType,
      },
    );
    _ensureSuccess(response, fallback: 'voice read update failed');
  }

  Future<List<WKSyncExtraMsg>> syncMessageExtras({
    required String channelId,
    required int channelType,
    required int extraVersion,
    required String deviceUuid,
    int limit = 100,
  }) async {
    final response = await _client.post(
      '/v1/message/extra/sync',
      data: {
        'channel_id': channelId,
        'channel_type': channelType,
        'extra_version': extraVersion,
        'source': deviceUuid.trim(),
        'limit': limit,
      },
    );
    _ensureSuccess(response, fallback: '鍚屾娑堟伅 extra 澶辫触');

    final raw = response.data;
    final List<dynamic> items;
    if (raw is List) {
      items = raw;
    } else if (raw is Map && raw['data'] is List) {
      items = raw['data'] as List<dynamic>;
    } else {
      items = const [];
    }

    return items
        .whereType<Map>()
        .map((item) => _parseSyncExtra(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> togglePinnedMessage({
    required String messageId,
    required int messageSeq,
    required String channelId,
    required int channelType,
  }) async {
    final response = await _client.post(
      ApiConfig.messagePinned,
      data: <String, dynamic>{
        'message_id': messageId,
        'message_seq': messageSeq,
        'channel_id': channelId,
        'channel_type': channelType,
      },
    );
    _ensureSuccess(response, fallback: 'toggle pinned message failed');
  }

  Future<PinnedMessageSyncSnapshot> syncPinnedMessages({
    required String channelId,
    required int channelType,
    required int version,
  }) async {
    final response = await _client.post(
      ApiConfig.messagePinnedSync,
      data: <String, dynamic>{
        'channel_id': channelId,
        'channel_type': channelType,
        'version': version < 0 ? 0 : version,
      },
    );
    _ensureSuccess(response, fallback: 'sync pinned messages failed');

    final body = _resolveBody(response.data);
    final payload = body['data'] is Map ? _resolveBody(body['data']) : body;
    final pinnedRows = payload['pinned_messages'] is List
        ? payload['pinned_messages'] as List<dynamic>
        : const <dynamic>[];
    final messages = payload['messages'] is List
        ? payload['messages'] as List<dynamic>
        : const <dynamic>[];

    return PinnedMessageSyncSnapshot(
      pinnedMessages: pinnedRows
          .whereType<Map>()
          .map((item) => PinnedMessageEntry.fromJson(_resolveBody(item)))
          .toList(growable: false),
      messages: messages
          .whereType<Map>()
          .map((item) => _parseSyncMsg(_resolveBody(item)))
          .toList(growable: false),
    );
  }

  Future<void> clearPinnedMessages({
    required String channelId,
    required int channelType,
  }) async {
    final response = await _client.post(
      ApiConfig.messagePinnedClear,
      data: <String, dynamic>{
        'channel_id': channelId,
        'channel_type': channelType,
      },
    );
    _ensureSuccess(response, fallback: 'clear pinned messages failed');
  }

  Future<void> syncAck({required int lastMessageSeq}) async {
    if (lastMessageSeq <= 0) {
      return;
    }

    final response = await _client.post('/v1/message/syncack/$lastMessageSeq');
    _ensureSuccess(response, fallback: 'message sync ack 澶辫触');
  }

  Future<void> clearChannelMessages({
    required String channelId,
    required int channelType,
  }) async {
    final response = await _client.post(
      '/v1/message/offset',
      data: {'channel_id': channelId, 'channel_type': channelType},
    );
    _ensureSuccess(response, fallback: '娓呯┖娑堟伅澶辫触');
  }

  Future<String> uploadFile({
    required String filePath,
    required String channelId,
    required int channelType,
  }) async {
    return _fileApi.uploadChatFile(
      filePath: filePath,
      channelId: channelId,
      channelType: channelType,
    );
  }

  WKSyncExtraMsg _parseSyncExtra(Map<String, dynamic> json) {
    return WKSyncExtraMsg()
      ..messageID = _readInt(json['message_id'])
      ..messageIdStr = (json['message_id_str'] ?? '').toString()
      ..revoke = _readInt(json['revoke'])
      ..revoker = (json['revoker'] ?? '').toString()
      ..voiceStatus = _readInt(json['voice_status'])
      ..isMutualDeleted = _readInt(json['is_mutual_deleted'])
      ..extraVersion = _readInt(json['extra_version'])
      ..unreadCount = _readInt(json['unread_count'])
      ..readedCount = _readInt(json['readed_count'])
      ..readed = _readInt(json['readed'])
      ..isPinned = _readInt(json['is_pinned'])
      ..contentEdit = json['content_edit']
      ..editedAt = _readInt(json['edited_at']);
  }

  WKSyncMsg _parseSyncMsg(Map<String, dynamic> json) {
    final msg = WKSyncMsg()
      ..messageID = (json['message_id'] ?? '').toString()
      ..messageSeq = _readInt(json['message_seq'])
      ..clientMsgNO = (json['client_msg_no'] ?? '').toString()
      ..fromUID = (json['from_uid'] ?? '').toString()
      ..channelID = (json['channel_id'] ?? '').toString()
      ..channelType = _readInt(json['channel_type'])
      ..timestamp = _readInt(json['timestamp'])
      ..voiceStatus = _readInt(json['voice_status'])
      ..isDeleted = _readInt(json['is_deleted'])
      ..revoke = _readInt(json['revoke'])
      ..revoker = (json['revoker'] ?? '').toString()
      ..extraVersion = _readInt(json['extra_version'])
      ..unreadCount = _readInt(json['unread_count'])
      ..readedCount = _readInt(json['readed_count'])
      ..readed = _readInt(json['readed'])
      ..isPinned = _readInt(json['is_pinned'])
      ..receipt = _readInt(json['receipt'])
      ..setting = _readInt(json['setting'])
      ..payload = json['payload'];

    final extra = json['message_extra'];
    if (extra is Map) {
      msg.messageExtra = _parseSyncExtra(_resolveBody(extra));
    }

    final reactions = json['reactions'];
    if (reactions is List) {
      msg.reactions = reactions
          .whereType<Map>()
          .map((item) => _parseSyncReaction(_resolveBody(item)))
          .toList(growable: false);
    }

    return msg;
  }

  WKSyncMsgReaction _parseSyncReaction(Map<String, dynamic> json) {
    return WKSyncMsgReaction()
      ..messageID = (json['message_id'] ?? '').toString()
      ..uid = (json['uid'] ?? '').toString()
      ..name = (json['name'] ?? '').toString()
      ..channelID = (json['channel_id'] ?? '').toString()
      ..channelType = _readInt(json['channel_type'])
      ..seq = _readInt(json['seq'])
      ..emoji = (json['emoji'] ?? '').toString()
      ..isDeleted = _readInt(json['is_deleted'])
      ..createdAt = (json['created_at'] ?? '').toString();
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PinnedMessageSyncSnapshot {
  const PinnedMessageSyncSnapshot({
    required this.pinnedMessages,
    required this.messages,
  });

  final List<PinnedMessageEntry> pinnedMessages;
  final List<WKSyncMsg> messages;
}

class PinnedMessageEntry {
  const PinnedMessageEntry({
    required this.messageId,
    required this.messageSeq,
    required this.channelId,
    required this.channelType,
    required this.isDeleted,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String messageId;
  final int messageSeq;
  final String channelId;
  final int channelType;
  final int isDeleted;
  final int version;
  final String createdAt;
  final String updatedAt;

  factory PinnedMessageEntry.fromJson(Map<String, dynamic> json) {
    return PinnedMessageEntry(
      messageId: (json['message_id'] ?? '').toString(),
      messageSeq: _readPinnedInt(json['message_seq']),
      channelId: (json['channel_id'] ?? '').toString(),
      channelType: _readPinnedInt(json['channel_type']),
      isDeleted: _readPinnedInt(json['is_deleted']),
      version: _readPinnedInt(json['version']),
      createdAt: (json['created_at'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

int _readPinnedInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class SyncMessagesResp {
  final int code;
  final String? msg;
  final List<dynamic>? messages;
  final int? lastSeq;
  final int? lastMessageSeq;

  SyncMessagesResp({
    required this.code,
    this.msg,
    this.messages,
    this.lastSeq,
    this.lastMessageSeq,
  });

  factory SyncMessagesResp.fromDynamic(dynamic raw) {
    if (raw is List) {
      final resolvedLastSeq = _resolveLastMessageSeq(raw);
      return SyncMessagesResp(
        code: 0,
        messages: raw,
        lastSeq: resolvedLastSeq,
        lastMessageSeq: resolvedLastSeq,
      );
    }

    final json = _resolveBody(raw);
    final data = _resolveBody(json['data']);
    final payload = data.isEmpty ? json : data;
    final resolvedMessages = payload['messages'] is List
        ? payload['messages'] as List<dynamic>
        : const <dynamic>[];
    final directLastSeq = _readInt(
      payload['last_message_seq'] ?? payload['last_seq'],
    );
    final resolvedLastSeq = directLastSeq > 0
        ? directLastSeq
        : _resolveLastMessageSeq(resolvedMessages);
    return SyncMessagesResp(
      code: _readInt(json['code']),
      msg: (json['msg'] ?? json['message'])?.toString(),
      messages: resolvedMessages,
      lastSeq: resolvedLastSeq,
      lastMessageSeq: resolvedLastSeq,
    );
  }

  static Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  static int _resolveLastMessageSeq(List<dynamic> messages) {
    var maxSeq = 0;
    for (final item in messages) {
      if (item is! Map) {
        continue;
      }
      final current = _readInt(item['message_seq']);
      if (current > maxSeq) {
        maxSeq = current;
      }
    }
    return maxSeq;
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
