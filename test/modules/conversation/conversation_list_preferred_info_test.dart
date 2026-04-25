import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_item_loader.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/type/const.dart';

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

  group('personal conversation metadata fallback', () {
    test('does not fetch built-in personal accounts', () {
      expect(
        shouldFetchPersonalConversationUserInfo(
          conversation: _buildPersonalConversation('u_10000'),
          currentUid: 'u_self',
          resolvedTitle: 'u_10000',
        ),
        isFalse,
      );
      expect(
        shouldFetchPersonalConversationUserInfo(
          conversation: _buildPersonalConversation('fileHelper'),
          currentUid: 'u_self',
          resolvedTitle: 'fileHelper',
        ),
        isFalse,
      );
    });

    test('personal fallback preserves preferred avatar and vip', () async {
      final conversation = _buildPersonalConversation('u_alice')
        ..setReminderList([]);
      var calls = 0;

      final data = await resolveConversationListItemData(
        ConversationListItemRequest(
          conversation: conversation,
          preferredAvatarUrl: 'https://example.com/preferred.png',
          preferredVipLevel: 1,
          refreshToken: 0,
        ),
        currentUid: 'u_self',
        personalUserInfoLoader: (uid) async {
          calls += 1;
          return UserInfo(
            uid: uid,
            name: 'Loaded Alice',
            avatar: 'https://example.com/loaded.png',
            vipLevel: 2,
          );
        },
      );

      expect(calls, 1);
      expect(data.title, 'Loaded Alice');
      expect(data.avatarUrl, 'https://example.com/preferred.png');
      expect(data.vipLevel, 1);
    });
  });
}

WKUIConversationMsg _buildPersonalConversation(String channelId) {
  return WKUIConversationMsg()
    ..channelID = channelId
    ..channelType = WKChannelType.personal
    ..clientMsgNo = 'client_$channelId'
    ..lastMsgTimestamp = 1713000000;
}
