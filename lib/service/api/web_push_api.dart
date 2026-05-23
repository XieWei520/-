import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import 'api_client.dart';

class WebPushApi {
  WebPushApi._();

  static final WebPushApi _instance = WebPushApi._();
  static WebPushApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  Future<WebPushConfig> getWebPushConfig() async {
    final response = await _client.get(ApiConfig.webPushConfig);
    _ensureSuccess(response, fallback: 'web push config unavailable');
    return WebPushConfig.fromDynamic(_payloadOf(response.data));
  }

  Future<void> registerWebPushSubscription(
    WebPushSubscription subscription,
  ) async {
    final response = await _client.post(
      ApiConfig.webPushSubscription,
      data: subscription.toJson(),
    );
    _ensureSuccess(response, fallback: 'web push subscription failed');
  }

  Future<void> deleteWebPushSubscription() async {
    final response = await _client.delete(ApiConfig.webPushSubscription);
    _ensureSuccess(response, fallback: 'web push subscription delete failed');
  }

  Future<void> updateWebPushClientState(WebPushClientState state) async {
    final response = await _client.post(
      ApiConfig.webPushClientState,
      data: state.toJson(),
    );
    _ensureSuccess(response, fallback: 'web push client state failed');
  }

  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final statusCode = response.statusCode ?? 200;
    final body = _mapOf(response.data);
    final code = body['code'];
    final status = body['status'];
    final hasErrorCode =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      final message = (body['msg'] ?? body['message'] ?? fallback).toString();
      throw Exception(message);
    }
  }

  Map<String, dynamic> _payloadOf(dynamic raw) {
    final body = _mapOf(raw);
    final data = body['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return body;
  }

  Map<String, dynamic> _mapOf(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }
}

class WebPushConfig {
  const WebPushConfig({
    required this.enabled,
    required this.publicKey,
    required this.subject,
  });

  final bool enabled;
  final String publicKey;
  final String subject;

  bool get canSubscribe => enabled && publicKey.trim().isNotEmpty;

  factory WebPushConfig.fromDynamic(dynamic raw) {
    final json = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    return WebPushConfig(
      enabled: json['enabled'] == true,
      publicKey: (json['public_key'] ?? json['publicKey'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
    );
  }
}

class WebPushSubscription {
  const WebPushSubscription({
    required this.endpoint,
    required this.p256dh,
    required this.auth,
    this.expirationTime,
  });

  final String endpoint;
  final String p256dh;
  final String auth;
  final int? expirationTime;

  bool get isValid =>
      endpoint.trim().isNotEmpty &&
      p256dh.trim().isNotEmpty &&
      auth.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'endpoint': endpoint,
      if (expirationTime != null) 'expiration_time': expirationTime,
      'keys': <String, dynamic>{'p256dh': p256dh, 'auth': auth},
    };
  }
}

class WebPushClientState {
  const WebPushClientState({
    required this.endpoint,
    required this.visibility,
    required this.permission,
    required this.standalone,
    required this.userAgent,
  });

  final String endpoint;
  final String visibility;
  final String permission;
  final bool standalone;
  final String userAgent;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'endpoint': endpoint,
      'visibility': visibility,
      'permission': permission,
      'standalone': standalone,
      'user_agent': userAgent,
    };
  }
}
