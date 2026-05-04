import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/video_call/call_conversation_record_service.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'builds canceled outgoing video call as a system notice payload',
    () async {
      final writes = <CallConversationRecordPayload>[];
      final service = CallConversationRecordService(
        writePayload: (payload) async {
          writes.add(payload);
        },
      );

      await service.recordCallSummary(
        roomId: 'call_1',
        channelId: 'u_b',
        channelType: WKChannelType.personal,
        channelName: 'Test User',
        callType: CallType.video,
        direction: CallDirection.outgoing,
        status: CallHistoryStatus.canceled,
      );

      expect(writes, hasLength(1));
      expect(writes.single.text, '已取消视频通话');
      expect(writes.single.payload['type'], callConversationRecordType);
      expect(writes.single.payload['room_id'], 'call_1');
      expect(writes.single.payload['status'], CallHistoryStatus.canceled.value);
    },
  );

  test(
    'builds missed incoming audio call as a system notice payload',
    () async {
      final writes = <CallConversationRecordPayload>[];
      final service = CallConversationRecordService(
        writePayload: (payload) async {
          writes.add(payload);
        },
      );

      await service.recordCallSummary(
        roomId: 'call_2',
        channelId: 'u_b',
        channelType: WKChannelType.personal,
        channelName: 'Test User',
        callType: CallType.audio,
        direction: CallDirection.incoming,
        status: CallHistoryStatus.missed,
      );

      expect(writes, hasLength(1));
      expect(writes.single.text, '未接听语音通话');
      expect(writes.single.payload['direction'], CallDirection.incoming.value);
      expect(writes.single.payload['call_type'], CallType.audio.value);
    },
  );

  test('builds an in-memory chat message for web call records', () {
    final payload = CallConversationRecordPayload(
      text: '\u5df2\u53d6\u6d88\u89c6\u9891\u901a\u8bdd',
      clientMsgNo: 'call_summary_call_3_1_outgoing_canceled',
      payload: <String, dynamic>{
        'type': callConversationRecordType,
        'content': '\u5df2\u53d6\u6d88\u89c6\u9891\u901a\u8bdd',
        'room_id': 'call_3',
        'channel_id': 'u_b',
        'channel_type': WKChannelType.personal,
        'channel_name': 'Test User',
        'call_type': CallType.video.value,
        'direction': CallDirection.outgoing.value,
        'status': CallHistoryStatus.canceled.value,
      },
    );

    final message = buildCallConversationRecordMessage(
      payload,
      fromUid: 'u_me',
      now: DateTime.fromMillisecondsSinceEpoch(1777184800123),
    );

    expect(message.clientMsgNO, payload.clientMsgNo);
    expect(message.channelID, 'u_b');
    expect(message.channelType, WKChannelType.personal);
    expect(message.fromUID, 'u_me');
    expect(message.header.redDot, isFalse);
    expect(message.status, WKSendMsgResult.sendSuccess);
    expect(message.timestamp, 1777184800);
    expect(message.orderSeq, 1777184800123);
    expect(message.content, contains('"room_id":"call_3"'));
  });

  test('web or non-app runtimes use ephemeral call record delivery', () {
    expect(
      shouldUseEphemeralCallConversationRecord(isWeb: true, sdkAppMode: true),
      isTrue,
    );
    expect(
      shouldUseEphemeralCallConversationRecord(isWeb: false, sdkAppMode: false),
      isTrue,
    );
    expect(
      shouldUseEphemeralCallConversationRecord(isWeb: false, sdkAppMode: true),
      isFalse,
    );
  });
}
