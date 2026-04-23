import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/service/api/openapi_api.dart';
import 'package:wukong_im_app/wukong_scan/openapi_webview_bridge.dart';

void main() {
  group('OpenApiWebViewBridgeController', () {
    test(
      'handleRawMessage returns auth code callback after approval',
      () async {
        final prompts = <OpenApiAuthorizationPrompt>[];
        final controller = OpenApiWebViewBridgeController(
          fetchAppInfo: (appId) async => const OpenApiAppInfo(
            appId: 'crm',
            appName: 'CRM Workspace',
            appLogo: 'https://cdn.example.com/crm.png',
          ),
          fetchAuthCode: (appId) async => 'auth-123',
          loadCurrentUser: () async => UserInfo(
            uid: 'u-1',
            name: 'Alice',
            avatar: 'https://cdn.example.com/users/u-1.png',
          ),
          requestAuthorization: (prompt) async {
            prompts.add(prompt);
            return true;
          },
        );

        final result = await controller.handleRawMessage(
          jsonEncode(<String, dynamic>{
            'handlerName': 'auth',
            'callbackId': 'cb_1',
            'data': const <String, dynamic>{'app_id': 'crm'},
          }),
        );

        expect(result.handled, isTrue);
        expect(result.callback?.callbackId, 'cb_1');
        expect(result.callback?.payload, <String, dynamic>{'code': 'auth-123'});
        expect(prompts.single.appInfo.appId, 'crm');
        expect(prompts.single.appInfo.appName, 'CRM Workspace');
        expect(prompts.single.currentUser?.uid, 'u-1');
        expect(prompts.single.currentUser?.name, 'Alice');
      },
    );

    test(
      'handleRawMessage returns an error callback when app_id is missing',
      () async {
        var fetchAppInfoCalled = false;
        final controller = OpenApiWebViewBridgeController(
          fetchAppInfo: (appId) async {
            fetchAppInfoCalled = true;
            return const OpenApiAppInfo(appId: '', appName: '', appLogo: '');
          },
          fetchAuthCode: (appId) async => 'unused',
          loadCurrentUser: () async => UserInfo(uid: 'u-1'),
          requestAuthorization: (_) async => true,
        );

        final result = await controller.handleRawMessage(
          jsonEncode(<String, dynamic>{
            'handlerName': 'auth',
            'callbackId': 'cb_1',
            'data': const <String, dynamic>{},
          }),
        );

        expect(result.handled, isTrue);
        expect(
          result.callback?.payload,
          containsPair('error', 'Missing app_id.'),
        );
        expect(fetchAppInfoCalled, isFalse);
      },
    );

    test(
      'handleRawMessage returns an error callback when user denies authorization',
      () async {
        var fetchAuthCodeCalled = false;
        final controller = OpenApiWebViewBridgeController(
          fetchAppInfo: (appId) async => const OpenApiAppInfo(
            appId: 'crm',
            appName: 'CRM Workspace',
            appLogo: '',
          ),
          fetchAuthCode: (appId) async {
            fetchAuthCodeCalled = true;
            return 'unused';
          },
          loadCurrentUser: () async => UserInfo(uid: 'u-1', name: 'Alice'),
          requestAuthorization: (_) async => false,
        );

        final result = await controller.handleRawMessage(
          jsonEncode(<String, dynamic>{
            'handlerName': 'auth',
            'callbackId': 'cb_1',
            'data': const <String, dynamic>{'app_id': 'crm'},
          }),
        );

        expect(result.handled, isTrue);
        expect(
          result.callback?.payload,
          containsPair('error', 'Authorization canceled.'),
        );
        expect(fetchAuthCodeCalled, isFalse);
      },
    );

    test('handleRawMessage ignores unsupported handlers', () async {
      final controller = OpenApiWebViewBridgeController(
        fetchAppInfo: (_) async => const OpenApiAppInfo(
          appId: 'crm',
          appName: 'CRM Workspace',
          appLogo: '',
        ),
        fetchAuthCode: (_) async => 'unused',
        loadCurrentUser: () async => UserInfo(uid: 'u-1'),
        requestAuthorization: (_) async => true,
      );

      final result = await controller.handleRawMessage(
        jsonEncode(<String, dynamic>{
          'handlerName': 'quit',
          'callbackId': 'cb_1',
          'data': const <String, dynamic>{},
        }),
      );

      expect(result.handled, isFalse);
      expect(result.callback, isNull);
    });
  });

  group('OpenApiWebViewBridgeCallback', () {
    test('toJavaScript targets WebViewJavascriptBridge callback delivery', () {
      final callback = OpenApiWebViewBridgeCallback(
        callbackId: 'cb_1',
        payload: const <String, dynamic>{'code': 'auth-123'},
      );

      final script = callback.toJavaScript();

      expect(script, contains('WebViewJavascriptBridge'));
      expect(script, contains('cb_1'));
      expect(script, contains('auth-123'));
    });
  });
}
