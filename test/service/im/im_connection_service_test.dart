import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/im_route_info.dart';
import 'package:wukong_im_app/service/im/im_connection_service.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ImConnectionService policy', () {
    test('normalizes credentials and rejects incomplete sessions', () {
      expect(
        ImConnectionService.resolveStoredCredentials(
          uid: ' u1 ',
          apiToken: ' api ',
          imToken: ' im ',
          deviceSessionId: ' device ',
        ),
        const ImConnectionCredentials(
          uid: 'u1',
          apiToken: 'api',
          imToken: 'im',
          deviceSessionId: 'device',
        ),
      );

      expect(
        ImConnectionService.resolveStoredCredentials(
          uid: 'u1',
          apiToken: 'api',
          imToken: '',
          deviceSessionId: 'device',
        ),
        isNull,
      );
    });

    test('maps SDK connection status to user-facing errors', () {
      expect(
        ImConnectionService.resolveConnectionError(
          WKConnectStatus.syncCompleted,
          null,
        ),
        isNull,
      );
      expect(
        ImConnectionService.resolveConnectionError(
          WKConnectStatus.kicked,
          null,
        ),
        'IM session was kicked out.',
      );
      expect(
        ImConnectionService.resolveConnectionError(
          WKConnectStatus.noNetwork,
          null,
        ),
        'Network unavailable.',
      );
      expect(
        ImConnectionService.resolveConnectionError(WKConnectStatus.fail, 401),
        'IM connection failed. reason=401',
      );
      expect(
        ImConnectionService.resolveConnectionError(WKConnectStatus.fail, 0),
        isNull,
      );
    });

    test('keeps realtime connected for desktop and local notifications', () {
      expect(
        ImConnectionService.shouldDisconnectForBackgroundLifecycle(
          isWeb: false,
          hasActiveCallOrPendingSetup: false,
          keepRealtimeForDesktopNotifications: true,
        ),
        isFalse,
      );
      expect(
        ImConnectionService.shouldDisconnectForBackgroundLifecycle(
          isWeb: false,
          hasActiveCallOrPendingSetup: false,
          keepRealtimeForLocalNotifications: true,
        ),
        isFalse,
      );
      expect(
        ImConnectionService.shouldDisconnectForBackgroundLifecycle(
          isWeb: false,
          hasActiveCallOrPendingSetup: false,
        ),
        isTrue,
      );
    });

    test('builds gateway uri and selects preferred route transports', () {
      expect(
        ImConnectionService.buildSessionGatewayUri(
          baseUrl: 'https://example.com',
          deviceSessionId: 'device',
          lastAckedSeq: 7,
          controlProtocol: 'protobuf',
        ).toString(),
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
        ImConnectionService.selectConnectAddr(
          route,
          fallbackAddr: 'fallback:5100',
        ),
        'wss://example.com/ws',
      );
    });

    test('backs off exponentially while respecting max delay', () {
      const policy = ImConnectionBackoffPolicy(
        baseDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 10),
      );

      expect(policy.delayForAttempt(1), const Duration(seconds: 1));
      expect(policy.delayForAttempt(4), const Duration(seconds: 8));
      expect(policy.delayForAttempt(8), const Duration(seconds: 10));
    });

    test('reduces connection snapshots from SDK status updates', () {
      const previous = ImConnectionSnapshot(
        isInitializing: true,
        uid: 'u1',
        error: 'old',
      );

      final synced = ImConnectionService.snapshotForStatus(
        previous: previous,
        status: WKConnectStatus.syncCompleted,
        reasonCode: null,
      );

      expect(synced.isConnected, isTrue);
      expect(synced.isInitialized, isTrue);
      expect(synced.error, isNull);

      final kicked = ImConnectionService.snapshotForStatus(
        previous: synced,
        status: WKConnectStatus.kicked,
        reasonCode: null,
      );

      expect(kicked.isConnected, isFalse);
      expect(kicked.isInitialized, isTrue);
      expect(kicked.error, 'IM session was kicked out.');
    });
  });

  group('ImConnectionCredentials', () {
    test('uses value equality for provider graph and tests', () {
      expect(
        const ImConnectionCredentials(
          uid: 'u1',
          apiToken: 'api',
          imToken: 'im',
          deviceSessionId: 'device',
        ),
        const ImConnectionCredentials(
          uid: 'u1',
          apiToken: 'api',
          imToken: 'im',
          deviceSessionId: 'device',
        ),
      );
    });
  });
}
