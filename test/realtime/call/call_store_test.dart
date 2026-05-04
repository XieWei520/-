import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/realtime/call/call_event_mapper.dart';
import 'package:wukong_im_app/realtime/call/call_state_machine.dart';
import 'package:wukong_im_app/realtime/call/call_store.dart';
import 'package:wukong_im_app/realtime/session/session_event_frame.dart';

void main() {
  test(
    'call store ignores stale events from an old room once a new room is active',
    () async {
      final store = CallStore(machine: CallStateMachine());
      addTearDown(store.dispose);

      final states = <CallSessionState>[];
      final subscription = store.stream.listen(states.add);
      addTearDown(subscription.cancel);

      store.apply(
        const CallEvent.invite(
          roomId: 'room_02',
          peerUid: 'u_peer_02',
          peerName: 'Peer 02',
          callType: CallType.audio,
        ),
      );
      store.apply(
        const CallEvent.remoteState(
          roomId: 'room_01',
          status: CallRoomStatus.ended,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(store.state.roomId, 'room_02');
      expect(store.state.status, CallLifecycleStatus.invited);
      expect(states, hasLength(1));
    },
  );

  test(
    'call store broadcasts accepted domain events and state updates',
    () async {
      final store = CallStore(machine: CallStateMachine());
      addTearDown(store.dispose);

      final events = <CallEvent>[];
      final states = <CallSessionState>[];
      final eventSubscription = store.events.listen(events.add);
      final stateSubscription = store.stream.listen(states.add);
      addTearDown(eventSubscription.cancel);
      addTearDown(stateSubscription.cancel);

      store.apply(
        const CallEvent.localDial(
          roomId: 'room_03',
          peerUid: 'u_peer_03',
          peerName: 'Peer 03',
          callType: CallType.video,
        ),
      );
      store.apply(
        const CallEvent.remoteState(
          roomId: 'room_03',
          status: CallRoomStatus.connected,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(events.map((event) => event.roomId), <String>[
        'room_03',
        'room_03',
      ]);
      expect(states.last.status, CallLifecycleStatus.connected);
    },
  );

  test(
    'call store ignores late remote events after a call has already ended',
    () async {
      final store = CallStore(machine: CallStateMachine());
      addTearDown(store.dispose);

      final states = <CallSessionState>[];
      final events = <CallEvent>[];
      final stateSubscription = store.stream.listen(states.add);
      final eventSubscription = store.events.listen(events.add);
      addTearDown(stateSubscription.cancel);
      addTearDown(eventSubscription.cancel);

      store.apply(
        const CallEvent.localDial(
          roomId: 'room_05',
          peerUid: 'u_peer_05',
          peerName: 'Peer 05',
          callType: CallType.audio,
        ),
      );
      store.apply(
        const CallEvent.remoteSignal(
          roomId: 'room_05',
          fromUid: 'u_peer_05',
          signalType: CallSignalType.hangup,
          payload: <String, dynamic>{},
        ),
      );

      final acceptedLateEvent = store.apply(
        const CallEvent.remoteState(
          roomId: 'room_05',
          status: CallRoomStatus.connected,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(acceptedLateEvent, isFalse);
      expect(store.state.status, CallLifecycleStatus.ended);
      expect(events, hasLength(2));
      expect(states.last.status, CallLifecycleStatus.ended);
    },
  );

  test('event mapper converts session frames into call events', () {
    final mapper = CallEventMapper(currentUid: 'u_self');

    final invite = mapper.mapFrame(
      const SessionEventFrame(
        eventId: 'evt_invite',
        userSeq: 1,
        serverTs: 1712000000,
        kind: 'call.invite',
        aggregateId: 'room_04',
        payload: <String, dynamic>{
          'room_id': 'room_04',
          'caller_uid': 'u_peer_04',
          'caller_name': 'Peer 04',
          'callee_uid': 'u_self',
          'call_type': 1,
          'status': 0,
        },
      ),
    );
    final signal = mapper.mapFrame(
      const SessionEventFrame(
        eventId: 'evt_signal',
        userSeq: 2,
        serverTs: 1712000001,
        kind: 'call.signal',
        aggregateId: 'room_04',
        payload: <String, dynamic>{
          'room_id': 'room_04',
          'from_uid': 'u_peer_04',
          'signal_type': 0,
          'payload': <String, dynamic>{'sdp': 'offer'},
        },
      ),
    );

    expect(invite, isA<InviteCallEvent>());
    expect((invite as InviteCallEvent).peerUid, 'u_peer_04');
    expect(invite.callType, CallType.video);

    expect(signal, isA<RemoteSignalCallEvent>());
    expect((signal as RemoteSignalCallEvent).signalType, CallSignalType.offer);
    expect(signal.payload['sdp'], 'offer');
  });

  test('event mapper treats self-authored invite replay as local dial', () {
    final mapper = CallEventMapper(currentUid: 'u_self');

    final event = mapper.mapFrame(
      const SessionEventFrame(
        eventId: 'evt_self_invite',
        userSeq: 3,
        serverTs: 1712000002,
        kind: 'call.invite',
        aggregateId: 'room_06',
        payload: <String, dynamic>{
          'room_id': 'room_06',
          'caller_uid': 'u_self',
          'callee_uid': 'u_peer_06',
          'callee_name': 'Peer 06',
          'call_type': 0,
          'status': 0,
        },
      ),
    );

    expect(event, isA<LocalDialCallEvent>());
    expect((event as LocalDialCallEvent).peerUid, 'u_peer_06');
    expect(event.callType, CallType.audio);
  });

  test('call store ignores apply and reset after dispose', () async {
    final store = CallStore(machine: CallStateMachine());

    await store.dispose();

    final accepted = store.apply(
      const CallEvent.localDial(
        roomId: 'room_disposed',
        peerUid: 'u_peer',
        peerName: 'Peer',
        callType: CallType.audio,
      ),
    );

    expect(accepted, isFalse);
    expect(store.state, const CallSessionState.idle());
    expect(store.reset, returnsNormally);
  });
}
