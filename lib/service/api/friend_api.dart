import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../data/models/friend.dart';
import 'api_client.dart';

class FriendApi {
  FriendApi._();

  static final FriendApi _instance = FriendApi._();
  static FriendApi get instance => _instance;

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

  Future<List<Friend>> getFriends() async {
    final response = await _client.get(
      ApiConfig.friends,
      queryParameters: {
        'api_version': 1,
        'limit': 1000,
        'version': 0,
      },
    );
    _ensureSuccess(response, fallback: 'Load friends failed');

    final List<dynamic> list;
    if (response.data is List) {
      list = response.data as List<dynamic>;
    } else if (response.data is Map && response.data['data'] != null) {
      list = response.data['data'] as List<dynamic>;
    } else {
      list = [];
    }

    return list.map((json) => Friend.fromJson(json)).toList();
  }

  Future<void> addFriend(
    String uid, {
    String? remark,
    String? extra,
    String? vercode,
  }) async {
    final applyRemark = (extra?.trim().isNotEmpty ?? false)
        ? extra!.trim()
        : (remark?.trim().isNotEmpty ?? false)
        ? remark!.trim()
        : null;
    final response = await _client.post(
      ApiConfig.friendRequest,
      data: {
        'to_uid': uid,
        'remark': ?applyRemark,
        if (vercode != null && vercode.trim().isNotEmpty)
          'vercode': vercode.trim(),
      },
    );
    _ensureSuccess(response, fallback: '添加好友失败');
  }

  Future<List<FriendRequest>> getFriendRequests() async {
    final response = await _client.get(
      ApiConfig.friendRequests,
      queryParameters: {
        'page_index': 1,
        'page_size': 100,
      },
    );
    _ensureSuccess(response, fallback: '加载好友请求失败');

    final List<dynamic> list;
    if (response.data is List) {
      list = response.data as List<dynamic>;
    } else if (response.data is Map && response.data['data'] != null) {
      list = response.data['data'] as List<dynamic>;
    } else {
      list = [];
    }

    return list.map((json) => FriendRequest.fromJson(json)).toList();
  }

  Future<void> acceptFriendRequest(String token) async {
    final response = await _client.post(
      ApiConfig.friendResponse,
      data: {'token': token},
    );
    _ensureSuccess(response, fallback: '同意好友请求失败');
  }

  Future<void> refuseFriendRequest(String fromUid) async {
    final response = await _client.put('${ApiConfig.friendRefuse}/$fromUid');
    _ensureSuccess(response, fallback: '拒绝好友请求失败');
  }

  Future<void> deleteFriend(String uid) async {
    final response = await _client.delete('${ApiConfig.friends}/$uid');
    _ensureSuccess(response, fallback: '删除好友失败');
  }

  Future<void> updateFriendRemark(String uid, String remark) async {
    final response = await _client.put(
      ApiConfig.friendRemark,
      data: {'uid': uid, 'remark': remark},
    );
    _ensureSuccess(response, fallback: '更新好友备注失败');
  }
}
