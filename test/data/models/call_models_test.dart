import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';

void main() {
  group('CallRoom parsing', () {
    test('parses primitive json payload', () {
      final room = CallRoom.fromJson({
        'room_id': 'call_123',
        'caller_uid': 'u1',
        'callee_uid': 'u2',
        'call_type': 1,
        'status': 2,
        'created_at': '2026-03-30 12:00:00',
      });

      expect(room.roomId, 'call_123');
      expect(room.callType, CallType.video);
      expect(room.status, CallRoomStatus.connected);
    });
  });

  group('CallSignal parsing', () {
    test('parses json payload when provided as string', () {
      final signal = CallSignal.fromJson({
        'from_uid': 'u2',
        'signal_type': 1,
        'payload': '{"sdp":"v=0","type":"answer"}',
        'created_at': '2026-03-30 12:10:00',
      });

      expect(signal.signalType, CallSignalType.answer);
      expect(signal.payload['type'], 'answer');
      expect(signal.payload['sdp'], 'v=0');
    });

    test('handles non-json payload gracefully', () {
      final signal = CallSignal.fromJson({
        'from_uid': 'u3',
        'signal_type': 3,
        'payload': 'hangup',
      });

      expect(signal.signalType, CallSignalType.hangup);
      expect(signal.payload['value'], 'hangup');
    });
  });
}
