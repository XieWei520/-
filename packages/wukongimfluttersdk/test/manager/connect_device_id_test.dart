import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/manager/connect_manager.dart';
import 'package:wukongimfluttersdk/wkim.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WKIM.shared.options = Options.newDefault('u_device', 'token_device');
  });

  test('connect packet device id prefers explicit app device id', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('u_device_device_id', 'sdk_private_device');
    WKIM.shared.options.deviceID = 'bound_device_id';

    final resolved = await resolveConnectDeviceID();

    expect(resolved, 'bound_device_id');
  });

  test('connect packet device id preserves legacy SDK fallback', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('u_device_device_id', 'sdk_private_device');

    final resolved = await resolveConnectDeviceID();

    expect(resolved, 'sdk_private_deviceF');
  });
}
