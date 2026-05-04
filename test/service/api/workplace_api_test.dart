import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/workplace_api.dart';

void main() {
  group('WorkplaceApi', () {
    test(
      'getPreferences uses GET /v1/workplace/preferences and parses snapshot',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'data': <String, dynamic>{
              'enabled_module_sids': <String>['module.sales', 'module.todo'],
              'added_app_ids': <String>['app.crm'],
              'ordered_app_ids': <String>['app.crm', 'app.docs'],
              'record_app_ids': <String>['app.attendance'],
              'updated_at': '2026-04-10T12:34:56Z',
              'version': 7,
            },
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final snapshot = await WorkplaceApi.instance.getPreferences();

        expect(adapter.lastRequestOptions?.path, '/v1/workplace/preferences');
        expect(adapter.lastRequestOptions?.method, 'GET');
        expect(adapter.lastRequestOptions?.responseType, ResponseType.plain);
        expect(snapshot.enabledModuleSids, <String>[
          'module.sales',
          'module.todo',
        ]);
        expect(snapshot.addedAppIds, <String>['app.crm']);
        expect(snapshot.orderedAppIds, <String>['app.crm', 'app.docs']);
        expect(snapshot.recordAppIds, <String>['app.attendance']);
        expect(snapshot.updatedAt, '2026-04-10T12:34:56Z');
        expect(snapshot.version, 7);
      },
    );

    test(
      'updateEnabledModules uses PUT /v1/workplace/preferences/modules payload',
      () async {
        final adapter = _RecordingJsonAdapter(
          payload: <String, dynamic>{
            'data': <String, dynamic>{
              'enabled_module_sids': <String>['module.todo'],
              'added_app_ids': <String>['app.crm'],
              'ordered_app_ids': <String>['app.crm'],
              'record_app_ids': <String>['app.attendance'],
              'updated_at': '2026-04-10T13:11:12Z',
              'version': 8,
            },
          },
        );
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final snapshot = await WorkplaceApi.instance.updateEnabledModules(
          const <String>['module.todo', 'module.todo', '   '],
        );

        expect(
          adapter.lastRequestOptions?.path,
          '/v1/workplace/preferences/modules',
        );
        expect(adapter.lastRequestOptions?.method, 'PUT');
        expect(
          adapter.lastRequestOptions?.data,
          containsPair('module_sids', <String>['module.todo']),
        );
        expect(snapshot.enabledModuleSids, <String>['module.todo']);
        expect(snapshot.version, 8);
        expect(snapshot.updatedAt, '2026-04-10T13:11:12Z');
      },
    );

    test('getPreferences throws when payload is malformed', () async {
      final adapter = _RecordingPlainTextAdapter(payload: 'not-json');
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await expectLater(
        WorkplaceApi.instance.getPreferences(),
        throwsA(isA<FormatException>()),
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

class _RecordingPlainTextAdapter implements HttpClientAdapter {
  _RecordingPlainTextAdapter({required this.payload});

  final String payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      payload,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.textPlainContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
