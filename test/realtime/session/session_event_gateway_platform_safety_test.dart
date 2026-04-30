import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('session event gateway does not import native websocket directly', () {
    final source = File(
      'lib/realtime/session/session_event_gateway.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("web_socket_channel/io.dart")));
    expect(source, isNot(contains("wk_http_client_proxy_io.dart")));
    expect(source, isNot(contains('IOWebSocketChannel')));
  });
}
