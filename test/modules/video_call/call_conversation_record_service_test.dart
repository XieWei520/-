import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/video_call/call_conversation_record_service.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('builds canceled outgoing video call as a system notice payload', () async {
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
  });

  test('builds missed incoming audio call as a system notice payload', () async {
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
  });
}
