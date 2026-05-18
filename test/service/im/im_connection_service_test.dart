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

  group('ImConnectionService listener binding', () {
    test('unbinds stale listener before binding a fresh status listener', () {
      final sdk = _FakeImSdkConnectionPort();
      final service = ImConnectionService(
        sdk: sdk,
        realtimeRuntime: const _FakeImRealtimeRuntimePort(),
        routeResolver: (_) async => '127.0.0.1:5100',
        listenerKey: 'test_listener',
      );
      final forwarded = <int>[];

      service.bindConnectionStatusListener(
        onStatus: (status, reasonCode, extra) {
          forwarded.add(status);
        },
      );

      expect(sdk.unboundKeys, <String>['test_listener']);
      expect(sdk.boundKeys, <String>['test_listener']);

      sdk.emit(
        status: WKConnectStatus.syncCompleted,
        reasonCode: null,
        extra: 'ready',
      );

      expect(forwarded, <int>[WKConnectStatus.syncCompleted]);
      expect(
        service.snapshot,
        const ImConnectionSnapshot(
          isInitialized: true,
          isConnected: true,
          status: WKConnectStatus.syncCompleted,
        ),
      );
    });

    test('updates snapshot before forwarding failed status', () {
      final sdk = _FakeImSdkConnectionPort();
      final service = ImConnectionService(
        sdk: sdk,
        realtimeRuntime: const _FakeImRealtimeRuntimePort(),
        routeResolver: (_) async => '127.0.0.1:5100',
      );
      ImConnectionSnapshot? observedSnapshot;

      service.bindConnectionStatusListener(
        onStatus: (status, reasonCode, extra) {
          observedSnapshot = service.snapshot;
        },
      );

      sdk.emit(status: WKConnectStatus.fail, reasonCode: 401, extra: null);

      expect(
        observedSnapshot,
        const ImConnectionSnapshot(
          isConnected: false,
          status: WKConnectStatus.fail,
          reasonCode: 401,
          error: 'IM connection failed. reason=401',
        ),
      );
    });

    test('unbindConnectionStatusListener removes the owned listener key', () {
      final sdk = _FakeImSdkConnectionPort();
      final service = ImConnectionService(
        sdk: sdk,
        realtimeRuntime: const _FakeImRealtimeRuntimePort(),
        routeResolver: (_) async => '127.0.0.1:5100',
        listenerKey: 'owned_listener',
      );

      service.unbindConnectionStatusListener();

      expect(sdk.unboundKeys, <String>['owned_listener']);
    });
  });
}

class _FakeImSdkConnectionPort implements ImSdkConnectionPort {
  final boundKeys = <String>[];
  final unboundKeys = <String>[];
  final _listeners = <String, ImConnectionStatusHandler>{};

  @override
  Future<bool> setup(ImConnectionCredentials credentials) async {
    return true;
  }

  @override
  void connect() {}

  @override
  void disconnect({required bool isLogout}) {}

  @override
  void bindStatusListener({
    required String key,
    required ImConnectionStatusHandler onStatus,
  }) {
    boundKeys.add(key);
    _listeners[key] = onStatus;
  }

  @override
  void unbindStatusListener(String key) {
    unboundKeys.add(key);
    _listeners.remove(key);
  }

  void emit({
    required int status,
    required int? reasonCode,
    required String? extra,
  }) {
    for (final listener in List<ImConnectionStatusHandler>.from(
      _listeners.values,
    )) {
      listener(status, reasonCode, extra);
    }
  }
}

class _FakeImRealtimeRuntimePort implements ImRealtimeRuntimePort {
  const _FakeImRealtimeRuntimePort();

  @override
  bool get isRunning => false;

  @override
  Future<void> start({
    required String apiToken,
    required String deviceSessionId,
    required int lastAckedSeq,
  }) async {}

  @override
  Future<void> stop() async {}
}
