import 'package:web_socket_channel/html.dart';

import 'call_realtime_client.dart';

class WebCallRealtimeClient extends ManagedCallRealtimeClient {
  WebCallRealtimeClient({CallRealtimeSocketConnector? connect})
    : super(connect: connect ?? _defaultConnect);

  static CallRealtimeSocket _defaultConnect(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _WebCallRealtimeSocket(HtmlWebSocketChannel.connect(uri));
  }
}

class _WebCallRealtimeSocket implements CallRealtimeSocket {
  _WebCallRealtimeSocket(this._channel);

  final HtmlWebSocketChannel _channel;

  @override
  Stream<Object?> get stream => _channel.stream.cast<Object?>();

  @override
  Future<void> ready() => _channel.ready;

  @override
  void add(Object? data) {
    _channel.sink.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) => _channel.sink.close();
}
