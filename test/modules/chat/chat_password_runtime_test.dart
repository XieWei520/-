import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/constants/app_constants.dart';
import 'package:wukong_im_app/core/utils/crypto_utils.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/modules/chat/chat_password_runtime.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  setUp(() async {
    await StorageUtils.clear();
  });

  test('unlockChat decrements the remaining attempts after a wrong password', () async {
    final runtime = ChatPasswordRuntime(
      loadChannel: _loadProtectedChannel,
      clearChannelMessages: (_, _) async {},
    );

    final result = await runtime.unlockChat(
      channelId: 'u_secure',
      channelType: WKChannelType.personal,
      password: 'wrong-pass',
      uid: 'u_secure',
      storedChatPasswordHash: CryptoUtils.md5('654321u_secure'),
    );

    expect(result.unlocked, isFalse);
    expect(result.remainingAttempts, 2);
    expect(StorageUtils.getInt(AppConstants.keyChatPwdCount), 2);
  });

  test('unlockChat resets the remaining attempts after a correct password', () async {
    final runtime = ChatPasswordRuntime(
      loadChannel: _loadProtectedChannel,
      clearChannelMessages: (_, _) async {},
    );
    await StorageUtils.setInt(AppConstants.keyChatPwdCount, 1);

    final result = await runtime.unlockChat(
      channelId: 'u_secure',
      channelType: WKChannelType.personal,
      password: '654321',
      uid: 'u_secure',
      storedChatPasswordHash: CryptoUtils.md5('654321u_secure'),
    );

    expect(result.unlocked, isTrue);
    expect(result.remainingAttempts, chatPasswordMaxAttempts);
    expect(
      StorageUtils.getInt(AppConstants.keyChatPwdCount),
      chatPasswordMaxAttempts,
    );
  });

  test('unlockChat clears local messages when attempts are already exhausted', () async {
    var clearedChannel = '';
    var clearedType = -1;
    final runtime = ChatPasswordRuntime(
      loadChannel: _loadProtectedChannel,
      clearChannelMessages: (channelId, channelType) async {
        clearedChannel = channelId;
        clearedType = channelType;
      },
    );
    await StorageUtils.setInt(AppConstants.keyChatPwdCount, 0);

    final result = await runtime.unlockChat(
      channelId: 'u_secure',
      channelType: WKChannelType.personal,
      password: 'wrong-pass',
      uid: 'u_secure',
      storedChatPasswordHash: CryptoUtils.md5('654321u_secure'),
    );

    expect(result.unlocked, isFalse);
    expect(result.messagesCleared, isTrue);
    expect(result.remainingAttempts, 0);
    expect(clearedChannel, 'u_secure');
    expect(clearedType, WKChannelType.personal);
  });
}

Future<WKChannel?> _loadProtectedChannel(String channelId, int channelType) async {
  return WKChannel(channelId, channelType)
    ..remoteExtraMap = <String, dynamic>{'chat_pwd_on': 1}
    ..localExtra = <String, dynamic>{'chat_pwd_on': 1};
}
