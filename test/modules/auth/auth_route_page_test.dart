import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wukong_im_app/app/navigation/app_route_location.dart';
import 'package:wukong_im_app/app/navigation/app_router.dart';
import 'package:wukong_im_app/app/navigation/auth_route_page.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';

void main() {
  test('buildAuthRoutePage applies the shared auth transition contract', () {
    const pageKey = ValueKey<String>('auth-route-page');
    const child = SizedBox();
    const arguments = <String, String>{'source': 'test'};

    final page = buildAuthRoutePage<void>(
      key: pageKey,
      name: 'auth-route',
      arguments: arguments,
      restorationId: 'restore-auth-route',
      child: child,
    );

    expect(page, isA<CustomTransitionPage<void>>());
    expect(page.key, pageKey);
    expect(page.name, 'auth-route');
    expect(page.arguments, arguments);
    expect(page.restorationId, 'restore-auth-route');
    expect(page.transitionDuration, const Duration(milliseconds: 260));
    expect(page.reverseTransitionDuration, const Duration(milliseconds: 220));
    expect(page.child, child);
  });

  testWidgets(
    'auth route pageBuilder preserves default route settings semantics',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authCurrentUserLoaderProvider.overrideWithValue(() async => null),
          authDraftSyncProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final matchList = router.configuration.findMatch(
        Uri.parse('/auth/web-login-confirm?authCode=auth-1&encrypt=enc-1'),
      );
      expect(matchList.isError, isFalse);

      final route = router.configuration.routes.whereType<GoRoute>().firstWhere(
        (entry) => entry.path == AppRouteLocation.authWebLoginConfirm,
      );
      final routeMatch = matchList.last;
      final state = routeMatch.buildState(router.configuration, matchList);

      late BuildContext context;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (buildContext) {
              context = buildContext;
              return const SizedBox();
            },
          ),
        ),
      );

      final page = route.pageBuilder!(context, state);

      expect(page.name, AppRouteLocation.authWebLoginConfirm);
      expect(page.arguments, <String, String>{
        'authCode': 'auth-1',
        'encrypt': 'enc-1',
      });
      expect(page.restorationId, state.pageKey.value);
    },
  );
}
