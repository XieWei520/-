import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/modules/robot_config/feishu_robot_credentials.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns empty credentials when nothing is stored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesFeishuRobotCredentialsStore();

    final credentials = await store.load();

    expect(credentials.appId, isEmpty);
    expect(credentials.appSecret, isEmpty);
    expect(credentials.isConfigured, isFalse);
  });

  test('save trims and restores local Feishu credentials', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = SharedPreferencesFeishuRobotCredentialsStore();

    await store.save(
      const FeishuRobotCredentials(
        appId: ' cli_a123 ',
        appSecret: ' secret-value ',
      ),
    );

    final credentials = await store.load();
    expect(credentials.appId, 'cli_a123');
    expect(credentials.appSecret, 'secret-value');
    expect(credentials.isConfigured, isTrue);
  });
}
