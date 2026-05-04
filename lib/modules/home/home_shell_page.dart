import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../service/im/im_service.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_tab_shell.dart';
import '../contacts/contacts_page.dart';
import '../conversation/web_conversation_workspace.dart';
import '../user/user_page.dart';
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

  void _retryInitialize() {
    final bootstrap = ref.read(homeBootstrapStateProvider);
    if (bootstrap.isLoading && !bootstrap.isReady) {
      return;
    }
    _markBootstrapStart();
    ref.read(homeBootstrapStateProvider.notifier).initialize();
  }

  @override
  void dispose() {
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
              onPressed: _retryInitialize,
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

    if (connectionBanner == null) {
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
            child: _HomeConnectionBanner(data: connectionBanner),
          ),
        ),
      ],
    );
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

    if (!state.isInitialized && !state.isInitializing) {
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
