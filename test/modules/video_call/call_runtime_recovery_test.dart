import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/video_call/call_conversation_record_service.dart';
import 'package:wukong_im_app/modules/video_call/call_session_service.dart';
import 'package:wukong_im_app/modules/video_call/call_coordinator.dart';
import 'package:wukong_im_app/modules/video_call/video_call_service.dart';
import 'package:wukong_im_app/realtime/call/call_state_machine.dart';
import 'package:wukong_im_app/realtime/call/call_store.dart';
import 'package:wukong_im_app/realtime/session/session_event_frame.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('speakerphone routing support', () {
    test('is disabled on unsupported desktop and web platforms', () {
      expect(
        supportsSpeakerphoneRouting(
          platform: TargetPlatform.windows,
          isWeb: false,
        ),
        isFalse,
      );
      expect(
        supportsSpeakerphoneRouting(
          platform: TargetPlatform.linux,
          isWeb: false,
        ),
        isFalse,
      );
      expect(
        supportsSpeakerphoneRouting(
          platform: TargetPlatform.android,
          isWeb: false,
        ),
        isTrue,
      );
      expect(
        supportsSpeakerphoneRouting(platform: TargetPlatform.iOS, isWeb: false),
        isTrue,
      );
      expect(
        supportsSpeakerphoneRouting(
          platform: TargetPlatform.android,
          isWeb: true,
        ),
        isFalse,
      );
    });

    test(
      'uses desktop-safe media constraint candidates for Windows video calls',
      () {
        final candidates = buildUserMediaConstraintCandidates(
          videoEnabled: true,
          platform: TargetPlatform.windows,
          isWeb: false,
        );

        expect(candidates, hasLength(3));
        expect(candidates.first['audio'], isTrue);
        expect(candidates.first['video'], isA<Map<String, dynamic>>());
        expect(
          (candidates.first['video'] as Map<String, dynamic>).containsKey(
            'facingMode',
          ),
          isFalse,
        );
        expect(candidates.last['video'], isTrue);
      },
    );

    test(
      'allows audio-only fallback when video is requested but no camera track is returned',
      () {
        final resolution = resolveLocalMediaCapture(
          videoRequested: true,
          audioTrackCount: 1,
          videoTrackCount: 0,
        );

        expect(resolution.acceptsStream, isTrue);
        expect(resolution.localVideoAvailable, isFalse);
        expect(resolution.retryNextCandidate, isFalse);
      },
    );

    test(
      'requests a recvonly video transceiver when a video call has no local camera track',
      () {
        expect(
          shouldAddRecvOnlyVideoTransceiver(
            enableVideo: true,
            localVideoAvailable: false,
          ),
          isTrue,
        );
        expect(
          shouldAddRecvOnlyVideoTransceiver(
            enableVideo: true,
            localVideoAvailable: true,
          ),
          isFalse,
        );
        expect(
          shouldAddRecvOnlyVideoTransceiver(
            enableVideo: false,
            localVideoAvailable: false,
          ),
          isFalse,
        );
      },
    );

    test(
      'records a chat summary when a remote end closes an active direct call',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        final writes = <CallConversationRecordPayload>[];
        final service = VideoCallService(
          callStore: store,
          currentUidReader: () => 'u_self',
          conversationRecordService: CallConversationRecordService(
            writePayload: (payload) async {
              writes.add(payload);
            },
          ),
        );
        addTearDown(service.dispose);

        service.debugAdoptRoomForTest(
          CallRoom(
            roomId: 'room_summary_01',
            callerUid: 'u_self',
            calleeUid: 'u_peer',
            callType: CallType.video,
            status: CallRoomStatus.ringing,
            calleeName: 'Peer',
          ),
          channelId: 'u_peer',
        );

        await service.endCall(remote: true);

        expect(writes, hasLength(1));
        expect(
          writes.single.text,
          '\u5df2\u53d6\u6d88\u89c6\u9891\u901a\u8bdd',
        );
        expect(writes.single.payload['room_id'], 'room_summary_01');
      },
    );

    test(
      'records a canceled summary when outgoing call setup fails after room adoption',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        final writes = <CallConversationRecordPayload>[];
        final service = VideoCallService(
          callStore: store,
          currentUidReader: () => 'u_self',
          conversationRecordService: CallConversationRecordService(
            writePayload: (payload) async {
              writes.add(payload);
            },
          ),
        );
        addTearDown(service.dispose);

        service.debugAdoptRoomForTest(
          CallRoom(
            roomId: 'room_start_fail_01',
            callerUid: 'u_self',
            calleeUid: 'u_peer',
            callType: CallType.video,
            status: CallRoomStatus.pending,
            calleeName: 'Peer',
          ),
          channelId: 'u_peer',
        );

        await service.debugRecoverFailedStartForTest(
          roomId: 'room_start_fail_01',
          cancelServerRoom: false,
        );

        expect(writes, hasLength(1));
        expect(
          writes.single.text,
          '\u5df2\u53d6\u6d88\u89c6\u9891\u901a\u8bdd',
        );
        expect(writes.single.payload['room_id'], 'room_start_fail_01');
      },
    );
  });

  group('guarded async call actions', () {
    test('captures asynchronous failures from fire-and-forget tasks', () async {
      final errors = <Object>[];

      fireAndForgetCall(
        () async => throw StateError('boom'),
        debugLabel: 'test guarded task',
        onError: (error, _) => errors.add(error),
      );

      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });
  });

  group('pending call recovery loop', () {
    test('rejects an empty pending-call backoff schedule', () {
      expect(
        () => PendingCallRecoveryLoop(
          callStore: CallStore(machine: const CallStateMachine()),
          fetchPendingCalls: ({required fallback}) async => <CallRoom>[],
          currentUidReader: () => 'u_self',
          backoffSchedule: const <Duration>[],
        ),
        throwsArgumentError,
      );
    });

    test(
      'defaults to degradation-only polling with the approved backoff schedule',
      () {
        final loop = PendingCallRecoveryLoop(
          callStore: CallStore(machine: const CallStateMachine()),
          fetchPendingCalls: ({required fallback}) async => <CallRoom>[],
          currentUidReader: () => 'u_self',
        );
        addTearDown(loop.stop);

        expect(loop.enableSafetyPolling, isFalse);
        expect(loop.degradedThreshold, const Duration(seconds: 6));
        expect(loop.backoffSchedule, <Duration>[
          Duration(seconds: 2),
          Duration(seconds: 5),
          Duration(seconds: 15),
          Duration(seconds: 30),
          Duration(seconds: 60),
        ]);
      },
    );

    test('does not poll by default until the gateway is degraded', () async {
      final store = CallStore(machine: const CallStateMachine());
      addTearDown(store.dispose);

      var fetchCount = 0;
      final loop = PendingCallRecoveryLoop(
        callStore: store,
        fetchPendingCalls: ({required fallback}) async {
          fetchCount++;
          expect(fallback, isTrue);
          return <CallRoom>[
            CallRoom(
              roomId: 'room_pending_01',
              callerUid: 'u_peer',
              calleeUid: 'u_self',
              callType: CallType.video,
              status: CallRoomStatus.pending,
              callerName: 'Peer',
            ),
          ];
        },
        currentUidReader: () => 'u_self',
        degradedThreshold: Duration.zero,
        backoffSchedule: const <Duration>[Duration(milliseconds: 1)],
        delay: (_) => Completer<void>().future,
      );
      addTearDown(loop.stop);

      loop.setGatewayDegradationReader((_) => false);
      loop.start();

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, 0);
      expect(store.state.isActive, isFalse);

      loop.setGatewayDegradationReader((_) => true);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(fetchCount, 1);
      expect(store.state.roomId, 'room_pending_01');
      expect(store.state.status, CallLifecycleStatus.invited);
    });

    test(
      'wakes degradation-only polling when a passive reader later reports degraded',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        var degraded = false;
        var fetchCount = 0;
        final scheduledDelays = <Duration>[];
        final delayCompleters = <Completer<void>>[];
        final loop = PendingCallRecoveryLoop(
          callStore: store,
          fetchPendingCalls: ({required fallback}) async {
            fetchCount++;
            expect(fallback, isTrue);
            return <CallRoom>[
              CallRoom(
                roomId: 'room_pending_02',
                callerUid: 'u_peer',
                calleeUid: 'u_self',
                callType: CallType.video,
                status: CallRoomStatus.pending,
                callerName: 'Peer',
              ),
            ];
          },
          currentUidReader: () => 'u_self',
          degradedThreshold: const Duration(seconds: 6),
          backoffSchedule: const <Duration>[Duration(milliseconds: 1)],
          delay: (delay) {
            scheduledDelays.add(delay);
            final completer = Completer<void>();
            delayCompleters.add(completer);
            return completer.future;
          },
        );
        addTearDown(loop.stop);

        loop.setGatewayDegradationReader((_) => degraded);
        loop.start();

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 0);
        expect(store.state.isActive, isFalse);
        expect(scheduledDelays, <Duration>[Duration(seconds: 6)]);

        degraded = true;
        delayCompleters.single.complete();

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 1);
        expect(store.state.roomId, 'room_pending_02');
        expect(store.state.status, CallLifecycleStatus.invited);
      },
    );

    test(
      'ignores pending call fallback responses after stop invalidates the loop',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        var fetchCount = 0;
        final fetchCompleter = Completer<List<CallRoom>>();
        final loop = PendingCallRecoveryLoop(
          callStore: store,
          fetchPendingCalls: ({required fallback}) {
            fetchCount++;
            expect(fallback, isTrue);
            return fetchCompleter.future;
          },
          currentUidReader: () => 'u_self',
          degradedThreshold: Duration.zero,
          backoffSchedule: const <Duration>[Duration(milliseconds: 1)],
          delay: (_) => Completer<void>().future,
        );
        addTearDown(loop.stop);

        loop.setGatewayDegradationReader((_) => true);
        loop.start();

        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 1);
        expect(store.state.isActive, isFalse);

        loop.stop();
        fetchCompleter.complete(<CallRoom>[
          CallRoom(
            roomId: 'room_stale_stop_01',
            callerUid: 'u_peer',
            calleeUid: 'u_self',
            callType: CallType.video,
            status: CallRoomStatus.pending,
            callerName: 'Peer',
          ),
        ]);

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(store.state.isActive, isFalse);
        expect(store.state.roomId, isNot('room_stale_stop_01'));
        expect(store.state.status, CallLifecycleStatus.idle);
      },
    );

    test(
      'uses a positive degradation wake delay when threshold is zero and reader stays false',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        var fetchCount = 0;
        final scheduledDelays = <Duration>[];
        final delayCompleters = <Completer<void>>[];
        final loop = PendingCallRecoveryLoop(
          callStore: store,
          fetchPendingCalls: ({required fallback}) async {
            fetchCount++;
            return <CallRoom>[];
          },
          currentUidReader: () => 'u_self',
          degradedThreshold: Duration.zero,
          backoffSchedule: const <Duration>[Duration(milliseconds: 1)],
          delay: (delay) {
            scheduledDelays.add(delay);
            final completer = Completer<void>();
            delayCompleters.add(completer);
            return completer.future;
          },
        );
        addTearDown(loop.stop);

        loop.setGatewayDegradationReader((_) => false);
        loop.start();

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 0);
        expect(scheduledDelays, <Duration>[Duration(milliseconds: 1)]);

        delayCompleters.single.complete();

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 0);
        expect(scheduledDelays, <Duration>[
          Duration(milliseconds: 1),
          Duration(milliseconds: 1),
        ]);
      },
    );

    test(
      'can disable safety polling and only poll when gateway is degraded',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        var fetchCount = 0;
        final loop = PendingCallRecoveryLoop(
          callStore: store,
          fetchPendingCalls: ({required fallback}) async {
            fetchCount++;
            return <CallRoom>[];
          },
          currentUidReader: () => 'u_self',
          enableSafetyPolling: false,
          degradedThreshold: Duration.zero,
          backoffSchedule: const <Duration>[Duration(milliseconds: 1)],
          delay: (_) => Completer<void>().future,
        );
        addTearDown(loop.stop);

        loop.setGatewayDegradationReader((_) => false);
        loop.start();

        await Future<void>.delayed(Duration.zero);
        expect(fetchCount, 0);

        loop.setGatewayDegradationReader((_) => true);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 1);
      },
    );
  });

  group('call coordinator lifecycle', () {
    test(
      'stop clears stale call state before the next login session starts',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        final coordinator = CallCoordinator(
          callStore: store,
          currentUidReader: () => 'u_self',
          fetchPendingCalls: ({required fallback}) async => <CallRoom>[],
        );

        coordinator.start(GlobalKey<NavigatorState>());
        await coordinator.handleSessionFrame(
          const SessionEventFrame(
            eventId: 'evt_invite_stop',
            userSeq: 11,
            serverTs: 1712000011,
            kind: 'call.invite',
            aggregateId: 'room_stop_01',
            payload: <String, dynamic>{
              'room_id': 'room_stop_01',
              'caller_uid': 'u_peer',
              'caller_name': 'Peer',
              'callee_uid': 'u_self',
              'call_type': 1,
            },
          ),
        );

        expect(store.state.status, CallLifecycleStatus.invited);

        coordinator.stop();

        expect(store.state.status, CallLifecycleStatus.idle);
        expect(store.state.roomId, isEmpty);
      },
    );
  });

  group('signal recovery loop', () {
    test(
      'startCall can delegate to an injected session orchestrator facade',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        final orchestrator = _FakeCallSessionOrchestrator();
        final service = VideoCallService(
          callStore: store,
          currentUidReader: () => 'u_self',
          callSessionOrchestrator: orchestrator,
        );
        addTearDown(service.dispose);

        final states = <CallState>[];
        await service.startCall(
          targetUid: 'u_peer',
          targetName: 'Peer',
          callType: CallType.video,
          onStateChanged: states.add,
          onRemoteStream: (_) {},
        );

        expect(orchestrator.startOutgoingCalls, 1);
        expect(orchestrator.lastCalleeUid, 'u_peer');
        expect(states, contains(CallState.ringing));
      },
    );

    test('rejects an empty signal backoff schedule', () {
      expect(
        () => SignalRecoveryLoop(
          callStore: CallStore(machine: const CallStateMachine()),
          fetchSignals: (_, {required fallback}) async => <CallSignal>[],
          applyRemoteSignal: (_) => false,
          currentUidReader: () => 'u_self',
          backoffSchedule: const <Duration>[],
        ),
        throwsArgumentError,
      );
    });

    test(
      'replays fallback signals for the active room and skips local echoes',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        store.apply(
          const CallEvent.localDial(
            roomId: 'room_signal_01',
            peerUid: 'u_peer',
            peerName: 'Peer',
            callType: CallType.audio,
          ),
        );

        final appliedEvents = <RemoteSignalCallEvent>[];
        final sleepGate = Completer<void>();
        var fetchCount = 0;
        final loop = SignalRecoveryLoop(
          callStore: store,
          fetchSignals: (roomId, {required fallback}) async {
            fetchCount++;
            expect(roomId, 'room_signal_01');
            expect(fallback, isTrue);
            return <CallSignal>[
              CallSignal(
                fromUid: 'u_self',
                signalType: CallSignalType.offer,
                payload: const <String, dynamic>{'sdp': 'self'},
              ),
              CallSignal(
                fromUid: 'u_peer',
                signalType: CallSignalType.offer,
                payload: const <String, dynamic>{'sdp': 'remote_offer'},
              ),
            ];
          },
          applyRemoteSignal: (event) {
            appliedEvents.add(event);
            return store.apply(event);
          },
          currentUidReader: () => 'u_self',
          degradedThreshold: Duration.zero,
          backoffSchedule: const <Duration>[Duration(milliseconds: 1)],
          delay: (_) => sleepGate.future,
        );
        addTearDown(() {
          loop.stop();
          if (!sleepGate.isCompleted) {
            sleepGate.complete();
          }
        });

        loop.setGatewayDegradationReader((_) => true);
        loop.start();

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(fetchCount, 1);
        expect(appliedEvents, hasLength(1));
        expect(appliedEvents.single.fromUid, 'u_peer');
        expect(appliedEvents.single.signalType, CallSignalType.offer);
        expect(appliedEvents.single.payload['sdp'], 'remote_offer');
      },
    );

    test(
      'buffered remote signals replay offer before ice candidates after accept',
      () {
        final queue = BufferedRemoteSignalQueue();

        queue.add(
          const RemoteSignalCallEvent(
            roomId: 'room_buffer_01',
            fromUid: 'u_peer',
            signalType: CallSignalType.iceCandidate,
            payload: <String, dynamic>{'candidate': 'ice_01'},
          ),
        );
        queue.add(
          const RemoteSignalCallEvent(
            roomId: 'room_buffer_01',
            fromUid: 'u_peer',
            signalType: CallSignalType.offer,
            payload: <String, dynamic>{'sdp': 'offer_01'},
          ),
        );

        final replay = queue.take('room_buffer_01');

        expect(replay.map((event) => event.signalType), <CallSignalType>[
          CallSignalType.offer,
          CallSignalType.iceCandidate,
        ]);
      },
    );

    test(
      'room setup guard stops accept flow once the room is no longer active',
      () {
        expect(
          shouldContinueRoomSetup(
            currentRoom: CallRoom(
              roomId: 'room_guard_01',
              callerUid: 'u_peer',
              calleeUid: 'u_self',
              callType: CallType.audio,
              status: CallRoomStatus.pending,
            ),
            roomId: 'room_guard_01',
            storeState: const CallSessionState(
              status: CallLifecycleStatus.connecting,
              roomId: 'room_guard_01',
              peerUid: 'u_peer',
              peerName: 'Peer',
              callType: CallType.audio,
              direction: CallDirection.incoming,
            ),
          ),
          isTrue,
        );

        expect(
          shouldContinueRoomSetup(
            currentRoom: null,
            roomId: 'room_guard_01',
            storeState: const CallSessionState(
              status: CallLifecycleStatus.ended,
              roomId: 'room_guard_01',
              peerUid: 'u_peer',
              peerName: 'Peer',
              callType: CallType.audio,
              direction: CallDirection.incoming,
            ),
          ),
          isFalse,
        );
      },
    );

    test(
      'resolved accepted UI state keeps connected once buffered replay already connected',
      () {
        expect(
          resolveAcceptedIncomingUiState(CallState.connected),
          CallState.connected,
        );
        expect(
          resolveAcceptedIncomingUiState(CallState.calling),
          CallState.ringing,
        );
      },
    );

    test(
      'accept incoming call refuses a room that is no longer active',
      () async {
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        final service = VideoCallService(
          callStore: store,
          currentUidReader: () => 'u_self',
        );
        addTearDown(service.dispose);

        final room = CallRoom(
          roomId: 'room_dead_01',
          callerUid: 'u_peer',
          calleeUid: 'u_self',
          callType: CallType.audio,
          status: CallRoomStatus.canceled,
          callerName: 'Peer',
        );

        await expectLater(
          () => service.acceptIncomingCall(
            room: room,
            callType: room.callType,
            onStateChanged: (_) {},
            onRemoteStream: (_) {},
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}

class _FakeCallSessionOrchestrator implements CallSessionOrchestrator {
  int startOutgoingCalls = 0;
  String? lastCalleeUid;

  @override
  CallSessionState get state => const CallSessionState(
    status: CallLifecycleStatus.ringing,
    roomId: 'room_session_01',
    peerUid: 'u_peer',
    peerName: 'Peer',
    callType: CallType.video,
    direction: CallDirection.outgoing,
  );

  @override
  Stream<CallSessionState> get stream => const Stream<CallSessionState>.empty();

  @override
  Future<void> acceptIncoming({required CallRoom room}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<void> startOutgoing({
    required String calleeUid,
    required String calleeName,
    required CallType callType,
  }) async {
    startOutgoingCalls += 1;
    lastCalleeUid = calleeUid;
  }

  @override
  Future<void> startGroupOutgoing({
    required String channelId,
    required int channelType,
    required String channelName,
    required List<CallParticipant> participants,
    required CallType callType,
  }) async {}
}
