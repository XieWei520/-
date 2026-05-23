enum WebAlertPlatform { desktop, android, apple, otherMobile, unknown }

enum WebAlertInstallMode { browserTab, standalone }

enum WebAlertBackgroundReliability {
  foregroundOnly,
  pageAliveOnly,
  webPushReady,
}

class WebAlertCapability {
  const WebAlertCapability({
    required this.platform,
    required this.installMode,
    required this.notificationPermission,
    required this.supportsNotification,
    required this.supportsServiceWorker,
    required this.supportsPush,
    required this.secureContext,
  });

  final WebAlertPlatform platform;
  final WebAlertInstallMode installMode;
  final String notificationPermission;
  final bool supportsNotification;
  final bool supportsServiceWorker;
  final bool supportsPush;
  final bool secureContext;

  bool get canAskForNotificationPermission {
    return supportsNotification &&
        secureContext &&
        notificationPermission == 'default';
  }

  bool get hasNotificationPermission => notificationPermission == 'granted';

  bool get isNotificationPermissionDenied => notificationPermission == 'denied';

  bool get canUseServiceWorkerPush {
    return secureContext &&
        supportsNotification &&
        supportsServiceWorker &&
        supportsPush &&
        hasNotificationPermission;
  }

  WebAlertBackgroundReliability get backgroundReliability {
    if (platform == WebAlertPlatform.apple &&
        installMode == WebAlertInstallMode.browserTab) {
      return WebAlertBackgroundReliability.foregroundOnly;
    }
    if (canUseServiceWorkerPush) {
      return WebAlertBackgroundReliability.webPushReady;
    }
    return WebAlertBackgroundReliability.pageAliveOnly;
  }

  String get bannerMessage {
    if (!secureContext) {
      return '当前网页不是 HTTPS，无法完整启用后台消息提醒';
    }
    if (!supportsNotification) {
      return '当前浏览器不支持系统通知，只能进行前台网页提醒';
    }
    if (isNotificationPermissionDenied) {
      return '网页通知已被浏览器拦截，请在站点设置中允许通知';
    }
    return switch (platform) {
      WebAlertPlatform.desktop => '点击开启电脑网页消息提醒；后台通知由浏览器和系统控制',
      WebAlertPlatform.android =>
        installMode == WebAlertInstallMode.standalone
            ? '点击开启手机 PWA 消息提醒；切后台后由浏览器通知接管'
            : '点击开启手机网页提醒；建议安装到桌面提升后台提醒稳定性',
      WebAlertPlatform.apple =>
        installMode == WebAlertInstallMode.standalone
            ? '点击开启 iPhone 主屏 Web App 提醒；后台通知需系统授权'
            : 'iPhone Safari 普通标签页后台不可靠；添加到主屏幕后再开启提醒',
      WebAlertPlatform.otherMobile => '点击开启手机网页提醒；后台能力取决于浏览器和系统限制',
      WebAlertPlatform.unknown => '点击开启网页消息提醒，后台通知由浏览器和系统控制',
    };
  }

  String get reliabilityMessage {
    return switch (backgroundReliability) {
      WebAlertBackgroundReliability.webPushReady =>
        '当前浏览器已具备后台系统通知基础能力。浏览器关闭或系统免打扰时仍由系统策略决定。',
      WebAlertBackgroundReliability.pageAliveOnly =>
        '当前只能增强页面存活时的提醒；浏览器关闭、页面被冻结或系统限制后台时无法保证声音。',
      WebAlertBackgroundReliability.foregroundOnly =>
        '当前普通 iPhone Safari 标签页只能保证前台提醒；后台提醒请添加到主屏幕后再开启。',
    };
  }

