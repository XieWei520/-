import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import 'app_display_preferences.dart';
import '../data/providers/auth_provider.dart';
import '../modules/home/home_badge_snapshot.dart';
import '../modules/home/home_surface_kernel.dart';
import '../modules/video_call/call_coordinator.dart';
import '../core/theme/wk_dark_theme.dart';
import '../widgets/wk_theme.dart';
import '../wukong_push/device_badge_service.dart';
import '../wukong_push/notification/browser_notification_click_bridge.dart';
import '../wukong_push/notification_permission_prompt_bridge.dart';
import '../wukong_scan/scan_qr_code_bridge.dart';
import '../wukong_push/push_service.dart';
import '../wukong_uikit/setting/setting_preferences.dart';
import 'navigation/app_push_route_bridge.dart';
import 'navigation/app_router.dart';

class WuKongApp extends ConsumerStatefulWidget {
  const WuKongApp({super.key});

  @override
  ConsumerState<WuKongApp> createState() => _WuKongAppState();
}

class _WuKongAppState extends ConsumerState<WuKongApp> {
  late final AppPushRouteBridge _pushRouteBridge;
  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<HomeBadgeSnapshot> _badgeSubscription;
  late final DeviceBadgeSyncBridge _deviceBadgeSyncBridge;
  late final BrowserNotificationClickBridge _browserNotificationClickBridge;
  late final NotificationPermissionPromptBridge
  _notificationPermissionPromptBridge;
  bool _flushPendingScheduled = false;

  @override
  void initState() {
    super.initState();
    _deviceBadgeSyncBridge = DeviceBadgeSyncBridge(
      updateBadge: DeviceBadgeService.instance.updateBadge,
      isLoggedIn: () => ref.read(authProvider).isLoggedIn,
    );
    DeviceBadgeService.instance.registerEndpoint();
    _browserNotificationClickBridge = BrowserNotificationClickBridge.instance;
    _browserNotificationClickBridge.start(
      onNotificationClick: PushService.instance.handleNotificationTapPayload,
    );
    _notificationPermissionPromptBridge =
        NotificationPermissionPromptBridge.instance;
    _notificationPermissionPromptBridge.ensureRegistered();
    _pushRouteBridge = AppPushRouteBridge(
      messageEvents: PushService.instance.messageEvents,
      isLoggedIn: () => ref.read(authProvider).isLoggedIn,
      isRestoringSession: () => ref.read(authProvider).isRestoringSession,
      onOpenChat: (intent) {
        ref.read(appRouterProvider).push(intent.location);
      },
    );
    _pushRouteBridge.start(
      consumePendingOpenedEvents:
          PushService.instance.consumePendingOpenedEvents,
    );
    _authSubscription = ref.listenManual<AuthState>(authProvider, (_, next) {
      if (!next.isLoggedIn) {
        _deviceBadgeSyncBridge.reset();
      }
      _scheduleFlushPending();
    });
    _badgeSubscription = ref.listenManual<HomeBadgeSnapshot>(
      homeBadgeSnapshotProvider,
      (_, next) {
        unawaited(_deviceBadgeSyncBridge.sync(next));
      },
    );
    unawaited(_deviceBadgeSyncBridge.sync(ref.read(homeBadgeSnapshotProvider)));
    _scheduleFlushPending();
  }

  @override
  void dispose() {
    _badgeSubscription.close();
    _authSubscription.close();
    unawaited(_browserNotificationClickBridge.dispose());
    unawaited(_pushRouteBridge.dispose());
    super.dispose();
  }

  void _scheduleFlushPending() {
    if (_flushPendingScheduled) {
      return;
    }
    _flushPendingScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushPendingScheduled = false;
      if (!mounted) {
        return;
      }
      _pushRouteBridge.flushPending();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final authState = ref.watch(authProvider);
    ScanQrCodeBridge.instance
      ..ensureRegistered()
      ..bindNavigator(router.routerDelegate.navigatorKey);
    _notificationPermissionPromptBridge.bindNavigator(
      router.routerDelegate.navigatorKey,
    );

    if (authState.isLoggedIn) {
      CallCoordinator.instance.start(router.routerDelegate.navigatorKey);
    } else {
      CallCoordinator.instance.stop();
    }

    return ValueListenableBuilder<int>(
      valueListenable: WKSettingPreferences.appearanceChanges,
      builder: (context, ignoredValue, ignoredChild) {
        final themeMode = switch (WKSettingPreferences.getThemeMode()) {
          WKThemeSettingMode.light => ThemeMode.light,
          WKThemeSettingMode.dark => ThemeMode.dark,
          WKThemeSettingMode.followSystem => ThemeMode.system,
        };

        return MaterialApp.router(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: WKTheme.themeData,
          darkTheme: WKDarkTheme.themeData,
          themeMode: themeMode,
          builder: (context, child) =>
              AppDisplayPreferences(child: child ?? const SizedBox.shrink()),
          locale: const Locale('zh', 'CN'),
          supportedLocales: const <Locale>[Locale('zh', 'CN')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        );
      },
    );
  }
}

typedef WuKongIMApp = WuKongApp;
