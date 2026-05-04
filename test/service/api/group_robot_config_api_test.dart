import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/group_api.dart';

void main() {
  group('GroupApi robot config persistence', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    test(
      'updateFeishuRobotConfig keeps submitted display fields when response is stale',
      () async {
        const groupNo = 'g_robot_feishu_stale';
        Map<String, dynamic>? updatePayload;
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'PUT' &&
              path == '${ApiConfig.groups}/$groupNo/robot/feishu') {
            updatePayload = Map<String, dynamic>.from(
              (options.data as Map?) ?? const <String, dynamic>{},
            );
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildFeishuConfigJson(
                groupNo: groupNo,
                displayName: '旧飞书机器人',
                displayAvatar: 'https://example.com/old-feishu.png',
              ),
            });
          }
          if (method == 'GET' &&
              path == '${ApiConfig.groups}/$groupNo/robot/feishu') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildFeishuConfigJson(
                groupNo: groupNo,
                displayName: '旧飞书机器人',
                displayAvatar: 'https://example.com/old-feishu.png',
              ),
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final saved = await GroupApi.instance.updateFeishuRobotConfig(
          groupNo,
          displayName: '新飞书机器人',
          displayAvatar: 'https://example.com/new-feishu.png',
        );

        expect(updatePayload, isNotNull);
        expect(saved.groupNo, groupNo);
        expect(saved.displayName, '新飞书机器人');
        expect(saved.displayAvatar, 'https://example.com/new-feishu.png');

        final reloaded = await GroupApi.instance.getFeishuRobotConfig(groupNo);
        expect(reloaded, isNotNull);
        expect(reloaded!.displayName, '新飞书机器人');
        expect(reloaded.displayAvatar, 'https://example.com/new-feishu.png');
      },
    );

    test(
      'updateDingTalkRobotConfig accepts code-only response and returns submitted display fields',
      () async {
        const groupNo = 'g_robot_dingtalk_code_only';
        final adapter = _RoutingJsonAdapter((options) {
          final method = options.method.toUpperCase();
          final path = options.uri.path;

          if (method == 'PUT' &&
              path == '${ApiConfig.groups}/$groupNo/robot/dingtalk') {
            return _MockJsonResponse(const <String, dynamic>{'code': 0});
          }
          if (method == 'GET' &&
              path == '${ApiConfig.groups}/$groupNo/robot/dingtalk') {
            return _MockJsonResponse(<String, dynamic>{
              'code': 0,
              'data': _buildDingTalkConfigJson(
                groupNo: groupNo,
                displayName: '旧钉钉机器人',
                displayAvatar: 'https://example.com/old-dingtalk.png',
              ),
            });
          }

          return _MockJsonResponse(<String, dynamic>{
            'code': 404,
            'msg': 'Unhandled request: $method $path',
          }, statusCode: 404);
        });
        ApiClient.instance.dio.httpClientAdapter = adapter;

        final saved = await GroupApi.instance.updateDingTalkRobotConfig(
          groupNo,
          enabled: false,
          displayName: '新钉钉机器人',
          displayAvatar: 'https://example.com/new-dingtalk.png',
        );

        expect(saved.groupNo, groupNo);
        expect(saved.enabled, isFalse);
        expect(saved.displayName, '新钉钉机器人');
        expect(saved.displayAvatar, 'https://example.com/new-dingtalk.png');

        final reloaded = await GroupApi.instance.getDingTalkRobotConfig(
          groupNo,
        );
        expect(reloaded, isNotNull);
        expect(reloaded!.displayName, '新钉钉机器人');
        expect(reloaded.displayAvatar, 'https://example.com/new-dingtalk.png');
      },
    );
  });
}

Map<String, dynamic> _buildFeishuConfigJson({
  required String groupNo,
  String displayName = '',
  String displayAvatar = '',
}) {
  return <String, dynamic>{
    'group_no': groupNo,
    'webhook_url': 'https://example.com/feishu/webhook',
    'secret': 'feishu-secret',
    'app_id': 'cli_xxx',
    'app_secret': '',
    'enabled': 1,
    'secret_set': 1,
    'app_secret_set': 1,
    'last_push_at': 0,
    'last_error': '',
    'updated_at': '2026-04-25 12:00:00',
    'display_name': displayName,
    'display_avatar': displayAvatar,
    'webhook_mode': 'im_generated',
    'official_webhook_url': '',
    'official_secret': '',
  };
}

Map<String, dynamic> _buildDingTalkConfigJson({
  required String groupNo,
  String displayName = '',
  String displayAvatar = '',
}) {
  return <String, dynamic>{
    'group_no': groupNo,
    'webhook_url': 'https://example.com/dingtalk/webhook',
    'secret': 'dingtalk-secret',
    'enabled': 1,
    'secret_set': 1,
    'last_push_at': 0,
    'last_error': '',
    'updated_at': '2026-04-25 12:00:00',
    'display_name': displayName,
    'display_avatar': displayAvatar,
    'webhook_mode': 'im_generated',
    'official_webhook_url': '',
    'official_secret': '',
  };
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
