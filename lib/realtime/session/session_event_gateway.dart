import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';

import '../../service/api/api_client.dart';
import '../../wk_foundation/net/wk_http_client_proxy_io.dart';
import '../control/control_proto_codec.dart';
import '../telemetry/realtime_rollout_telemetry.dart';
import 'session_event_frame.dart';

export '../control/control_event.dart';

abstract class SessionSocket {
  Stream<Object?> get stream;

  Future<void> ready();

  Future<void> close([int? code, String? reason]);
}

typedef SessionSocketConnector =
    SessionSocket Function(Uri uri, {Map<String, String>? headers});
typedef SessionAckWriter = Future<void> Function(int lastAckedSeq);

class SessionEventGateway {
  SessionEventGateway({
    SessionSocketConnector? connect,
    SessionAckWriter? ack,
    SessionEventGatewayTelemetry? telemetry,
  }) : _connect = connect ?? _defaultConnect,
       _ack = ack ?? _defaultAck,
       _telemetry = telemetry;

  final SessionSocketConnector _connect;
  final SessionAckWriter _ack;
  final SessionEventGatewayTelemetry? _telemetry;

  SessionSocket? _socket;

  int lastReceivedSeq = 0;
  int lastAckedSeq = 0;

  Future<Stream<SessionEventFrame>> open(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    _bindSessionId(uri);
    final socket = _connect(uri, headers: headers);
    try {
      await socket.ready();
    } catch (_) {
      await socket.close();
      rethrow;
    }
    _socket = socket;
    return socket.stream.map((raw) {
      _telemetry?.recordInboundControlFrame();
      final frame = _decodeFrameWithTelemetry(raw);
      if (frame.userSeq > lastReceivedSeq) {
        lastReceivedSeq = frame.userSeq;
      }
      return frame;
    });
  }

  Future<void> ack(int seq) async {
    if (seq <= lastAckedSeq) {
      return;
    }
    await _ack(seq);
    lastAckedSeq = seq;
  }

  Future<void> close() async {
    final socket = _socket;
    _socket = null;
    if (socket == null) {
      return;
    }
    await socket.close();
  }

  static SessionSocket _defaultConnect(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _WebSocketSessionSocket(
      IOWebSocketChannel.connect(
        uri,
        headers: headers,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 10),
        customClient: createNativeProxyAwareHttpClient(),
      ),
    );
  }

  static Future<void> _defaultAck(int lastAckedSeq) {
    return ApiClient.instance.post(
      '/v1/realtime/session/events/ack',
      data: <String, dynamic>{'last_acked_seq': lastAckedSeq},
    );
  }

  static SessionEventFrame _decodeFrame(Object? raw) {
    if (raw is String) {
      return _decodeJsonTextFrame(raw);
    }
    if (raw is List<int>) {
      final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
      final jsonFrame = _tryDecodeJsonBytesFrame(bytes);
      if (jsonFrame != null) {
        return jsonFrame;
      }
      final envelope = ControlProtoCodec.decodeEnvelope(bytes);
      return ControlProtoCodec.toSessionEventFrame(envelope);
    }
    throw const FormatException('Unsupported session event frame payload.');
  }

  static SessionEventFrame _decodeJsonTextFrame(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('Unsupported session event frame payload.');
    }
    return SessionEventFrame.fromJson(Map<String, dynamic>.from(decoded));
  }

  static SessionEventFrame? _tryDecodeJsonBytesFrame(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        return null;
      }
      return SessionEventFrame.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  SessionEventFrame _decodeFrameWithTelemetry(Object? raw) {
    try {
      return _decodeFrame(raw);
    } catch (_) {
      _telemetry?.recordControlFrameDecodeError();
      rethrow;
    }
  }

  void _bindSessionId(Uri uri) {
    final sessionId = uri.queryParameters['device_session_id']?.trim() ?? '';
    if (sessionId.isEmpty) {
      return;
    }
    _telemetry?.bindSessionId(sessionId);
  }
}

class _WebSocketSessionSocket implements SessionSocket {
  _WebSocketSessionSocket(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Stream<Object?> get stream => _channel.stream.cast<Object?>();

  @override
  Future<void> ready() => _channel.ready;

  @override
  Future<void> close([int? code, String? reason]) => _channel.sink.close();
}
