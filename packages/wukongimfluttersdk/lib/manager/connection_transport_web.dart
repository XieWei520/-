// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'connection_transport_base.dart';

class WKBrowserWebSocketConnectionTransport implements WKConnectionTransport {
  final html.WebSocket _socket;
  StreamSubscription<html.MessageEvent>? _messageSubscription;
  StreamSubscription<html.Event>? _closeSubscription;
  StreamSubscription<html.Event>? _errorSubscription;

  WKBrowserWebSocketConnectionTransport._(this._socket);

  static Future<WKBrowserWebSocketConnectionTransport> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = html.WebSocket(uri.toString())..binaryType = 'arraybuffer';
    final completer = Completer<html.WebSocket>();
    Timer? timeoutTimer;
    late final StreamSubscription<html.Event> openSubscription;
    late final StreamSubscription<html.Event> errorSubscription;

    void cleanup() {
      timeoutTimer?.cancel();
      openSubscription.cancel();
      errorSubscription.cancel();
    }

    openSubscription = socket.onOpen.listen((_) {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete(socket);
      }
    });
    errorSubscription = socket.onError.listen((_) {
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(
          StateError('WebSocket connection failed: $uri'),
          StackTrace.current,
        );
      }
    });
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        cleanup();
        socket.close();
        completer.completeError(
          TimeoutException('WebSocket connection timed out: $uri', timeout),
          StackTrace.current,
        );
      }
    });

    final connected = await completer.future;
    return WKBrowserWebSocketConnectionTransport._(connected);
  }

  @override
  Future<void> send(Uint8List data) async {
    _socket.send(data);
  }

  @override
  void listen(
    void Function(Uint8List data) onData, {
    void Function(Object error, StackTrace stackTrace)? onError,
    void Function()? onDone,
  }) {
    _messageSubscription ??= _socket.onMessage.listen((event) {
      final bytes = WKWebSocketFrameConverter.toBytes(event.data);
      if (bytes != null) {
        onData(bytes);
      }
    });
    _errorSubscription ??= _socket.onError.listen((event) {
      onError?.call(
        StateError('WebSocket transport error: ${event.type}'),
        StackTrace.current,
      );
    });
    _closeSubscription ??= _socket.onClose.listen((_) {
      onDone?.call();
    });
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _closeSubscription?.cancel();
    _messageSubscription = null;
    _errorSubscription = null;
    _closeSubscription = null;
    _socket.close();
  }
}

Future<WKConnectionTransport> connectTcp(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 5),
}) {
  return Future<WKConnectionTransport>.error(
    UnsupportedError('TCP transport is unavailable in browser builds.'),
  );
}

Future<WKConnectionTransport> connectWebSocket(
  Uri uri, {
  Duration timeout = const Duration(seconds: 5),
}) {
  return WKBrowserWebSocketConnectionTransport.connect(uri, timeout: timeout);
}
