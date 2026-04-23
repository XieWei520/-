import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import 'api_client.dart';
import 'file_api.dart';

class CollectionApi {
  CollectionApi._();

  static final CollectionApi _instance = CollectionApi._();
  static CollectionApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  Future<void> add({
    required String clientMsgNo,
    String? messageId,
    int? messageSeq,
    int? orderSeq,
    String? content,
    int? contentType,
    String? channelId,
    int? channelType,
    String? senderUid,
    String? senderName,
  }) async {
    final data = <String, dynamic>{'client_msg_no': clientMsgNo};
    if (messageId != null) {
      data['message_id'] = messageId;
    }
    if (messageSeq != null && messageSeq > 0) {
      data['message_seq'] = messageSeq;
    }
    if (orderSeq != null && orderSeq > 0) {
      data['order_seq'] = orderSeq;
    }
    if (content != null) {
      data['content'] = content;
    }
    if (contentType != null) {
      data['content_type'] = contentType;
    }
    if (channelId != null && channelId.trim().isNotEmpty) {
      data['channel_id'] = channelId.trim();
    }
    if (channelType != null && channelType > 0) {
      data['channel_type'] = channelType;
    }
    if (senderUid != null && senderUid.trim().isNotEmpty) {
      data['sender_uid'] = senderUid.trim();
    }
    if (senderName != null && senderName.trim().isNotEmpty) {
      data['sender_name'] = senderName.trim();
    }
    await _client.post(ApiConfig.favorite, data: data);
  }

