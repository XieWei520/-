import 'package:web_socket_channel/io.dart';

import '../../../wk_foundation/net/wk_http_client_proxy_io.dart';
import 'call_realtime_client.dart';

class IoCallRealtimeClient extends ManagedCallRealtimeClient {
  IoCallRealtimeClient({CallRealtimeSocketConnector? connect})
    : super(connect: connect ?? _defaultConnect);

  static CallRealtimeSocket _defaultConnect(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _IoCallRealtimeSocket(
      IOWebSocketChannel.connect(
        uri,
        headers: headers,
        pingInterval: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 10),
        customClient: createNativeProxyAwareHttpClient(),
      ),
    );
  }
}

class _IoCallRealtimeSocket implements CallRealtimeSocket {
  _IoCallRealtimeSocket(this._channel);

  final IOWebSocketChannel _channel;

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
