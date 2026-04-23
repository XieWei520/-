import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_foundation/net/wk_http_client_proxy_io.dart';

void main() {
  group('native proxy bypass', () {
    test('treats websocket requests to the api host as direct', () {
      expect(
        shouldBypassNativeProxyForUri(
          apiBaseUri: Uri.parse('https://wemx.cc'),
          requestUri: Uri.parse(
            'wss://wemx.cc/v1/realtime/session/events/ws',
          ),
        ),
        isTrue,
      );

      expect(
        shouldBypassNativeProxyForUri(
          apiBaseUri: Uri.parse('https://gateway.example.com'),
          requestUri: Uri.parse(
            'wss://gateway.example.com/v1/realtime/session/events/ws',
          ),
        ),
        isTrue,
      );

      expect(
        shouldBypassNativeProxyForUri(
          apiBaseUri: Uri.parse('https://wemx.cc'),
          requestUri: Uri.parse(
            'https://wemx.cc:0/v1/realtime/session/events/ws',
          ),
        ),
        isTrue,
      );
    });

    test('keeps explicit port matching for direct websocket routing', () {
      expect(
        shouldBypassNativeProxyForUri(
          apiBaseUri: Uri.parse('http://gateway.example.com:8080'),
          requestUri: Uri.parse('ws://gateway.example.com:8080/realtime'),
        ),
        isTrue,
      );

      expect(
        shouldBypassNativeProxyForUri(
          apiBaseUri: Uri.parse('http://gateway.example.com:8080'),
          requestUri: Uri.parse('ws://gateway.example.com:8081/realtime'),
        ),
        isFalse,
      );
    });

    test('builds a resolver that forces direct websocket requests', () {
      final resolver = createNativeProxyResolver(
        baseUrl: 'http://gateway.example.com:8080',
      );

      expect(
        resolver(Uri.parse('ws://gateway.example.com:8080/realtime')),
        'DIRECT',
      );
      expect(
        resolver(
          Uri.parse('http://gateway.example.com:8080/v1/user/login'),
        ),
        'DIRECT',
      );
    });
  });
}
