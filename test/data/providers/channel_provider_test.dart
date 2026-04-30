import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/providers/channel_provider.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';

void main() {
  group('MyGroupListNotifier', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await StorageUtils.init();
      await StorageUtils.clear();
      await StorageUtils.setUid('u_owner');
      await StorageUtils.setToken('token_owner');
    });

    test(
      'upserts renamed group so conversation preferred title refreshes',
      () async {
        final notifier = MyGroupListNotifier(
          loadOnInit: false,
          fetchGroups: () async => <GroupInfo>[
            GroupInfo(groupNo: 'g_renamed', name: '旧群名'),
          ],
        );

        await notifier.loadGroups();
        notifier.upsertGroup(GroupInfo(groupNo: 'g_renamed', name: '新群名'));

        final preferred = buildPreferredGroupConversationInfoMap(
          notifier.state.valueOrNull ?? const <GroupInfo>[],
        );

        expect(preferred['g_renamed']?.title, '新群名');
      },
    );
  });
}
