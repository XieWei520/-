import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_shell_page.dart';
import 'package:wukong_im_app/modules/home/home_badge_snapshot.dart';
import 'package:wukong_im_app/modules/home/home_surface_kernel.dart';
import 'package:wukong_im_app/service/im/im_service.dart';
import 'package:wukong_im_app/widgets/wk_tab_shell.dart';
import 'package:wukongimfluttersdk/type/const.dart';

const _homeBootstrapRetryButtonKey = ValueKey<String>(
  'home-bootstrap-retry-button',
);

class _FailedBootstrapController extends HomeBootstrapController {
  @override
  HomeBootstrapState build() {
    return HomeBootstrapState.failed(StateError('boom'));
  }
}

class _FakeIMService extends IMService {
  _FakeIMService(this._initHandler);

  Future<bool> Function() _initHandler;
  int initCalls = 0;

  void setInitHandler(Future<bool> Function() handler) {
    _initHandler = handler;
  }

  void setConnectionState(IMServiceState next) {
    state = next;
  }

  @override
  Future<bool> init() {
    initCalls += 1;
    return _initHandler();
  }
}

void main() {
  testWidgets('home shell shows retry state when bootstrap fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeBootstrapStateProvider.overrideWith(
            _FailedBootstrapController.new,
          ),
        ],
        child: const MaterialApp(home: HomeShellPage()),
      ),
    );

    expect(find.byKey(_homeBootstrapRetryButtonKey), findsOneWidget);
  });

  testWidgets(
    'home shell keeps retry after post-frame without reading badges',
    (tester) async {
      var badgeRead = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeBootstrapStateProvider.overrideWith(
              _FailedBootstrapController.new,
            ),
            homeBadgeSnapshotProvider.overrideWith((ref) {
              badgeRead = true;
              return HomeBadgeSnapshot();
            }),
          ],
          child: const MaterialApp(home: HomeShellPage()),
        ),
      );

      await tester.pump();

      expect(find.byKey(_homeBootstrapRetryButtonKey), findsOneWidget);
      expect(badgeRead, isFalse);
    },
  );

  testWidgets('home shell skips loading flash when autoInitializeIM is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeBadgeSnapshotProvider.overrideWith((ref) {
            return HomeBadgeSnapshot();
          }),
        ],
        child: const MaterialApp(
          home: HomeShellPage(
            autoInitializeIM: false,
            pagesOverride: <Widget>[SizedBox(), SizedBox(), SizedBox()],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(WKTabShell), findsOneWidget);
  });

  testWidgets('home shell overlays reconnecting banner without blocking tabs', (
    tester,
  ) async {
    final service = _FakeIMService(() async => true)
      ..setConnectionState(
        const IMServiceState(
          isInitialized: true,
          isConnected: false,
          connectionStatus: WKConnectStatus.connecting,
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imServiceProvider.overrideWith((ref) => service),
          homeBadgeSnapshotProvider.overrideWith((ref) {
            return HomeBadgeSnapshot();
          }),
        ],
        child: const MaterialApp(
          home: HomeShellPage(
            autoInitializeIM: false,
            pagesOverride: <Widget>[
              Text('conversation body'),
              SizedBox(),
              SizedBox(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('home-im-connection-banner')),
      findsOneWidget,
    );
    expect(find.text('正在重连，消息会在连接恢复后发送'), findsOneWidget);
    expect(find.byType(WKTabShell), findsOneWidget);
    expect(find.text('conversation body'), findsOneWidget);
  });

  testWidgets('home shell hides connection banner after sync completes', (
    tester,
  ) async {
    final service = _FakeIMService(() async => true)
      ..setConnectionState(
        const IMServiceState(
          isInitialized: true,
          isConnected: true,
          connectionStatus: WKConnectStatus.syncCompleted,
        ),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imServiceProvider.overrideWith((ref) => service),
          homeBadgeSnapshotProvider.overrideWith((ref) {
            return HomeBadgeSnapshot();
          }),
        ],
        child: const MaterialApp(
          home: HomeShellPage(
            autoInitializeIM: false,
            pagesOverride: <Widget>[SizedBox(), SizedBox(), SizedBox()],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('home-im-connection-banner')),
      findsNothing,
    );
    expect(find.byType(WKTabShell), findsOneWidget);
  });

  testWidgets(
    'home shell logs initial visibility when autoInitializeIM is false',
    (tester) async {
      final events = <String>[];
      final kernel = HomeSurfaceKernel(logEvent: events.add);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeSurfaceKernelProvider.overrideWith((ref) => kernel),
            homeBadgeSnapshotProvider.overrideWith((ref) {
              return HomeBadgeSnapshot();
            }),
          ],
          child: const MaterialApp(
            home: HomeShellPage(
              autoInitializeIM: false,
              pagesOverride: <Widget>[SizedBox(), SizedBox(), SizedBox()],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(events, contains('home_bootstrap_ready'));
      expect(events, contains('surface_visible:conversations'));
    },
  );

  testWidgets('home shell retry marks bootstrap start and recovery signals', (
    tester,
  ) async {
    final events = <String>[];
    final kernel = HomeSurfaceKernel(logEvent: events.add);
    final service = _FakeIMService(() async => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeBootstrapStateProvider.overrideWith(
            _FailedBootstrapController.new,
          ),
          homeSurfaceKernelProvider.overrideWith((ref) => kernel),
          imServiceProvider.overrideWith((ref) => service),
        ],
        child: const MaterialApp(
          home: HomeShellPage(
            pagesOverride: <Widget>[SizedBox(), SizedBox(), SizedBox()],
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_homeBootstrapRetryButtonKey));
    await tester.pump();
    await tester.pump();

    expect(events, contains('home_bootstrap_start'));
    expect(events, contains('home_bootstrap_ready'));
    expect(events, contains('surface_healthy:conversations'));
    expect(events, contains('surface_healthy:contacts'));
  });

  test(
    'initialize ends in failed when init throws and clears loading',
    () async {
      final error = StateError('boom');
      final service = _FakeIMService(() => Future<bool>.error(error));
      final container = ProviderContainer(
        overrides: [imServiceProvider.overrideWith((ref) => service)],
      );
      addTearDown(container.dispose);

      final controller = container.read(homeBootstrapStateProvider.notifier);
      await controller.initialize();

      final state = container.read(homeBootstrapStateProvider);
      expect(state.isLoading, isFalse);
      expect(state.isReady, isFalse);
      expect(state.error, error);
    },
  );

  test('initialize guards concurrent calls and retries with loading', () async {
    final firstCompleter = Completer<bool>();
    final service = _FakeIMService(() => firstCompleter.future);
    final container = ProviderContainer(
      overrides: [imServiceProvider.overrideWith((ref) => service)],
    );
    addTearDown(container.dispose);

    final controller = container.read(homeBootstrapStateProvider.notifier);
    final first = controller.initialize();
    final second = controller.initialize();
    expect(service.initCalls, 1);

    firstCompleter.complete(false);
    await Future.wait([first, second]);

    var state = container.read(homeBootstrapStateProvider);
    expect(state.isReady, isFalse);
    expect(state.error, isNotNull);

    final retryCompleter = Completer<bool>();
    service.setInitHandler(() => retryCompleter.future);

    final retry = controller.initialize();
    state = container.read(homeBootstrapStateProvider);
    expect(state.isLoading, isTrue);

    retryCompleter.complete(true);
    await retry;

    state = container.read(homeBootstrapStateProvider);
    expect(state.isReady, isTrue);
  });

  test(
    'initialize returns in-flight future even when state is ready',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(homeBootstrapStateProvider.notifier);
      controller.state = const HomeBootstrapState.ready();

      final inflight = Completer<void>();
      controller.debugSetInFlight(inflight.future);

      final result = controller.initialize();
      var completed = false;
      result.then((_) => completed = true);

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      inflight.complete();
      await result;
      expect(completed, isTrue);
    },
  );

  test('initialize refreshes conversations after IM init succeeds', () async {
    final service = _FakeIMService(() async => true);
    var refreshCalls = 0;
    final container = ProviderContainer(
      overrides: [
        imServiceProvider.overrideWith((ref) => service),
        homeConversationBootstrapRefresherProvider.overrideWith(
          (ref) => () async {
            refreshCalls += 1;
          },
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(homeBootstrapStateProvider.notifier);
    await controller.initialize();

    expect(refreshCalls, 1);
  });

  test(
    'initialize refreshes contacts bootstrap chain after IM init succeeds',
    () async {
      final service = _FakeIMService(() async => true);
      var refreshCalls = 0;
      final container = ProviderContainer(
        overrides: [
          imServiceProvider.overrideWith((ref) => service),
          homeContactsBootstrapRefresherProvider.overrideWith(
            (ref) => () async {
              refreshCalls += 1;
            },
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(homeBootstrapStateProvider.notifier);
      await controller.initialize();

      expect(refreshCalls, 1);
    },
  );
}
