import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/video_call/call_coordinator.dart';
import 'package:wukong_im_app/modules/video_call/rtc_notification_bridge.dart';
import 'package:wukong_im_app/modules/video_call/video_call_service.dart';
import 'package:wukong_im_app/realtime/call/call_state_machine.dart';
import 'package:wukong_im_app/realtime/call/call_store.dart';
import 'package:wukong_im_app/realtime/session/session_event_frame.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'rtc notification bridge registers legacy endpoints and shows/cancels',
    () async {
      final adapter = _FakeRtcNotificationAdapter();
      final bridge = RtcNotificationBridge(adapter: adapter);
      final endpointManager = EndpointManager.getInstance();
      endpointManager.clear();
      addTearDown(endpointManager.clear);

      bridge.registerEndpoints(endpointManager: endpointManager);

      await endpointManager.invoke('show_rtc_notification', <String, dynamic>{
        'from_uid': 'u_peer',
        'from_name': 'Peer',
        'call_type': 1,
      });
      await endpointManager.invoke('cancel_rtc_notification');

      expect(adapter.showRequests, hasLength(1));
      expect(adapter.showRequests.single.fromUid, 'u_peer');
      expect(adapter.showRequests.single.fromName, 'Peer');
      expect(adapter.showRequests.single.callType, 1);
      expect(adapter.cancelCount, 1);
    },
  );

  test(
    'call coordinator shows rtc notification in background and cancels it on resume',
    () async {
      final store = CallStore(machine: const CallStateMachine());
      addTearDown(store.dispose);
      final adapter = _FakeRtcNotificationAdapter();
      final bridge = RtcNotificationBridge(adapter: adapter);
      final coordinator = CallCoordinator(
        callStore: store,
        currentUidReader: () => 'u_self',
        rtcNotificationBridge: bridge,
        videoCallService: _FakeVideoCallService(),
      );
      addTearDown(coordinator.stop);

      coordinator.start(GlobalKey<NavigatorState>());
      coordinator.didChangeAppLifecycleState(AppLifecycleState.paused);

      await coordinator.handleSessionFrame(
        const SessionEventFrame(
          eventId: 'evt_rtc_invite_01',
          userSeq: 1,
          serverTs: 1712000001,
          kind: 'call.invite',
          aggregateId: 'room_rtc_01',
          payload: <String, dynamic>{
            'room_id': 'room_rtc_01',
            'caller_uid': 'u_peer',
            'caller_name': 'Peer',
            'callee_uid': 'u_self',
            'call_type': 1,
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(adapter.showRequests, hasLength(1));
      expect(adapter.showRequests.single.fromUid, 'u_peer');
      expect(adapter.cancelCount, 0);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(adapter.cancelCount, 1);
    },
  );

  test(
    'rtc notification bridge tolerates missing plugin adapters during tests',
    () async {
      final bridge = RtcNotificationBridge(
        adapter: _ThrowingRtcNotificationAdapter(),
      );

      await expectLater(
        bridge.showRtcNotification(
          const RtcNotificationRequest(
            fromUid: 'u_peer',
            fromName: 'Peer',
            callType: 1,
          ),
        ),
        completes,
      );
      await expectLater(bridge.cancelRtcNotification(), completes);
    },
  );

  test(
    'rtc notification bridge tolerates late initialization errors from adapters',
    () async {
      final bridge = RtcNotificationBridge(
        adapter: _LateInitRtcNotificationAdapter(),
      );

      await expectLater(
        bridge.showRtcNotification(
          const RtcNotificationRequest(
            fromUid: 'u_peer',
            fromName: 'Peer',
            callType: 1,
          ),
        ),
        completes,
      );
      await expectLater(bridge.cancelRtcNotification(), completes);
    },
  );
}

class _FakeRtcNotificationAdapter implements RtcNotificationAdapter {
  final List<RtcNotificationRequest> showRequests = <RtcNotificationRequest>[];
  int cancelCount = 0;

  @override
  Future<void> cancel(int id) async {
    cancelCount += 1;
  }

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<void> show(RtcNotificationRequest request) async {
    showRequests.add(request);
  }
}

class _FakeVideoCallService extends VideoCallService {
  _FakeVideoCallService()
    : super(
        callStore: CallStore(machine: const CallStateMachine()),
        currentUidReader: () => 'u_self',
      );

  @override
  bool get hasActiveCallOrPendingSetup => false;

  @override
  Future<void> endCall({bool remote = false}) async {}

  @override
  Future<void> rejectIncomingCall(CallRoom room) async {}
}

class _ThrowingRtcNotificationAdapter implements RtcNotificationAdapter {
  @override
  Future<void> cancel(int id) {
    throw MissingPluginException('cancel unavailable');
  }

  @override
  Future<void> ensureInitialized() {
    throw MissingPluginException('init unavailable');
  }

  @override
  Future<void> show(RtcNotificationRequest request) {
    throw MissingPluginException('show unavailable');
  }
}

class _LateInitRtcNotificationAdapter implements RtcNotificationAdapter {
  @override
  Future<void> cancel(int id) async {
    _LateInitHolder().value;
  }

  @override
  Future<void> ensureInitialized() async {
    _LateInitHolder().value;
  }

  @override
  Future<void> show(RtcNotificationRequest request) async {
    _LateInitHolder().value;
  }
}

class _LateInitHolder {
  late final Object value;
}
