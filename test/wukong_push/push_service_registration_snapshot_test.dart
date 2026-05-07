import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/handlers/push_handler.dart'
    as handler;
import 'package:wukong_im_app/wukong_push/models/push_models.dart';
import 'package:wukong_im_app/wukong_push/push_service.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('push service captures APNs-ready registration state on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final fakeHandler = _FakePushHandler(
      permissionGranted: true,
      registrationSnapshot: const PushRegistrationSnapshot(
        deviceToken: 'fcm-token',
        apnsToken: 'apns-token',
        applePushTokenState: ApplePushTokenState.available,
      ),
    );

    final service = PushService(
      isPushSupported: () => true,
      handlerSelector: () async => fakeHandler,
      initializeNotifications:
          ({void Function(String payload)? onNotificationTap}) async {},
      onPermissionDenied: () async {},
    );

    await service.ensureInitialized();

    expect(service.registrationSnapshot?.deviceToken, 'fcm-token');
    expect(service.registrationSnapshot?.apnsToken, 'apns-token');
    expect(service.registrationSnapshot?.isApnsReady, isTrue);
  });

  test(
    'push service logs a diagnostic warning when iOS APNs token is missing',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final fakeHandler = _FakePushHandler(
        permissionGranted: true,
        registrationSnapshot: const PushRegistrationSnapshot(
          deviceToken: 'fcm-token',
          applePushTokenState: ApplePushTokenState.missing,
        ),
      );
      final logLines = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logLines.add(message);
        }
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {},
      );

      await service.ensureInitialized();

      expect(
        service.registrationSnapshot?.applePushTokenState,
        ApplePushTokenState.missing,
      );
      expect(
        logLines,
        contains(
          contains(
            'APNs token is not available yet despite having an FCM token',
          ),
        ),
      );
    },
  );

  test(
    'push service only logs the missing APNs warning once during initialization',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final fakeHandler = _FakePushHandler(
        permissionGranted: true,
        registrationSnapshot: const PushRegistrationSnapshot(
          deviceToken: 'fcm-token',
          applePushTokenState: ApplePushTokenState.missing,
        ),
        initialTokenOnInitialize: 'fcm-token',
      );
      final logLines = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logLines.add(message);
        }
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {},
      );

      await service.ensureInitialized();

      expect(
        logLines
            .where(
              (line) => line.contains(
                'APNs token is not available yet despite having an FCM token',
              ),
            )
            .length,
        1,
      );
    },
  );

  test(
    'push service ignores stale registration snapshots that resolve after a newer refresh',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final firstSnapshot = Completer<PushRegistrationSnapshot>();
      final secondSnapshot = Completer<PushRegistrationSnapshot>();
      final logLines = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logLines.add(message);
        }
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });
      final fakeHandler = _FakePushHandler(
        permissionGranted: true,
        registrationSnapshot: const PushRegistrationSnapshot(
          deviceToken: 'fallback-token',
          applePushTokenState: ApplePushTokenState.missing,
        ),
        initialTokenOnInitialize: 'fcm-token',
        registrationSnapshotFutures: <Future<PushRegistrationSnapshot>>[
          firstSnapshot.future,
          secondSnapshot.future,
        ],
      );

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {},
      );

      final initFuture = service.ensureInitialized();
      secondSnapshot.complete(
        const PushRegistrationSnapshot(
          deviceToken: 'fcm-token',
          apnsToken: 'apns-token',
          applePushTokenState: ApplePushTokenState.available,
        ),
      );
      await initFuture;

      firstSnapshot.complete(
        const PushRegistrationSnapshot(
          deviceToken: 'fcm-token',
          applePushTokenState: ApplePushTokenState.missing,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(service.registrationSnapshot?.isApnsReady, isTrue);
      expect(
        logLines.any(
          (line) => line.contains('APNs token is not available yet'),
        ),
        isFalse,
      );
    },
  );

  test(
    'push service marks Android registrations as APNs-not-applicable',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final fakeHandler = _FakePushHandler(
        permissionGranted: true,
        registrationSnapshot: const PushRegistrationSnapshot(
          deviceToken: 'fcm-token',
          applePushTokenState: ApplePushTokenState.notApplicable,
        ),
      );
      final logLines = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          logLines.add(message);
        }
      };
      addTearDown(() {
        debugPrint = originalDebugPrint;
      });

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {},
      );

      await service.ensureInitialized();

      expect(
        service.registrationSnapshot?.applePushTokenState,
        ApplePushTokenState.notApplicable,
      );
      expect(
        logLines.any(
          (line) => line.contains('APNs token is not available yet'),
        ),
        isFalse,
      );
    },
  );
}

class _FakePushHandler implements handler.PushHandler {
  _FakePushHandler({
    required this.permissionGranted,
    required this.registrationSnapshot,
    this.initialTokenOnInitialize,
    this.registrationSnapshotFutures,
  });

  final bool permissionGranted;
  final PushRegistrationSnapshot registrationSnapshot;
  final String? initialTokenOnInitialize;
  final List<Future<PushRegistrationSnapshot>>? registrationSnapshotFutures;

  @override
  Future<bool> ensurePermission() async => permissionGranted;

  @override
  Future<PushMessageEvent?> getInitialMessage() async => null;

  @override
  Future<PushRegistrationSnapshot> getRegistrationSnapshot() async {
    final futures = registrationSnapshotFutures;
    if (futures != null && futures.isNotEmpty) {
      return futures.removeAt(0);
    }
    return registrationSnapshot;
  }

  @override
  Future<String?> getToken() async => registrationSnapshot.deviceToken;

  @override
  Future<void> initialize({
    required void Function(String token) onTokenRefresh,
    required void Function(PushMessageEvent event) onMessageReceived,
  }) async {
    if (initialTokenOnInitialize != null) {
      onTokenRefresh(initialTokenOnInitialize!);
    }
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  handler.PushType get pushType => handler.PushType.fcm;

  @override
  Future<void> subscribe(String topic) async {}

  @override
  Future<void> unsubscribe(String topic) async {}

  @override
  void dispose() {}
}
