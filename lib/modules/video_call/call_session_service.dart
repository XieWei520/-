import '../../data/models/call.dart';
import '../../realtime/call/call_state_machine.dart';
import '../../realtime/call/call_store.dart';
import 'domain/call_bootstrap_models.dart';
import 'infrastructure/call_bootstrap_api.dart';
import 'infrastructure/call_realtime_client.dart';
import 'infrastructure/call_realtime_client_factory.dart';
import 'media/call_media_engine.dart';
import 'media/livekit_call_media_engine.dart';

typedef CallCapabilitiesResolver =
    CallMediaCapabilities Function(CallType callType);

CallSessionOrchestrator createDefaultCallSessionOrchestrator({
  required CallStore store,
}) {
  return CallSessionService(
    store: store,
    bootstrapApi: CallBootstrapApi(),
    realtimeClient: createPlatformCallRealtimeClient(),
    mediaEngine: LiveKitCallMediaEngine(),
  );
}

class CallQualitySample {
  const CallQualitySample({
    required this.roomId,
    required this.mediaStats,
    this.failureReason,
  });

  final String roomId;
  final Map<String, dynamic> mediaStats;
  final String? failureReason;
}

abstract interface class CallSessionOrchestrator {
  CallSessionState get state;

  Stream<CallSessionState> get stream;

  Future<void> startOutgoing({
    required String calleeUid,
    required String calleeName,
    required CallType callType,
  });

  Future<void> startGroupOutgoing({
    required String channelId,
    required int channelType,
    required String channelName,
    required List<CallParticipant> participants,
    required CallType callType,
  });

  Future<void> acceptIncoming({required CallRoom room});

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<void> disconnect();
}

class CallSessionService implements CallSessionOrchestrator {
  CallSessionService({
    required CallStore store,
    required CallBootstrapApi bootstrapApi,
    required CallRealtimeClient realtimeClient,
    required CallMediaEngine mediaEngine,
    CallCapabilitiesResolver? capabilitiesResolver,
  }) : _store = store,
       _bootstrapApi = bootstrapApi,
       _realtimeClient = realtimeClient,
       _mediaEngine = mediaEngine,
       _capabilitiesResolver =
           capabilitiesResolver ?? _defaultCapabilitiesResolver;

  factory CallSessionService.test() => CallSessionService(
    store: CallStore(machine: const CallStateMachine()),
    bootstrapApi: _TestCallBootstrapApi(),
    realtimeClient: _TestCallRealtimeClient(),
    mediaEngine: _TestCallMediaEngine(),
  );

  final CallStore _store;
  final CallBootstrapApi _bootstrapApi;
  final CallRealtimeClient _realtimeClient;
  final CallMediaEngine _mediaEngine;
  final CallCapabilitiesResolver _capabilitiesResolver;
  CallQualitySample? _lastQualitySample;

  CallQualitySample? get lastQualitySample => _lastQualitySample;

  @override
  CallSessionState get state => _store.state;

  @override
  Stream<CallSessionState> get stream => _store.stream;

  @override
  Future<void> startOutgoing({
    required String calleeUid,
    required String calleeName,
    required CallType callType,
  }) async {
    final bootstrap = await _bootstrapApi.createRoom(
      calleeUid: calleeUid,
      calleeName: calleeName,
      callType: callType,
      capabilities: _capabilitiesResolver(callType),
    );

    _store.apply(
      CallEvent.localDial(
        roomId: bootstrap.room.roomId,
        peerUid: calleeUid,
        peerName: calleeName,
        callType: callType,
      ),
    );

    await _connectBootstrap(
      bootstrap: bootstrap,
      enableVideo: callType == CallType.video,
    );
  }

  @override
  Future<void> startGroupOutgoing({
    required String channelId,
    required int channelType,
    required String channelName,
    required List<CallParticipant> participants,
    required CallType callType,
  }) async {
    if (participants.isEmpty) {
      throw ArgumentError.value(
        participants,
        'participants',
        'must not be empty',
      );
    }
    final bootstrap = await _bootstrapApi.createRoom(
      calleeUid: '',
      calleeName: '',
      callType: callType,
      capabilities: _capabilitiesResolver(callType),
      roomName: channelName,
      channelId: channelId,
      channelType: channelType,
      participants: participants,
    );

    _store.apply(
      CallEvent.localDial(
        roomId: bootstrap.room.roomId,
        peerUid: channelId,
        peerName: channelName,
        callType: callType,
      ),
    );

    await _connectBootstrap(
      bootstrap: bootstrap,
      enableVideo: callType == CallType.video,
    );
  }

  @override
  Future<void> acceptIncoming({required CallRoom room}) async {
    final accepted = _store.apply(CallEvent.localAccept(roomId: room.roomId));
    if (!accepted) {
      throw StateError('Call session is no longer active.');
    }

    final bootstrap = await _bootstrapApi.getSession(
      roomId: room.roomId,
      capabilities: _capabilitiesResolver(room.callType),
    );

    await _connectBootstrap(
      bootstrap: bootstrap,
      enableVideo: room.callType == CallType.video,
    );
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) {
    return _mediaEngine.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) {
    return _mediaEngine.setCameraEnabled(enabled);
  }

