import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/call.dart';

const int callConversationRecordType = 10020;

const String _audioCallLabel = '\u8bed\u97f3\u901a\u8bdd';
const String _videoCallLabel = '\u89c6\u9891\u901a\u8bdd';
const String _canceledPrefix = '\u5df2\u53d6\u6d88';
const String _missedPrefix = '\u672a\u63a5\u542c';
const String _rejectedPrefix = '\u5df2\u62d2\u7edd';
const String _endedSuffix = '\u7ed3\u675f';
const String _systemUid = 'u_10000';

String buildCallConversationRecordText({
  required CallType callType,
  required CallDirection direction,
  required CallHistoryStatus status,
}) {
  final label = switch (callType) {
    CallType.audio => _audioCallLabel,
    CallType.video => _videoCallLabel,
  };
  return switch (status) {
    CallHistoryStatus.completed => '$label$_endedSuffix',
    CallHistoryStatus.canceled => '$_canceledPrefix$label',
    CallHistoryStatus.missed => '$_missedPrefix$label',
    CallHistoryStatus.rejected => '$_rejectedPrefix$label',
    CallHistoryStatus.ringing || CallHistoryStatus.connected => '',
  };
}

String buildCallConversationRecordClientMsgNo({
  required String roomId,
  required CallType callType,
  required CallDirection direction,
  required CallHistoryStatus status,
}) {
  final normalizedRoomId = roomId.trim();
  return [
    'call_summary',
    normalizedRoomId,
    callType.value.toString(),
    direction.value,
    status.value,
  ].join('_');
}

@immutable
class CallConversationRecordPayload {
  const CallConversationRecordPayload({
    required this.text,
    required this.payload,
    required this.clientMsgNo,
  });

  final String text;
  final Map<String, dynamic> payload;
  final String clientMsgNo;
}

class CallConversationRecordService {
  CallConversationRecordService({
    Future<void> Function(CallConversationRecordPayload payload)? writePayload,
  }) : _writePayload = writePayload ?? _defaultWritePayload;

  static final CallConversationRecordService instance =
      CallConversationRecordService();

  final Future<void> Function(CallConversationRecordPayload payload)
  _writePayload;

  Future<void> recordCallSummary({
    required String roomId,
    required String channelId,
    required int channelType,
    required String channelName,
    required CallType callType,
    required CallDirection direction,
    required CallHistoryStatus status,
  }) async {
    final normalizedRoomId = roomId.trim();
    final normalizedChannelId = channelId.trim();
    if (normalizedRoomId.isEmpty || normalizedChannelId.isEmpty) {
      return;
    }

    final text = buildCallConversationRecordText(
      callType: callType,
      direction: direction,
      status: status,
    );
    if (text.isEmpty) {
      return;
    }

    final payload = CallConversationRecordPayload(
      text: text,
      clientMsgNo: buildCallConversationRecordClientMsgNo(
        roomId: normalizedRoomId,
        callType: callType,
        direction: direction,
        status: status,
      ),
      payload: <String, dynamic>{
        'type': callConversationRecordType,
        'content': text,
        'room_id': normalizedRoomId,
        'channel_id': normalizedChannelId,
        'channel_type': channelType,
        'channel_name': channelName.trim(),
        'call_type': callType.value,
        'direction': direction.value,
        'status': status.value,
      },
    );
    await _writePayload(payload);
  }

  static Future<void> _defaultWritePayload(
    CallConversationRecordPayload payload,
  ) async {
    try {
      final existing = await WKIM.shared.messageManager.getWithClientMsgNo(
        payload.clientMsgNo,
      );
      if (existing != null) {
        debugPrint(
          '[call/chat-record] skip duplicate clientMsgNo=${payload.clientMsgNo}',
        );
        return;
      }

      final message = WKMsg()
        ..clientMsgNO = payload.clientMsgNo
        ..channelID = payload.payload['channel_id']?.toString().trim() ?? ''
        ..channelType = _readChannelType(payload.payload['channel_type'])
        ..fromUID = _resolveFromUid()
        ..contentType = WkMessageContentType.unknown
        ..content = jsonEncode(payload.payload)
        ..status = WKSendMsgResult.sendSuccess
        ..header.redDot = false;
      if (message.channelID.isEmpty) {
        return;
      }

      message.orderSeq = await WKIM.shared.messageManager.getMessageOrderSeq(
        0,
        message.channelID,
        message.channelType,
      );
      final clientSeq = await WKIM.shared.messageManager.saveMsg(message);
      message.clientSeq = clientSeq;
      if (clientSeq <= 0) {
        return;
      }

      final uiMessage = await WKIM.shared.conversationManager.saveWithLiMMsg(
        message,
        0,
      );
      WKIM.shared.messageManager.setOnMsgInserted(message);
      if (uiMessage != null) {
        WKIM.shared.conversationManager.setRefreshUIMsgs(<WKUIConversationMsg>[
          uiMessage,
        ]);
      }
      debugPrint(
        '[call/chat-record] inserted roomId=${payload.payload['room_id']} '
        'status=${payload.payload['status']} text=${payload.text}',
      );
    } catch (error, stackTrace) {
      debugPrint('[call/chat-record] insert failed: $error');
      debugPrint('$stackTrace');
    }
  }
}

int _readChannelType(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  return int.tryParse(raw?.toString() ?? '') ?? WKChannelType.personal;
}

String _resolveFromUid() {
  final currentUid = StorageUtils.getUid()?.trim() ?? '';
  return currentUid.isNotEmpty ? currentUid : _systemUid;
}
