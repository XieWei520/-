import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../modules/launch_policy/launch_policy_models.dart';
import 'api_client.dart';

class LaunchPolicyApi {
  LaunchPolicyApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;
  final Options _plainTextOptions = Options(responseType: ResponseType.plain);

  Future<LaunchPolicyResponse> fetchLaunchPolicy({
    required LaunchPlatform platform,
    required String version,
    required int buildNumber,
  }) async {
    final response = await _client.get(
      ApiConfig.launchPolicy,
      queryParameters: {
        'platform': platform.wireName,
        'version': version,
        'build': buildNumber,
      },
      options: _plainTextOptions,
    );
    return LaunchPolicyResponse.fromJson(_normalizeResponseData(response.data));
  }

  Map<String, dynamic> _normalizeResponseData(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is String) {
      final body = rawData.trim();
      if (body.isEmpty) {
        return const <String, dynamic>{};
      }
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return const <String, dynamic>{};
  }
}
