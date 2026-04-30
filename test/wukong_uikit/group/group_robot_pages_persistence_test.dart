import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_dingtalk_bot_page.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_feishu_bot_page.dart';

void main() {
  group('group robot page display identity persistence', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    });

    testWidgets('Feishu avatar upload immediately saves display identity', (
      tester,
    ) async {
      const groupNo = 'g_feishu_auto_save';
      Map<String, dynamic>? updatePayload;
      final adapter = _RoutingJsonAdapter((options) {
        final method = options.method.toUpperCase();
        final path = options.uri.path;

        if (method == 'GET' &&
            path == '${ApiConfig.groups}/$groupNo/robot/feishu') {
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': _buildFeishuConfigJson(groupNo: groupNo),
          });
        }
        if (method == 'PUT' &&
            path == '${ApiConfig.groups}/$groupNo/robot/feishu') {
          updatePayload = Map<String, dynamic>.from(
            (options.data as Map?) ?? const <String, dynamic>{},
          );
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': _buildFeishuConfigJson(
              groupNo: groupNo,
              displayName:
                  updatePayload?['display_name']?.toString() ?? '群内机器人',
              displayAvatar: updatePayload?['display_avatar']?.toString() ?? '',
            ),
          });
        }

        return _MockJsonResponse(<String, dynamic>{
          'code': 404,
          'msg': 'Unhandled request: $method $path',
        }, statusCode: 404);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await tester.pumpWidget(
        MaterialApp(
          home: GroupFeishuBotPage(
            groupNo: groupNo,
            groupName: '测试群',
            pickDisplayAvatarImage: () async => 'C:\\fake\\feishu.png',
            uploadDisplayAvatarImage: (_, _) async =>
                'https://example.com/new-feishu.png',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final uploadButton = find.byKey(
        const ValueKey('group-robot-upload-avatar-button'),
      );
      await _scrollTo(tester, uploadButton);
      await tester.tap(uploadButton);
      await tester.pumpAndSettle();

      expect(updatePayload, isNotNull);
      expect(updatePayload?['display_name'], '群内机器人');
      expect(
        updatePayload?['display_avatar'],
        'https://example.com/new-feishu.png',
      );
    });

    testWidgets('DingTalk display name edits are auto-saved after debounce', (
      tester,
    ) async {
      const groupNo = 'g_dingtalk_auto_save';
      Map<String, dynamic>? updatePayload;
      final adapter = _RoutingJsonAdapter((options) {
        final method = options.method.toUpperCase();
        final path = options.uri.path;

        if (method == 'GET' &&
            path == '${ApiConfig.groups}/$groupNo/robot/dingtalk') {
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': _buildDingTalkConfigJson(groupNo: groupNo),
          });
        }
        if (method == 'PUT' &&
            path == '${ApiConfig.groups}/$groupNo/robot/dingtalk') {
          updatePayload = Map<String, dynamic>.from(
            (options.data as Map?) ?? const <String, dynamic>{},
          );
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': _buildDingTalkConfigJson(
              groupNo: groupNo,
              displayName:
                  updatePayload?['display_name']?.toString() ?? '钉钉群机器人',
              displayAvatar:
                  updatePayload?['display_avatar']?.toString() ??
                  'https://example.com/old-dingtalk.png',
            ),
          });
        }

        return _MockJsonResponse(<String, dynamic>{
          'code': 404,
          'msg': 'Unhandled request: $method $path',
        }, statusCode: 404);
      });
      ApiClient.instance.dio.httpClientAdapter = adapter;

      await tester.pumpWidget(
        const MaterialApp(
          home: GroupDingTalkBotPage(groupNo: groupNo, groupName: '测试群'),
        ),
      );
      await tester.pumpAndSettle();

      final nameField = find.byKey(
        const ValueKey('group-robot-display-name-field'),
      );
      await _scrollTo(tester, nameField);
      await tester.enterText(nameField, '新的钉钉机器人');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(updatePayload, isNotNull);
      expect(updatePayload?['display_name'], '新的钉钉机器人');
      expect(
        updatePayload?['display_avatar'],
        'https://example.com/old-dingtalk.png',
      );
    });
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _buildFeishuConfigJson({
  required String groupNo,
  String displayName = '群内机器人',
  String displayAvatar = 'https://example.com/old-feishu.png',
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
    'display_name': displayName,
    'display_avatar': displayAvatar,
    'webhook_mode': 'im_generated',
    'official_webhook_url': '',
    'official_secret': '',
    'updated_at': '2026-04-25 12:00:00',
  };
}

Map<String, dynamic> _buildDingTalkConfigJson({
  required String groupNo,
  String displayName = '钉钉群机器人',
  String displayAvatar = 'https://example.com/old-dingtalk.png',
}) {
  return <String, dynamic>{
    'group_no': groupNo,
    'webhook_url': 'https://example.com/dingtalk/webhook',
    'secret': 'dingtalk-secret',
    'enabled': 1,
    'secret_set': 1,
    'last_push_at': 0,
    'last_error': '',
    'display_name': displayName,
    'display_avatar': displayAvatar,
    'webhook_mode': 'im_generated',
    'official_webhook_url': '',
    'official_secret': '',
    'updated_at': '2026-04-25 12:00:00',
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
