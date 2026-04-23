import 'dart:convert';

import 'package:dio/dio.dart';

import '../../modules/workplace/workplace_catalog_models.dart';
import '../../modules/workplace/workplace_preferences_models.dart';
import 'api_client.dart';

class WorkplaceApi {
  WorkplaceApi._();

  static final WorkplaceApi _instance = WorkplaceApi._();
  static WorkplaceApi get instance => _instance;

  static const String _bannerPath = '/v1/workplace/banner';
  static const String _categoryPath = '/v1/workplace/category';
  static const String _addedAppPath = '/v1/workplace/app';
  static const String _recordPath = '/v1/workplace/app/record';

  final ApiClient _client = ApiClient.instance;
  final Options _plainTextOptions = Options(responseType: ResponseType.plain);

  Future<WorkplacePreferencesSnapshot> getPreferences() async {
    final response = await _client.get(
      '/v1/workplace/preferences',
      options: _plainTextOptions,
    );
    return WorkplacePreferencesSnapshot.fromJson(
      _resolvePayload(response.data),
    );
  }

  Future<WorkplacePreferencesSnapshot> updateEnabledModules(
    List<String> enabledModuleSids,
  ) async {
    final response = await _client.put(
      '/v1/workplace/preferences/modules',
      data: <String, dynamic>{'module_sids': _normalizeSids(enabledModuleSids)},
      options: _plainTextOptions,
    );
    return WorkplacePreferencesSnapshot.fromJson(
      _resolvePayload(response.data),
    );
  }

  Future<List<WorkplaceBanner>> fetchBanners() async {
    final response = await _client.get(_bannerPath, options: _plainTextOptions);
    return _resolveListPayload(
      response.data,
    ).map(_normalizeMap).map(WorkplaceBanner.fromJson).toList(growable: false);
  }

  Future<List<WorkplaceCategory>> fetchCategories() async {
    final response = await _client.get(
      _categoryPath,
      options: _plainTextOptions,
    );
    return _resolveListPayload(response.data)
        .map(_normalizeMap)
        .map(WorkplaceCategory.fromJson)
        .toList(growable: false);
  }

  Future<List<WorkplaceApp>> fetchAddedApps() async {
    final response = await _client.get(
      _addedAppPath,
      options: _plainTextOptions,
    );
    return _resolveListPayload(
      response.data,
    ).map(_normalizeMap).map(WorkplaceApp.fromJson).toList(growable: false);
  }

  Future<List<WorkplaceApp>> fetchAppsByCategory(String categoryNo) async {
    final normalizedCategoryNo = categoryNo.trim();
    final response = await _client.get(
      '/v1/workplace/categorys/$normalizedCategoryNo/app',
      options: _plainTextOptions,
    );
    return _resolveListPayload(
      response.data,
    ).map(_normalizeMap).map(WorkplaceApp.fromJson).toList(growable: false);
  }

  Future<List<WorkplaceApp>> fetchRecordedApps() async {
    final response = await _client.get(_recordPath, options: _plainTextOptions);
    return _resolveListPayload(
      response.data,
    ).map(_normalizeMap).map(WorkplaceApp.fromJson).toList(growable: false);
  }

  Future<void> addApp(String appId) async {
    final response = await _client.post('/v1/workplace/apps/${appId.trim()}');
    _ensureSuccess(response, fallback: 'add workplace app failed');
  }

  Future<void> removeApp(String appId) async {
    final response = await _client.delete('/v1/workplace/apps/${appId.trim()}');
    _ensureSuccess(response, fallback: 'remove workplace app failed');
  }

  Future<void> reorderApps(List<String> appIds) async {
    final response = await _client.put(
      '/v1/workplace/app/reorder',
      data: <String, dynamic>{'app_ids': _normalizeSids(appIds)},
    );
    _ensureSuccess(response, fallback: 'reorder workplace apps failed');
  }

  Future<void> addRecord(String appId) async {
    final response = await _client.post(
      '/v1/workplace/apps/${appId.trim()}/record',
    );
    _ensureSuccess(response, fallback: 'add workplace record failed');
  }

  Future<void> removeRecord(String appId) async {
    final response = await _client.delete(
      '/v1/workplace/apps/${appId.trim()}/record',
    );
    _ensureSuccess(response, fallback: 'remove workplace record failed');
  }

  Map<String, dynamic> _resolvePayload(dynamic rawData) {
    final body = _normalizeBody(rawData);
    final data = body['data'];
    if (data == null) {
      return body;
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('Response data payload must be a JSON object.');
  }

  List<dynamic> _resolveListPayload(dynamic rawData) {
    final body = _normalizeBody(rawData);
    final data = body['data'];
    if (data == null) {
      return body is List ? body as List<dynamic> : const <dynamic>[];
    }
    if (data is List) {
      return data;
    }
    throw const FormatException('Response data payload must be a JSON array.');
  }

  Map<String, dynamic> _normalizeBody(dynamic rawData) {
    if (rawData == null) {
      throw const FormatException('Response payload is empty.');
    }
    if (rawData is String) {
      final body = rawData.trim();
      if (body.isEmpty) {
        throw const FormatException('Response payload is empty.');
      }
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is List) {
        return <String, dynamic>{'data': decoded};
      }
      throw const FormatException('Response payload must be valid JSON.');
    }
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is List) {
      return <String, dynamic>{'data': rawData};
    }
    throw FormatException(
      'Unsupported response payload type: ${rawData.runtimeType}.',
    );
  }

  Map<String, dynamic> _normalizeMap(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    throw const FormatException('Response item must be a JSON object.');
  }

  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _normalizeBody(response.data);
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

  List<String> _normalizeSids(List<String> sids) {
    final normalized = <String>[];
    for (final sid in sids) {
      final value = sid.trim();
      if (value.isEmpty || normalized.contains(value)) {
        continue;
      }
      normalized.add(value);
    }
    return normalized;
  }
}
