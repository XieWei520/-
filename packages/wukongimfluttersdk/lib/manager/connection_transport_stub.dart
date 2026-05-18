import 'connection_transport_base.dart';

Future<WKConnectionTransport> connectTcp(
  String host,
  int port, {
  Duration timeout = const Duration(seconds: 5),
}) {
  return Future<WKConnectionTransport>.error(
    UnsupportedError('TCP transport is unavailable on this platform.'),
  );
}

Future<WKConnectionTransport> connectWebSocket(
  Uri uri, {
  Duration timeout = const Duration(seconds: 5),
}) {
  return Future<WKConnectionTransport>.error(
    UnsupportedError('WebSocket transport is unavailable on this platform.'),
  );
}
