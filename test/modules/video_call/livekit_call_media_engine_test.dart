import 'package:flutter_test/flutter_test.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wukong_im_app/modules/video_call/media/livekit_call_media_engine.dart';

void main() {
  group('LiveKitCallMediaEngine', () {
    test(
      'connect joins room and enables microphone and camera for video',
      () async {
        final room = _FakeLiveKitRoomHandle();
        final engine = LiveKitCallMediaEngine(roomFactory: () => room);

        await engine.connect(
          url: 'wss://infoequity.qingyunshe.top/livekit',
          token: 'lk-token',
          enableVideo: true,
        );

        expect(room.connectCalls, 1);
        expect(room.connectedUrl, 'wss://infoequity.qingyunshe.top/livekit');
        expect(room.connectedToken, 'lk-token');
        expect(room.connectedRoomOptions, isNotNull);
        expect(room.connectedRoomOptions!.adaptiveStream, isTrue);
        expect(room.connectedRoomOptions!.dynacast, isTrue);
        expect(room.microphoneStates, <bool>[true]);
        expect(room.cameraStates, <bool>[true]);
        expect(engine.isConnected, isTrue);
      },
    );

    test('connect keeps camera disabled for audio-first sessions', () async {
      final room = _FakeLiveKitRoomHandle();
      final engine = LiveKitCallMediaEngine(roomFactory: () => room);

      await engine.connect(
        url: 'wss://infoequity.qingyunshe.top/livekit',
        token: 'lk-token',
        enableVideo: false,
      );

      expect(room.microphoneStates, <bool>[true]);
      expect(room.cameraStates, isEmpty);
    });

    test('toggle methods and disconnect forward to the active room', () async {
      final room = _FakeLiveKitRoomHandle();
      final engine = LiveKitCallMediaEngine(roomFactory: () => room);

      await engine.connect(
        url: 'wss://infoequity.qingyunshe.top/livekit',
        token: 'lk-token',
        enableVideo: true,
      );
      await engine.setMicrophoneEnabled(false);
      await engine.setCameraEnabled(false);
      await engine.disconnect();

      expect(room.microphoneStates, <bool>[true, false]);
      expect(room.cameraStates, <bool>[true, false]);
      expect(room.disconnectCalls, 1);
      expect(engine.isConnected, isFalse);
    });

    test(
      'connect failure disconnects the room and keeps engine disconnected',
      () async {
        final room = _FakeLiveKitRoomHandle(connectError: StateError('boom'));
        final engine = LiveKitCallMediaEngine(roomFactory: () => room);

        await expectLater(
          engine.connect(
            url: 'wss://infoequity.qingyunshe.top/livekit',
            token: 'lk-token',
            enableVideo: true,
          ),
          throwsA(isA<StateError>()),
        );

        expect(room.disconnectCalls, 1);
        expect(engine.isConnected, isFalse);
      },
    );

    test('isConnected mirrors the underlying room handle state', () async {
      final room = _FakeLiveKitRoomHandle();
      final engine = LiveKitCallMediaEngine(roomFactory: () => room);

      await engine.connect(
        url: 'wss://infoequity.qingyunshe.top/livekit',
        token: 'lk-token',
        enableVideo: true,
      );
      room.setConnected(false);

      expect(engine.isConnected, isFalse);
    });

    test('collectStats returns the room snapshot when connected', () async {
      final room = _FakeLiveKitRoomHandle(
        stats: <String, dynamic>{
          'publish_bitrate': 128000,
          'subscribe_bitrate': 256000,
          'participant_count': 2,
        },
      );
      final engine = LiveKitCallMediaEngine(roomFactory: () => room);

      await engine.connect(
        url: 'wss://infoequity.qingyunshe.top/livekit',
        token: 'lk-token',
        enableVideo: true,
      );

      final stats = await engine.collectStats();

      expect(stats['publish_bitrate'], 128000);
      expect(stats['subscribe_bitrate'], 256000);
      expect(stats['participant_count'], 2);
    });

    test('collectStats returns a zeroed snapshot when disconnected', () async {
      final room = _FakeLiveKitRoomHandle();
      final engine = LiveKitCallMediaEngine(roomFactory: () => room);

      final stats = await engine.collectStats();

      expect(stats['connected'], isFalse);
      expect(stats['publish_bitrate'], 0);
      expect(stats['subscribe_bitrate'], 0);
    });
  });
}

class _FakeLiveKitRoomHandle implements LiveKitRoomHandle {
  _FakeLiveKitRoomHandle({
    this.connectError,
    this.stats = const <String, dynamic>{},
  });

  final Object? connectError;
  final Map<String, dynamic> stats;
  int connectCalls = 0;
  int disconnectCalls = 0;
  bool _connected = false;
  String? connectedUrl;
  String? connectedToken;
  RoomOptions? connectedRoomOptions;
  final List<bool> microphoneStates = <bool>[];
  final List<bool> cameraStates = <bool>[];

  @override
  Object? get session => null;

  @override
  bool get isConnected => _connected;

  void setConnected(bool value) {
    _connected = value;
  }

  @override
  Future<void> connect(
    String url,
    String token, {
    RoomOptions? roomOptions,
  }) async {
    connectCalls += 1;
    connectedUrl = url;
    connectedToken = token;
    connectedRoomOptions = roomOptions;
    if (connectError != null) {
      throw connectError!;
    }
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _connected = false;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraStates.add(enabled);
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    microphoneStates.add(enabled);
  }

  @override
  Future<Map<String, dynamic>> collectStats() async {
    return <String, dynamic>{
      'connected': _connected,
      'publish_bitrate': 0,
      'subscribe_bitrate': 0,
      ...stats,
    };
  }
}
