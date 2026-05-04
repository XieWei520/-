import '../../../data/models/call.dart';
import '../../../service/api/api_client.dart';
import '../domain/call_bootstrap_models.dart';

class CallBootstrapApiException implements Exception {
  const CallBootstrapApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CallBootstrapApi {
  CallBootstrapApi({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<CallBootstrap> createRoom({
    required String calleeUid,
    required String calleeName,
    required CallType callType,
    required CallMediaCapabilities capabilities,
    String? roomName,
    String? channelId,
    int? channelType,
    List<CallParticipant> participants = const <CallParticipant>[],
  }) async {
    final requestData = <String, dynamic>{
      'callee_uid': calleeUid,
      'callee_name': calleeName,
      'call_type': callType.value,
      'capabilities': capabilities.toJson(),
    };
    final normalizedRoomName = roomName?.trim() ?? '';
    final normalizedChannelId = channelId?.trim() ?? '';
    if (normalizedRoomName.isNotEmpty) {
      requestData['room_name'] = normalizedRoomName;
    }
    if (normalizedChannelId.isNotEmpty) {
      requestData['channel_id'] = normalizedChannelId;
    }
    if (channelType != null) {
      requestData['channel_type'] = channelType;
    }
    if (participants.isNotEmpty) {
      requestData['participants'] = participants
          .map((item) => item.toJson())
          .toList(growable: false);
    }

    final response = await _client.post(
      '/v1/extra/call/room',
      data: requestData,
    );

    final body = response.data;
    final envelope = body is Map<String, dynamic>
        ? body
        : body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    final status = _parseStatusCode(envelope['status']);
    if ((status ?? 200) >= 400 || envelope['success'] == false) {
      throw CallBootstrapApiException(
        _extractMessage(envelope) ?? 'Call bootstrap request failed',
        statusCode: status,
      );
    }
    final payload = envelope['data'];
    if (payload is Map<String, dynamic>) {
      return CallBootstrap.fromJson(payload);
    }
    if (payload is Map) {
      return CallBootstrap.fromJson(Map<String, dynamic>.from(payload));
    }
    throw const CallBootstrapApiException('Call bootstrap payload missing');
  }

  Future<CallBootstrap> getSession({
    required String roomId,
    required CallMediaCapabilities capabilities,
  }) async {
    final response = await _client.get(
      '/v1/extra/call/session/$roomId',
      queryParameters: capabilities.toJson(),
    );

    final body = response.data;
    final envelope = body is Map<String, dynamic>
        ? body
        : body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    final status = _parseStatusCode(envelope['status']);
    if ((status ?? 200) >= 400 || envelope['success'] == false) {
      throw CallBootstrapApiException(
        _extractMessage(envelope) ?? 'Call session request failed',
        statusCode: status,
      );
    }
    final payload = envelope['data'];
    if (payload is Map<String, dynamic>) {
      return CallBootstrap.fromJson(payload);
    }
    if (payload is Map) {
      return CallBootstrap.fromJson(Map<String, dynamic>.from(payload));
    }
    throw const CallBootstrapApiException('Call session payload missing');
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

  String? _extractMessage(Map<String, dynamic> data) {
    final text =
        (data['msg'] ?? data['message'] ?? data['error'])?.toString().trim() ??
        '';
    return text.isEmpty ? null : text;
  }
}
