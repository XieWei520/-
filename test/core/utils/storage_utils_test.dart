import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('init migrates legacy wk auth keys into current auth keys', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'wk_uid': 'legacy-user',
      'wk_token': 'legacy-token',
    });

    await StorageUtils.init();

    expect(StorageUtils.isLoggedIn(), isTrue);
    expect(StorageUtils.getUid(), 'legacy-user');
    expect(StorageUtils.getToken(), 'legacy-token');
    expect(StorageUtils.prefs.getString(AppConstants.keyUid), 'legacy-user');
    expect(StorageUtils.prefs.getString(AppConstants.keyToken), 'legacy-token');
  });
}
