import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/providers/conversation_provider.dart';
import '../../platform/browser_startup_recovery_service.dart';
import '../../service/im/im_service.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_tab_shell.dart';
import '../../wukong_push/notification/web_notification_manager.dart';
import '../contacts/contacts_page.dart';
import '../conversation/web_conversation_workspace.dart';
import '../user/user_page.dart';
import 'home_pwa_resume_coordinator.dart';
import 'home_surface_contract.dart';
import 'home_surface_kernel.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({
    super.key,
    this.autoInitializeIM = true,
    this.pagesOverride,
  });

  final bool autoInitializeIM;
  final List<Widget>? pagesOverride;

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  static const List<Widget> _defaultPages = <Widget>[
    WebConversationWorkspace(),
    ContactsPage(),
    UserPage(),
  ];
  static const List<HomeSurfaceId> _sharedBootstrapSurfaces = <HomeSurfaceId>[
    HomeSurfaceId.conversations,
    HomeSurfaceId.contacts,
  ];
  ProviderSubscription<HomeBootstrapState>? _bootstrapSubscription;
  ProviderSubscription<int>? _tabSubscription;
  HomePwaResumeCoordinator? _pwaResumeCoordinator;
  bool _webAlertUnlockDismissed = false;
  bool _webAlertUnlocking = false;

  @override
  void initState() {
    super.initState();
    _bindKernelListeners();
    _scheduleInitialSurfaceVisible();
    final controller = ref.read(homeBootstrapStateProvider.notifier);
    final bootstrap = ref.read(homeBootstrapStateProvider);
    if (!widget.autoInitializeIM) {
      Future.microtask(() {
        if (!mounted) {
          return;
        }
        controller.markReadyWithoutInit();
      });
      return;
    }

    if (kIsWeb) {
      _pwaResumeCoordinator = createHomePwaResumeCoordinator(
        onRecover: _recoverPwaMessageState,
      )..start();
    }

    if (bootstrap.isReady || bootstrap.error != null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final current = ref.read(homeBootstrapStateProvider);
      if (current.isLoading && !current.isReady && current.error == null) {
        _markBootstrapStart();
        controller.initialize();
      }
    });
  }

  void _bindKernelListeners() {
    final kernel = ref.read(homeSurfaceKernelProvider);
    _bootstrapSubscription = ref.listenManual<HomeBootstrapState>(
      homeBootstrapStateProvider,
      (previous, next) {
        if (next.isReady && previous?.isReady != true) {
          _markBootstrapReady();
        } else if (next.error != null && previous?.error != next.error) {
          _markBootstrapFailed();
        }
      },
    );
    _tabSubscription = ref.listenManual<int>(homeCurrentTabIndexProvider, (
      previous,
      next,
    ) {
      if (previous == next) {
        return;
      }
      if (previous != null) {
        kernel.markSurfaceHidden(HomeSurfaceId.values[previous]);
      }
      kernel.markSurfaceVisible(HomeSurfaceId.values[next]);
    });
  }

  void _scheduleInitialSurfaceVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(homeSurfaceKernelProvider)
          .markSurfaceVisible(
            HomeSurfaceId.values[ref.read(homeCurrentTabIndexProvider)],
          );
    });
  }

  void _markBootstrapStart() {
    final kernel = ref.read(homeSurfaceKernelProvider);
    kernel.markBootstrapStart();
    _setSharedSurfaceReliability(SurfaceReliabilityState.stale);
  }

  void _markBootstrapReady() {
    final kernel = ref.read(homeSurfaceKernelProvider);
    kernel.markBootstrapReady();
    _setSharedSurfaceReliability(SurfaceReliabilityState.healthy);
  }

  void _markBootstrapFailed() {
    _setSharedSurfaceReliability(SurfaceReliabilityState.degraded);
  }

  void _setSharedSurfaceReliability(SurfaceReliabilityState state) {
    final kernel = ref.read(homeSurfaceKernelProvider);
    for (final surfaceId in _sharedBootstrapSurfaces) {
      if (kernel.reliabilityFor(surfaceId) == state) {
        continue;
      }
      kernel.markSurfaceReliability(surfaceId, state);
    }
  }

  Future<void> _retryInitialize() async {
    final bootstrap = ref.read(homeBootstrapStateProvider);
    if (bootstrap.isLoading && !bootstrap.isReady) {
      return;
    }
    final recoveryService = ref.read(browserStartupRecoveryServiceProvider);
    final recoveryStarted = await recoveryService.recoverFromStartupFailure();
    if (recoveryStarted || !mounted) {
      return;
    }
    _markBootstrapStart();
    await ref.read(homeBootstrapStateProvider.notifier).initialize();
    if (!mounted || !recoveryService.hasRecoveredStartupFailure) {
      return;
    }
    final nextBootstrap = ref.read(homeBootstrapStateProvider);
    if (nextBootstrap.error != null) {
      await recoveryService.resetDamagedSession();
    }
  }

  @override
  void dispose() {
    _pwaResumeCoordinator?.dispose();
    _bootstrapSubscription?.close();
    _tabSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(homeBootstrapStateProvider);

    if (widget.autoInitializeIM) {
      if (bootstrap.isLoading && !bootstrap.isReady) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (bootstrap.error != null) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey<String>('home-bootstrap-retry-button'),
              onPressed: () {
                unawaited(_retryInitialize());
              },
              child: const Text('重试'),
            ),
          ),
        );
      }
    }

    final badges = ref.watch(homeBadgeSnapshotProvider);
    final pages = widget.pagesOverride ?? _defaultPages;
    final connectionBanner = _HomeConnectionBannerData.from(
      ref.watch(imServiceProvider),
    );
    final showWebAlertUnlockBanner =
        kIsWeb &&
        !_webAlertUnlockDismissed &&
        (!WebNotificationManager.instance.isInitialized ||
            !WebNotificationManager
                .instance
                .capability
                .hasNotificationPermission);

    final shell = WKTabShell(
      currentIndex: ref.watch(homeCurrentTabIndexProvider),
      pages: pages,
      items: <WKTabShellItemData>[
        WKTabShellItemData(
          label: '聊天',
          normalIcon: WKReferenceAssets.tabChatNormal,
          selectedIcon: WKReferenceAssets.tabChatSelected,
          badgeCount: badges.badgeFor(HomeSurfaceId.conversations),
        ),
        WKTabShellItemData(
          label: '联系人',
          normalIcon: WKReferenceAssets.tabContactsNormal,
          selectedIcon: WKReferenceAssets.tabContactsSelected,
          badgeCount: badges.badgeFor(HomeSurfaceId.contacts),
        ),
        WKTabShellItemData(
          label: '我的',
          normalIcon: WKReferenceAssets.tabMineNormal,
          selectedIcon: WKReferenceAssets.tabMineSelected,
        ),
      ],
      onTap: (index) =>
          ref.read(homeCurrentTabIndexProvider.notifier).state = index,
    );

    if (connectionBanner == null && !showWebAlertUnlockBanner) {
      return shell;
    }

    return Stack(
      children: [
        shell,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showWebAlertUnlockBanner)
                  _HomeWebAlertUnlockBanner(
                    unlocking: _webAlertUnlocking,
                    message: WebNotificationManager
                        .instance
                        .capability
                        .bannerMessage,
                    reliabilityMessage: WebNotificationManager
                        .instance
                        .capability
                        .reliabilityMessage,
                    recommendedActions: WebNotificationManager
                        .instance
                        .capability
                        .recommendedActions,
                    diagnosticsMessage: WebNotificationManager
                        .instance
                        .capability
                        .diagnosticsMessage,
                    onEnable: _enableWebMessageAlerts,
                    onDismiss: () {
                      setState(() => _webAlertUnlockDismissed = true);
                    },
                  ),
                if (connectionBanner != null)
                  _HomeConnectionBanner(data: connectionBanner),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _enableWebMessageAlerts() async {
    if (_webAlertUnlocking) {
      return;
    }
    setState(() => _webAlertUnlocking = true);
    await WebNotificationManager.instance.init();
    if (!mounted) {
      return;
    }
    setState(() {
      _webAlertUnlocking = false;
      _webAlertUnlockDismissed =
          WebNotificationManager.instance.capability.hasNotificationPermission;
    });
  }

  Future<void> _recoverPwaMessageState(String reason) async {
    if (!mounted) {
      return;
    }

    try {
      await WebNotificationManager.instance.refreshBackgroundDeliveryState();
      if (!mounted) {
        return;
      }
      await ref.read(imServiceProvider.notifier).init();
      if (!mounted) {
        return;
      }
      await ref.read(conversationProvider.notifier).refreshNow();
    } catch (error, stackTrace) {
      debugPrint('PWA message resume recovery failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _HomeConnectionBannerData {
  const _HomeConnectionBannerData({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  static _HomeConnectionBannerData? from(IMServiceState state) {
    final connected =
        state.isConnected ||
        state.connectionStatus == WKConnectStatus.success ||
        state.connectionStatus == WKConnectStatus.syncCompleted;
    if (connected) {
      return null;
    }

    if (!state.isInitialized && !state.isInitializing && state.error == null) {
      return null;
    }

    switch (state.connectionStatus) {
      case WKConnectStatus.connecting:
        return const _HomeConnectionBannerData(
          message: '正在重连，消息会在连接恢复后发送',
          icon: Icons.sync_rounded,
          color: WKColors.warning,
        );
      case WKConnectStatus.noNetwork:
        return const _HomeConnectionBannerData(
          message: '网络不可用，消息将在恢复后自动同步',
          icon: Icons.wifi_off_rounded,
          color: WKColors.warning,
        );
      case WKConnectStatus.syncMsg:
        return const _HomeConnectionBannerData(
          message: '正在同步离线消息',
          icon: Icons.cloud_sync_rounded,
          color: WKColors.info,
        );
      case WKConnectStatus.kicked:
        return const _HomeConnectionBannerData(
          message: '当前账号已在其他设备登录',
          icon: Icons.error_outline_rounded,
          color: WKColors.danger,
        );
      default:
        return const _HomeConnectionBannerData(
          message: '连接异常，正在等待恢复',
          icon: Icons.info_outline_rounded,
          color: WKColors.warning,
        );
    }
  }
}

class _HomeConnectionBanner extends StatelessWidget {
  const _HomeConnectionBanner({required this.data});

  final _HomeConnectionBannerData data;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: data.message,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          offset: Offset.zero,
          child: Container(
            key: const ValueKey<String>('home-im-connection-banner'),
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(
              horizontal: WKSpace.md,
              vertical: WKSpace.sm,
            ),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                data.color.withValues(alpha: 0.12),
                WKColors.white,
              ),
              border: Border.all(color: data.color.withValues(alpha: 0.28)),
              borderRadius: BorderRadius.circular(WKRadius.lg),
              boxShadow: WKShadows.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon, size: 18, color: data.color),
                const SizedBox(width: WKSpace.xs),
                Expanded(
                  child: Text(
                    data.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: data.color,
                      fontFamily: WKFontFamily.primary,
                      fontFamilyFallback: WKTypography.fontFamilyFallback,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeWebAlertUnlockBanner extends StatelessWidget {
  const _HomeWebAlertUnlockBanner({
    required this.unlocking,
    required this.message,
    required this.reliabilityMessage,
    required this.recommendedActions,
    required this.diagnosticsMessage,
    required this.onEnable,
    required this.onDismiss,
  });

  final bool unlocking;
  final String message;
  final String reliabilityMessage;
  final List<String> recommendedActions;
  final String diagnosticsMessage;
  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('home-web-alert-unlock-banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(
        horizontal: WKSpace.md,
        vertical: WKSpace.sm,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          WKColors.info.withValues(alpha: 0.12),
          WKColors.white,
        ),
        border: Border.all(color: WKColors.info.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 18,
            color: WKColors.info,
          ),
          const SizedBox(width: WKSpace.xs),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: WKColors.info,
                fontFamily: WKFontFamily.primary,
                fontFamilyFallback: WKTypography.fontFamilyFallback,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: unlocking ? null : onEnable,
            child: Text(unlocking ? '开启中' : '开启'),
          ),
          IconButton(
            tooltip: '查看提醒能力',
            onPressed: unlocking
                ? null
                : () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('网页提醒能力'),
                        content: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(reliabilityMessage),
                              const SizedBox(height: WKSpace.sm),
                              Text(diagnosticsMessage),
                              if (recommendedActions.isNotEmpty) ...[
                                const SizedBox(height: WKSpace.md),
                                const Text('建议操作'),
                                const SizedBox(height: WKSpace.xs),
                                for (final action in recommendedActions)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: WKSpace.xs,
                                    ),
                                    child: Text('• $action'),
                                  ),
                              ],
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('知道了'),
                          ),
                        ],
                      ),
                    );
                  },
            icon: const Icon(Icons.info_outline_rounded, size: 18),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: unlocking ? null : onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
