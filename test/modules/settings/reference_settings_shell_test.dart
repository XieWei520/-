import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/account_security_page.dart';
import 'package:wukong_im_app/modules/settings/privacy_settings_page.dart';
import 'package:wukong_im_app/modules/settings/settings_strings.dart';
import 'package:wukong_im_app/modules/settings/settings_surface_widgets.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/widgets/wk_sub_page_scaffold.dart';
import 'package:wukong_im_app/wukong_login/pc_login_page.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUpAll(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  setUp(() {
    ApiClient.instance.dio.httpClientAdapter = _ImmediateSuccessAdapter();
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  Widget buildApp({required Widget home}) {
    return MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: const <Locale>[
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }

  testWidgets('privacy settings shell baseline stays unchanged', (
    tester,
  ) async {
    final strings = resolveSettingsStrings(locale: const Locale('zh', 'CN'));

    await tester.pumpWidget(buildApp(home: const PrivacySettingsPage()));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScaffold), findsOneWidget);
    expect(find.byType(SettingsHero), findsAtLeastNWidgets(1));
    expect(find.byType(SettingsSection), findsAtLeastNWidgets(1));
    expect(find.byType(WKSubPageScaffold), findsNothing);
    expect(find.text(strings.privacySettingsTitle), findsOneWidget);
  });

  testWidgets('account security shell baseline stays unchanged', (
    tester,
  ) async {
    final strings = resolveSettingsStrings(locale: const Locale('zh', 'CN'));

    await tester.pumpWidget(buildApp(home: const AccountSecurityPage()));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScaffold), findsOneWidget);
    expect(find.byType(SettingsHero), findsAtLeastNWidgets(1));
    expect(find.byType(SettingsSection), findsAtLeastNWidgets(1));
    expect(find.byType(WKSubPageScaffold), findsNothing);
    expect(find.text(strings.accountSecurityTitle), findsOneWidget);
  });

  testWidgets('pc login shell baseline stays unchanged', (tester) async {
    final strings = resolveSettingsStrings(locale: const Locale('zh', 'CN'));

    await tester.pumpWidget(buildApp(home: const PCLoginPage()));
    await tester.pumpAndSettle();

    expect(find.byType(WKSubPageScaffold), findsOneWidget);
    expect(find.byType(SettingsScaffold), findsNothing);
    expect(find.text(strings.pcLoginPageTitle), findsOneWidget);
  });
}

class _ImmediateSuccessAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
