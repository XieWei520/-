import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/handlers/push_handler.dart'
    as handler;
import 'package:wukong_im_app/wukong_push/models/push_models.dart';
import 'package:wukong_im_app/wukong_push/notification/foreground_notification_plan.dart';
import 'package:wukong_im_app/wukong_push/push_service.dart';

void main() {
  test(
    'push service prompts for notification settings when permission is denied',
    () async {
      final fakeHandler = _FakePushHandler(permissionGranted: false);
      var promptCount = 0;

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {
          promptCount += 1;
        },
      );

      await service.ensureInitialized();

      expect(promptCount, 1);
      expect(fakeHandler.initializeCallCount, 0);
    },
  );

  test(
    'push service skips the notification prompt when permission is already granted',
    () async {
      final fakeHandler = _FakePushHandler(permissionGranted: true);
      var promptCount = 0;

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {
          promptCount += 1;
        },
      );

      await service.ensureInitialized();

      expect(promptCount, 0);
      expect(fakeHandler.initializeCallCount, 1);
    },
  );

  test(
    'push service logs the unconfigured vendor handlers when no handler is available',
    () async {
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
        handlerSelector: () async => null,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {},
      );

      await service.ensureInitialized();

      expect(
        logLines,
        contains(
          contains(
            'no compatible push handler detected; app is currently configured for FCM only, vendor handlers pending: HMS, MI, OPPO, VIVO.',
          ),
        ),
      );
    },
  );

  test(
    'push registration stays non-fatal when handler initialization fails',
    () async {
      final fakeHandler = _FakePushHandler(
        permissionGranted: true,
        initializeError: StateError('Firebase not configured'),
        tokenError: StateError('No Firebase App has been created'),
      );

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {},
      );

      await service.handleLogin();

      expect(fakeHandler.getTokenCallCount, 0);
    },
  );

  test(
    'push service sends foreground events through the injected notification presenter',
    () async {
      final deliveredPlan = Completer<ForegroundNotificationPlan>();
      final fakeHandler = _FakePushHandler(
        permissionGranted: true,
        initialForegroundEvent: PushMessageEvent(
          payload: PushPayload(
            raw: const <String, dynamic>{'message_id': 'msg-web-01'},
            messageId: 'msg-web-01',
            title: 'Alice',
            body: 'Hello Web',
          ),
          data: const <String, dynamic>{'message_id': 'msg-web-01'},
          trigger: PushMessageTrigger.foreground,
        ),
      );

      final service = PushService(
        isPushSupported: () => true,
        handlerSelector: () async => fakeHandler,
        initializeNotifications:
            ({void Function(String payload)? onNotificationTap}) async {},
        onPermissionDenied: () async {},
        showForegroundNotification: (plan, event) async {
          deliveredPlan.complete(plan);
        },
      );

      await service.ensureInitialized();

      final plan = await deliveredPlan.future.timeout(
        const Duration(seconds: 1),
      );
      expect(plan.title, 'Alice');
      expect(plan.body, 'Hello Web');
    },
  );
}

class _FakePushHandler implements handler.PushHandler {
  _FakePushHandler({
    required this.permissionGranted,
    this.initializeError,
    this.tokenError,
    this.initialForegroundEvent,
  });

  final bool permissionGranted;
  final Object? initializeError;
  final Object? tokenError;
  final PushMessageEvent? initialForegroundEvent;
  int initializeCallCount = 0;
  int getTokenCallCount = 0;

  @override
  Future<bool> ensurePermission() async => permissionGranted;

  @override
  Future<PushMessageEvent?> getInitialMessage() async => null;

  @override
  Future<PushRegistrationSnapshot> getRegistrationSnapshot() async {
    return const PushRegistrationSnapshot(
      applePushTokenState: ApplePushTokenState.notApplicable,
    );
  }

  @override
  Future<String?> getToken() async {
    getTokenCallCount += 1;
    final error = tokenError;
    if (error != null) {
      throw error;
    }
    return null;
  }

  @override
  Future<void> initialize({
    required void Function(String token) onTokenRefresh,
    required void Function(PushMessageEvent event) onMessageReceived,
  }) async {
    initializeCallCount += 1;
    final error = initializeError;
    if (error != null) {
      throw error;
    }
    final event = initialForegroundEvent;
    if (event != null) {
      onMessageReceived(event);
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
