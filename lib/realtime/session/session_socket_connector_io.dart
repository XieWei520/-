import 'package:web_socket_channel/io.dart';

import '../../wk_foundation/net/wk_http_client_proxy_io.dart';
import 'session_socket.dart';

SessionSocket createDefaultSessionSocket(
  Uri uri, {
  Map<String, String>? headers,
}) {
  return _IoSessionSocket(
    IOWebSocketChannel.connect(
      uri,
      headers: headers,
      // Native sockets can send auth/control headers directly. Keep the
      // browser-only subprotocol tunnel out of the IO path because the current
      // production gateway rejects those subprotocols with HTTP 400.
      pingInterval: const Duration(seconds: 20),
      connectTimeout: const Duration(seconds: 10),
      customClient: createNativeProxyAwareHttpClient(),
    ),
  );
}

class _IoSessionSocket implements SessionSocket {
  _IoSessionSocket(this._channel);

  final IOWebSocketChannel _channel;

  @override
  Stream<Object?> get stream => _channel.stream.cast<Object?>();

  @override
  Future<void> ready() => _channel.ready;

  @override
  Future<void> close([int? code, String? reason]) {
    return _channel.sink.close(code, reason);
  }
}
