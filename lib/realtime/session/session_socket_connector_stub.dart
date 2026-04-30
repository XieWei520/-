import 'package:web_socket_channel/web_socket_channel.dart';

import 'session_socket.dart';

SessionSocket createDefaultSessionSocket(
  Uri uri, {
  Map<String, String>? headers,
}) {
  return _WebSessionSocket(WebSocketChannel.connect(uri));
}

class _WebSessionSocket implements SessionSocket {
  _WebSessionSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<Object?> get stream => _channel.stream.cast<Object?>();

  @override
  Future<void> ready() => _channel.ready;

  @override
  Future<void> close([int? code, String? reason]) {
    return _channel.sink.close(code, reason);
  }
}
