import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../realtime/session/session_event_frame.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry.dart';
import 'api_client.dart';
import 'im_route_info.dart';

class IMSyncApi {
  IMSyncApi._();

  static final IMSyncApi _instance = IMSyncApi._();
  static IMSyncApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;

  Future<WKSyncConversation> syncConversation({
    required int version,
    required String lastMsgSeqs,
    required int msgCount,
    required String deviceUuid,
  }) async {
    final response = await _client.post(
      '/v1/conversation/sync',
      data: {
        'version': version,
        'last_msg_seqs': lastMsgSeqs,
        'msg_count': msgCount,
        'device_uuid': deviceUuid,
      },
    );

    final data = _unwrapMap(response.data);
    final result = WKSyncConversation()
      ..uid = _readString(data['uid'])
      ..cmdVersion = _readInt(data['cmd_version']);

    final commands = data['cmds'];
    if (commands is List) {
      result.cmds = commands
          .whereType<Map>()
          .map((item) => _parseSyncCommand(item))
          .toList();
    } else {
      result.cmds = [];
    }

    final channelStatus = data['channel_status'];
    if (channelStatus is List) {
      result.channelStatus = channelStatus
          .whereType<Map>()
          .map((item) => _parseChannelState(item))
          .toList();
    } else {
      result.channelStatus = [];
    }

    final conversations = data['conversations'];
    if (conversations is List) {
      result.conversations = conversations
          .whereType<Map>()
          .map((item) => _parseSyncConversation(item))
          .toList();
    } else {
      result.conversations = [];
    }

    return result;
  }

  Future<WKSyncChannelMsg> syncChannelMessages({
    required String channelId,
    required int channelType,
    required int startMessageSeq,
    required int endMessageSeq,
    required int limit,
    required int pullMode,
    required String deviceUuid,
  }) async {
    final normalizedStartSeq = startMessageSeq < 0 ? 0 : startMessageSeq;
    final normalizedEndSeq = endMessageSeq < 0 ? 0 : endMessageSeq;
    final response = await _client.post(
      '/v1/message/channel/sync',
      data: {
        'channel_id': channelId,
        'channel_type': channelType,
        'start_message_seq': normalizedStartSeq,
        'end_message_seq': normalizedEndSeq,
        'limit': limit,
        'pull_mode': pullMode,
        'device_uuid': deviceUuid,
      },
    );

    final data = _unwrapMap(response.data);
    final result = WKSyncChannelMsg()
      ..startMessageSeq = _readInt(data['start_message_seq'])
      ..endMessageSeq = _readInt(data['end_message_seq'])
      ..more = _readInt(data['more']);

    final messages = data['messages'];
    if (messages is List) {
      result.messages = messages
          .whereType<Map>()
          .map((item) => _parseSyncMsg(item))
          .toList();
    } else {
      result.messages = [];
    }

    return result;
  }

  Future<dynamic> pageChannelMessages({
    required String channelId,
    required int channelType,
    required int beforeMessageSeq,
    int limit = 50,
  }) {
    return ApiClient.instance.get(
      '/v1/messages/page',
      queryParameters: <String, dynamic>{
        'channel_id': channelId,
        'channel_type': channelType,
        'before_message_seq': beforeMessageSeq,
        'limit': limit,
      },
    );
  }

