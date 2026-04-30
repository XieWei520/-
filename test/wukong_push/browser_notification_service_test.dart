import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/browser_notification_service.dart';
import 'package:wukong_im_app/wukong_push/notification/foreground_notification_plan.dart';

void main() {
  group('BrowserForegroundNotificationService', () {
    test('requests permission and shows notification when granted', () async {
      final gateway = _FakeBrowserNotificationGateway(
        permission: BrowserNotificationPermission.prompt,
        requestedPermission: BrowserNotificationPermission.granted,
      );
      final service = BrowserForegroundNotificationService(gateway: gateway);

      final result = await service.showPlan(_plan(messageId: 'msg-01'));

      expect(result, BrowserNotificationDelivery.shown);
      expect(gateway.requestPermissionCallCount, 1);
      expect(gateway.shownNotifications, hasLength(1));
      expect(gateway.shownNotifications.single.title, 'Alice');
      expect(gateway.shownNotifications.single.body, 'Hello');
      expect(gateway.shownNotifications.single.tag, 'wk-message-msg-01');
      expect(gateway.shownNotifications.single.icon, 'icons/Icon-192.png');
      expect(
        gateway.shownNotifications.single.badge,
        'icons/Icon-maskable-192.png',
      );

      await gateway.shownNotifications.single.onClick?.call();
      expect(gateway.focusWindowCallCount, 1);
    });

    test('runs click action when foreground notification is clicked', () async {
      final gateway = _FakeBrowserNotificationGateway(
        permission: BrowserNotificationPermission.granted,
      );
      final service = BrowserForegroundNotificationService(gateway: gateway);
      var clickActions = 0;

      await service.showPlan(
        _plan(messageId: 'msg-click'),
        onClick: () async {
          clickActions += 1;
        },
      );
      await gateway.shownNotifications.single.onClick?.call();

      expect(clickActions, 1);
      expect(gateway.focusWindowCallCount, 1);
    });

    test(
      'runs click action even when focusing the browser window fails',
      () async {
        final gateway = _FakeBrowserNotificationGateway(
          permission: BrowserNotificationPermission.granted,
          focusError: StateError('focus blocked'),
        );
        final service = BrowserForegroundNotificationService(gateway: gateway);
        var clickActions = 0;

        await service.showPlan(
          _plan(messageId: 'msg-focus-fails'),
          onClick: () async {
            clickActions += 1;
          },
        );
        await gateway.shownNotifications.single.onClick?.call();

        expect(gateway.focusWindowCallCount, 1);
        expect(clickActions, 1);
      },
    );

    test('does not show notification when permission is denied', () async {
      final gateway = _FakeBrowserNotificationGateway(
        permission: BrowserNotificationPermission.denied,
      );
      final service = BrowserForegroundNotificationService(gateway: gateway);

      final result = await service.showPlan(_plan(messageId: 'msg-02'));

      expect(result, BrowserNotificationDelivery.permissionDenied);
      expect(gateway.requestPermissionCallCount, 0);
      expect(gateway.shownNotifications, isEmpty);
    });

    test(
      'returns permissionDenied when requesting browser permission fails',
      () async {
        final gateway = _FakeBrowserNotificationGateway(
          permission: BrowserNotificationPermission.prompt,
          requestPermissionError: StateError('permission API blocked'),
        );
        final service = BrowserForegroundNotificationService(gateway: gateway);

        final result = await service.showPlan(
          _plan(messageId: 'msg-permission-fails'),
        );

        expect(result, BrowserNotificationDelivery.permissionDenied);
        expect(gateway.requestPermissionCallCount, 1);
        expect(gateway.shownNotifications, isEmpty);
      },
    );

    test('returns unsupported when the browser API is unavailable', () async {
      final gateway = _FakeBrowserNotificationGateway(
        isSupported: false,
        permission: BrowserNotificationPermission.granted,
      );
      final service = BrowserForegroundNotificationService(gateway: gateway);

      final result = await service.showPlan(_plan(messageId: 'msg-03'));

      expect(result, BrowserNotificationDelivery.unsupported);
      expect(gateway.shownNotifications, isEmpty);
    });
  });
}

ForegroundNotificationPlan _plan({required String messageId}) {
  return ForegroundNotificationPlan(
    title: 'Alice',
    body: 'Hello',
    payload: jsonEncode(<String, dynamic>{
      'payload': <String, dynamic>{
        'channel_id': 'u_alice',
        'channel_type': 1,
        'message_id': messageId,
      },
      'title': 'Alice',
      'body': 'Hello',
    }),
    channelId: 'wk_new_msg_notification',
    channelName: 'New message notifications',
    importance: Importance.defaultImportance,
  );
}

class _FakeBrowserNotificationGateway implements BrowserNotificationGateway {
  _FakeBrowserNotificationGateway({
    this.isSupported = true,
    required BrowserNotificationPermission permission,
    BrowserNotificationPermission? requestedPermission,
    this.focusError,
    this.requestPermissionError,
  }) : _permission = permission,
       _requestedPermission = requestedPermission ?? permission;

  @override
  final bool isSupported;

  final BrowserNotificationPermission _requestedPermission;
  final List<BrowserNotificationPayload> shownNotifications =
      <BrowserNotificationPayload>[];
  int requestPermissionCallCount = 0;
  int focusWindowCallCount = 0;
  BrowserNotificationPermission _permission;
  final Object? focusError;
  final Object? requestPermissionError;

  @override
  BrowserNotificationPermission get permission => _permission;

  @override
  Future<BrowserNotificationPermission> requestPermission() async {
    requestPermissionCallCount += 1;
    final error = requestPermissionError;
    if (error != null) {
      throw error;
    }
    _permission = _requestedPermission;
    return _permission;
  }

  @override
  Future<void> show(BrowserNotificationPayload notification) async {
    shownNotifications.add(notification);
  }

  @override
  Future<void> focusWindow() async {
    focusWindowCallCount += 1;
    final error = focusError;
    if (error != null) {
      throw error;
    }
  }
}
