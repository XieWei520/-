import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import 'api_client.dart';

class RemoteConversationDraft {
  final String channelId;
  final int channelType;
  final int browseTo;
  final int keepMessageSeq;
  final int keepOffsetY;
  final String draft;
  final int version;

  const RemoteConversationDraft({
    required this.channelId,
    required this.channelType,
    this.browseTo = 0,
    this.keepMessageSeq = 0,
    this.keepOffsetY = 0,
    required this.draft,
    required this.version,
  });

  factory RemoteConversationDraft.fromJson(Map<String, dynamic> json) {
    return RemoteConversationDraft(
      channelId: (json['channel_id'] ?? '').toString(),
      channelType: _readInt(json['channel_type']),
      browseTo: _readInt(json['browse_to']),
      keepMessageSeq: _readInt(json['keep_message_seq']),
      keepOffsetY: _readInt(json['keep_offset_y']),
      draft: (json['draft'] ?? '').toString(),
      version: _readInt(json['version']),
    );
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

abstract class ConversationDraftRemoteStore {
  Future<List<RemoteConversationDraft>> syncExtras({required int version});

  Future<int?> updateExtra({
    required String channelId,
    required int channelType,
    int? browseTo,
    int? keepMessageSeq,
    int? keepOffsetY,
    String? draft,
  });

  Future<List<RemoteConversationDraft>> syncDrafts({required int version});

  Future<int?> updateDraft({
    required String channelId,
    required int channelType,
    required String draft,
  });
}

class ConversationDraftApi implements ConversationDraftRemoteStore {
  ConversationDraftApi._();

  static final ConversationDraftApi _instance = ConversationDraftApi._();
  static ConversationDraftApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

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

  @override
  Future<List<RemoteConversationDraft>> syncExtras({
    required int version,
  }) async {
    final response = await _client.post(
      ApiConfig.conversationExtraSync,
      data: {'version': version},
    );
    _ensureSuccess(response, fallback: '鍚屾浼氳瘽 extra 澶辫触');

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
        .map(
          (item) => RemoteConversationDraft.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.channelId.trim().isNotEmpty)
        .toList();
  }

  @override
  Future<List<RemoteConversationDraft>> syncDrafts({
    required int version,
  }) {
    return syncExtras(version: version);
  }

  @override
  Future<int?> updateExtra({
    required String channelId,
    required int channelType,
    int? browseTo,
    int? keepMessageSeq,
    int? keepOffsetY,
    String? draft,
  }) async {
    final data = <String, dynamic>{};
    if (browseTo != null) {
      data['browse_to'] = browseTo;
    }
    if (keepMessageSeq != null) {
      data['keep_message_seq'] = keepMessageSeq;
    }
    if (keepOffsetY != null) {
      data['keep_offset_y'] = keepOffsetY;
    }
    if (draft != null) {
      data['draft'] = draft;
    }

    final response = await _client.post(
      '${ApiConfig.conversations}/$channelId/$channelType/extra',
      data: data,
    );
    _ensureSuccess(response, fallback: '鏇存柊浼氳瘽 extra 澶辫触');

    final body = _resolveBody(response.data);
    final directVersion = body['version'];
    if (directVersion is num) {
      return directVersion.toInt();
    }

    final nestedVersion = body['data'] is Map
        ? (body['data'] as Map)['version']
        : null;
    if (nestedVersion is num) {
      return nestedVersion.toInt();
    }

    return null;
  }

  @override
  Future<int?> updateDraft({
    required String channelId,
    required int channelType,
    required String draft,
  }) {
    return updateExtra(
      channelId: channelId,
      channelType: channelType,
      draft: draft,
    );
  }
}
