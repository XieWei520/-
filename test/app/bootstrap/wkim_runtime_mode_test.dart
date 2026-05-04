import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/bootstrap/wkim_runtime_mode.dart';
import 'package:wukong_im_app/wk_foundation/runtime/app_environment.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  tearDown(() {
    WKIM.shared.runMode = Model.app;
  });

  test(
    'configureWkImRuntimeMode switches SDK to web mode for web environment',
    () {
      configureWkImRuntimeMode(
        AppEnvironment(platform: AppPlatform.web, isWeb: true),
      );

      expect(WKIM.shared.runMode, Model.web);
    },
  );

  test(
    'configureWkImRuntimeMode keeps SDK in app mode for native environments',
    () {
      WKIM.shared.runMode = Model.web;

      configureWkImRuntimeMode(
        AppEnvironment(platform: AppPlatform.android, isWeb: false),
      );

      expect(WKIM.shared.runMode, Model.app);
    },
  );

  test('configured web runtime lets WKIM setup skip local sqflite', () async {
    configureWkImRuntimeMode(
      AppEnvironment(platform: AppPlatform.web, isWeb: true),
    );

    final setup = await WKIM.shared.setup(
      Options.newDefault('web_uid', 'web_token', addr: 'wss://example.test/ws'),
    );

    expect(setup, isTrue);
  });
}
