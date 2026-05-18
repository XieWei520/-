import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wukong_im_app/app/app.dart';

void main() {
  testWidgets(
    'launch policy dialogs use the router navigator context below MaterialApp',
    (tester) async {
      late BuildContext appContext;
      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) {
              return const Scaffold(body: Text('home'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            appContext = context;
            return MaterialApp.router(routerConfig: router);
          },
        ),
      );
      await tester.pumpAndSettle();

      final dialogContext = resolveLaunchPolicyDialogContext(
        appContext: appContext,
        router: router,
      );

      // appContext 位于 MaterialApp 之上，不能直接用于 showDialog。
      expect(
        Localizations.of<MaterialLocalizations>(
          appContext,
          MaterialLocalizations,
        ),
        isNull,
      );
      expect(dialogContext, isNotNull);
      expect(
        Localizations.of<MaterialLocalizations>(
          dialogContext!,
          MaterialLocalizations,
        ),
        isNotNull,
      );
    },
  );
}
