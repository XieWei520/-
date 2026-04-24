import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';

void main() {
  group('conversation preferred info maps', () {
    test('prefers friend remark over name when building conversation info', () {
      final infos = buildPreferredPersonalConversationInfoMap([
        Friend(
          uid: 'u_alice',
          name: 'Alice',
          avatar: 'media/alice.png',
          remark: 'Teammate Alice',
        ),
      ]);

      final info = infos['u_alice'];
      expect(info, isNotNull);
      expect(info!.title, 'Teammate Alice');
      expect(info.avatarUrl, contains('media/alice.png'));
    });

    test('carries vip level into personal conversation info', () {
      final infos = buildPreferredPersonalConversationInfoMap([
        Friend.fromJson({'uid': 'u_vip', 'name': 'VIP Alice', 'vip_level': 1}),
      ]);

      final info = infos['u_vip'];
      expect(info, isNotNull);
      expect(info!.vipLevel, 1);
    });

    test('carries normalized friend category into personal conversation info', () {
      final infos = buildPreferredPersonalConversationInfoMap([
        Friend(
          uid: 'u_system',
          name: 'System Friend',
          category: ' SYSTEM ',
        ),
      ]);

      final info = infos['u_system'];
      expect(info, isNotNull);
      expect(info!.category, 'system');
    });

    test('prefers group remark over name when building conversation info', () {
      final infos = buildPreferredGroupConversationInfoMap([
        GroupInfo(
          groupNo: 'g_demo',
          name: 'Demo Group',
          remark: 'Core Team',
          avatar: 'media/group.png',
        ),
      ]);

      final info = infos['g_demo'];
      expect(info, isNotNull);
      expect(info!.title, 'Core Team');
      expect(info.avatarUrl, contains('media/group.png'));
    });
  });
}
