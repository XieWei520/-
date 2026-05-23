import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/web_alert_capability.dart';

void main() {
  test('desktop web copy explains browser and system controlled alerts', () {
    final capability = buildWebAlertCapability(
      userAgent:
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124',
      standalone: false,
      notificationPermission: 'default',
      supportsNotification: true,
      supportsServiceWorker: true,
      supportsPush: true,
      secureContext: true,
    );

    expect(capability.platform, WebAlertPlatform.desktop);
    expect(capability.bannerMessage, contains('电脑网页消息提醒'));
    expect(capability.diagnosticsMessage, contains('电脑浏览器'));
    expect(
      capability.backgroundReliability,
      WebAlertBackgroundReliability.pageAliveOnly,
    );
    expect(capability.recommendedActions, contains('点击“开启”并在浏览器权限弹窗中选择允许通知'));
    expect(capability.canAskForNotificationPermission, isTrue);
  });

  test('Android browser copy recommends installing PWA', () {
    final capability = buildWebAlertCapability(
      userAgent:
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/124 Mobile',
      standalone: false,
      notificationPermission: 'default',
      supportsNotification: true,
      supportsServiceWorker: true,
      supportsPush: true,
      secureContext: true,
    );

    expect(capability.platform, WebAlertPlatform.android);
    expect(capability.installMode, WebAlertInstallMode.browserTab);
    expect(capability.bannerMessage, contains('建议安装到桌面'));
    expect(capability.diagnosticsMessage, contains('Android 手机浏览器'));
    expect(
      capability.recommendedActions,
      contains('Android 手机建议安装到桌面并从桌面图标打开'),
    );
  });

  test('Android PWA copy states browser notification handoff', () {
    final capability = buildWebAlertCapability(
      userAgent:
          'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/124 Mobile',
      standalone: true,
      notificationPermission: 'granted',
      supportsNotification: true,
      supportsServiceWorker: true,
      supportsPush: true,
      secureContext: true,
    );

    expect(capability.platform, WebAlertPlatform.android);
    expect(capability.installMode, WebAlertInstallMode.standalone);
    expect(capability.bannerMessage, contains('手机 PWA 消息提醒'));
    expect(capability.hasNotificationPermission, isTrue);
    expect(
      capability.backgroundReliability,
      WebAlertBackgroundReliability.webPushReady,
    );
    expect(capability.reliabilityMessage, contains('后台系统通知基础能力'));
  });

  test('iPhone Safari copy states ordinary tab background limit', () {
    final capability = buildWebAlertCapability(
      userAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 Version/17.4 Mobile Safari/604.1',
      standalone: false,
      notificationPermission: 'default',
      supportsNotification: true,
      supportsServiceWorker: true,
      supportsPush: false,
      secureContext: true,
    );

    expect(capability.platform, WebAlertPlatform.apple);
    expect(capability.bannerMessage, contains('Safari 普通标签页后台不可靠'));
    expect(capability.diagnosticsMessage, contains('添加到主屏幕'));
    expect(
      capability.backgroundReliability,
      WebAlertBackgroundReliability.foregroundOnly,
    );
    expect(
      capability.recommendedActions,
      contains('iPhone 普通 Safari 标签页后台不可靠，请添加到主屏幕使用'),
    );
  });

  test('iPhone Home Screen PWA copy allows system notification guidance', () {
    final capability = buildWebAlertCapability(
      userAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 Version/17.4 Mobile Safari/604.1',
      standalone: true,
      notificationPermission: 'granted',
      supportsNotification: true,
      supportsServiceWorker: true,
      supportsPush: true,
      secureContext: true,
    );

    expect(capability.platform, WebAlertPlatform.apple);
    expect(capability.installMode, WebAlertInstallMode.standalone);
    expect(capability.bannerMessage, contains('iPhone 主屏 Web App 提醒'));
    expect(capability.diagnosticsMessage, isNot(contains('普通 Safari')));
    expect(
      capability.backgroundReliability,
      WebAlertBackgroundReliability.webPushReady,
    );
  });

  test('insecure context explains HTTPS requirement', () {
    final capability = buildWebAlertCapability(
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      standalone: false,
      notificationPermission: 'default',
      supportsNotification: true,
      supportsServiceWorker: true,
      supportsPush: true,
      secureContext: false,
    );

    expect(capability.canAskForNotificationPermission, isFalse);
    expect(capability.bannerMessage, contains('不是 HTTPS'));
    expect(capability.diagnosticsMessage, contains('需要 HTTPS'));
    expect(
      capability.recommendedActions,
      contains('使用 HTTPS 访问，非安全页面无法完整启用通知和 Service Worker'),
    );
  });

  test('denied notification permission recommends browser settings', () {
    final capability = buildWebAlertCapability(
      userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      standalone: false,
      notificationPermission: 'denied',
      supportsNotification: true,
      supportsServiceWorker: true,
      supportsPush: true,
      secureContext: true,
    );

    expect(capability.canAskForNotificationPermission, isFalse);
    expect(capability.isNotificationPermissionDenied, isTrue);
    expect(capability.bannerMessage, contains('已被浏览器拦截'));
    expect(capability.recommendedActions, contains('已被浏览器拦截通知，请到浏览器站点设置中改为允许'));
  });
}
