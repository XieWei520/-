import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../data/models/report.dart';
import 'api_client.dart';

class ReportApi {
  ReportApi._();

  static final ReportApi _instance = ReportApi._();
  static ReportApi get instance => _instance;

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

  Future<List<ReportCategory>> getCategories({String? languageCode}) async {
    final normalizedLanguageCode = languageCode?.trim() ?? '';
    final response = await _client.get(
      ApiConfig.reportCategories,
      queryParameters: normalizedLanguageCode.isEmpty
          ? null
          : {'lang': normalizedLanguageCode},
    );
    _ensureSuccess(response, fallback: '加载举报分类失败');

    final rawList = response.data is List
        ? response.data as List<dynamic>
        : response.data is Map && response.data['data'] is List
        ? response.data['data'] as List<dynamic>
        : const <dynamic>[];

    return rawList
        .whereType<Map>()
        .map((json) => ReportCategory.fromJson(Map<String, dynamic>.from(json)))
        .where((category) => category.categoryNo.trim().isNotEmpty)
        .toList();
  }

  Future<void> submitReport({
    required String channelId,
    required int channelType,
    required String categoryNo,
    String remark = '',
    List<String> imgs = const <String>[],
  }) async {
    final response = await _client.post(
      ApiConfig.reports,
      data: {
        'channel_id': channelId,
        'channel_type': channelType,
        'category_no': categoryNo,
        'remark': remark,
        'imgs': imgs,
      },
    );
    _ensureSuccess(response, fallback: '提交举报失败');
  }
}
