import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';

void main() {
  group('ImRouteInfo', () {
    test('fromMap reads formal IM route contract fields', () {
      final route = ImRouteInfo.fromMap(<String, dynamic>{
        'tcp_addr': '  wemx.cc:5100  ',
        'ws_addr': 'ws://wemx.cc:5200',
        'wss_addr': 'wss://wemx.cc/ws',
        'preferred_transport': ' wss ',
        'preferred_addr': ' wss://wemx.cc/ws ',
      });

      expect(route.tcpAddr, 'wemx.cc:5100');
      expect(route.wsAddr, 'ws://wemx.cc:5200');
      expect(route.wssAddr, 'wss://wemx.cc/ws');
      expect(route.preferredTransport, 'wss');
      expect(route.preferredAddr, 'wss://wemx.cc/ws');
    });

    test('resolvePreferredAddr prefers valid preferred_addr when it matches transport', () {
      final route = ImRouteInfo(
        tcpAddr: 'wemx.cc:5100',
        wsAddr: 'ws://wemx.cc:5200',
        wssAddr: 'wss://wemx.cc/ws',
        preferredTransport: 'wss',
        preferredAddr: 'wss://preferred.wemx.cc/ws',
      );

      expect(
        route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'wss://preferred.wemx.cc/ws',
      );
    });

    test('resolvePreferredAddr falls back to wss when preferred pair is invalid', () {
      final route = ImRouteInfo(
        tcpAddr: 'wemx.cc:5100',
        wsAddr: 'ws://wemx.cc:5200',
        wssAddr: 'wss://wemx.cc/ws',
        preferredTransport: 'wss',
        preferredAddr: 'https://wemx.cc/ws',
      );

      expect(
        route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'wss://wemx.cc/ws',
      );
    });

    test('resolvePreferredAddr falls back to ws, tcp, then local fallback', () {
      final wsRoute = ImRouteInfo(
        tcpAddr: 'wemx.cc:5100',
        wsAddr: 'ws://wemx.cc:5200',
        wssAddr: 'https://wemx.cc/ws',
        preferredTransport: 'wss',
        preferredAddr: 'wss://',
      );
      expect(
        wsRoute.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'ws://wemx.cc:5200',
      );

      final tcpRoute = ImRouteInfo(
        tcpAddr: 'wemx.cc:5100',
        wsAddr: 'http://wemx.cc:5200',
        wssAddr: '',
        preferredTransport: 'ws',
        preferredAddr: 'wemx.cc:5200',
      );
      expect(
        tcpRoute.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'wemx.cc:5100',
      );

      const emptyRoute = ImRouteInfo.empty();
      expect(
        emptyRoute.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'fallback.example:5100',
      );
    });
  });
}
