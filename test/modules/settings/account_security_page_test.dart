import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/utils/crypto_utils.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/settings/account_security_page.dart';
import 'package:wukong_im_app/service/api/api_client.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets(
    'account security page sends destroy sms and destroys account after confirmation',
    (tester) async {
      final adapter = _AccountSecurityAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;
      late _TestAuthNotifier authNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              authNotifier = _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(uid: 'u_destroy', name: 'Destroy Tester'),
                ),
              );
              return authNotifier;
            }),
          ],
          child: MaterialApp(
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
            home: const AccountSecurityPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('account-security-destroy-account')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(
          const ValueKey<String>('account-security-destroy-send-code'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        adapter.requests.any(
          (request) =>
              request.path.toString().contains('/user/sms/destroy') &&
              request.method == 'POST',
        ),
        isTrue,
      );

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('account-security-destroy-code-field'),
        ),
        '123456',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('account-security-destroy-confirm')),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        adapter.requests.any(
          (request) =>
              request.path.toString().contains('/user/destroy/123456') &&
              request.method == 'DELETE',
        ),
        isTrue,
      );
      expect(authNotifier.logoutCalls, 1);
    },
  );

  testWidgets(
    'account security page submits chat password dialog through confirmed API contract',
    (tester) async {
      final adapter = _AccountSecurityAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;
      late _TestAuthNotifier authNotifier;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              authNotifier = _TestAuthNotifier(
                ref,
                initialState: AuthState(
                  isLoggedIn: true,
                  isRestoringSession: false,
                  userInfo: UserInfo(uid: 'u_chatpwd', name: 'Chat Tester'),
                ),
              );
              return authNotifier;
            }),
          ],
          child: MaterialApp(
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
            home: const AccountSecurityPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('account-security-chat-password')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('account-security-login-password-field'),
        ),
        'login-pass',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('account-security-chat-password-field'),
        ),
        'chat-pass',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>(
            'account-security-confirm-chat-password-field',
          ),
        ),
        'chat-pass',
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('account-security-chat-password-confirm'),
        ),
      );
      await tester.pumpAndSettle();

      final request = adapter.requests.lastWhere(
        (options) =>
            options.path == ApiConfig.userChatPwd &&
            options.method.toUpperCase() == 'POST',
      );
      expect(
        request.data,
        containsPair('chat_pwd', CryptoUtils.md5('chat-passu_chatpwd')),
      );
      expect(request.data, containsPair('login_pwd', 'login-pass'));
      expect(
        authNotifier.state.userInfo?.chatPwd,
        CryptoUtils.md5('chat-passu_chatpwd'),
      );
    },
  );
}

class _AccountSecurityAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);

    Object payload = const <String, dynamic>{'code': 0};
    if (options.path == ApiConfig.userDevices) {
      payload = const <String, dynamic>{
        'code': 0,
        'data': <Map<String, dynamic>>[],
      };
    }

    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }

  int logoutCalls = 0;

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    state = AuthState(isRestoringSession: false);
  }
}
