import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_tab_shell.dart';
import '../contacts/contacts_page.dart';
import '../conversation/conversation_list_page.dart';
import '../user/user_page.dart';
import 'home_surface_contract.dart';
import 'home_surface_kernel.dart';

class HomeShellPage extends ConsumerStatefulWidget {
  const HomeShellPage({super.key, this.autoInitializeIM = true, this.pagesOverride});

  final bool autoInitializeIM;
  final List<Widget>? pagesOverride;

  @override
  ConsumerState<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends ConsumerState<HomeShellPage> {
  static const List<Widget> _defaultPages = <Widget>[
    ConversationListPage(),
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
    _tabSubscription = ref.listenManual<int>(
      homeCurrentTabIndexProvider,
      (previous, next) {
        if (previous == next) {
          return;
        }
        if (previous != null) {
          kernel.markSurfaceHidden(HomeSurfaceId.values[previous]);
        }
        kernel.markSurfaceVisible(HomeSurfaceId.values[next]);
      },
    );
  }

  void _scheduleInitialSurfaceVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(homeSurfaceKernelProvider).markSurfaceVisible(
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
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (bootstrap.error != null) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: _retryInitialize,
              child: const Text('Retry'),
            ),
          ),
        );
      }
    }

    final badges = ref.watch(homeBadgeSnapshotProvider);
    final pages = widget.pagesOverride ?? _defaultPages;

    return WKTabShell(
      currentIndex: ref.watch(homeCurrentTabIndexProvider),
      pages: pages,
      items: <WKTabShellItemData>[
        WKTabShellItemData(
          label: 'Chats',
          normalIcon: WKReferenceAssets.tabChatNormal,
          selectedIcon: WKReferenceAssets.tabChatSelected,
          badgeCount: badges.badgeFor(HomeSurfaceId.conversations),
        ),
        WKTabShellItemData(
          label: 'Contacts',
          normalIcon: WKReferenceAssets.tabContactsNormal,
          selectedIcon: WKReferenceAssets.tabContactsSelected,
          badgeCount: badges.badgeFor(HomeSurfaceId.contacts),
        ),
        WKTabShellItemData(
          label: 'Me',
          normalIcon: WKReferenceAssets.tabMineNormal,
          selectedIcon: WKReferenceAssets.tabMineSelected,
        ),
      ],
      onTap: (index) =>
          ref.read(homeCurrentTabIndexProvider.notifier).state = index,
    );
  }
}
