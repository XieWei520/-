import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_dingtalk_bot_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  testWidgets('renders IM-only display identity controls', (tester) async {
    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(),
        });
      }

      return _MockJsonResponse(<String, dynamic>{
        'code': 404,
        'msg': 'Unhandled request: $method $path',
      }, statusCode: 404);
    });

    await _pumpPage(tester);

    final fieldFinder = find.byKey(
      const ValueKey('group-robot-display-name-field'),
    );
    await _scrollTo(tester, fieldFinder);

    expect(fieldFinder, findsOneWidget);
    final field = tester.widget<TextField>(fieldFinder);
    expect(field.controller?.text, '钉钉群机器人');

    expect(find.textContaining('仅影响悟空 IM 群内显示'), findsOneWidget);
    expect(find.textContaining('不会修改钉钉官方机器人资料'), findsOneWidget);
  });

  testWidgets('saves display identity fields in update payload', (
    tester,
  ) async {
    Map<String, dynamic>? updatePayload;

    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(),
        });
      }

      if (method == 'PUT' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        updatePayload = Map<String, dynamic>.from(
          (options.data as Map?) ?? const <String, dynamic>{},
        );
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(
            webhookUrl: updatePayload?['regenerate_webhook'] == 1
                ? 'https://example.com/dingtalk/new_webhook'
                : 'https://example.com/dingtalk/webhook',
            secret: updatePayload?['regenerate_secret'] == 1
                ? 'SECnewSecret'
                : 'SECtest123',
            displayName: updatePayload?['display_name']?.toString() ?? '钉钉群机器人',
            displayAvatar:
                updatePayload?['display_avatar']?.toString() ??
                'https://im.example.com/robot-dingtalk.png',
          ),
        });
      }

      return _MockJsonResponse(<String, dynamic>{
        'code': 404,
        'msg': 'Unhandled request: $method $path',
      }, statusCode: 404);
    });

    await _pumpPage(tester);

    final saveCell = find.byKey(const ValueKey('group-robot-save-config-cell'));
    await _scrollTo(tester, saveCell);

    expect(saveCell, findsOneWidget);
    await tester.tap(saveCell);
    await tester.pumpAndSettle();

    expect(updatePayload, isNotNull);
    expect(updatePayload?['display_name'], '钉钉群机器人');
    expect(
      updatePayload?['display_avatar'],
      'https://im.example.com/robot-dingtalk.png',
    );
    expect(updatePayload?.containsKey('official_webhook_url'), isFalse);
    expect(updatePayload?.containsKey('official_secret'), isFalse);
  });

  testWidgets('can switch to official mode', (tester) async {
    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(),
        });
      }

      return _MockJsonResponse(<String, dynamic>{
        'code': 404,
        'msg': 'Unhandled request: $method $path',
      }, statusCode: 404);
    });

    await _pumpPage(tester);

    final officialModeFinder = find.byKey(
      const ValueKey('group-robot-webhook-mode-official'),
    );
    final imModeFinder = find.byKey(
      const ValueKey('group-robot-webhook-mode-im-generated'),
    );

    await _scrollTo(tester, officialModeFinder);
    expect(imModeFinder, findsOneWidget);
    expect(officialModeFinder, findsOneWidget);
    expect(find.text('IM 接收 Webhook'), findsOneWidget);
    expect(find.text('官方 Webhook'), findsOneWidget);

    await tester.tap(officialModeFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('group-robot-official-webhook-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('group-robot-official-secret-field')),
      findsOneWidget,
    );
    expect(find.text('当前版本说明：官方 Webhook 消息不会回流同步到 IM 群聊。'), findsOneWidget);
  });

  testWidgets('rejects bypass-style invalid DingTalk official URLs', (
    tester,
  ) async {
    Map<String, dynamic>? updatePayload;

    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(),
        });
      }

      if (method == 'PUT' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        updatePayload = Map<String, dynamic>.from(
          (options.data as Map?) ?? const <String, dynamic>{},
        );
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(),
        });
      }

      return _MockJsonResponse(<String, dynamic>{
        'code': 404,
        'msg': 'Unhandled request: $method $path',
      }, statusCode: 404);
    });

    await _pumpPage(tester);

    final officialModeFinder = find.byKey(
      const ValueKey('group-robot-webhook-mode-official'),
    );
    await _scrollTo(tester, officialModeFinder);
    await tester.tap(officialModeFinder);
    await tester.pumpAndSettle();

    final officialWebhookField = find.byKey(
      const ValueKey('group-robot-official-webhook-field'),
    );
    final saveCell = find.byKey(const ValueKey('group-robot-save-config-cell'));

    await _scrollTo(tester, officialWebhookField);
    await tester.enterText(
      officialWebhookField,
      'https://evil.com/?next=oapi.dingtalk.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await _scrollTo(tester, saveCell);
    await tester.ensureVisible(saveCell);
    await tester.tap(saveCell);
    await tester.pumpAndSettle();

    expect(
      find.text('无效的钉钉 Webhook URL（必须包含 oapi.dingtalk.com 或 api.dingtalk.com）'),
      findsOneWidget,
    );
    expect(updatePayload, isNull);
  });

  testWidgets('sends official webhook payload when saving official mode', (
    tester,
  ) async {
    Map<String, dynamic>? updatePayload;

    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(),
        });
      }

      if (method == 'PUT' &&
          path == '${ApiConfig.groups}/g_dingtalk/robot/dingtalk') {
        updatePayload = Map<String, dynamic>.from(
          (options.data as Map?) ?? const <String, dynamic>{},
        );
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildDingTalkConfigJson(
            webhookMode:
                updatePayload?['webhook_mode']?.toString() ?? 'im_generated',
            officialWebhookUrl:
                updatePayload?['official_webhook_url']?.toString() ?? '',
            officialSecret: updatePayload?['official_secret']?.toString() ?? '',
          ),
        });
      }

      return _MockJsonResponse(<String, dynamic>{
        'code': 404,
        'msg': 'Unhandled request: $method $path',
      }, statusCode: 404);
    });

    await _pumpPage(tester);

    final officialModeFinder = find.byKey(
      const ValueKey('group-robot-webhook-mode-official'),
    );
    await _scrollTo(tester, officialModeFinder);
    await tester.tap(officialModeFinder);
    await tester.pumpAndSettle();

    final officialWebhookField = find.byKey(
      const ValueKey('group-robot-official-webhook-field'),
    );
    final officialSecretField = find.byKey(
      const ValueKey('group-robot-official-secret-field'),
    );
    final saveCell = find.byKey(const ValueKey('group-robot-save-config-cell'));

    await _scrollTo(tester, officialWebhookField);
    await tester.enterText(
      officialWebhookField,
      'https://oapi.dingtalk.com/robot/send?access_token=abc123',
    );
    await tester.enterText(officialSecretField, 'dingtalk-official-secret');

    await _scrollTo(tester, saveCell);
    await tester.tap(saveCell);
    await tester.pumpAndSettle();

    expect(updatePayload, isNotNull);
    expect(updatePayload?['webhook_mode'], 'official');
    expect(
      updatePayload?['official_webhook_url'],
      'https://oapi.dingtalk.com/robot/send?access_token=abc123',
    );
    expect(updatePayload?['official_secret'], 'dingtalk-official-secret');
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: GroupDingTalkBotPage(groupNo: 'g_dingtalk', groupName: '测试群'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    220,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _buildDingTalkConfigJson({
  String webhookUrl = 'https://example.com/dingtalk/webhook',
  String secret = 'SECtest123',
  String displayName = '钉钉群机器人',
  String displayAvatar = 'https://im.example.com/robot-dingtalk.png',
  String webhookMode = 'im_generated',
  String officialWebhookUrl = '',
  String officialSecret = '',
}) {
  return <String, dynamic>{
    'group_no': 'g_dingtalk',
    'webhook_url': webhookUrl,
    'secret': secret,
    'enabled': 1,
    'secret_set': 1,
    'last_push_at': 1713513600,
    'last_error': '',
    'display_name': displayName,
    'display_avatar': displayAvatar,
    'webhook_mode': webhookMode,
    'official_webhook_url': officialWebhookUrl,
    'official_secret': officialSecret,
    'updated_at': '2026-04-22 10:00:00',
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
