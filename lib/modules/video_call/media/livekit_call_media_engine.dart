import 'package:livekit_client/livekit_client.dart';

import 'call_media_engine.dart';

typedef LiveKitRoomFactory = LiveKitRoomHandle Function();

abstract interface class LiveKitRoomHandle {
  bool get isConnected;

  Object? get session;

  Future<void> connect(String url, String token, {RoomOptions? roomOptions});

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> setCameraEnabled(bool enabled);

  Future<Map<String, dynamic>> collectStats();

  Future<void> disconnect();
}

class LiveKitCallMediaEngine implements CallMediaEngine {
  LiveKitCallMediaEngine({
    LiveKitRoomFactory? roomFactory,
    RoomOptions roomOptions = const RoomOptions(
      adaptiveStream: true,
      dynacast: true,
    ),
  }) : _roomFactory = roomFactory ?? _defaultRoomFactory,
       _roomOptions = roomOptions;

  final LiveKitRoomFactory _roomFactory;
  final RoomOptions _roomOptions;

  LiveKitRoomHandle? _room;

  @override
  bool get isConnected => _room?.isConnected ?? false;

  @override
  Object? get session => _room?.session;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required bool enableVideo,
  }) async {
    await disconnect();

    final room = _roomFactory();
    try {
      await room.connect(url, token, roomOptions: _roomOptions);
      await room.setMicrophoneEnabled(true);
      if (enableVideo) {
        await room.setCameraEnabled(true);
      }
    } catch (_) {
      await room.disconnect();
      rethrow;
    }

    _room = room;
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    await _room?.setCameraEnabled(enabled);
  }

  @override
  Future<Map<String, dynamic>> collectStats() async {
    final room = _room;
    if (room == null || !room.isConnected) {
      return _zeroStatsSnapshot();
    }
    return room.collectStats();
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    await room?.disconnect();
  }

  static LiveKitRoomHandle _defaultRoomFactory() {
    return _LiveKitRoomAdapter();
  }
}

class _LiveKitRoomAdapter implements LiveKitRoomHandle {
  Room? _room;

  @override
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  @override
  Object? get session => _room;

  @override
  Future<void> connect(
    String url,
    String token, {
    RoomOptions? roomOptions,
  }) async {
    final room = Room(roomOptions: roomOptions ?? const RoomOptions());
    _room = room;
    try {
      await room.connect(url, token);
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    await room?.disconnect();
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    await _room?.localParticipant?.setCameraEnabled(enabled);
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    await _room?.localParticipant?.setMicrophoneEnabled(enabled);
  }

  @override
  Future<Map<String, dynamic>> collectStats() async {
    final room = _room;
    if (room == null || room.connectionState != ConnectionState.connected) {
      return _zeroStatsSnapshot();
    }

    final publishBitrate = _sumTrackBitrate(
      room.localParticipant?.trackPublications.values ?? const <dynamic>[],
    );
    final subscribeBitrate = _sumTrackBitrate(
      room.remoteParticipants.values.expand(
        (participant) => participant.trackPublications.values,
      ),
    );

    return <String, dynamic>{
      'connected': true,
      'publish_bitrate': publishBitrate,
      'subscribe_bitrate': subscribeBitrate,
      'participant_count':
          room.remoteParticipants.length +
          (room.localParticipant == null ? 0 : 1),
    };
  }
}

Map<String, dynamic> _zeroStatsSnapshot() {
  return <String, dynamic>{
    'connected': false,
    'publish_bitrate': 0,
    'subscribe_bitrate': 0,
    'participant_count': 0,
  };
}

int _sumTrackBitrate(Iterable<dynamic> publications) {
  var total = 0;
  for (final publication in publications) {
    final dynamic currentBitrate = publication.track?.currentBitrate;
    if (currentBitrate is num) {
      total += currentBitrate.toInt();
    }
  }
  return total;
}
