import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';

void main() {
  test('resolvePreferredAddr prefers preferred_addr when valid', () {
    final route = ImRouteInfo(
      tcpAddr: 'infoequity.qingyunshe.top:5100',
      wsAddr: 'ws://infoequity.qingyunshe.top:5200',
      wssAddr: 'wss://infoequity.qingyunshe.top/ws',
      preferredTransport: 'wss',
      preferredAddr: 'wss://infoequity.qingyunshe.top/ws',
    );

    expect(
      route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
      'wss://infoequity.qingyunshe.top/ws',
    );
  });

  test(
    'resolvePreferredAddr falls back from invalid preferred_addr to wss',
    () {
      final route = ImRouteInfo(
        tcpAddr: 'infoequity.qingyunshe.top:5100',
        wsAddr: 'ws://infoequity.qingyunshe.top:5200',
        wssAddr: 'wss://infoequity.qingyunshe.top/ws',
        preferredTransport: 'wss',
        preferredAddr: 'https://infoequity.qingyunshe.top/ws',
      );

      expect(
        route.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
        'wss://infoequity.qingyunshe.top/ws',
      );
    },
  );

  test('resolvePreferredAddr falls back to tcp then local fallback', () {
    final tcpOnly = ImRouteInfo(
      tcpAddr: 'infoequity.qingyunshe.top:5100',
      wsAddr: '',
      wssAddr: '',
      preferredTransport: '',
      preferredAddr: '',
    );

    expect(
      tcpOnly.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
      'infoequity.qingyunshe.top:5100',
    );

    const emptyRoute = ImRouteInfo.empty();
    expect(
      emptyRoute.resolvePreferredAddr(fallbackAddr: 'fallback.example:5100'),
      'fallback.example:5100',
    );
  });
}
