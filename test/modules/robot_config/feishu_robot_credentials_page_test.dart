import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/robot_config/feishu_robot_credentials.dart';
import 'package:wukong_im_app/modules/robot_config/feishu_robot_credentials_page.dart';

void main() {
  testWidgets('page masks existing App Secret by default', (tester) async {
    final store = _MemoryFeishuRobotCredentialsStore(
      initial: const FeishuRobotCredentials(
        appId: 'cli_a123',
        appSecret: 'secret-value',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: FeishuRobotCredentialsPage(store: store)),
    );
    await tester.pumpAndSettle();

    expect(find.text('飞书机器人配置'), findsOneWidget);
    expect(find.text('cli_a123'), findsOneWidget);

    final secretField = tester.widget<TextField>(
      find.byKey(const ValueKey('feishu-robot-app-secret-field')),
    );
    expect(secretField.obscureText, isTrue);
  });

  testWidgets('page saves credentials locally', (tester) async {
    final store = _MemoryFeishuRobotCredentialsStore();

    await tester.pumpWidget(
      MaterialApp(home: FeishuRobotCredentialsPage(store: store)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('feishu-robot-app-id-field')),
      ' cli_a123 ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feishu-robot-app-secret-field')),
      ' secret-value ',
    );
    await tester.tap(find.byKey(const ValueKey('feishu-robot-save-button')));
    await tester.pumpAndSettle();

    expect(store.saved.appId, 'cli_a123');
    expect(store.saved.appSecret, 'secret-value');
    expect(find.text('飞书机器人配置已保存到本机'), findsOneWidget);
  });
}

class _MemoryFeishuRobotCredentialsStore
    implements FeishuRobotCredentialsStore {
  _MemoryFeishuRobotCredentialsStore({
    FeishuRobotCredentials initial = FeishuRobotCredentials.empty,
  }) : saved = initial;

  FeishuRobotCredentials saved;

  @override
  Future<FeishuRobotCredentials> load() async => saved;

  @override
  Future<void> save(FeishuRobotCredentials credentials) async {
    saved = credentials.normalize();
  }
}
