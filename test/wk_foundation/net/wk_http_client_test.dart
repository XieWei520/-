import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/service/api/api_client.dart' as service_api;
import 'package:wukong_im_app/wk_foundation/errors/app_failure.dart';
import 'package:wukong_im_app/wk_foundation/net/wk_http_client.dart';
import 'package:wukong_im_app/wukong_base/net/api_client.dart' as base_api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('signed headers include auth and device identity when provided', () {
    final client = WkHttpClient(
      now: () => DateTime.fromMillisecondsSinceEpoch(123456),
      nonceFactory: (_) => 'nonce-fixed',
    );

    final headers = client.buildSignedHeaders(
      data: const <String, dynamic>{'hello': 'world'},
      token: 'token-1',
      deviceId: 'device-1',
      deviceSessionId: 'session-1',
    );

    expect(headers['token'], 'token-1');
    expect(headers['X-Device-ID'], 'device-1');
    expect(headers['X-Device-Session-ID'], 'session-1');
    expect(headers['timestamp'], '123456');
    expect(headers['noncestr'], 'nonce-fixed');
    expect(headers['appid'], isNotEmpty);
    expect(headers['sign'], isNotEmpty);
  });

  test(
    'canonical client can sync its base url from runtime auth override',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await StorageUtils.init();

      final client = WkHttpClient();
      expect(client.dio.options.baseUrl, ApiConfig.baseUrl);

      await StorageUtils.setString(
        AppConstants.keyAuthLoginApiBaseUrl,
        'http://127.0.0.1:5001',
      );
      client.syncBaseUrlWithConfig();
      expect(client.dio.options.baseUrl, 'http://127.0.0.1:5001');

      await StorageUtils.remove(AppConstants.keyAuthLoginApiBaseUrl);
      client.syncBaseUrlWithConfig();
      expect(client.dio.options.baseUrl, ApiConfig.baseUrl);
    },
  );

  test('failure mapper preserves server failures', () {
    final request = RequestOptions(path: '/messages');
    final response = Response<void>(requestOptions: request, statusCode: 502);
    final exception = DioException(
      requestOptions: request,
      response: response,
      type: DioExceptionType.badResponse,
    );

    final failure = AppFailure.fromDio(exception);

    expect(failure.kind, AppFailureKind.server);
    expect(failure.statusCode, 502);
  });

  test('failure mapper extracts server message from JSON string responses', () {
    final request = RequestOptions(path: '/auth/login');
    final response = Response<String>(
      requestOptions: request,
      statusCode: 400,
      data: '{"msg":"密码不正确！"}',
    );
    final exception = DioException(
      requestOptions: request,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Request failed with status code: 400',
    );

    final failure = AppFailure.fromDio(exception);

    expect(failure.kind, AppFailureKind.server);
    expect(failure.statusCode, 400);
    expect(failure.message, '密码不正确！');
  });

  test('failure describe removes generic exception prefix noise', () {
    final message = AppFailure.describe(
      Exception('send register code failed'),
      fallbackMessage: 'Request failed',
    );

    expect(message, 'send register code failed');
  });

  test(
    '401 response throws unauthorized failure and clears in-memory token',
    () async {
      final client = WkHttpClient();
      client.dio.httpClientAdapter = _StaticResponseAdapter(statusCode: 401);
      client.setToken('stale-token');

      expect(client.dio.options.headers['token'], 'stale-token');

      await expectLater(
        client.get('/auth/check'),
        throwsA(
          isA<DioException>()
              .having((error) => error.response?.statusCode, 'statusCode', 401)
              .having(
                (error) => (error.error as AppFailure).kind,
                'failure kind',
                AppFailureKind.unauthorized,
              ),
        ),
      );
      expect(client.dio.options.headers.containsKey('token'), isFalse);
    },
  );

  test('multipart upload keeps multipart content type and succeeds', () async {
    final client = WkHttpClient();
    final adapter = _RecordingResponseAdapter(statusCode: 200);
    client.dio.httpClientAdapter = adapter;

    final tempDir = await Directory.systemTemp.createTemp(
      'wk_http_client_multipart',
    );
    final uploadFile = File('${tempDir.path}/upload.txt');
    await uploadFile.writeAsString('payload');
    addTearDown(() => _deleteDirWithRetry(tempDir));

    final response = await client.uploadFile(
      '/upload',
      uploadFile.path,
      data: const <String, dynamic>{'note': 'demo'},
    );

    expect(response.statusCode, 200);
    final request = adapter.lastRequestOptions;
    expect(request, isNotNull);
    expect(request!.data, isA<FormData>());
    final contentType = request.contentType ?? '';
    expect(contentType, contains('multipart/form-data'));
    expect(contentType, isNot(contains('application/json')));
    expect(request.headers['sign'], isNotNull);
  });

  test(
    'canonical client forwards cancel token to all request methods',
    () async {
      final client = WkHttpClient();
      client.dio.httpClientAdapter = _StaticResponseAdapter(statusCode: 200);

      final tempDir = await Directory.systemTemp.createTemp(
        'wk_http_client_cancel',
      );
      final uploadFile = File('${tempDir.path}/upload.txt');
      await uploadFile.writeAsString('payload');
      addTearDown(() => _deleteDirWithRetry(tempDir));

      Future<void> expectCancelled(
        Future<Response<dynamic>> Function(CancelToken token) invocation,
      ) async {
        final token = CancelToken()..cancel('cancelled');
        await expectLater(
          invocation(token),
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.cancel,
            ),
          ),
        );
      }

      await expectCancelled(
        (token) => client.get('/cancel/get', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.post('/cancel/post', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.put('/cancel/put', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.delete('/cancel/delete', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.uploadFile(
          '/cancel/upload',
          uploadFile.path,
          cancelToken: token,
        ),
      );
    },
  );

  test(
    'wukong_base wrapper forwards cancel token for compatibility methods',
    () async {
      final client = base_api.ApiClient.instance;
      client.dio.httpClientAdapter = _StaticResponseAdapter(statusCode: 200);

      final tempDir = await Directory.systemTemp.createTemp(
        'wk_wrapper_cancel',
      );
      final uploadFile = File('${tempDir.path}/upload.txt');
      await uploadFile.writeAsString('payload');
      addTearDown(() => _deleteDirWithRetry(tempDir));

      Future<void> expectCancelled(
        Future<Response<dynamic>> Function(CancelToken token) invocation,
      ) async {
        final token = CancelToken()..cancel('cancelled');
        await expectLater(
          invocation(token),
          throwsA(
            isA<DioException>().having(
              (error) => error.type,
              'type',
              DioExceptionType.cancel,
            ),
          ),
        );
      }

      await expectCancelled(
        (token) => client.get('/compat/get', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.post('/compat/post', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.put('/compat/put', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.delete('/compat/delete', cancelToken: token),
      );
      await expectCancelled(
        (token) => client.uploadFile(
          '/compat/upload',
          filePath: uploadFile.path,
          fileKey: 'file',
          cancelToken: token,
        ),
      );
    },
  );

  test('service wrapper surfaces HTTP failures through AppFailure', () async {
    final client = service_api.ApiClient.instance;
    client.dio.httpClientAdapter = _StaticResponseAdapter(statusCode: 500);

    await expectLater(
      client.get('/service/failure'),
      throwsA(
        isA<DioException>()
            .having((error) => error.response?.statusCode, 'statusCode', 500)
            .having(
              (error) => (error.error as AppFailure).kind,
              'failure kind',
              AppFailureKind.server,
            ),
      ),
    );
  });
}

class _StaticResponseAdapter implements HttpClientAdapter {
  _StaticResponseAdapter({required this.statusCode});

  final int statusCode;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingResponseAdapter extends _StaticResponseAdapter {
  _RecordingResponseAdapter({required super.statusCode});

  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return super.fetch(options, requestStream, cancelFuture);
  }
}

Future<void> _deleteDirWithRetry(Directory dir) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      return;
    } catch (_) {
      if (attempt == 2) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
