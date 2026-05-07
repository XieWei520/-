import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/call.dart';
import 'package:wukong_im_app/modules/video_call/call_session_service.dart';
import 'package:wukong_im_app/modules/video_call/domain/call_bootstrap_models.dart';
import 'package:wukong_im_app/modules/video_call/infrastructure/call_bootstrap_api.dart';
import 'package:wukong_im_app/modules/video_call/infrastructure/call_realtime_client.dart';
import 'package:wukong_im_app/modules/video_call/media/call_media_engine.dart';
import 'package:wukong_im_app/realtime/call/call_state_machine.dart';
import 'package:wukong_im_app/realtime/call/call_store.dart';

void main() {
  group('CallSessionService', () {
    test('startOutgoing bootstraps control and media layers', () async {
      final bootstrapApi = _FakeCallBootstrapApi();
      final realtimeClient = _FakeCallRealtimeClient();
      final mediaEngine = _FakeCallMediaEngine();
      final store = CallStore(machine: const CallStateMachine());
      addTearDown(store.dispose);

      final service = CallSessionService(
        store: store,
        bootstrapApi: bootstrapApi,
        realtimeClient: realtimeClient,
        mediaEngine: mediaEngine,
      );

      await service.startOutgoing(
        calleeUid: 'u_peer',
        calleeName: 'Peer',
        callType: CallType.video,
      );

      expect(bootstrapApi.createRoomCalls, 1);
      expect(bootstrapApi.lastCreateCalleeUid, 'u_peer');
      expect(
        realtimeClient.connectedUri?.toString(),
        contains('ticket=test-ticket'),
      );
      expect(
        realtimeClient.connectedUri?.toString(),
        contains('room_id=room_test_01'),
      );
      expect(mediaEngine.connectedUrl, 'wss://infoequity.cn/livekit');
      expect(mediaEngine.connectedToken, 'test-ticket');
      expect(mediaEngine.connectedEnableVideo, isTrue);
      expect(service.state.roomId, 'room_test_01');
      expect(service.state.status, CallLifecycleStatus.connected);
      expect(service.lastQualitySample?.roomId, 'room_test_01');
      expect(service.lastQualitySample?.failureReason, isNull);
      expect(service.lastQualitySample?.mediaStats['publish_bitrate'], 128000);
    });

    test(
      'acceptIncoming fetches participant session and connects in audio mode',
      () async {
        final bootstrapApi = _FakeCallBootstrapApi();
        final realtimeClient = _FakeCallRealtimeClient();
        final mediaEngine = _FakeCallMediaEngine();
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        store.apply(
          const CallEvent.invite(
            roomId: 'room_test_02',
            peerUid: 'u_peer',
            peerName: 'Peer',
            callType: CallType.audio,
          ),
        );

        final service = CallSessionService(
          store: store,
          bootstrapApi: bootstrapApi,
          realtimeClient: realtimeClient,
          mediaEngine: mediaEngine,
        );

        await service.acceptIncoming(
          room: CallRoom(
            roomId: 'room_test_02',
            callerUid: 'u_peer',
            callerName: 'Peer',
            calleeUid: 'u_self',
            callType: CallType.audio,
            status: CallRoomStatus.pending,
          ),
        );

        expect(bootstrapApi.getSessionCalls, 1);
        expect(bootstrapApi.lastSessionRoomId, 'room_test_02');
        expect(mediaEngine.connectedEnableVideo, isFalse);
        expect(service.state.roomId, 'room_test_02');
        expect(service.state.status, CallLifecycleStatus.connected);
        expect(service.lastQualitySample?.roomId, 'room_test_02');
        expect(service.lastQualitySample?.failureReason, isNull);
      },
    );

    test('records failure telemetry when media connection fails', () async {
      final bootstrapApi = _FakeCallBootstrapApi();
      final realtimeClient = _FakeCallRealtimeClient();
      final mediaEngine = _FakeCallMediaEngine(
        connectError: StateError('boom'),
      );
      final store = CallStore(machine: const CallStateMachine());
      addTearDown(store.dispose);

      final service = CallSessionService(
        store: store,
        bootstrapApi: bootstrapApi,
        realtimeClient: realtimeClient,
        mediaEngine: mediaEngine,
      );

      await expectLater(
        service.startOutgoing(
          calleeUid: 'u_peer',
          calleeName: 'Peer',
          callType: CallType.video,
        ),
        throwsA(isA<StateError>()),
      );

      expect(service.lastQualitySample?.roomId, 'room_test_01');
      expect(service.lastQualitySample?.failureReason, contains('boom'));
      expect(service.lastQualitySample?.mediaStats['connected'], isFalse);
      expect(service.lastQualitySample?.mediaStats['publish_bitrate'], 0);
      expect(service.lastQualitySample?.mediaStats['subscribe_bitrate'], 0);
      expect(service.lastQualitySample?.mediaStats['participant_count'], 0);
      expect(service.state, const CallSessionState.idle());
    });

    test('disconnect clears the last quality sample', () async {
      final bootstrapApi = _FakeCallBootstrapApi();
      final realtimeClient = _FakeCallRealtimeClient();
      final mediaEngine = _FakeCallMediaEngine();
      final store = CallStore(machine: const CallStateMachine());
      addTearDown(store.dispose);

      final service = CallSessionService(
        store: store,
        bootstrapApi: bootstrapApi,
        realtimeClient: realtimeClient,
        mediaEngine: mediaEngine,
      );

      await service.startOutgoing(
        calleeUid: 'u_peer',
        calleeName: 'Peer',
        callType: CallType.video,
      );
      await service.disconnect();

      expect(service.lastQualitySample, isNull);
      expect(service.state, const CallSessionState.idle());
    });

    test(
      'startGroupOutgoing bootstraps control and media for group rooms',
      () async {
        final bootstrapApi = _FakeCallBootstrapApi();
        final realtimeClient = _FakeCallRealtimeClient();
        final mediaEngine = _FakeCallMediaEngine();
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        final service = CallSessionService(
          store: store,
          bootstrapApi: bootstrapApi,
          realtimeClient: realtimeClient,
          mediaEngine: mediaEngine,
        );

        await service.startGroupOutgoing(
          channelId: 'g_demo',
          channelType: 2,
          channelName: '研发群',
          participants: const <CallParticipant>[
            CallParticipant(
              uid: 'u_alice',
              name: 'Alice',
              role: 1,
              inviteStatus: 0,
            ),
            CallParticipant(
              uid: 'u_bob',
              name: 'Bob',
              role: 1,
              inviteStatus: 0,
            ),
          ],
          callType: CallType.video,
        );

        expect(bootstrapApi.createRoomCalls, 1);
        expect(bootstrapApi.lastCreateRoomName, '研发群');
        expect(bootstrapApi.lastCreateChannelId, 'g_demo');
        expect(bootstrapApi.lastCreateChannelType, 2);
        expect(
          bootstrapApi.lastCreateParticipants.map((item) => item.uid),
          <String>['u_alice', 'u_bob'],
        );
        expect(service.state.roomId, 'room_test_01');
        expect(service.state.status, CallLifecycleStatus.connected);
        expect(service.state.peerUid, 'g_demo');
        expect(service.state.peerName, '研发群');
        expect(mediaEngine.connectedEnableVideo, isTrue);
      },
    );

    test(
      'stats collection failure does not fail the connected session',
      () async {
        final bootstrapApi = _FakeCallBootstrapApi();
        final realtimeClient = _FakeCallRealtimeClient();
        final mediaEngine = _FakeCallMediaEngine(
          statsError: StateError('stats'),
        );
        final store = CallStore(machine: const CallStateMachine());
        addTearDown(store.dispose);

        final service = CallSessionService(
          store: store,
          bootstrapApi: bootstrapApi,
          realtimeClient: realtimeClient,
          mediaEngine: mediaEngine,
        );

        await service.startOutgoing(
          calleeUid: 'u_peer',
          calleeName: 'Peer',
          callType: CallType.video,
        );

        expect(service.state.roomId, 'room_test_01');
        expect(service.state.status, CallLifecycleStatus.connected);
        expect(service.lastQualitySample?.failureReason, isNull);
        expect(service.lastQualitySample?.mediaStats['connected'], isTrue);
        expect(service.lastQualitySample?.mediaStats['publish_bitrate'], 0);
        expect(service.lastQualitySample?.mediaStats['subscribe_bitrate'], 0);
        expect(service.lastQualitySample?.mediaStats['participant_count'], 0);
      },
    );
  });
}

