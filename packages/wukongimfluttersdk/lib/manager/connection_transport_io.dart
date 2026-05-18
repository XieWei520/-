import 'dart:io';
import 'dart:typed_data';

import 'connection_transport_base.dart';

class WKTcpConnectionTransport implements WKConnectionTransport {
  final Socket _socket;

  WKTcpConnectionTransport._(this._socket);

  static Future<WKTcpConnectionTransport> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    return WKTcpConnectionTransport._(socket);
  }

  @override
  Future<void> send(Uint8List data) async {
    _socket.add(data);
    await _socket.flush();
  }

  @override
  void listen(
    void Function(Uint8List data) onData, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
  }) {
    _socket.listen(
      onData,
      onError: (Object error, StackTrace stackTrace) {
        onError?.call(error, stackTrace);
      },
      onDone: onDone,
    );
  }

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

class WKIoWebSocketConnectionTransport implements WKConnectionTransport {
  final WebSocket _socket;

  WKIoWebSocketConnectionTransport._(this._socket);

  static Future<WKIoWebSocketConnectionTransport> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await WebSocket.connect(
      uri.toString(),
      compression: CompressionOptions.compressionOff,
    ).timeout(timeout);
    return WKIoWebSocketConnectionTransport._(socket);
  }

  @override
  Future<void> send(Uint8List data) async {
    _socket.add(data);
  }

  @override
  void listen(
    void Function(Uint8List data) onData, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
  }) {
    _socket.listen(
      (dynamic frame) {
        final bytes = WKWebSocketFrameConverter.toBytes(frame);
        if (bytes != null) {
          onData(bytes);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        onError?.call(error, stackTrace);
      },
      onDone: onDone,
    );
  }

  @override
  Future<void> close() async {
    await _socket.close();
  }
}

Future<WKConnectionTransport> connectTcp(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 5),
}) {
  return WKTcpConnectionTransport.connect(host, port, timeout: timeout);
}

Future<WKConnectionTransport> connectWebSocket(
  Uri uri, {
  Duration timeout = const Duration(seconds: 5),
}) {
  return WKIoWebSocketConnectionTransport.connect(uri, timeout: timeout);
}
