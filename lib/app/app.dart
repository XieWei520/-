import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import 'app_display_preferences.dart';
import '../data/providers/auth_provider.dart';
import '../modules/home/home_badge_snapshot.dart';
import '../modules/home/home_surface_kernel.dart';
import '../modules/local_monitor/local_monitor_auto_forward_coordinator.dart';
import '../modules/local_monitor/local_monitor_auto_forward_runner_factory.dart'
    deferred as local_monitor_runners;
import '../modules/launch_policy/launch_policy_controller.dart';
import '../modules/launch_policy/launch_policy_dialogs.dart';
import '../modules/video_call/video_call_runtime_bridge.dart';
import '../core/theme/wk_dark_theme.dart';
import '../widgets/wk_theme.dart';
import '../wukong_push/android_keep_alive_service.dart';
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
  late final LocalMonitorAutoForwardCoordinator
  _localMonitorAutoForwardCoordinator;
  late final LaunchPolicyController _launchPolicyController;
  GoRouter? _boundRouter;
  bool _callCoordinatorRunning = false;
  bool _flushPendingScheduled = false;
  bool _launchPolicyCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _deviceBadgeSyncBridge = DeviceBadgeSyncBridge(
      updateBadge: DeviceBadgeService.instance.updateBadge,
      isLoggedIn: () => ref.read(authProvider).isLoggedIn,
    );
    DeviceBadgeService.instance.registerEndpoint();
    AndroidKeepAliveService.instance.registerEndpoint();
    _browserNotificationClickBridge = BrowserNotificationClickBridge.instance;
    _browserNotificationClickBridge.start(
      onNotificationClick: PushService.instance.handleNotificationTapPayload,
    );
    _notificationPermissionPromptBridge =
        NotificationPermissionPromptBridge.instance;
    _notificationPermissionPromptBridge.ensureRegistered();
    _localMonitorAutoForwardCoordinator = LocalMonitorAutoForwardCoordinator(
      loadRunners: _loadLocalMonitorAutoForwardRunners,
    );
    _launchPolicyController = LaunchPolicyController();
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
      _syncCallCoordinator(next.isLoggedIn);
      _syncLocalMonitorAutoForwarding(next.isLoggedIn);
      _scheduleFlushPending();
    });
    _badgeSubscription = ref.listenManual<HomeBadgeSnapshot>(
      homeBadgeSnapshotProvider,
      (_, next) {
        unawaited(_deviceBadgeSyncBridge.sync(next));
      },
    );
    unawaited(_deviceBadgeSyncBridge.sync(ref.read(homeBadgeSnapshotProvider)));
    _syncLocalMonitorAutoForwarding(ref.read(authProvider).isLoggedIn);
    _scheduleFlushPending();
    _scheduleLaunchPolicyCheck();
  }

  void _bindRouterSideEffects(GoRouter router) {
    if (identical(_boundRouter, router)) {
      return;
    }
    _boundRouter = router;
    final navigatorKey = router.routerDelegate.navigatorKey;
    ScanQrCodeBridge.instance
      ..ensureRegistered()
      ..bindNavigator(navigatorKey);
    _notificationPermissionPromptBridge.bindNavigator(navigatorKey);
    if (_callCoordinatorRunning) {
      unawaited(VideoCallRuntimeBridge.instance.startCoordinator(navigatorKey));
    }
  }

  void _syncCallCoordinator(bool isLoggedIn) {
    final router = _boundRouter;
    if (isLoggedIn) {
      if (router == null) {
        return;
      }
      if (!_callCoordinatorRunning) {
        unawaited(
          VideoCallRuntimeBridge.instance.startCoordinator(
            router.routerDelegate.navigatorKey,
          ),
        );
        _callCoordinatorRunning = true;
      }
      return;
    }
    if (_callCoordinatorRunning) {
      unawaited(VideoCallRuntimeBridge.instance.stopCoordinator());
      _callCoordinatorRunning = false;
    }
  }

  void _syncLocalMonitorAutoForwarding(bool isLoggedIn) {
    _localMonitorAutoForwardCoordinator.syncLoggedIn(isLoggedIn);
  }

  @override
  void dispose() {
    _badgeSubscription.close();
    _authSubscription.close();
    unawaited(_browserNotificationClickBridge.dispose());
    unawaited(_pushRouteBridge.dispose());
    if (_callCoordinatorRunning) {
      unawaited(VideoCallRuntimeBridge.instance.stopCoordinator());
      _callCoordinatorRunning = false;
    }
    _localMonitorAutoForwardCoordinator.dispose();
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

  void _scheduleLaunchPolicyCheck() {
    if (_launchPolicyCheckScheduled) {
      return;
    }
    _launchPolicyCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final decision = await _launchPolicyController.checkLaunchPolicy();
      if (!mounted) {
        return;
      }
      final dialogContext = resolveLaunchPolicyDialogContext(
        appContext: context,
        router: _boundRouter ?? ref.read(appRouterProvider),
      );
      if (dialogContext == null) {
        return;
      }
      switch (decision.type) {
        case LaunchPolicyDecisionType.forceUpgrade:
          final policy = decision.versionPolicy;
          if (policy != null) {
            if (!dialogContext.mounted) {
              return;
            }
            await showForcedUpgradeDialog(dialogContext, policy: policy);
          }
        case LaunchPolicyDecisionType.showNotice:
          final notice = decision.startupNotice;
          if (notice != null) {
            if (!dialogContext.mounted) {
              return;
            }
            await showStartupNoticeDialog(dialogContext, notice: notice);
            await _launchPolicyController.markNoticeShown(notice);
          }
        case LaunchPolicyDecisionType.none:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final authState = ref.watch(authProvider);
    _bindRouterSideEffects(router);
    _syncCallCoordinator(authState.isLoggedIn);

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

Future<List<LocalMonitorAutoForwardRunnerController>>
_loadLocalMonitorAutoForwardRunners() async {
  await local_monitor_runners.loadLibrary();
  return local_monitor_runners.createDefaultLocalMonitorAutoForwardRunners();
}

BuildContext? resolveLaunchPolicyDialogContext({
  required BuildContext appContext,
  required GoRouter router,
}) {
  final navigatorContext = router.routerDelegate.navigatorKey.currentContext;
  if (navigatorContext != null &&
      Localizations.of<MaterialLocalizations>(
            navigatorContext,
            MaterialLocalizations,
          ) !=
          null) {
    return navigatorContext;
  }
  if (Localizations.of<MaterialLocalizations>(
        appContext,
        MaterialLocalizations,
      ) !=
      null) {
    return appContext;
  }
  return null;
}
