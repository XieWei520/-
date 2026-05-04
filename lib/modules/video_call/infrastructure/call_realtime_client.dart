import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

Uri buildCallRealtimeUri({
  required String controlUrl,
  required String ticket,
  required String roomId,
}) {
  final base = Uri.parse(controlUrl);
  final queryParameters = <String, String>{
    ...base.queryParameters,
    'ticket': ticket,
    'room_id': roomId,
  };
  return base.replace(queryParameters: queryParameters);
}

class CallControlEvent {
  const CallControlEvent({
    required this.type,
    required this.roomId,
    this.participant,
    this.targetParticipant,
    this.payload = const <String, dynamic>{},
  });

  final String type;
  final String roomId;
  final String? participant;
  final String? targetParticipant;
  final Map<String, dynamic> payload;

  factory CallControlEvent.fromJson(Map<String, dynamic> json) {
    final payload = <String, dynamic>{
      ..._readPayload(json['payload']),
      ...Map<String, dynamic>.from(json)
        ..remove('type')
        ..remove('room_id')
        ..remove('participant')
        ..remove('target_participant')
        ..remove('payload'),
    };

    return CallControlEvent(
      type: json['type']?.toString() ?? 'unknown',
      roomId: json['room_id']?.toString() ?? '',
      participant: json['participant']?.toString(),
      targetParticipant: json['target_participant']?.toString(),
      payload: payload,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'room_id': roomId,
      if ((participant ?? '').trim().isNotEmpty) 'participant': participant,
      if ((targetParticipant ?? '').trim().isNotEmpty)
        'target_participant': targetParticipant,
      ...payload,
    };
  }
}

String encodeCallControlEvent(CallControlEvent event) {
  return jsonEncode(event.toJson());
}

CallControlEvent decodeCallControlEvent(dynamic raw) {
  final json = _decodeJsonObject(raw);
  return CallControlEvent.fromJson(json);
}

abstract interface class CallRealtimeSocket {
  Stream<Object?> get stream;

  Future<void> ready();

  void add(Object? data);

  Future<void> close([int? code, String? reason]);
}

typedef CallRealtimeSocketConnector =
    CallRealtimeSocket Function(Uri uri, {Map<String, String>? headers});

abstract interface class CallRealtimeClient {
  Stream<CallControlEvent> get events;

  Future<void> connect({required Uri uri, Map<String, String>? headers});

  Future<void> send(CallControlEvent event);

  Future<void> disconnect();
}

class ManagedCallRealtimeClient implements CallRealtimeClient {
  ManagedCallRealtimeClient({required CallRealtimeSocketConnector connect})
    : _connect = connect;

  final CallRealtimeSocketConnector _connect;
  final StreamController<CallControlEvent> _eventsController =
      StreamController<CallControlEvent>.broadcast();

  CallRealtimeSocket? _socket;
  StreamSubscription<Object?>? _subscription;

  @override
  Stream<CallControlEvent> get events => _eventsController.stream;

  @override
  Future<void> connect({required Uri uri, Map<String, String>? headers}) async {
    await disconnect();

    final socket = _connect(uri, headers: headers);
    try {
      await socket.ready();
    } catch (_) {
      await socket.close();
      rethrow;
    }

    _socket = socket;
    _subscription = socket.stream.listen(
      (raw) => _eventsController.add(decodeCallControlEvent(raw)),
      onError: _eventsController.addError,
      onDone: () {
        if (identical(_socket, socket)) {
          _socket = null;
          _subscription = null;
        }
      },
    );
  }

  @override
  Future<void> send(CallControlEvent event) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Call realtime client is not connected.');
    }
    socket.add(encodeCallControlEvent(event));
  }

  @override
  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
    }
  }
}

Map<String, dynamic> _decodeJsonObject(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is String) {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  if (raw is Uint8List) {
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  if (raw is List<int>) {
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  throw const FormatException('Unsupported call control payload.');
}

Map<String, dynamic> _readPayload(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return Map<String, dynamic>.from(raw);
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return const <String, dynamic>{};
}
