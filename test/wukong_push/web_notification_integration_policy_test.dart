import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'IMService forwards incoming messages to the shared web alert contract',
    () {
      final source = File('lib/service/im/im_service.dart').readAsStringSync();
      final bridgeSource = File(
        'lib/service/im/im_notification_bridge.dart',
      ).readAsStringSync();

      expect(source, contains('im_notification_bridge.dart'));
      expect(source, contains('_notificationBridge.scheduleMessageAlert'));
      expect(source, contains('lifecycleState: _appLifecycleState'));
      expect(bridgeSource, contains('web_notification_manager.dart'));
      expect(bridgeSource, contains('buildMessageAlertPlan'));
      expect(bridgeSource, contains('webNotifications.showNewMessageAlert'));
      expect(bridgeSource, contains('plan: plan'));
    },
  );

  test(
    'login submit initializes the web notification manager from user gesture',
    () {
      final source = File(
        'lib/modules/auth/presentation/pages/auth_login_page.dart',
      ).readAsStringSync();

      expect(source, contains('web_notification_manager.dart'));
      expect(source, contains('WebNotificationManager.instance.init'));
      expect(source, contains('triggeredByAutoLogin'));
    },
  );

  test('home shell exposes a web alert unlock action after auto login', () {
    final source = File(
      'lib/modules/home/home_shell_page.dart',
    ).readAsStringSync();

    expect(source, contains('web_notification_manager.dart'));
    expect(source, contains('home-web-alert-unlock-banner'));
    expect(source, contains('.bannerMessage'));
    expect(source, contains('reliabilityMessage:'));
    expect(source, contains('recommendedActions:'));
    expect(source, contains('capability'));
    expect(source, contains('查看提醒能力'));
    expect(source, contains('建议操作'));
    expect(source, contains('WebNotificationManager.instance.init'));
    expect(source, contains('hasNotificationPermission'));
  });

  test(
    'web notification implementation uses package web and never dart html',
    () {
      final source = File(
        'lib/wukong_push/notification/web_notification_manager_web.dart',
      ).readAsStringSync();

      expect(source, contains("import 'package:web/web.dart' as web;"));
      expect(source, contains('WebAlertCapability'));
      expect(source, contains('serviceWorker'));
      expect(source, contains('PushManager'));
      expect(source, contains('isSecureContext'));
      expect(source, contains('display-mode: standalone'));
      expect(source, contains('_readNotificationPermission'));
      expect(
        source,
        contains('notificationPermission => _readNotificationPermission()'),
      );
      expect(source, contains('pushManager.subscribe'));
      expect(source, contains('applicationServerKey'));
      expect(source, contains('registerWebPushSubscription'));
      expect(source, isNot(contains('dart:html')));
    },
  );

  test('web notifications mirror the desktop alert policy', () {
    final source = File(
      'lib/wukong_push/notification/web_notification_manager_web.dart',
    ).readAsStringSync();

    expect(source, contains('DesktopMessageAlertPolicy'));
    expect(source, contains('MessageAlertPlan'));
    expect(source, contains('messageSoundAssetPath'));
    expect(source, contains('HTMLAudioElement'));
    expect(source, contains('_unlockHtmlAudioElementsForIos'));
    expect(source, contains('_playHtmlAudioElement'));
    expect(source, contains(r'assets/assets/$normalized'));
    expect(source, contains('await _playMessageSound();'));
    expect(source, isNot(contains('silent: true')));
    expect(source, contains('silent: false'));
    expect(source, contains('data: notification.payload.toJS'));
    expect(source, contains("web.window.postMessage"));
    expect(source, contains('browserNotification.onclick'));
    expect(source, contains('web.window.focus()'));
    expect(source, isNot(contains('startTitleBlink();')));
  });

  test('PWA service worker displays background push notifications', () {
    final source = File('web/wk_pwa_service_worker.js').readAsStringSync();

    expect(source, contains("self.addEventListener('push'"));
    expect(source, contains('event.data.json()'));
    expect(source, contains('self.registration.showNotification'));
    expect(source, contains('renotify: true'));
    expect(source, contains('vibrate:'));
    expect(source, contains('badge:'));
    expect(source, isNot(contains('silent: true')));
  });

  test(
    'PWA notification click routes existing windows to safe same-origin URL',
    () {
      final source = File('web/wk_pwa_service_worker.js').readAsStringSync();

      expect(source, contains('normalizeNotificationClickUrl'));
      expect(source, contains('url.origin !== self.location.origin'));
      expect(source, contains('resolveConversationRoute'));
      expect(
        source,
        contains(
          r'/chat/${encodeURIComponent(channelType)}/${encodeURIComponent(channelId)}',
        ),
      );
      expect(source, contains('resolveNotificationClickTarget'));
      expect(source, contains('return client.navigate(targetUrl).then'));
      expect(source, contains('client.postMessage'));
      expect(source, contains('self.clients.openWindow(targetUrl)'));
    },
  );

  test('pubspec declares bundled notification audio assets', () {
    final source = File('pubspec.yaml').readAsStringSync();

    expect(source, contains('- assets/audio/'));
  });

  test('web push API client exposes VAPID config and subscription upload', () {
    final source = File('lib/service/api/web_push_api.dart').readAsStringSync();
    final config = File('lib/core/config/api_config.dart').readAsStringSync();

    expect(source, contains('class WebPushApi'));
    expect(source, contains('getWebPushConfig'));
    expect(source, contains('registerWebPushSubscription'));
    expect(source, contains('deleteWebPushSubscription'));
    expect(source, contains('updateWebPushClientState'));
    expect(source, contains('class WebPushClientState'));
    expect(source, contains('endpoint'));
    expect(source, contains('p256dh'));
    expect(source, contains('auth'));
    expect(config, contains('webPushConfig'));
    expect(config, contains('webPushSubscription'));
    expect(config, contains('webPushClientState'));
  });

  test(
    'web notification manager reports page lifecycle for Web Push reliability',
    () {
      final source = File(
        'lib/wukong_push/notification/web_notification_manager_web.dart',
      ).readAsStringSync();

      expect(source, contains('visibilitychange'));
      expect(source, contains('pagehide'));
      expect(source, contains('_visibleHeartbeatTimer'));
      expect(source, contains('_startVisibleHeartbeat'));
      expect(source, contains('_stopVisibleHeartbeat'));
      expect(source, contains('refreshBackgroundDeliveryState'));
      expect(source, contains('_reportWebPushClientState'));
      expect(source, contains('updateWebPushClientState'));
      expect(source, contains('_ensureWebPushSubscription'));
    },
  );

  test('home shell coordinates iOS PWA resume recovery', () {
    final shell = File(
      'lib/modules/home/home_shell_page.dart',
    ).readAsStringSync();
    final coordinator = File(
      'lib/modules/home/home_pwa_resume_coordinator_web.dart',
    ).readAsStringSync();
    final contract = File(
      'lib/modules/home/home_pwa_resume_coordinator_contract.dart',
    ).readAsStringSync();
    final export = File(
      'lib/modules/home/home_pwa_resume_coordinator.dart',
    ).readAsStringSync();
    final stub = File(
      'lib/modules/home/home_pwa_resume_coordinator_stub.dart',
    ).readAsStringSync();

    expect(shell, contains('home_pwa_resume_coordinator.dart'));
    expect(shell, contains('HomePwaResumeCoordinator'));
    expect(
      shell,
      contains(
        'WebNotificationManager.instance.refreshBackgroundDeliveryState',
      ),
    );
    expect(shell, contains('imServiceProvider.notifier'));
    expect(shell, contains('conversationProvider.notifier'));
    expect(shell, contains('refreshNow'));
    expect(coordinator, contains('visibilitychange'));
    expect(coordinator, contains('pageshow'));
    expect(coordinator, contains('focus'));
    expect(coordinator, contains('online'));
    expect(coordinator, contains("addEventListener("));
    expect(coordinator, contains("'message'"));
    expect(coordinator, contains('wk.push.subscriptionchange'));
    expect(coordinator, contains('wk.notification.click'));
    expect(coordinator, contains('resumeThrottle'));
    expect(coordinator, contains('triggerRecovery'));
    expect(export, contains("if (dart.library.js_interop)"));
    expect(contract, contains('typedef HomePwaResumeRecovery'));
    expect(stub, contains('NoopHomePwaResumeCoordinator'));
  });

  test(
    'PWA service worker asks clients to recover stale push subscriptions',
    () {
      final source = File('web/wk_pwa_service_worker.js').readAsStringSync();

      expect(
        source,
        contains("self.addEventListener('pushsubscriptionchange'"),
      );
      expect(source, contains('broadcastClientMessage'));
      expect(source, contains('wk.push.subscriptionchange'));
      expect(source, contains('includeUncontrolled: true'));
      expect(source, contains('client.postMessage'));
    },
  );

  test('backend exposes Redis backed Web Push subscription endpoints', () {
    final userApi = File(
      '.codex-backend-work/src/modules/user/api.go',
    ).readAsStringSync();
    final common = File(
      '.codex-backend-work/src/serverlib/common/constant.go',
    ).readAsStringSync();

    expect(userApi, contains('/web_push/config'));
    expect(userApi, contains('/web_push/subscription'));
    expect(userApi, contains('/web_push/client_state'));
    expect(userApi, contains('registerWebPushSubscription'));
    expect(userApi, contains('unregisterWebPushSubscription'));
    expect(userApi, contains('updateWebPushClientState'));
    expect(userApi, contains('WK_WEB_PUSH_VAPID_PUBLIC_KEY'));
    expect(common, contains('UserWebPushSubscriptionPrefix'));
  });

  test('backend sends Web Push from offline message webhook path', () {
    final webhookApi = File(
      '.codex-backend-work/src/modules/webhook/api.go',
    ).readAsStringSync();
    final webPush = File(
      '.codex-backend-work/src/modules/webhook/push_webpush.go',
    ).readAsStringSync();
    final goMod = File('.codex-backend-work/src/go.mod').readAsStringSync();

    expect(webhookApi, contains('pushWebPush'));
    expect(webhookApi, contains('UserWebPushSubscriptionPrefix'));
    expect(webPush, contains('WK_WEB_PUSH_VAPID_PRIVATE_KEY'));
    expect(webPush, contains('webpush.SendNotification'));
    expect(webPush, contains('webPushTTLSeconds'));
    expect(webPush, contains('pushWebPushToBackgroundSubscriptions'));
    expect(webPush, contains('channel_id'));
    expect(webPush, contains('channel_type'));
    expect(webPush, contains('message_id'));
    expect(webPush, contains('信息平权'));
    expect(webPush, contains('收到一条新消息'));
    expect(goMod, contains('github.com/SherClockHolmes/webpush-go'));
  });
}
