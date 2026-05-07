import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';

void main() {
  group('ImRouteInfo', () {
    test('fromMap reads formal IM route contract fields', () {
      final route = ImRouteInfo.fromMap(<String, dynamic>{
        'tcp_addr': '  infoequity.cn:5100  ',
        'ws_addr': 'ws://infoequity.cn:5200',
        'wss_addr': 'wss://infoequity.cn/ws',
        'preferred_transport': ' wss ',
        'preferred_addr': ' wss://infoequity.cn/ws ',
      });

      expect(route.tcpAddr, 'infoequity.cn:5100');
      expect(route.wsAddr, 'ws://infoequity.cn:5200');
      expect(route.wssAddr, 'wss://infoequity.cn/ws');
      expect(route.preferredTransport, 'wss');
      expect(route.preferredAddr, 'wss://infoequity.cn/ws');
    });

    test(
      'resolvePreferredAddr prefers valid preferred_addr when it matches transport',
      () {
        final route = ImRouteInfo(
          tcpAddr: 'infoequity.cn:5100',
          wsAddr: 'ws://infoequity.cn:5200',
          wssAddr: 'wss://infoequity.cn/ws',
          preferredTransport: 'wss',
          preferredAddr: 'wss://preferred.infoequity.cn/ws',
        );

        expect(
          route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
          'wss://preferred.infoequity.cn/ws',
        );
      },
    );

    test(
      'resolvePreferredAddr falls back to wss when preferred pair is invalid',
      () {
        final route = ImRouteInfo(
          tcpAddr: 'infoequity.cn:5100',
          wsAddr: 'ws://infoequity.cn:5200',
          wssAddr: 'wss://infoequity.cn/ws',
          preferredTransport: 'wss',
          preferredAddr: 'https://infoequity.cn/ws',
        );

        expect(
          route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
          'wss://infoequity.cn/ws',
        );
      },
    );

    test('resolvePreferredAddr falls back to ws, tcp, then fallback', () {
      final wsRoute = ImRouteInfo(
        tcpAddr: 'infoequity.cn:5100',
        wsAddr: 'ws://infoequity.cn:5200',
        wssAddr: 'https://infoequity.cn/ws',
        preferredTransport: 'wss',
        preferredAddr: 'wss://',
      );
      expect(
        wsRoute.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'ws://infoequity.cn:5200',
      );

      final tcpRoute = ImRouteInfo(
        tcpAddr: 'infoequity.cn:5100',
        wsAddr: 'http://infoequity.cn:5200',
        wssAddr: '',
        preferredTransport: 'ws',
        preferredAddr: 'infoequity.cn:5200',
      );
      expect(
        tcpRoute.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'infoequity.cn:5100',
      );

      const emptyRoute = ImRouteInfo.empty();
      expect(
        emptyRoute.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'fallback.example:5100',
      );
    });

    test('validates tcp and websocket connect addresses strictly', () {
      expect(isValidTcpConnectAddr('infoequity.cn:5100'), isTrue);
      expect(isValidTcpConnectAddr('infoequity.cn:70000'), isFalse);
      expect(isValidTcpConnectAddr('wss://infoequity.cn/ws'), isFalse);
      expect(
        isValidWebSocketConnectUri(
          'wss://infoequity.cn/ws',
          expectedScheme: 'wss',
        ),
        isTrue,
      );
      expect(
        isValidWebSocketConnectUri(
          'https://infoequity.cn/ws',
          expectedScheme: 'wss',
        ),
        isFalse,
      );
    });

    test('detects local/private fallback addresses for tunnel mode', () {
      expect(shouldPreferLocalFallbackImAddr('127.0.0.1:15100'), isTrue);
      expect(shouldPreferLocalFallbackImAddr('localhost:15100'), isTrue);
      expect(shouldPreferLocalFallbackImAddr('10.0.0.8:15100'), isTrue);
      expect(shouldPreferLocalFallbackImAddr('172.16.0.8:15100'), isTrue);
      expect(shouldPreferLocalFallbackImAddr('192.168.1.8:15100'), isTrue);
      expect(shouldPreferLocalFallbackImAddr('infoequity.cn:5100'), isFalse);
    });
  });
}
