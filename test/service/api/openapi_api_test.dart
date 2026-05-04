import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/openapi_api.dart';

void main() {
  group('OpenApiApi', () {
    test(
      'getAppInfo uses GET /v1/apps/:app_id and parses app metadata',
      () async {
        final adapter = _RecordingAdapter(
          payload: const <String, dynamic>{
            'app_id': 'crm',
            'app_name': 'CRM Workspace',
            'app_logo': 'https://cdn.example.com/crm.png',
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final appInfo = await OpenApiApi.instance.getAppInfo('crm');

        expect(adapter.lastRequestOptions?.path, '/v1/apps/crm');
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(adapter.lastRequestOptions?.responseType, ResponseType.plain);
        expect(appInfo.appId, 'crm');
        expect(appInfo.appName, 'CRM Workspace');
        expect(appInfo.appLogo, 'https://cdn.example.com/crm.png');
      },
    );

    test(
      'getAuthCode uses GET /v1/openapi/authcode query parameter and reads authcode',
      () async {
        final adapter = _RecordingAdapter(
          payload: const <String, dynamic>{'authcode': 'auth-123'},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final authCode = await OpenApiApi.instance.getAuthCode('crm');

        expect(adapter.lastRequestOptions?.path, '/v1/openapi/authcode');
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(
          adapter.lastRequestOptions?.queryParameters,
          containsPair('app_id', 'crm'),
        );
        expect(adapter.lastRequestOptions?.responseType, ResponseType.plain);
        expect(authCode, 'auth-123');
      },
    );

    test('getAuthCode throws on backend business failure payload', () async {
      ApiClient.instance.dio.httpClientAdapter = _RecordingAdapter(
        payload: const <String, dynamic>{'status': 400, 'msg': 'app denied'},
      );

      await expectLater(
        () => OpenApiApi.instance.getAuthCode('crm'),
        throwsA(predicate((error) => error.toString().contains('app denied'))),
      );
    });

    test('getAppInfo throws when payload is malformed', () async {
      ApiClient.instance.dio.httpClientAdapter = _RecordingAdapter(
        payload: const <String, dynamic>{'data': <String, dynamic>{}},
      );

      await expectLater(
        OpenApiApi.instance.getAppInfo('crm'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.payload});

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
