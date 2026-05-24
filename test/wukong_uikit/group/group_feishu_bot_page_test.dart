import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/modules/robot_config/feishu_robot_credentials.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_feishu_bot_page.dart';

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
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(),
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
    expect(field.controller?.text, '群内机器人');

    expect(find.textContaining('仅影响悟空 IM 群内显示'), findsOneWidget);
    expect(find.textContaining('不会修改飞书官方机器人资料'), findsOneWidget);
  });

  testWidgets('saves display identity fields in update payload', (
    tester,
  ) async {
    Map<String, dynamic>? updatePayload;

    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(),
        });
      }

      if (method == 'PUT' &&
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        updatePayload = Map<String, dynamic>.from(
          (options.data as Map?) ?? const <String, dynamic>{},
        );
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(
            appId: updatePayload?['app_id']?.toString() ?? 'cli_xxx',
            appSecret: updatePayload?['app_secret']?.toString() ?? 'app-secret',
            displayName: updatePayload?['display_name']?.toString() ?? '群内机器人',
            displayAvatar:
                updatePayload?['display_avatar']?.toString() ??
                'https://im.example.com/robot-feishu.png',
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
    expect(updatePayload?['display_name'], '群内机器人');
    expect(
      updatePayload?['display_avatar'],
      'https://im.example.com/robot-feishu.png',
    );
    expect(updatePayload?.containsKey('official_webhook_url'), isFalse);
    expect(updatePayload?.containsKey('official_secret'), isFalse);
  });

  testWidgets(
    'submits configured Feishu OpenAPI credentials without rendering per-group fields',
    (tester) async {
      Map<String, dynamic>? updatePayload;

      ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
        final method = options.method.toUpperCase();
        final path = options.uri.path;

        if (method == 'GET' &&
            path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': _buildFeishuConfigJson(),
          });
        }

        if (method == 'PUT' &&
            path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
          updatePayload = Map<String, dynamic>.from(
            (options.data as Map?) ?? const <String, dynamic>{},
          );
          return _MockJsonResponse(<String, dynamic>{
            'code': 0,
            'data': _buildFeishuConfigJson(
              displayName:
                  updatePayload?['display_name']?.toString() ?? '?????',
              displayAvatar:
                  updatePayload?['display_avatar']?.toString() ??
                  'https://im.example.com/robot-feishu.png',
            ),
          });
        }

        return _MockJsonResponse(<String, dynamic>{
          'code': 404,
          'msg': 'Unhandled request: $method $path',
        }, statusCode: 404);
      });

      await _pumpPage(
        tester,
        credentialsStore: _MemoryFeishuRobotCredentialsStore(
          initial: const FeishuRobotCredentials(
            appId: 'cli_configured',
            appSecret: 'secret-configured',
          ),
        ),
      );

      expect(find.text('?? OpenAPI ??'), findsNothing);
      expect(find.text('????'), findsNothing);
      expect(find.text('????'), findsNothing);
      expect(find.textContaining('App Secret'), findsNothing);

      final saveCell = find.byKey(
        const ValueKey('group-robot-save-config-cell'),
      );
      await _scrollTo(tester, saveCell);
      await tester.tap(saveCell);
      await tester.pumpAndSettle();

      expect(updatePayload, isNotNull);
      expect(updatePayload?['app_id'], 'cli_configured');
      expect(updatePayload?['app_secret'], 'secret-configured');
    },
  );

  testWidgets('can switch to official mode', (tester) async {
    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(),
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

  testWidgets('rejects bypass-style invalid Feishu official URLs', (
    tester,
  ) async {
    Map<String, dynamic>? updatePayload;

    ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
      final method = options.method.toUpperCase();
      final path = options.uri.path;

      if (method == 'GET' &&
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(),
        });
      }

      if (method == 'PUT' &&
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        updatePayload = Map<String, dynamic>.from(
          (options.data as Map?) ?? const <String, dynamic>{},
        );
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(),
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
      'https://evil.com/?next=open.feishu.cn',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await _scrollTo(tester, saveCell);
    await tester.ensureVisible(saveCell);
    await tester.tap(saveCell);
    await tester.pumpAndSettle();

    expect(find.text('无效的飞书 Webhook URL（必须包含 open.feishu.cn）'), findsOneWidget);

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
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(),
        });
      }

      if (method == 'PUT' &&
          path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
        updatePayload = Map<String, dynamic>.from(
          (options.data as Map?) ?? const <String, dynamic>{},
        );
        return _MockJsonResponse(<String, dynamic>{
          'code': 0,
          'data': _buildFeishuConfigJson(
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
      'https://open.feishu.cn/open-apis/bot/v2/hook/abc123',
    );
    await tester.enterText(officialSecretField, 'feishu-official-secret');

    await _scrollTo(tester, saveCell);
    await tester.tap(saveCell);
    await tester.pumpAndSettle();

    expect(updatePayload, isNotNull);
    expect(updatePayload?['webhook_mode'], 'official');
    expect(
      updatePayload?['official_webhook_url'],
      'https://open.feishu.cn/open-apis/bot/v2/hook/abc123',
    );
    expect(updatePayload?['official_secret'], 'feishu-official-secret');
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  FeishuRobotCredentialsStore? credentialsStore,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GroupFeishuBotPage(
        groupNo: 'g_feishu',
        groupName: '测试群',
        credentialsStore:
            credentialsStore ?? _MemoryFeishuRobotCredentialsStore(),
      ),
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

Map<String, dynamic> _buildFeishuConfigJson({
  String appId = 'cli_xxx',
  String appSecret = 'app-secret',
  String displayName = '群内机器人',
  String displayAvatar = 'https://im.example.com/robot-feishu.png',
  String webhookMode = 'im_generated',
  String officialWebhookUrl = '',
  String officialSecret = '',
}) {
  return <String, dynamic>{
    'group_no': 'g_feishu',
    'webhook_url': 'https://example.com/webhook',
    'secret': 'sign-secret',
    'app_id': appId,
    'app_secret': appSecret,
    'enabled': 1,
    'secret_set': 1,
    'app_secret_set': 1,
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

class _MemoryFeishuRobotCredentialsStore
    implements FeishuRobotCredentialsStore {
  _MemoryFeishuRobotCredentialsStore({
    FeishuRobotCredentials initial = FeishuRobotCredentials.empty,
  }) : _credentials = initial;

  FeishuRobotCredentials _credentials;

  @override
  Future<FeishuRobotCredentials> load() async => _credentials;

  @override
  Future<void> save(FeishuRobotCredentials credentials) async {
    _credentials = credentials.normalize();
  }
}
