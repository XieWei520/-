import 'package:dio/dio.dart';

import 'api_client.dart';

class ChannelApi {
  ChannelApi._();

  static final ChannelApi _instance = ChannelApi._();
  static ChannelApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
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

  Future<ChannelInfo> getChannelInfo({
    required String channelId,
    required int channelType,
    CancelToken? cancelToken,
  }) async {
    final response = await _client.get(
      '/v1/channels/$channelId/$channelType',
      cancelToken: cancelToken,
    );
    _ensureSuccess(response, fallback: 'Fetch channel info failed');

    final body = _resolveBody(response.data);
    final payload = body['data'] is Map
        ? _resolveBody(body['data'])
        : body;
    return ChannelInfo.fromJson(payload);
  }

  Future<void> setMessageAutoDelete({
    required String channelId,
    required int channelType,
    required int seconds,
    CancelToken? cancelToken,
  }) async {
    if (seconds < 0) {
      throw ArgumentError.value(seconds, 'seconds', 'Must be non-negative');
    }
    final response = await _client.post(
      '/v1/channels/$channelId/$channelType/message/autodelete',
      data: <String, dynamic>{'msg_auto_delete': seconds},
      cancelToken: cancelToken,
    );
    _ensureSuccess(response, fallback: 'Set message auto delete failed');
  }
}

class ChannelInfo {
  const ChannelInfo({
    required this.channelId,
    required this.channelType,
    required this.name,
    required this.extra,
  });

  final String channelId;
  final int channelType;
  final String name;
  final Map<String, dynamic> extra;

  int get msgAutoDelete => _readInt(extra['msg_auto_delete']);

  factory ChannelInfo.fromJson(Map<String, dynamic> json) {
    final channel = json['channel'] is Map
        ? Map<String, dynamic>.from(json['channel'] as Map)
        : <String, dynamic>{};
    final extra = json['extra'] is Map
        ? Map<String, dynamic>.from(json['extra'] as Map)
        : <String, dynamic>{};
    return ChannelInfo(
      channelId: (channel['channel_id'] ?? json['channel_id'] ?? '').toString(),
      channelType: _readInt(channel['channel_type'] ?? json['channel_type']),
      name: (json['name'] ?? '').toString(),
      extra: extra,
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
