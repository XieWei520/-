import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_scan/scan_service.dart';

void main() {
  group('ScanServiceResult', () {
    test('preserves login confirm auth code and pub key', () {
      final result = ScanServiceResult.fromJson({
        'forward': 'native',
        'type': 'loginConfirm',
        'data': {'auth_code': 'auth-123', 'pub_key': 'pub-key-xyz'},
      }, 'raw-content');

      expect(result.type, 'loginConfirm');
      expect(result.authCode, 'auth-123');
      expect(result.pubKey, 'pub-key-xyz');
    });

    test('parses internal join-group url into structured fields', () {
      final internalHost = Uri.parse(ApiConfig.baseUrl);
      final joinUri = Uri(
        scheme: internalHost.scheme,
        host: internalHost.host,
        port: internalHost.hasPort ? internalHost.port : null,
        path: '/join_group.html',
        queryParameters: const {'group_no': 'g_1001', 'auth_code': 'auth_123'},
      );

      final result = ScanServiceResult.fromJson({
        'forward': 'h5',
        'type': 'webview',
        'data': {'url': joinUri.toString()},
      }, joinUri.toString());

      expect(result.isInternalJoinGroupUrl, isTrue);
      expect(result.joinGroupNo, 'g_1001');
      expect(result.joinGroupAuthCode, 'auth_123');
    });

    test('does not mark external join-group url as internal join', () {
      final result = ScanServiceResult.fromJson({
        'forward': 'h5',
        'type': 'webview',
        'data': {
          'url':
              'https://example.com/join_group.html?group_no=g_1001&auth_code=auth_123',
        },
      }, 'raw-content');

      expect(result.isInternalJoinGroupUrl, isFalse);
      expect(result.joinGroupNo, isNull);
      expect(result.joinGroupAuthCode, isNull);
    });
  });

  group('ScanService', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test(
      'normalizes relative internal qrcode url without leading slash',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{
            'forward': 'native',
            'type': 'text',
            'data': <String, dynamic>{},
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await ScanService.instance.processScanResult('v1/qrcode/abc');

        final requestUri = adapter.lastRequestOptions?.uri;
        final baseUri = Uri.parse(ApiConfig.baseUrl);
        expect(requestUri, isNotNull);
        expect(requestUri?.host, baseUri.host);
        expect(requestUri?.path, '/v1/qrcode/abc');
      },
    );

    test(
      'preserves query parameters for relative internal qrcode url',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: const <String, dynamic>{
            'forward': 'native',
            'type': 'text',
            'data': <String, dynamic>{},
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await ScanService.instance.processScanResult(
          '/v1/qrcode/abc?foo=1&bar=2',
        );

        final requestUri = adapter.lastRequestOptions?.uri;
        expect(requestUri, isNotNull);
        expect(requestUri?.path, '/v1/qrcode/abc');
        expect(requestUri?.queryParameters, containsPair('foo', '1'));
        expect(requestUri?.queryParameters, containsPair('bar', '2'));
      },
    );

    test('throws when http 200 envelope has non-zero code', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{'code': 1, 'msg': 'scan parse failed'},
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await expectLater(
        () => ScanService.instance.processScanResult('/v1/qrcode/abc'),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('scan parse failed'),
          ),
        ),
      );
    });

    test('throws when http 200 envelope has error status field', () async {
      final adapter = _RecordingJsonAdapter(
        payload: const <String, dynamic>{
          'status': 500,
          'message': 'upstream parse error',
        },
      );
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await expectLater(
        () => ScanService.instance.processScanResult('/v1/qrcode/abc'),
        throwsA(
          predicate<Object>(
            (error) => error.toString().contains('upstream parse error'),
          ),
        ),
      );
    });
  });
}

class _RecordingJsonAdapter implements HttpClientAdapter {
  _RecordingJsonAdapter({required this.payload});

  final Object payload;
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
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