  Future<ImRouteInfo> fetchUserConnectRoute({required String uid}) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return const ImRouteInfo.empty();
    }

    final response = await _client.get(
      '/v1/users/${Uri.encodeComponent(normalizedUid)}/im',
    );
    final data = _unwrapMap(response.data);
    return ImRouteInfo.fromMap(data);
  }

  Future<void> ackConversationSync({
    required int cmdVersion,
    required String deviceUuid,
  }) async {
    final normalizedDeviceUuid = deviceUuid.trim();
    if (normalizedDeviceUuid.isEmpty) {
      return;
    }

    await _client.post(
      '/v1/conversation/syncack',
      data: <String, dynamic>{
        'cmd_version': cmdVersion,
        'device_uuid': normalizedDeviceUuid,
      },
    );
  }

  Future<List<SessionEventFrame>> pullAfterSeq({
    required int afterSeq,
    int limit = 200,
  }) async {
    final normalizedAfterSeq = afterSeq < 0 ? 0 : afterSeq;
    var normalizedLimit = limit;
    if (normalizedLimit <= 0) {
      normalizedLimit = 200;
    } else if (normalizedLimit > 200) {
      normalizedLimit = 200;
    }

    final response = await _client.get(
      '/v1/realtime/session/events/pull_after_seq',
      queryParameters: <String, dynamic>{
        'after_seq': normalizedAfterSeq,
        'limit': normalizedLimit,
      },
    );
    final rows = _unwrapList(response.data);
    return rows
        .whereType<Map>()
        .map(
          (item) => SessionEventFrame.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> uploadRealtimeRolloutTelemetry(
    List<RealtimeTelemetryEvent> events,
  ) async {
    if (events.isEmpty) {
      return;
    }
    await _client.post(
      '/v1/realtime/session/rollout/telemetry',
      data: <String, dynamic>{
        'events': events.map((event) => event.toJson()).toList(growable: false),
      },
    );
  }

  WKSyncConvMsg _parseSyncConversation(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final conversation = WKSyncConvMsg()
      ..channelID = _readString(json['channel_id'])
      ..channelType = _readInt(json['channel_type'])
      ..lastClientMsgNO = _readString(json['last_client_msg_no'])
      ..lastMsgSeq = _readInt(json['last_msg_seq'])
      ..offsetMsgSeq = _readInt(json['offset_msg_seq'])
      ..timestamp = _readInt(json['timestamp'])
      ..unread = _readInt(json['unread'])
      ..version = _readInt(json['version']);

    final recents = json['recents'];
    if (recents is List) {
      conversation.recents = recents
          .whereType<Map>()
          .map((item) => _parseSyncMsg(item))
          .toList();
    } else {
      conversation.recents = [];
    }

    return conversation;
  }

  WkSyncCMD _parseSyncCommand(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return WkSyncCMD()
      ..cmd = _readString(json['cmd'])
      ..param = json['param'];
  }

  WKChannelState _parseChannelState(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return WKChannelState()
      ..channelID = _readString(json['channel_id'])
      ..channelType = _readInt(json['channel_type'])
      ..calling = _readInt(json['calling']);
  }

  WKSyncMsg _parseSyncMsg(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final msg = WKSyncMsg()
      ..messageID = _readString(json['message_id'])
      ..messageSeq = _readInt(json['message_seq'])
      ..clientMsgNO = _readString(json['client_msg_no'])
      ..fromUID = _readString(json['from_uid'])
      ..channelID = _readString(json['channel_id'])
      ..channelType = _readInt(json['channel_type'])
      ..timestamp = _readInt(json['timestamp'])
      ..voiceStatus = _readInt(json['voice_status'])
      ..isDeleted = _readInt(json['is_deleted'])
      ..revoke = _readInt(json['revoke'])
      ..revoker = _readString(json['revoker'])
      ..extraVersion = _readInt(json['extra_version'])
      ..unreadCount = _readInt(json['unread_count'])
      ..readedCount = _readInt(json['readed_count'])
      ..readed = _readInt(json['readed'])
      ..isPinned = _readInt(json['is_pinned'])
      ..receipt = _readInt(json['receipt'])
      ..setting = _readInt(json['setting'])
      ..payload = json['payload'];

    final extra = json['message_extra'];
    if (extra is Map) {
      msg.messageExtra = _parseSyncExtra(extra);
    }

    final reactions = json['reactions'];
    if (reactions is List) {
      msg.reactions = reactions
          .whereType<Map>()
          .map((item) => _parseSyncReaction(item))
          .toList();
    }

    return msg;
  }

  WKSyncExtraMsg _parseSyncExtra(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return WKSyncExtraMsg()
      ..messageID = _readInt(json['message_id'])
      ..messageIdStr = _readString(json['message_id_str'])
      ..revoke = _readInt(json['revoke'])
      ..revoker = _readString(json['revoker'])
      ..voiceStatus = _readInt(json['voice_status'])
      ..isMutualDeleted = _readInt(json['is_mutual_deleted'])
      ..extraVersion = _readInt(json['extra_version'])
      ..unreadCount = _readInt(json['unread_count'])
      ..readedCount = _readInt(json['readed_count'])
      ..readed = _readInt(json['readed'])
      ..isPinned = _readInt(json['is_pinned'])
      ..contentEdit = json['content_edit']
      ..editedAt = _readInt(json['edited_at']);
  }

  WKSyncMsgReaction _parseSyncReaction(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    return WKSyncMsgReaction()
      ..messageID = _readString(json['message_id'])
      ..uid = _readString(json['uid'])
      ..name = _readString(json['name'])
      ..channelID = _readString(json['channel_id'])
      ..channelType = _readInt(json['channel_type'])
      ..seq = _readInt(json['seq'])
      ..emoji = _readString(json['emoji'])
      ..isDeleted = _readInt(json['is_deleted'])
      ..createdAt = _readString(json['created_at']);
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map) {
        return Map<String, dynamic>.from(raw['data'] as Map);
      }
      return raw;
    }

    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      if (map['data'] is Map) {
        return Map<String, dynamic>.from(map['data'] as Map);
      }
      return map;
    }

    return {};
  }

  List<dynamic> _unwrapList(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) {
        return data;
      }
      return const <dynamic>[];
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final data = map['data'];
      if (data is List) {
        return data;
      }
      return const <dynamic>[];
    }
    return const <dynamic>[];
  }

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString();
  }
}
