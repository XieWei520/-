import 'package:dio/dio.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';

import '../../core/utils/storage_utils.dart';
import 'api_client.dart';

class ReminderApi {
  ReminderApi._();

  static final ReminderApi _instance = ReminderApi._();
  static ReminderApi get instance => _instance;

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

  Future<List<WKReminder>> syncReminders({
    required int version,
    int limit = 200,
    List<String>? channelIds,
  }) async {
    final response = await _client.post(
      '/v1/message/reminder/sync',
      data: {
        'version': version,
        'limit': limit,
        'channel_ids': channelIds ?? const <String>[],
      },
    );
    _ensureSuccess(response, fallback: '同步提醒失败');

    final rawList = response.data is List
        ? response.data as List<dynamic>
        : response.data is Map && response.data['data'] is List
        ? response.data['data'] as List<dynamic>
        : const <dynamic>[];

    final loginUid = StorageUtils.getUid()?.trim() ?? '';
    return rawList
        .whereType<Map>()
        .map(
          (item) => _parseReminder(
            Map<String, dynamic>.from(item),
            loginUid: loginUid,
          ),
        )
        .toList();
  }

  Future<void> doneReminders(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    final response = await _client.post('/v1/message/reminder/done', data: ids);
    _ensureSuccess(response, fallback: '处理提醒失败');
  }

  WKReminder cloneReminder(WKReminder reminder, {int? done, int? version}) {
    final cloned = WKReminder()
      ..reminderID = reminder.reminderID
      ..messageID = reminder.messageID
      ..channelID = reminder.channelID
      ..channelType = reminder.channelType
      ..messageSeq = reminder.messageSeq
      ..type = reminder.type
      ..isLocate = reminder.isLocate
      ..uid = reminder.uid
      ..text = reminder.text
      ..data = reminder.data
      ..version = version ?? reminder.version
      ..done = done ?? reminder.done
      ..needUpload = reminder.needUpload
      ..publisher = reminder.publisher;
    return cloned;
  }

  WKReminder _parseReminder(
    Map<String, dynamic> json, {
    required String loginUid,
  }) {
    final reminder = WKReminder()
      ..reminderID = _readInt(json['id'])
      ..messageID = json['message_id']?.toString() ?? ''
      ..channelID = json['channel_id']?.toString() ?? ''
      ..channelType = _readInt(json['channel_type'])
      ..messageSeq = _readInt(json['message_seq'])
      ..type = _readInt(json['reminder_type'])
      ..isLocate = _readInt(json['is_locate'])
      ..uid = json['uid']?.toString() ?? ''
      ..text = json['text']?.toString() ?? ''
      ..data = json['data']
      ..version = _readInt(json['version'])
      ..done = _readInt(json['done'])
      ..publisher = json['publisher']?.toString() ?? '';

    if (loginUid.isNotEmpty && reminder.publisher == loginUid) {
      reminder.done = 1;
    }

    return reminder;
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
