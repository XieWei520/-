import 'dart:async';

import 'package:livekit_client/livekit_client.dart';

import 'call_media_engine.dart';

typedef LiveKitRoomFactory = LiveKitRoomHandle Function();

abstract interface class LiveKitRoomHandle {
  bool get isConnected;

  Object? get session;

  Stream<CallMediaConnectionState> get connectionStates;

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
  final StreamController<CallMediaConnectionState> _connectionStateController =
      StreamController<CallMediaConnectionState>.broadcast();

  LiveKitRoomHandle? _room;
  StreamSubscription<CallMediaConnectionState>? _roomStateSubscription;
  CallMediaConnectionState? _lastConnectionState;

  @override
  bool get isConnected => _room?.isConnected ?? false;

  @override
  Stream<CallMediaConnectionState> get connectionStates =>
      _connectionStateController.stream;

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
    _emitConnectionState(CallMediaConnectionState.connecting);
    _roomStateSubscription = room.connectionStates.listen(_emitConnectionState);
    try {
      await room.connect(url, token, roomOptions: _roomOptions);
      _room = room;
      _emitConnectionState(CallMediaConnectionState.connected);
      await room.setMicrophoneEnabled(true);
      if (enableVideo) {
        await room.setCameraEnabled(true);
      }
    } catch (_) {
      _emitConnectionState(CallMediaConnectionState.failed);
      await _roomStateSubscription?.cancel();
      _roomStateSubscription = null;
      await room.disconnect();
      rethrow;
    }
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
    await _roomStateSubscription?.cancel();
    _roomStateSubscription = null;
    await room?.disconnect();
    if (room != null) {
      _emitConnectionState(CallMediaConnectionState.disconnected);
    }
  }

  void _emitConnectionState(CallMediaConnectionState state) {
    if (_connectionStateController.isClosed || _lastConnectionState == state) {
      return;
    }
    _lastConnectionState = state;
    _connectionStateController.add(state);
  }

  static LiveKitRoomHandle _defaultRoomFactory() {
    return _LiveKitRoomAdapter();
  }
}

class _LiveKitRoomAdapter implements LiveKitRoomHandle {
  final StreamController<CallMediaConnectionState> _connectionStateController =
      StreamController<CallMediaConnectionState>.broadcast();

  Room? _room;
  CancelListenFunc? _cancelRoomEvents;
  CallMediaConnectionState? _lastConnectionState;

  @override
  bool get isConnected => _room?.connectionState == ConnectionState.connected;

  @override
  Object? get session => _room;

  @override
  Stream<CallMediaConnectionState> get connectionStates =>
      _connectionStateController.stream;

  @override
  Future<void> connect(
    String url,
    String token, {
    RoomOptions? roomOptions,
  }) async {
    final room = Room(roomOptions: roomOptions ?? const RoomOptions());
    _room = room;
    _bindRoomEvents(room);
    try {
      await room.connect(url, token);
    } catch (_) {
      _emitConnectionState(CallMediaConnectionState.failed);
      await disconnect();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    _room = null;
    final cancelRoomEvents = _cancelRoomEvents;
    _cancelRoomEvents = null;
    await cancelRoomEvents?.call();
    await room?.disconnect();
    if (room != null) {
      _emitConnectionState(CallMediaConnectionState.disconnected);
    }
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

  void _bindRoomEvents(Room room) {
    _cancelRoomEvents = room.events.listen((event) {
      if (event is RoomConnectedEvent || event is RoomReconnectedEvent) {
        _emitConnectionState(CallMediaConnectionState.connected);
        return;
      }
      if (event is RoomReconnectingEvent) {
        _emitConnectionState(CallMediaConnectionState.reconnecting);
        return;
      }
      if (event is RoomDisconnectedEvent) {
        _emitConnectionState(CallMediaConnectionState.disconnected);
      }
    });
  }

  void _emitConnectionState(CallMediaConnectionState state) {
    if (_connectionStateController.isClosed || _lastConnectionState == state) {
      return;
    }
    _lastConnectionState = state;
    _connectionStateController.add(state);
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
