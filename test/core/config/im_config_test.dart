import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/im_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    IMConfig.clearDebugDeviceFlagOverride();
  });

  test('windows defaults to PC device flag without override', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(IMConfig.currentDeviceFlag, IMConfig.deviceFlagPC);
  });

  test('debug runtime override can force Windows device flag to APP', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    IMConfig.setDebugDeviceFlagOverride(IMConfig.deviceFlagApp);

    expect(IMConfig.currentDeviceFlag, IMConfig.deviceFlagApp);
  });
}
