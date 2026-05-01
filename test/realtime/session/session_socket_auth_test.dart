import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/realtime/session/session_socket_auth.dart';

void main() {
  test('encodes auth token as websocket subprotocol for browser sockets', () {
    final protocols = buildBrowserSessionSocketProtocols(<String, String>{
      'token': 'api-token-01',
      'X-Realtime-Control-Protocol': 'protobuf',
    });

    expect(protocols, isNotNull);
    expect(protocols, contains('wk-token.YXBpLXRva2VuLTAx'));
    expect(protocols, contains('wk-control.protobuf'));
  });

  test('omits websocket subprotocols when no auth headers are present', () {
    expect(buildBrowserSessionSocketProtocols(null), isNull);
    expect(buildBrowserSessionSocketProtocols(<String, String>{}), isNull);
  });
}