class _FakeCallBootstrapApi implements CallBootstrapApi {
  int createRoomCalls = 0;
  int getSessionCalls = 0;
  String? lastCreateCalleeUid;
  String? lastCreateRoomName;
  String? lastCreateChannelId;
  int? lastCreateChannelType;
  List<CallParticipant> lastCreateParticipants = const <CallParticipant>[];
  String? lastSessionRoomId;

  @override
  Future<CallBootstrap> createRoom({
    required String calleeUid,
    required String calleeName,
    required CallType callType,
    required CallMediaCapabilities capabilities,
    String? roomName,
    String? channelId,
    int? channelType,
    List<CallParticipant> participants = const <CallParticipant>[],
  }) async {
    createRoomCalls += 1;
    lastCreateCalleeUid = calleeUid;
    lastCreateRoomName = roomName;
    lastCreateChannelId = channelId;
    lastCreateChannelType = channelType;
    lastCreateParticipants = participants;
    return _bootstrap(
      roomId: 'room_test_01',
      calleeUid: calleeUid,
      calleeName: calleeName,
      callType: callType,
      roomName: roomName,
      channelId: channelId,
      channelType: channelType,
      participants: participants,
    );
  }

  @override
  Future<CallBootstrap> getSession({
    required String roomId,
    required CallMediaCapabilities capabilities,
  }) async {
    getSessionCalls += 1;
    lastSessionRoomId = roomId;
    return _bootstrap(
      roomId: roomId,
      calleeUid: 'u_self',
      calleeName: 'Self',
      callType: CallType.audio,
    );
  }

