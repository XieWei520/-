import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';
import 'package:wukong_im_app/service/im/coordinators/connection_coordinator.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ConnectionCoordinator', () {
    test('normalizes stored credentials and rejects incomplete sessions', () {
      final coordinator = ConnectionCoordinator();

      expect(
        coordinator.resolveStoredCredentials(
          uid: ' u1 ',
          apiToken: ' api ',
          imToken: ' im ',
          deviceSessionId: ' device ',
        ),
        const StoredImInitCredentials(
          uid: 'u1',
          apiToken: 'api',
          imToken: 'im',
          deviceSessionId: 'device',
        ),
      );

      expect(
        coordinator.resolveStoredCredentials(
          uid: 'u1',
          apiToken: 'api',
          imToken: '',
          deviceSessionId: 'device',
        ),
        isNull,
      );
    });

    test(
      'reuses active IM sessions without requiring realtime to be healthy',
      () {
        const coordinator = ConnectionCoordinator();

        for (final status in <int>[
          WKConnectStatus.connecting,
          WKConnectStatus.success,
          WKConnectStatus.syncMsg,
          WKConnectStatus.syncCompleted,
        ]) {
          expect(
            coordinator.shouldReuseInitializedSession(
              initializedUid: 'u1',
              initializedToken: 'im',
              initializedDeviceSessionId: 'device',
              uid: 'u1',
              token: 'im',
              deviceSessionId: 'device',
              connectionStatus: status,
              sessionRuntimeRunning: false,
            ),
            isTrue,
            reason: 'status=$status should not force an IM reconnect',
          );
        }

        expect(
          coordinator.shouldDisconnectForBackgroundLifecycle(
            isWeb: false,
            hasActiveCallOrPendingSetup: false,
            keepRealtimeForDesktopNotifications: true,
          ),
          isFalse,
        );
      },
    );

    test('builds gateway uri and prefers explicit route transports', () {
      const coordinator = ConnectionCoordinator();

      expect(
        coordinator
            .buildSessionGatewayUri(
              baseUrl: 'https://example.com',
              deviceSessionId: 'device',
              lastAckedSeq: 7,
              controlProtocol: 'protobuf',
            )
            .toString(),
        'wss://example.com/v1/realtime/session/events/ws?device_session_id=device&last_acked_seq=7&control_protocol=protobuf',
      );

      final route = ImRouteInfo(
        tcpAddr: 'tcp.example:5100',
        wsAddr: 'ws://example.com/ws',
        wssAddr: 'wss://example.com/ws',
        preferredTransport: 'wss',
        preferredAddr: '',
      );

      expect(
        coordinator.selectConnectAddr(route, fallbackAddr: 'fallback:5100'),
        'wss://example.com/ws',
      );
    });

    test('owns the Flutter lifecycle keepalive policy', () {
      const coordinator = ConnectionCoordinator();

      expect(
        coordinator.shouldKeepConnectionInBackground(
          lifecycleState: AppLifecycleState.paused,
          hasActiveCallOrPendingSetup: true,
        ),
        isTrue,
      );
      expect(
        coordinator.shouldKeepConnectionInBackground(
          lifecycleState: AppLifecycleState.resumed,
          hasActiveCallOrPendingSetup: false,
        ),
        isTrue,
      );
    });
  });
}
