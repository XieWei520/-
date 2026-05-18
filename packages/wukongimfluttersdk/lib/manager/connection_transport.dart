import 'connection_transport_base.dart';
import 'connection_transport_stub.dart'
    if (dart.library.io) 'connection_transport_io.dart'
    if (dart.library.html) 'connection_transport_web.dart' as platform;

export 'connection_transport_base.dart';

class WKConnectionTransportFactory {
  static Future<WKConnectionTransport> connect(
    WKConnectTarget target, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    switch (target.type) {
      case WKTransportType.tcp:
        return platform.connectTcp(
          target.host,
          target.port!,
          timeout: timeout,
        );
      case WKTransportType.ws:
      case WKTransportType.wss:
        return platform.connectWebSocket(
          target.uri!,
          timeout: timeout,
        );
    }
  }
}
