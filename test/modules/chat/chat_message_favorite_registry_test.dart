import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/modules/chat/chat_message_favorite_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageUtils.init();
  });

  setUp(() async {
    await StorageUtils.clear();
  });

  test('persists favorite keys within current uid scope only', () async {
    final registry = SharedPrefsChatMessageFavoriteRegistry();
    await StorageUtils.setUid('favorite_user_a');

    await registry.markFavorited('mid:favorite-a');

    expect(registry.contains('mid:favorite-a'), isTrue);

    await StorageUtils.setUid('favorite_user_b');
    final userBRegistry = SharedPrefsChatMessageFavoriteRegistry();
    expect(userBRegistry.contains('mid:favorite-a'), isFalse);

    await userBRegistry.markFavorited('mid:favorite-b');

    await StorageUtils.setUid('favorite_user_a');
    final userARegistry = SharedPrefsChatMessageFavoriteRegistry();
    expect(userARegistry.snapshot(), contains('mid:favorite-a'));
    expect(userARegistry.snapshot(), isNot(contains('mid:favorite-b')));
  });

  test('does not persist or restore favorites when uid is empty', () async {
    await StorageUtils.setUid('favorite_user_a');
    final userARegistry = SharedPrefsChatMessageFavoriteRegistry();
    await userARegistry.markFavorited('mid:favorite-a');

    await StorageUtils.setUid('');
    final anonymousRegistry = SharedPrefsChatMessageFavoriteRegistry();
    expect(anonymousRegistry.snapshot(), isEmpty);
    expect(anonymousRegistry.contains('mid:favorite-a'), isFalse);
    await anonymousRegistry.markFavorited('mid:anonymous');
    expect(anonymousRegistry.snapshot(), isEmpty);
    expect(anonymousRegistry.contains('mid:anonymous'), isFalse);

    await StorageUtils.setUid('favorite_user_b');
    final userBRegistry = SharedPrefsChatMessageFavoriteRegistry();
    expect(userBRegistry.snapshot(), isEmpty);
    expect(userBRegistry.contains('mid:anonymous'), isFalse);

    await StorageUtils.setUid('favorite_user_a');
    final userARegistryReloaded = SharedPrefsChatMessageFavoriteRegistry();
    expect(userARegistryReloaded.contains('mid:favorite-a'), isTrue);
    expect(userARegistryReloaded.contains('mid:anonymous'), isFalse);
  });
}