  @override
  Future<void> disconnect() async {
    await _mediaEngine.disconnect();
    await _realtimeClient.disconnect();
    _lastQualitySample = null;
    _store.reset();
  }

  Future<void> _connectBootstrap({
    required CallBootstrap bootstrap,
    required bool enableVideo,
  }) async {
    final roomId = bootstrap.room.roomId;
    try {
      await _realtimeClient.connect(
        uri: buildCallRealtimeUri(
          controlUrl: bootstrap.join.controlUrl,
          ticket: bootstrap.ticket.token,
          roomId: roomId,
        ),
      );
      await _mediaEngine.connect(
        url: bootstrap.join.livekitUrl,
        token: bootstrap.ticket.token,
        enableVideo: enableVideo,
      );
      _lastQualitySample = CallQualitySample(
        roomId: roomId,
        mediaStats: await _captureQualityStats(),
      );
    } catch (error) {
      _lastQualitySample = CallQualitySample(
        roomId: roomId,
        mediaStats: _qualityStatsSnapshot(),
        failureReason: error.toString(),
      );
      await _mediaEngine.disconnect();
      await _realtimeClient.disconnect();
      _store.reset();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _captureQualityStats() async {
    try {
      return _normalizeQualityStats(
        await _mediaEngine.collectStats(),
        connected: _mediaEngine.isConnected,
      );
    } catch (_) {
      return _qualityStatsSnapshot(connected: _mediaEngine.isConnected);
    }
  }

  Map<String, dynamic> _normalizeQualityStats(
    Map<String, dynamic> rawStats, {
    required bool connected,
  }) {
    final stats = _qualityStatsSnapshot(connected: connected);
    final publishBitrate = rawStats['publish_bitrate'];
    final subscribeBitrate = rawStats['subscribe_bitrate'];
    final participantCount = rawStats['participant_count'];
    final rawConnected = rawStats['connected'];

    if (publishBitrate is num) {
      stats['publish_bitrate'] = publishBitrate.toInt();
    }
    if (subscribeBitrate is num) {
      stats['subscribe_bitrate'] = subscribeBitrate.toInt();
    }
    if (participantCount is num) {
      stats['participant_count'] = participantCount.toInt();
    }
    if (rawConnected is bool) {
      stats['connected'] = rawConnected;
    }

    return stats;
  }

  Map<String, dynamic> _qualityStatsSnapshot({bool connected = false}) {
    return <String, dynamic>{
      'connected': connected,
      'publish_bitrate': 0,
      'subscribe_bitrate': 0,
      'participant_count': 0,
    };
  }

  static CallMediaCapabilities _defaultCapabilitiesResolver(CallType callType) {
    return CallMediaCapabilities(
      platform: 'io',
      supportsVideo: callType == CallType.video,
      supportsAudio: true,
      prefersAudio: callType == CallType.audio,
      isSafari: false,
      isMobileWeb: false,
    );
  }
}

class _TestCallBootstrapApi implements CallBootstrapApi {
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
    return _bootstrap(
      roomId: 'room_test_01',
      calleeUid: calleeUid,
      calleeName: calleeName,
      callType: callType,
      capabilities: capabilities,
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
    return _bootstrap(
      roomId: roomId,
      calleeUid: 'u_self',
      calleeName: 'Self',
      callType: capabilities.prefersAudio ? CallType.audio : CallType.video,
      capabilities: capabilities,
    );
  }

  CallBootstrap _bootstrap({
    required String roomId,
    required String calleeUid,
    required String calleeName,
    required CallType callType,
    required CallMediaCapabilities capabilities,
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
      ticket: CallSessionTicket(
        token: 'test-ticket',
        expiresAt: 1711111111,
        roomId: roomId,
        participant: 'u_self',
      ),
      join: CallJoinDescriptor(
        controlUrl: 'wss://infoequity.cn/v1/callgateway/ws',
        livekitUrl: 'wss://infoequity.cn/livekit',
        roomName: roomId,
      ),
      capabilities: capabilities,
    );
  }
}

class _TestCallRealtimeClient implements CallRealtimeClient {
  @override
  Stream<CallControlEvent> get events => const Stream<CallControlEvent>.empty();

  @override
  Future<void> connect({
    required Uri uri,
    Map<String, String>? headers,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(CallControlEvent event) async {}
}

class _TestCallMediaEngine implements CallMediaEngine {
  @override
  bool get isConnected => false;

  @override
  Object? get session => null;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required bool enableVideo,
  }) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> setCameraEnabled(bool enabled) async {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {}

  @override
  Future<Map<String, dynamic>> collectStats() async {
    return const <String, dynamic>{
      'connected': false,
      'publish_bitrate': 0,
      'subscribe_bitrate': 0,
    };
  }
}
