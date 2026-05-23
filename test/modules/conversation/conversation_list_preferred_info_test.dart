import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/friend.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_item_loader.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukong_im_app/service/api/user_api.dart';

void main() {
  test(
    'missing cached message does not surface the literal no-message label',
    () {
      expect(resolveConversationPreviewText(null), isEmpty);
    },
  );

  test('conversation header uses readable tab title when connected', () {
    expect(resolveConversationHeaderTitle(WKConnectStatus.success), '消息');
    expect(resolveConversationHeaderTitle(WKConnectStatus.syncCompleted), '消息');
  });

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

    test('adds customer service accounts into personal conversation info', () {
      final infos = buildPreferredPersonalConversationInfoMap(
        const <Friend>[],
        customerServices: const <CustomerServiceAccount>[
          CustomerServiceAccount(uid: 'cs_001', name: '售后客服'),
        ],
      );

      final info = infos['cs_001'];
      expect(info, isNotNull);
      expect(info!.title, '售后客服');
      expect(info.category, 'customer_service');
    });

    test(
      'keeps friend display name while forcing customer service category for service accounts',
      () {
        final infos = buildPreferredPersonalConversationInfoMap(
          [Friend(uid: 'cs_001', name: '系统客服', remark: '专属客服')],
          customerServices: const <CustomerServiceAccount>[
            CustomerServiceAccount(uid: 'cs_001', name: '售后客服'),
          ],
        );

        final info = infos['cs_001'];
        expect(info, isNotNull);
        expect(info!.title, '专属客服');
        expect(info.category, 'customer_service');
      },
    );

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

    test('uses canonical group avatar when group payload has empty avatar', () {
      final infos = buildPreferredGroupConversationInfoMap([
        GroupInfo(groupNo: 'g_restart', name: 'Restart Group'),
      ]);

      final info = infos['g_restart'];
      expect(info, isNotNull);
      expect(info!.avatarUrl, contains('/v1/groups/g_restart/avatar'));
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

    test(
      'fetches personal metadata when channel already has nickname but vip is unknown',
      () async {
        final conversation = _buildPersonalConversation('u_vip')
          ..setReminderList([])
          ..setWkChannel(
            WKChannel('u_vip', WKChannelType.personal)
              ..channelName = 'VIP Alice',
          );
        var calls = 0;

        final data = await resolveConversationListItemData(
          ConversationListItemRequest(
            conversation: conversation,
            refreshToken: 0,
          ),
          currentUid: 'cs_agent',
          personalUserInfoLoader: (uid) async {
            calls += 1;
            return UserInfo(uid: uid, name: 'VIP Alice', vipLevel: 1);
          },
        );

        expect(calls, 1);
        expect(data.title, 'VIP Alice');
        expect(data.vipLevel, 1);
      },
    );
  });
}

WKUIConversationMsg _buildPersonalConversation(String channelId) {
  return WKUIConversationMsg()
    ..channelID = channelId
    ..channelType = WKChannelType.personal
    ..clientMsgNo = 'client_$channelId'
    ..lastMsgTimestamp = 1713000000;
}
