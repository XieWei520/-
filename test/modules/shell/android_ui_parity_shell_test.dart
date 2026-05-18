import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/runtime_capabilities_provider.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/modules/auth/login_page.dart';
import 'package:wukong_im_app/modules/conversation/main_page.dart';
import 'package:wukong_im_app/modules/user/user_page.dart';
import 'package:wukong_im_app/service/api/common_api.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';

void main() {
  testWidgets(
    'MainPage uses the Android-style custom tab shell with asset icons',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userPageVersionLoaderProvider.overrideWithValue(() async => null),
            customerServiceConversationAccountsProvider.overrideWith(
              (ref) async => const [],
            ),
          ],
          child: MaterialApp(home: MainPage(autoInitializeIM: false)),
        ),
      );

      expect(find.byKey(const ValueKey('wk_tab_shell')), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  WKReferenceAssets.tabChatSelected,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'LoginPage exposes Android-style background and underline field shell',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runtimeCapabilitiesProvider.overrideWith(
              (ref) async => const AppRuntimeCapabilities(
                webLoginUrl: '',
                webLoginReachable: false,
                webLoginStatusMessage: 'disabled',
              ),
            ),
          ],
          child: const MaterialApp(home: LoginPage()),
        ),
      );

      expect(find.byKey(const ValueKey('wk_login_background')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('auth_login_phone_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('auth_login_password_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('wk_login_terms_toggle')),
        findsOneWidget,
      );
    },
  );
}