  List<String> get recommendedActions {
    final actions = <String>[];

    if (!secureContext) {
      actions.add('使用 HTTPS 访问，非安全页面无法完整启用通知和 Service Worker');
    }
    if (!supportsNotification) {
      actions.add('当前浏览器不支持系统通知，建议更换 Chrome、Edge、Safari 或系统浏览器');
    } else if (notificationPermission == 'default') {
      actions.add('点击“开启”并在浏览器权限弹窗中选择允许通知');
    } else if (notificationPermission == 'denied') {
      actions.add('已被浏览器拦截通知，请到浏览器站点设置中改为允许');
    }
    if (!supportsServiceWorker) {
      actions.add('当前浏览器不支持 Service Worker，后台 Web Push 无法接管');
    }
    if (!supportsPush) {
      actions.add('当前浏览器未开放 Web Push API，后台推送能力受限');
    }

    switch (platform) {
      case WebAlertPlatform.android:
        if (installMode == WebAlertInstallMode.browserTab) {
          actions.add('Android 手机建议安装到桌面并从桌面图标打开');
        }
        actions.add('确认浏览器和系统通知没有被关闭，省电策略不要限制浏览器后台');
        break;
      case WebAlertPlatform.apple:
        if (installMode == WebAlertInstallMode.browserTab) {
          actions.add('iPhone 普通 Safari 标签页后台不可靠，请添加到主屏幕使用');
        } else {
          actions.add('确认是从主屏幕图标打开，并在系统通知设置中允许提醒');
        }
        break;
      case WebAlertPlatform.desktop:
        actions.add('确认浏览器站点通知和电脑系统通知均已允许');
        break;
      case WebAlertPlatform.otherMobile:
        actions.add('建议安装为 PWA；嵌入式浏览器通常只能作为前台提醒');
        break;
      case WebAlertPlatform.unknown:
        actions.add('确认浏览器支持通知、Service Worker 和 Push API');
        break;
    }

    return actions;
  }

  String get diagnosticsMessage {
    final parts = <String>[
      switch (platform) {
        WebAlertPlatform.desktop => '当前环境：电脑浏览器',
        WebAlertPlatform.android =>
          installMode == WebAlertInstallMode.standalone
              ? '当前环境：Android PWA'
              : '当前环境：Android 手机浏览器',
        WebAlertPlatform.apple =>
          installMode == WebAlertInstallMode.standalone
              ? '当前环境：Apple 主屏 Web App'
              : '当前环境：Apple Safari 普通网页',
        WebAlertPlatform.otherMobile => '当前环境：手机浏览器',
        WebAlertPlatform.unknown => '当前环境：网页',
      },
      supportsNotification ? '支持系统通知' : '不支持系统通知',
      supportsServiceWorker ? '支持 Service Worker' : '不支持 Service Worker',
      supportsPush ? '具备 Web Push API' : '未检测到 Web Push API',
      secureContext ? '安全上下文正常' : '需要 HTTPS 才能完整启用提醒',
      reliabilityMessage,
    ];

    if (platform == WebAlertPlatform.apple &&
        installMode == WebAlertInstallMode.browserTab) {
      parts.add('普通 Safari 标签页后台提醒不稳定，请添加到主屏幕');
    }
    if (platform == WebAlertPlatform.android &&
        installMode == WebAlertInstallMode.browserTab) {
      parts.add('建议安装 PWA，并允许浏览器通知');
    }
    if (!hasNotificationPermission) {
      parts.add(
        canAskForNotificationPermission ? '点击开启后请求通知权限' : '请在浏览器设置中允许通知',
      );
    }
    parts.addAll(recommendedActions);
    return parts.join('；');
  }
}

WebAlertCapability buildWebAlertCapability({
  required String userAgent,
  required bool standalone,
  required String notificationPermission,
  required bool supportsNotification,
  required bool supportsServiceWorker,
  required bool supportsPush,
  required bool secureContext,
}) {
  return WebAlertCapability(
    platform: detectWebAlertPlatform(userAgent),
    installMode: standalone
        ? WebAlertInstallMode.standalone
        : WebAlertInstallMode.browserTab,
    notificationPermission: notificationPermission,
    supportsNotification: supportsNotification,
    supportsServiceWorker: supportsServiceWorker,
    supportsPush: supportsPush,
    secureContext: secureContext,
  );
}

WebAlertPlatform detectWebAlertPlatform(String userAgent) {
  final normalized = userAgent.toLowerCase();
  if (_containsAny(normalized, const <String>['iphone', 'ipad', 'ipod'])) {
    return WebAlertPlatform.apple;
  }
  if (normalized.contains('android')) {
    return WebAlertPlatform.android;
  }
  if (_containsAny(normalized, const <String>[
    'mobile',
    'phone',
    'windows phone',
  ])) {
    return WebAlertPlatform.otherMobile;
  }
  if (_containsAny(normalized, const <String>[
    'windows',
    'macintosh',
    'linux',
    'cros',
  ])) {
    return WebAlertPlatform.desktop;
  }
  return WebAlertPlatform.unknown;
}

bool _containsAny(String value, List<String> tokens) {
  for (final token in tokens) {
    if (value.contains(token)) {
      return true;
    }
  }
  return false;
}