  CallBootstrap _bootstrap({
    required String roomId,
    required String calleeUid,
    required String calleeName,
    required CallType callType,
    String? roomName,
    String? channelId,
    int? channelType,
    List<CallParticipant> participants = const <CallParticipant>[],
  }) {
    return CallBootstrap(
      room: CallRoom(
        roomId: roomId,
        callerUid: 'u_self',
        calleeUid: calleeUid,
        callType: callType,
        status: CallRoomStatus.pending,
        roomName: roomName,
        channelId: channelId,
        channelType: channelType,
        participants: participants,
        calleeName: calleeName,
      ),
      ticket: const CallSessionTicket(
        token: 'test-ticket',
        expiresAt: 1711111111,
        roomId: 'room_test_01',
        participant: 'u_self',
      ),
      join: CallJoinDescriptor(
        controlUrl: 'wss://infoequity.cn/v1/callgateway/ws',
        livekitUrl: 'wss://infoequity.cn/livekit',
        roomName: roomId,
      ),
      capabilities: const CallMediaCapabilities(
        platform: 'io',
        supportsVideo: true,
        supportsAudio: true,
        prefersAudio: false,
        isSafari: false,
        isMobileWeb: false,
      ),
    );
  }
}

class _FakeCallRealtimeClient implements CallRealtimeClient {
  Uri? connectedUri;

  @override
  Stream<CallControlEvent> get events => const Stream<CallControlEvent>.empty();

  @override
  Future<void> connect({required Uri uri, Map<String, String>? headers}) async {
    connectedUri = uri;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(CallControlEvent event) async {}
}

class _FakeCallMediaEngine implements CallMediaEngine {
  _FakeCallMediaEngine({this.connectError, this.statsError});

  final Object? connectError;
  final Object? statsError;
  String? connectedUrl;
  String? connectedToken;
  bool? connectedEnableVideo;

  @override
  bool get isConnected => connectedUrl != null;

  @override
  Stream<CallMediaConnectionState> get connectionStates =>
      const Stream<CallMediaConnectionState>.empty();

  @override
  Object? get session => null;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required bool enableVideo,
  }) async {
    if (connectError != null) {
      throw connectError!;
    }
    connectedUrl = url;
    connectedToken = token;
    connectedEnableVideo = enableVideo;
  }

  @override
  Future<Map<String, dynamic>> collectStats() async {
    if (statsError != null) {
      throw statsError!;
    }
    return <String, dynamic>{
      'publish_bitrate': 128000,
      'subscribe_bitrate': 256000,
      'connected': connectedUrl != null,
      'participant_count': connectedUrl == null ? 0 : 2,
    };
  }

  @override
  Future<void> disconnect() async {
    connectedUrl = null;
    connectedToken = null;
    connectedEnableVideo = null;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}
}
