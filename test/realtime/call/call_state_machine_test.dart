import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/realtime/call/call_state_machine.dart';

void main() {
  test('call state machine enforces one active room and ordered transitions', () {
    final machine = CallStateMachine();

    final invited = machine.reduce(
      const CallSessionState.idle(),
      const CallEvent.invite(
        roomId: 'room_01',
        peerUid: 'u_peer_01',
        peerName: 'Peer 01',
        callType: CallType.video,
      ),
    );
    final connecting = machine.reduce(
      invited,
      const CallEvent.localAccept(roomId: 'room_01'),
    );
    final connected = machine.reduce(
      connecting,
      const CallEvent.remoteState(
        roomId: 'room_01',
        status: CallRoomStatus.connected,
      ),
    );

    expect(invited.status, CallLifecycleStatus.invited);
    expect(invited.direction, CallDirection.incoming);
    expect(connecting.status, CallLifecycleStatus.connecting);
    expect(connected.status, CallLifecycleStatus.connected);
    expect(connected.roomId, 'room_01');
    expect(connected.peerUid, 'u_peer_01');
    expect(connected.callType, CallType.video);
  });

  test('local dial becomes active call session for the new room', () {
    final machine = CallStateMachine();

    final dialing = machine.reduce(
      const CallSessionState.idle(),
      const CallEvent.localDial(
        roomId: 'room_02',
        peerUid: 'u_peer_02',
        peerName: 'Peer 02',
        callType: CallType.audio,
      ),
    );
    final ended = machine.reduce(
      dialing,
      const CallEvent.remoteSignal(
        roomId: 'room_02',
        fromUid: 'u_peer_02',
        signalType: CallSignalType.hangup,
        payload: <String, dynamic>{'reason': 'peer_left'},
      ),
    );

    expect(dialing.status, CallLifecycleStatus.ringing);
    expect(dialing.direction, CallDirection.outgoing);
    expect(ended.status, CallLifecycleStatus.ended);
    expect(ended.roomId, 'room_02');
  });
}
