import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/crypto_utils.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/mail_list_contact.dart';
import '../../data/models/user.dart';
import 'api_client.dart';

class UserApi {
  UserApi._();

  static final UserApi _instance = UserApi._();
  static UserApi get instance => _instance;

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

  Map<String, dynamic> _normalizeQrPayload(dynamic raw) {
    if (raw is String) {
      final value = raw.trim();
      return value.isEmpty
          ? <String, dynamic>{}
          : <String, dynamic>{'qrcode': value};
    }

    final body = _resolveBody(raw);
    final data = body['data'];
    if (data is String) {
      final value = data.trim();
      return value.isEmpty
          ? <String, dynamic>{}
          : <String, dynamic>{'qrcode': value};
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return body;
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

  Future<UserInfo> getUserInfo(String uid, {CancelToken? cancelToken}) async {
    final response = await _client.get(
      '${ApiConfig.userInfo}/$uid',
      cancelToken: cancelToken,
    );
    return UserInfo.fromJson(response.data);
  }

  Future<void> updateUserSetting(String uid, String key, Object? value) async {
    final response = await _client.put(
      '${ApiConfig.userInfo}/$uid/setting',
      data: <String, dynamic>{key: value},
    );
    _ensureSuccess(response, fallback: 'Update user setting failed');
  }

  Future<void> setChatPassword({
    required String uid,
    required String chatPassword,
    required String loginPassword,
    CancelToken? cancelToken,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw Exception('User uid is required');
    }
    if (chatPassword.isEmpty) {
      throw Exception('Chat password is required');
    }
    if (loginPassword.isEmpty) {
      throw Exception('Login password is required');
    }

    final response = await _client.post(
      ApiConfig.userChatPwd,
      data: <String, dynamic>{
        'chat_pwd': CryptoUtils.md5('$chatPassword$normalizedUid'),
        'login_pwd': loginPassword,
      },
      cancelToken: cancelToken,
    );
    _ensureSuccess(response, fallback: 'Set chat password failed');
  }

  Future<void> updateUserInfo({
    String? name,
    int? sex,
    String? avatar,
    String? shortNo,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) {
      data['name'] = name;
    }
    if (sex != null) {
      data['sex'] = sex;
    }
    if (avatar != null) {
      data['avatar'] = avatar;
    }
    if (shortNo != null) {
      data['short_no'] = shortNo;
    }

    final response = await _client.put('/v1/user/current', data: data);
    _ensureSuccess(response, fallback: '更新用户资料失败');
  }

  Future<String> uploadAvatar(String filePath) async {
    final uid = StorageUtils.getUid();
    if (uid == null || uid.isEmpty) {
      return '';
    }

    final response = await _client.uploadFile(
      '${ApiConfig.userInfo}/$uid/avatar',
      filePath,
      name: 'file',
    );
    _ensureSuccess(response, fallback: '上传头像失败');
    return ApiConfig.resolveMediaUrl(
      'users/$uid/avatar?t=${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<List<UserInfo>> getBlackList() async {
    final response = await _client.get(ApiConfig.userBlacklists);
    final list = _resolveList(response.data);
    return List<dynamic>.from(list)
        .map((json) => UserInfo.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> addBlackList(String uid) async {
    final response = await _client.post('${ApiConfig.userBlacklist}/$uid');
    _ensureSuccess(response, fallback: '添加黑名单失败');
  }

  Future<void> removeBlackList(String uid) async {
    final response = await _client.delete('${ApiConfig.userBlacklist}/$uid');
    _ensureSuccess(response, fallback: '移除黑名单失败');
  }

  Future<List<UserInfo>> searchUsers(String keyword) async {
    final response = await _client.get(
      '/v1/user/search',
      queryParameters: {'keyword': keyword},
    );
    _ensureSuccess(response, fallback: '搜索用户失败');

    if (response.data is List) {
      return List<dynamic>.from(response.data)
          .map((json) => UserInfo.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }

    if (response.data is Map && response.data['data'] is List) {
      return List<dynamic>.from(response.data['data'])
          .map((json) => UserInfo.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }

    if (response.data is Map && response.data['users'] is List) {
      return List<dynamic>.from(response.data['users'])
          .map((json) => UserInfo.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }

    if (response.data is Map &&
        response.data['exist'] == 1 &&
        response.data['data'] is Map) {
      return [
        UserInfo.fromJson(Map<String, dynamic>.from(response.data['data'])),
      ];
    }

    return [];
  }

  Future<UserInfo> getCurrentUser() async {
    final uid = StorageUtils.getUid();
    if (uid == null || uid.isEmpty) {
      return UserInfo(uid: '');
    }
    return getUserInfo(uid);
  }

  Future<Map<String, dynamic>> getQRCode() async {
    final response = await _client.get('/v1/user/qrcode');
    return _normalizeQrPayload(response.data);
  }

  Future<Map<String, dynamic>> getUserQrCode(String? uid) async {
    final normalizedUid = uid?.trim() ?? '';
    final currentUid = StorageUtils.getUid()?.trim() ?? '';
    if (normalizedUid.isNotEmpty && normalizedUid != currentUid) {
      throw Exception(
        'Remote user QR data must be built from vercode instead of /v1/user/:uid/qrcode.',
      );
    }
    return getQRCode();
  }

  Future<PcOnlineState> getPcOnlineState() async {
    final response = await _client.get('/v1/user/online');
    _ensureSuccess(response, fallback: '获取在线状态失败');
    final body = _resolveBody(response.data);
    final payload = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    return PcOnlineState.fromJson(payload['pc'] as Map?);
  }

  Future<void> uploadMailListContacts(
    List<MailListUploadContact> contacts,
  ) async {
    final response = await _client.post(
      ApiConfig.userMailList,
      data: contacts.map((contact) => contact.toJson()).toList(growable: false),
    );
    _ensureSuccess(response, fallback: 'Upload mail list contacts failed');
  }

  Future<List<MailListMatchedContact>> getMailListContacts() async {
    final response = await _client.get(ApiConfig.userMailList);
    _ensureSuccess(response, fallback: 'Fetch mail list contacts failed');
    final list = _resolveList(response.data);
    return list
        .map(
          (json) => MailListMatchedContact.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CustomerServiceAccount>> getCustomerServices({
    CancelToken? cancelToken,
  }) async {
    final response = await _client.get(
      ApiConfig.userCustomerServices,
      cancelToken: cancelToken,
    );
    _ensureSuccess(response, fallback: 'Fetch customer services failed');
    final list = _resolveList(response.data);
    return list
        .map(
          (json) => CustomerServiceAccount.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> sendDestroySmsCode({CancelToken? cancelToken}) async {
    final response = await _client.post(
      ApiConfig.userDestroySms,
      cancelToken: cancelToken,
    );
    _ensureSuccess(response, fallback: 'Send destroy SMS code failed');
  }

  Future<void> destroyAccount(String code, {CancelToken? cancelToken}) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw Exception('Destroy code is required');
    }
    final response = await _client.delete(
      ApiConfig.userDestroy(normalizedCode),
      cancelToken: cancelToken,
    );
    _ensureSuccess(response, fallback: 'Destroy account failed');
  }
}

class CustomerServiceAccount {
  const CustomerServiceAccount({required this.uid, required this.name});

  final String uid;
  final String name;

  factory CustomerServiceAccount.fromJson(Map<String, dynamic> json) {
    return CustomerServiceAccount(
      uid: (json['uid'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }
}

class PcOnlineState {
  final int online;
  final int muteOfApp;

  const PcOnlineState({required this.online, required this.muteOfApp});

  bool get isOnline => online == 1;

  factory PcOnlineState.fromJson(Map? json) {
    final body = json == null
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(json);
    return PcOnlineState(
      online: _parseIntLike(body['online']) ?? 0,
      muteOfApp: _parseIntLike(body['mute_of_app']) ?? 0,
    );
  }
}

int? _parseIntLike(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}
