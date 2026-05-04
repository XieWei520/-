import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/providers/conversation_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../service/api/friend_api.dart';
import '../../service/im/im_service.dart';
import '../../wukong_base/db/contacts_db.dart';
import 'home_badge_snapshot.dart';
import 'home_surface_contract.dart';

typedef HomeKernelLogEvent = void Function(String event);

class HomeSurfaceKernel {
  HomeSurfaceKernel({HomeKernelLogEvent? logEvent})
    : _logEvent = logEvent ?? _noopLogEvent;

  static void _noopLogEvent(String _) {}

  final HomeKernelLogEvent _logEvent;
  final Map<HomeSurfaceId, SurfaceReliabilityState> _reliability =
      <HomeSurfaceId, SurfaceReliabilityState>{
        for (final surface in HomeSurfaceId.values)
          surface: SurfaceReliabilityState.healthy,
      };

  void markBootstrapStart() => _logEvent('home_bootstrap_start');

  void markBootstrapReady() => _logEvent('home_bootstrap_ready');

  void markSurfaceVisible(HomeSurfaceId surfaceId) {
    _logEvent('surface_visible:${surfaceId.name}');
  }

  void markSurfaceHidden(HomeSurfaceId surfaceId) {
    _logEvent('surface_hidden:${surfaceId.name}');
  }

  void markSurfaceReliability(
    HomeSurfaceId surfaceId,
    SurfaceReliabilityState state,
  ) {
    _reliability[surfaceId] = state;
    _logEvent('surface_${state.name}:${surfaceId.name}');
  }

  SurfaceReliabilityState reliabilityFor(HomeSurfaceId surfaceId) {
    return _reliability[surfaceId] ?? SurfaceReliabilityState.healthy;
  }
}

final homeSurfaceKernelProvider = Provider<HomeSurfaceKernel>((ref) {
  return HomeSurfaceKernel();
});

typedef HomeConversationBootstrapRefresher = Future<void> Function();
typedef HomeContactsBootstrapRefresher = Future<void> Function();

@visibleForTesting
bool shouldPersistHomeContactsLocally({required bool isWeb}) => !isWeb;

final homeShouldPersistContactsLocallyProvider = Provider<bool>((ref) {
  return shouldPersistHomeContactsLocally(isWeb: kIsWeb);
});

final homeConversationBootstrapRefresherProvider =
    Provider<HomeConversationBootstrapRefresher>((ref) {
      return () async {
        await ref.read(conversationProvider.notifier).refreshNow();
      };
    });

final homeContactsBootstrapRefresherProvider =
    Provider<HomeContactsBootstrapRefresher>((ref) {
      return () async {
        if (!StorageUtils.isLoggedIn()) {
          return;
        }
        final friends = await FriendApi.instance.getFriends();
        if (ref.read(homeShouldPersistContactsLocallyProvider)) {
          await ContactsDB.instance.insertOrUpdateAll(friends);
        }
      };
    });

@immutable
class HomeBootstrapState {
  const HomeBootstrapState._({
    required this.isLoading,
    required this.isReady,
    this.error,
  });

  const HomeBootstrapState.loading() : this._(isLoading: true, isReady: false);
  const HomeBootstrapState.ready() : this._(isLoading: false, isReady: true);
  const HomeBootstrapState.failed(Object error)
    : this._(isLoading: false, isReady: false, error: error);

  final bool isLoading;
  final bool isReady;
  final Object? error;
}

class HomeBootstrapController extends Notifier<HomeBootstrapState> {
  Future<void>? _inFlight;

  @override
  HomeBootstrapState build() => const HomeBootstrapState.loading();

  Future<void> initialize() async {
    final pending = _inFlight;
    if (pending != null) {
      return pending;
    }

    if (state.isReady) {
      return;
    }

    state = const HomeBootstrapState.loading();
    final future = _runInitialize();
    _inFlight = future;
    return future;
  }

  Future<void> _runInitialize() async {
    try {
      final ok = await ref.read(imServiceProvider.notifier).init();
      if (ok) {
        await ref.read(homeConversationBootstrapRefresherProvider).call();
        await ref.read(homeContactsBootstrapRefresherProvider).call();
        state = const HomeBootstrapState.ready();
        return;
      }
      state = HomeBootstrapState.failed(
        StateError('IM initialization failed.'),
      );
    } catch (error) {
      state = HomeBootstrapState.failed(error);
    } finally {
      _inFlight = null;
    }
  }

  void markReadyWithoutInit() {
    state = const HomeBootstrapState.ready();
  }

  @visibleForTesting
  void debugSetInFlight(Future<void>? value) {
    _inFlight = value;
  }
}

final homeBootstrapStateProvider =
    NotifierProvider<HomeBootstrapController, HomeBootstrapState>(
      HomeBootstrapController.new,
    );

final homeCurrentTabIndexProvider = StateProvider<int>((ref) => 0);

final homeBadgeSnapshotProvider = Provider<HomeBadgeSnapshot>((ref) {
  final conversations = ref.watch(conversationProvider);
  final requests = ref.watch(friendRequestListProvider);
  return HomeBadgeSnapshot(
    bySurface: <HomeSurfaceId, int>{
      HomeSurfaceId.conversations: conversations.fold<int>(
        0,
        (sum, item) => sum + item.unreadCount,
      ),
      HomeSurfaceId.contacts: requests.maybeWhen(
        data: countPendingFriendRequests,
        orElse: () => 0,
      ),
      HomeSurfaceId.user: 0,
    },
  );
});
