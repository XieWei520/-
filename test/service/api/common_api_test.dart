import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/common_api.dart';

void main() {
  group('AppRuntimeCapabilities', () {
    test('parses can_modify_api_url switch from appconfig body', () {
      final capabilities = AppRuntimeCapabilities.fromAppConfigBody(
        body: {'can_modify_api_url': 1},
        webLoginReachable: false,
        webLoginStatusMessage: 'disabled',
      );

      expect(capabilities.canModifyApiUrl, isTrue);
    });

    test('keeps api base url editing disabled when switch is off', () {
      final capabilities = AppRuntimeCapabilities.fromAppConfigBody(
        body: {'can_modify_api_url': 0},
        webLoginReachable: false,
        webLoginStatusMessage: 'disabled',
      );

      expect(capabilities.canModifyApiUrl, isFalse);
    });

    test('parses short number edit switch from appconfig body', () {
      final capabilities = AppRuntimeCapabilities.fromAppConfigBody(
        body: {
          'web_url': 'https://infoequity.qingyunshe.top',
          'shortno_edit_off': 1,
        },
        webLoginReachable: false,
        webLoginStatusMessage: 'Web disabled',
      );

      expect(capabilities.webLoginUrl, 'https://infoequity.qingyunshe.top');
      expect(capabilities.shortNoEditable, isFalse);
      expect(capabilities.phoneSearchEnabled, isTrue);
      expect(capabilities.pcWebLoginEntryEnabled, isFalse);
    });

    test('treats short number editing as enabled when switch is off', () {
      final capabilities = AppRuntimeCapabilities.fromAppConfigBody(
        body: {
          'web_url': 'https://infoequity.qingyunshe.top',
          'shortno_edit_off': 0,
        },
        webLoginReachable: true,
        webLoginStatusMessage: 'Web enabled',
      );

      expect(capabilities.shortNoEditable, isTrue);
      expect(capabilities.pcWebLoginEntryEnabled, isTrue);
    });

    test('parses phone search switch from appconfig body', () {
      final capabilities = AppRuntimeCapabilities.fromAppConfigBody(
        body: {'phone_search_off': 1},
        webLoginReachable: false,
        webLoginStatusMessage: 'missing',
      );

      expect(capabilities.phoneSearchEnabled, isFalse);
    });
  });

  test(
    'getChatBackgrounds parses server-backed chat background list',
    () async {
      final originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      ApiClient.instance.dio.httpClientAdapter = _ChatBackgroundAdapter();
      addTearDown(() {
        ApiClient.instance.dio.httpClientAdapter = originalAdapter;
      });

      final options = await CommonApi.instance.getChatBackgrounds();

      expect(options, hasLength(2));
      expect(options.first.url, 'file/preview/common/chatbg/default/1_b.svg');
      expect(options.first.isSvg, isTrue);
      expect(options.first.lightColors, <String>['a6B0CDEB', 'a69FB0EA']);
      expect(options.last.url, 'file/preview/common/chatbg/default/14_b.jpg');
      expect(options.last.isSvg, isFalse);
    },
  );

  test(
    'getAppNewVersion requests the current native platform family',
    () async {
      final originalPlatform = debugDefaultTargetPlatformOverride;
      final originalAdapter = ApiClient.instance.dio.httpClientAdapter;
      final adapter = _AppVersionCaptureAdapter();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      ApiClient.instance.dio.httpClientAdapter = adapter;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = originalPlatform;
        ApiClient.instance.dio.httpClientAdapter = originalAdapter;
      });

      final version = await CommonApi.instance.getAppNewVersion('1.0.0');

      expect(adapter.requestedPath, '/v1/common/appversion/windows/1.0.0');
      expect(version?.os, 'windows');
    },
  );
}

class _ChatBackgroundAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(<Map<String, dynamic>>[
        <String, dynamic>{
          'cover': 'file/preview/common/chatbg/default/1_s.jpg',
          'url': 'file/preview/common/chatbg/default/1_b.svg',
          'is_svg': 1,
          'light_colors': <String>['a6B0CDEB', 'a69FB0EA'],
        },
        <String, dynamic>{
          'cover': 'file/preview/common/chatbg/default/14_s.jpg',
          'url': 'file/preview/common/chatbg/default/14_b.jpg',
          'is_svg': 0,
        },
      ]),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}

class _AppVersionCaptureAdapter implements HttpClientAdapter {
  String? requestedPath;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPath = options.path;
    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{'os': 'windows', 'app_version': '1.0.1'}),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
