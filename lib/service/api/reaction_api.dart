import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import 'api_client.dart';

class ReactionRecord {
  final String uid;
  final String name;
  final String channelId;
  final int channelType;
  final int seq;
  final String messageId;
  final String emoji;
  final bool isDeleted;
  final String createdAt;

  const ReactionRecord({
    required this.uid,
    required this.name,
    required this.channelId,
    required this.channelType,
    required this.seq,
    required this.messageId,
    required this.emoji,
    required this.isDeleted,
    required this.createdAt,
  });

  factory ReactionRecord.fromJson(Map<String, dynamic> json) {
    return ReactionRecord(
      uid: (json['uid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      channelId: (json['channel_id'] ?? '').toString(),
      channelType: json['channel_type'] is num
          ? (json['channel_type'] as num).toInt()
          : int.tryParse(json['channel_type']?.toString() ?? '0') ?? 0,
      seq: json['seq'] is num
          ? (json['seq'] as num).toInt()
          : int.tryParse(json['seq']?.toString() ?? '0') ?? 0,
      messageId: (json['message_id'] ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      isDeleted: json['is_deleted'] is num
          ? (json['is_deleted'] as num).toInt() == 1
          : (json['is_deleted']?.toString() ?? '0') == '1',
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class ReactionApi {
  ReactionApi._();

  static final ReactionApi _instance = ReactionApi._();
  static ReactionApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  /// Toggle (add/update/remove) a reaction for the given message.
  Future<void> toggleReaction({
    required String messageId,
    required String channelId,
    required int channelType,
    required String emoji,
  }) async {
    final payload = {
      'message_id': messageId,
      'channel_id': channelId,
      'channel_type': channelType,
      'emoji': emoji,
    };
    final Response response;
    try {
      response = await _client.post(
        '/v1/reactions',
        data: payload,
      );
    } catch (e) {
      rethrow;
    }
    if ((response.statusCode ?? 500) >= 400) {
      final msg = response.data is Map
          ? (response.data['msg'] ?? response.data['message'])
          : response.statusMessage;
      throw DioException(
        requestOptions: RequestOptions(
          path: '${ApiConfig.baseUrl}/v1/reactions',
        ),
        response: response,
        message: msg?.toString() ?? '添加/取消表情失败',
        type: DioExceptionType.badResponse,
      );
    }
  }

  /// Sync reactions for a given channel, starting from [seq].
  Future<List<ReactionRecord>> syncReactions({
    required String channelId,
    required int channelType,
    int seq = 0,
    int limit = 200,
  }) async {
    final response = await _client.post(
      '/v1/reaction/sync',
      data: {
        'channel_id': channelId,
        'channel_type': channelType,
        'seq': seq,
        'limit': limit,
      },
    );
    final data = response.data;
    if (response.statusCode != 200 || data == null) {
      debugPrint('Reaction sync failed: ${response.statusCode} ${response.data}');
      return const [];
    }

    if (data is List) {
      return data
          .whereType<Map>()
          .map((raw) => ReactionRecord.fromJson(Map<String, dynamic>.from(raw)))
          .toList();
    }
    return const [];
  }
}