  Future<List<Map<String, dynamic>>> getList({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.get(
      ApiConfig.favorites,
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final data = response.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> delete(dynamic id) async {
    await _client.delete('${ApiConfig.favorite}/$id');
  }

  Future<List<Map<String, dynamic>>> search({
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.post(
      '${ApiConfig.favorites}/search',
      data: {'keyword': keyword, 'page': page, 'page_size': pageSize},
    );
    final data = response.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(data);
  }
}

class TagApi {
  TagApi._();

  static final TagApi _instance = TagApi._();
  static TagApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  Future<List<Map<String, dynamic>>> getTags() async {
    final response = await _client.get(ApiConfig.tags);
    final data = response.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String> create({required String name, String? remark}) async {
    final data = <String, dynamic>{'name': name};
    if (remark != null) {
      data['remark'] = remark;
    }
    final response = await _client.post(ApiConfig.tag, data: data);
    return response.data['data']?['id']?.toString() ?? '';
  }

  Future<void> update({
    required String id,
    String? name,
    String? remark,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (remark != null) {
      data['remark'] = remark;
    }
    await _client.put('${ApiConfig.tag}/$id', data: data);
  }

  Future<void> delete(String id) async {
    await _client.delete('${ApiConfig.tag}/$id');
  }

  Future<void> addMembers({
    required String tagId,
    required List<String> uids,
  }) async {
    await _client.post('${ApiConfig.tag}/$tagId/members', data: {'uids': uids});
  }

  Future<void> removeMembers({
    required String tagId,
    required List<String> uids,
  }) async {
    await _client.delete(
      '${ApiConfig.tag}/$tagId/members',
      data: {'uids': uids},
    );
  }

  Future<List<Map<String, dynamic>>> getMembers(String tagId) async {
    final response = await _client.get('${ApiConfig.tag}/$tagId/members');
    final data = response.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(data);
  }
}

class MomentsApi {
  MomentsApi._();

  static final MomentsApi _instance = MomentsApi._();
  static MomentsApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final FileApi _fileApi = FileApi.instance;

  Future<List<Map<String, dynamic>>> getList({
    int page = 1,
    int pageSize = 20,
    String? maxId,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (maxId != null) {
      queryParams['max_id'] = maxId;
    }
    final response = await _client.get(
      ApiConfig.moments,
      queryParameters: queryParams,
    );
    final data = response.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String> publish({
    String? content,
    List<String>? images,
    List<String>? mentions,
    String? location,
  }) async {
    final data = <String, dynamic>{};
    if (content != null) {
      data['content'] = content;
    }
    if (images != null && images.isNotEmpty) {
      final normalizedImages = <String>[];
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        if (_isRemoteImage(image)) {
          normalizedImages.add(ApiConfig.resolveMediaUrl(image));
        } else {
          normalizedImages.add(
            await _fileApi.uploadMomentFile(image, index: i),
          );
        }
      }
      data['images'] = normalizedImages;
    }
    if (mentions != null) {
      data['mentions'] = mentions;
    }
    if (location != null) {
      data['location'] = location;
    }
    final response = await _client.post(ApiConfig.moment, data: data);
    return response.data['data']?['id']?.toString() ?? '';
  }

  Future<void> delete(String momentId) async {
    await _client.delete('${ApiConfig.moment}/$momentId');
  }

  Future<String> comment({
    required String momentId,
    required String content,
    String? replyTo,
  }) async {
    final data = <String, dynamic>{'content': content};
    if (replyTo != null) {
      data['reply_to'] = replyTo;
    }
    final response = await _client.post(
      '${ApiConfig.moment}/$momentId/comment',
      data: data,
    );
    return response.data['data']?['id']?.toString() ?? '';
  }

  Future<void> deleteComment({
    required String momentId,
    required String commentId,
  }) async {
    await _client.delete('${ApiConfig.moment}/$momentId/comment/$commentId');
  }

  Future<void> like(String momentId) async {
    await _client.post('${ApiConfig.moment}/$momentId/like');
  }

  Future<void> unlike(String momentId) async {
    await _client.delete('${ApiConfig.moment}/$momentId/like');
  }

  Future<List<Map<String, dynamic>>> getComments(
    String momentId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _client.get(
      '${ApiConfig.moment}/$momentId/comments',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final data = response.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(data);
  }

  bool _isRemoteImage(String value) {
    final lowerValue = value.trim().toLowerCase();
    return lowerValue.startsWith('http://') ||
        lowerValue.startsWith('https://');
  }
}

class SettingsApi {
  SettingsApi._();

  static final SettingsApi _instance = SettingsApi._();
  static SettingsApi get instance => _instance;

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

  List<dynamic> _resolveList(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Map && raw['data'] is List) {
      return List<dynamic>.from(raw['data'] as List);
    }
    return const <dynamic>[];
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

  Future<Map<String, dynamic>> getUserSettings() async {
    final response = await _client.get(ApiConfig.userSetting);
    _ensureSuccess(response, fallback: 'Load user settings failed');
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  Future<void> updateUserSettings(Map<String, dynamic> settings) async {
    final response = await _client.put(ApiConfig.userSetting, data: settings);
    _ensureSuccess(response, fallback: 'Update user settings failed');
  }

  Future<bool> getDeviceLockStatus() async {
    final response = await _client.get(ApiConfig.userDeviceLock);
    _ensureSuccess(response, fallback: 'Load device lock status failed');
    return response.data['data']?['enabled'] ?? false;
  }

  Future<void> setDeviceLock({
    required String password,
    required bool enabled,
  }) async {
    final response = await _client.post(
      ApiConfig.userDeviceLock,
      data: {'password': password, 'enabled': enabled},
    );
    _ensureSuccess(response, fallback: 'Update device lock failed');
  }

  Future<List<Map<String, dynamic>>> getBlacklist() async {
    final response = await _client.get(ApiConfig.userBlacklists);
    _ensureSuccess(response, fallback: 'Load blacklist failed');
    final data = _resolveList(response.data);
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> addBlacklist(String uid) async {
    final response = await _client.post('${ApiConfig.userBlacklist}/$uid');
    _ensureSuccess(response, fallback: 'Add blacklist failed');
  }

  Future<void> removeBlacklist(String uid) async {
    final response = await _client.delete('${ApiConfig.userBlacklist}/$uid');
    _ensureSuccess(response, fallback: 'Remove blacklist failed');
  }

  Future<List<Map<String, dynamic>>> getDevices() async {
    final response = await _client.get(ApiConfig.userDevices);
    _ensureSuccess(response, fallback: 'Load devices failed');
    final data = response.data['data'] ?? [];
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> deleteDevice(String deviceId) async {
    final response = await _client.delete('${ApiConfig.userDevices}/$deviceId');
    _ensureSuccess(response, fallback: 'Delete device failed');
  }
}
