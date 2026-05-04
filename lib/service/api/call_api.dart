import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/call.dart';
import 'api_client.dart';

class CallApiException implements Exception {
  const CallApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CallApi {
  CallApi._();

  static final CallApi _instance = CallApi._();
  static CallApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  Future<CallRoom> createRoom({
    required String calleeUid,
    required String calleeName,
    required CallType callType,
  }) async {
    final response = await _client.post(
      '/v1/extra/call/room',
      data: {
        'callee_uid': calleeUid,
        'callee_name': calleeName,
        'call_type': callType == CallType.audio ? 0 : 1,
      },
    );

    final data = _resolveResponseData(response, fallbackMessage: '创建通话房间失败');
    if (data is! Map) {
      throw const CallApiException('创建通话房间失败：响应数据格式不正确');
    }
    final room = CallRoom.fromJson(_resolveRoomPayload(data));
    if (room.roomId.trim().isEmpty) {
      throw const CallApiException('创建通话房间失败：服务端未返回房间ID');
    }
    return room;
  }

  Future<void> sendSignal({
    required String roomId,
    required CallSignalType type,
    required Map<String, dynamic> payload,
  }) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      return;
    }
    final body = {
      'room_id': normalizedRoomId,
      'from_uid': StorageUtils.getUid(),
      'signal_type': type.value,
      'payload': jsonEncode(payload),
    };
    final response = await _client.post('/v1/extra/call/signal', data: body);
    _resolveResponseData(response, fallbackMessage: '发送通话信令失败');
  }

  Future<void> updateStatus({
    required String roomId,
    required CallRoomStatus status,
  }) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      return;
    }
    final response = await _client.post(
      '/v1/extra/call/status',
      queryParameters: {'room_id': normalizedRoomId},
      data: {'status': status.value},
    );
    _resolveResponseData(response, fallbackMessage: '更新通话状态失败');
  }

  Future<List<CallSignal>> getSignals(
    String roomId, {
    bool fallback = false,
  }) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      return const [];
    }
    final response = await _client.get(
      '/v1/extra/call/signals/$normalizedRoomId',
      queryParameters: fallback ? const <String, dynamic>{'fallback': 1} : null,
    );
    final payload = _resolveResponseData(response, fallbackMessage: '获取通话信令失败');
    final list = _resolveListPayload(payload);
    return list
        .map((item) => CallSignal.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<CallRoom>> getPendingCalls({bool fallback = false}) async {
    final response = await _client.get(
      '/v1/extra/call/pending',
      queryParameters: fallback ? const <String, dynamic>{'fallback': 1} : null,
    );
    final payload = _resolveResponseData(
      response,
      fallbackMessage: '获取待处理通话失败',
    );
    final list = _resolveListPayload(payload);
    return list
        .map((item) => CallRoom.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  dynamic _resolveResponseData(
    Response<dynamic> response, {
    required String fallbackMessage,
  }) {
    final data = response.data;
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 400) {
      throw CallApiException(
        _extractMessage(data) ?? fallbackMessage,
        statusCode: statusCode,
      );
    }

    if (data is Map<String, dynamic>) {
      if (_isErrorEnvelope(data)) {
        throw CallApiException(
          _extractMessage(data) ?? fallbackMessage,
          statusCode:
              _parseStatusCode(data['status']) ??
              _parseStatusCode(data['code']) ??
              response.statusCode,
        );
      }
      return data['data'] ?? data;
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (_isErrorEnvelope(map)) {
        throw CallApiException(
          _extractMessage(map) ?? fallbackMessage,
          statusCode:
              _parseStatusCode(map['status']) ??
              _parseStatusCode(map['code']) ??
              response.statusCode,
        );
      }
      return map['data'] ?? map;
    }
    return data;
  }

  List<dynamic> _resolveListPayload(dynamic payload) {
    if (payload is List) {
      return List<dynamic>.from(payload);
    }
    if (payload is Map && payload['data'] is List) {
      return List<dynamic>.from(payload['data'] as List);
    }
    return const [];
  }

  Map<String, dynamic> _resolveRoomPayload(Map<dynamic, dynamic> payload) {
    final room = payload['room'];
    if (room is Map<String, dynamic>) {
      return room;
    }
    if (room is Map) {
      return Map<String, dynamic>.from(room);
    }
    return Map<String, dynamic>.from(payload);
  }

  bool _isErrorEnvelope(Map<String, dynamic> data) {
    final status =
        _parseStatusCode(data['status']) ?? _parseStatusCode(data['code']);
    if (status != null && status >= 400) {
      return true;
    }
    return data['success'] == false;
  }

  int? _parseStatusCode(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String? _extractMessage(dynamic data) {
    if (data is! Map) {
      return null;
    }
    final text =
        (data['msg'] ?? data['message'] ?? data['error'])?.toString().trim() ??
        '';
    return text.isEmpty ? null : text;
  }
}
