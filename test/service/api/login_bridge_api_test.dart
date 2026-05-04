import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/login_bridge_api.dart';

void main() {
  group('LoginBridgeApi', () {
    test(
      'getDevices reads the direct list payload returned by the live backend',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: const <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 7,
              'device_id': 'desktop-7',
              'device_name': 'MacBook Pro（本机）',
              'device_model': 'macOS',
              'last_login': '2026-04-08 09:00',
              'self': 1,
            },
          ],
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final devices = await LoginBridgeApi.instance.getDevices();

        expect(adapter.lastRequestOptions?.path, '/v1/user/devices');
        expect(devices.single.deviceId, 'desktop-7');
        expect(devices.single.deviceName, 'MacBook Pro（本机）');
        expect(devices.single.self, isTrue);
      },
    );

    test(
      'grantLogin throws on business failure even when HTTP is 200',
      () async {
        ApiClient.instance.dio.httpClientAdapter = _RecordingPlainAdapter(
          payload: const <String, dynamic>{'code': 1, 'msg': 'backend-denied'},
        );

        await expectLater(
          () =>
              LoginBridgeApi.instance.grantLogin('bad-auth', encrypt: 'enc-1'),
          throwsA(
            predicate((error) => error.toString().contains('backend-denied')),
          ),
        );
      },
    );

    test(
      'grantLogin falls back to default message when backend message is blank',
      () async {
        ApiClient.instance.dio.httpClientAdapter = _RecordingPlainAdapter(
          payload: const <String, dynamic>{
            'code': 1,
            'msg': '   ',
            'message': 'ignored-when-msg-blank',
          },
        );

        await expectLater(
          () => LoginBridgeApi.instance.grantLogin('bad-auth'),
          throwsA(predicate((error) => _hasNonBlankExceptionMessage(error))),
        );
      },
    );

    test(
      'deleteDevice rejects blank ids before touching the network',
      () async {
        final adapter = _RecordingPlainAdapter(
          payload: const <String, dynamic>{'code': 0},
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        await expectLater(
          () => LoginBridgeApi.instance.deleteDevice('   '),
          throwsA(isA<Exception>()),
        );
        expect(adapter.lastRequestOptions, isNull);
      },
    );

    test('grantLogin treats string business code as a failure', () async {
      ApiClient.instance.dio.httpClientAdapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'code': '1',
          'msg': 'string-code-failure',
        },
      );

      await expectLater(
        () => LoginBridgeApi.instance.grantLogin('bad-auth'),
        throwsA(
          predicate(
            (error) => error.toString().contains('string-code-failure'),
          ),
        ),
      );
    });

    test('grantLogin treats string status as a failure', () async {
      ApiClient.instance.dio.httpClientAdapter = _RecordingPlainAdapter(
        payload: const <String, dynamic>{
          'status': '500',
          'msg': 'string-status-failure',
        },
      );

      await expectLater(
        () => LoginBridgeApi.instance.grantLogin('bad-auth'),
        throwsA(
          predicate(
            (error) => error.toString().contains('string-status-failure'),
          ),
        ),
      );
    });

    test('getDevices reads bool-like "self" values from payload', () async {
      ApiClient.instance.dio.httpClientAdapter = _RecordingPlainAdapter(
        payload: const <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 8,
            'device_id': 'mobile-8',
            'device_name': 'iPhone',
            'device_model': 'iOS',
            'last_login': '2026-04-08 12:00',
            'self': 'true',
          },
        ],
      );

      final devices = await LoginBridgeApi.instance.getDevices();

      expect(devices.single.self, isTrue);
    });
  });
}

class _RecordingPlainAdapter implements HttpClientAdapter {
  _RecordingPlainAdapter({required this.payload});

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

bool _hasNonBlankExceptionMessage(Object? error) {
  final rendered = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  return rendered.trim().isNotEmpty;
}
