import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/workplace_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkplaceApi contracts', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test('fetchBanners parses the server banner contract', () async {
      final adapter = _RoutingJsonAdapter((options) {
        if (options.method.toUpperCase() == 'GET' &&
            options.uri.path == '/v1/workplace/banner') {
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'banner_no': 'banner-01',
                'cover': 'https://cdn.example/banner.png',
                'title': 'Workplace',
                'description': 'Featured tools',
                'jump_type': 1,
                'route': '/workplace/feature',
                'sort_num': 9,
                'created_at': '2026-04-16T12:00:00Z',
              },
            ],
          });
        }

        return _unhandled(options);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final banners = await WorkplaceApi.instance.fetchBanners();

      expect(banners, hasLength(1));
      expect(banners.single.bannerNo, 'banner-01');
      expect(banners.single.route, '/workplace/feature');
      expect(banners.single.jumpType, 1);
    });

    test(
      'fetchBanners also accepts raw list responses from the open-source server',
      () async {
        final adapter = _RoutingJsonAdapter((options) {
          if (options.method.toUpperCase() == 'GET' &&
              options.uri.path == '/v1/workplace/banner') {
            return _MockJsonResponse(<Map<String, dynamic>>[
              <String, dynamic>{
                'banner_no': 'banner-raw',
                'cover': 'https://cdn.example/raw.png',
                'title': 'Raw',
                'description': 'Unwrapped payload',
                'jump_type': 0,
                'route': 'https://example.com/raw',
                'sort_num': 2,
                'created_at': '2026-04-16T13:00:00Z',
              },
            ]);
          }

          return _unhandled(options);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final banners = await WorkplaceApi.instance.fetchBanners();

        expect(banners, hasLength(1));
        expect(banners.single.bannerNo, 'banner-raw');
        expect(banners.single.route, 'https://example.com/raw');
      },
    );

    test('fetchCategories parses the server category contract', () async {
      final adapter = _RoutingJsonAdapter((options) {
        if (options.method.toUpperCase() == 'GET' &&
            options.uri.path == '/v1/workplace/category') {
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'category_no': 'oa',
                'name': 'Office',
                'sort_num': 3,
              },
            ],
          });
        }

        return _unhandled(options);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final categories = await WorkplaceApi.instance.fetchCategories();

      expect(categories, hasLength(1));
      expect(categories.single.categoryNo, 'oa');
      expect(categories.single.name, 'Office');
      expect(categories.single.sortNum, 3);
    });

    test('fetchAppsByCategory keeps is_added and routing fields', () async {
      final adapter = _RoutingJsonAdapter((options) {
        if (options.method.toUpperCase() == 'GET' &&
            options.uri.path == '/v1/workplace/categorys/oa/app') {
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'app_id': 'crm',
                'sort_num': 10,
                'icon': 'https://cdn.example/crm.png',
                'name': 'CRM',
                'description': 'Customer management',
                'app_category': 'office',
                'status': 1,
                'jump_type': 0,
                'app_route': '/native/crm',
                'web_route': 'https://crm.example',
                'is_paid_app': 0,
                'is_added': 1,
              },
            ],
          });
        }

        return _unhandled(options);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      final apps = await WorkplaceApi.instance.fetchAppsByCategory('oa');

      expect(apps, hasLength(1));
      expect(apps.single.appId, 'crm');
      expect(apps.single.isAdded, isTrue);
      expect(apps.single.appRoute, '/native/crm');
      expect(apps.single.webRoute, 'https://crm.example');
    });

    test(
      'fetchAddedApps and fetchRecordedApps read the aligned user routes',
      () async {
        final adapter = _RoutingJsonAdapter((options) {
          if (options.method.toUpperCase() == 'GET' &&
              options.uri.path == '/v1/workplace/app') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'app_id': 'crm',
                  'sort_num': 2,
                  'icon': 'https://cdn.example/crm.png',
                  'name': 'CRM',
                  'description': 'Customer management',
                  'app_category': 'office',
                  'status': 1,
                  'jump_type': 0,
                  'app_route': '/native/crm',
                  'web_route': 'https://crm.example',
                  'is_paid_app': 0,
                },
              ],
            });
          }
          if (options.method.toUpperCase() == 'GET' &&
              options.uri.path == '/v1/workplace/app/record') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'app_id': 'attendance',
                  'sort_num': 1,
                  'icon': 'https://cdn.example/attendance.png',
                  'name': 'Attendance',
                  'description': 'Punch in',
                  'app_category': 'office',
                  'status': 1,
                  'jump_type': 1,
                  'app_route': '/native/attendance',
                  'web_route': '',
                  'is_paid_app': 0,
                  'is_added': 1,
                },
              ],
            });
          }

          return _unhandled(options);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final addedApps = await WorkplaceApi.instance.fetchAddedApps();
        final recordedApps = await WorkplaceApi.instance.fetchRecordedApps();

        expect(addedApps.single.appId, 'crm');
        expect(addedApps.single.isAdded, isFalse);
        expect(recordedApps.single.appId, 'attendance');
        expect(recordedApps.single.isAdded, isTrue);
      },
    );

    test('mutating workplace routes use the server-aligned paths', () async {
      final requests = <String>[];
      final adapter = _RoutingJsonAdapter((options) {
        requests.add(
          '${options.method.toUpperCase()} ${options.uri.path} ${jsonEncode(options.data)}',
        );
        return _MockJsonResponse(<String, dynamic>{'code': 0});
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await WorkplaceApi.instance.addApp('crm');
      await WorkplaceApi.instance.removeApp('crm');
      await WorkplaceApi.instance.reorderApps(const <String>['crm', 'oa']);
      await WorkplaceApi.instance.addRecord('crm');
      await WorkplaceApi.instance.removeRecord('crm');

      expect(requests, <String>[
        'POST /v1/workplace/apps/crm null',
        'DELETE /v1/workplace/apps/crm null',
        'PUT /v1/workplace/app/reorder {"app_ids":["crm","oa"]}',
        'POST /v1/workplace/apps/crm/record null',
        'DELETE /v1/workplace/apps/crm/record null',
      ]);
    });
  });
}

_MockJsonResponse _unhandled(RequestOptions options) {
  return _MockJsonResponse(<String, dynamic>{
    'code': 404,
    'msg': 'Unhandled request: ${options.method} ${options.uri.path}',
  }, statusCode: 404);
}

class _RoutingJsonAdapter implements HttpClientAdapter {
  _RoutingJsonAdapter(this._handler);

  final _MockJsonResponse Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final response = _handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.payload),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockJsonResponse {
  const _MockJsonResponse(this.payload, {this.statusCode = 200});

  final Object payload;
  final int statusCode;
}
