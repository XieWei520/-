import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';

void main() {
  group('GroupInfo', () {
    test('fromJson parses server-backed group detail settings', () {
      final group = GroupInfo.fromJson({
        'group_no': 'g-10001',
        'name': 'Migration Validation Group',
        'remark': 'General Group',
        'mute': 1,
        'top': 1,
        'show_nick': 0,
        'save': 1,
        'invite': 1,
        'allow_view_history_msg': 0,
        'join_group_remind': 1,
        'revoke_remind': 1,
        'receipt': 1,
        'forbidden_add_friend': 0,
        'screenshot': 1,
        'chat_pwd_on': 1,
        'role': 2,
        'member_count': 18,
        'forbidden_expir_time': 123456,
        'created_at': '2026-03-31T10:20:30Z',
        'updated_at': '2026-04-01T11:22:33Z',
      });

      expect(group.groupNo, 'g-10001');
      expect(group.name, 'Migration Validation Group');
      expect(group.remark, 'General Group');
      expect(group.mute, 1);
      expect(group.top, 1);
      expect(group.showNick, 0);
      expect(group.save, 1);
      expect(group.invite, 1);
      expect(group.allowViewHistoryMsg, 0);
      expect(group.joinGroupRemind, 1);
      expect(group.revokeRemind, 1);
      expect(group.receipt, 1);
      expect(group.forbiddenAddFriend, 0);
      expect(group.screenshot, 1);
      expect(group.chatPwdOn, 1);
      expect(group.role, 2);
      expect(group.memberCount, 18);
      expect(group.forbiddenExpirTime, 123456);
      expect(group.createdAt, '2026-03-31T10:20:30Z');
      expect(group.updatedAt, '2026-04-01T11:22:33Z');
    });

    test('fromJson supports channel-style aliases for display names', () {
      final group = GroupInfo.fromJson({
        'group_no': 'g-10002',
        'group_name': 'Alpha Group',
        'channel_name': 'Channel Alpha',
        'display_name': 'Display Alpha',
        'channel_remark': 'Pinned Alpha',
        'group_remark': 'Remark Alpha',
      });

      expect(group.name, 'Alpha Group');
      expect(group.remark, 'Pinned Alpha');
    });

    test('toJson serializes server-backed group detail settings', () {
      final group = GroupInfo(
        groupNo: 'g-10001',
        name: 'Migration Validation Group',
        remark: 'General Group',
        mute: 1,
        top: 1,
        showNick: 0,
        save: 1,
        invite: 1,
        allowViewHistoryMsg: 0,
        joinGroupRemind: 1,
        revokeRemind: 1,
        receipt: 1,
        forbiddenAddFriend: 0,
        screenshot: 1,
        chatPwdOn: 1,
        role: 2,
        memberCount: 18,
        forbiddenExpirTime: 123456,
        createdAt: '2026-03-31T10:20:30Z',
        updatedAt: '2026-04-01T11:22:33Z',
      );

      final json = group.toJson();

      expect(json, containsPair('group_no', 'g-10001'));
      expect(json, containsPair('name', 'Migration Validation Group'));
      expect(json, containsPair('remark', 'General Group'));
      expect(json, containsPair('mute', 1));
      expect(json, containsPair('top', 1));
      expect(json, containsPair('show_nick', 0));
      expect(json, containsPair('save', 1));
      expect(json, containsPair('invite', 1));
      expect(json, containsPair('allow_view_history_msg', 0));
      expect(json, containsPair('join_group_remind', 1));
      expect(json, containsPair('revoke_remind', 1));
      expect(json, containsPair('receipt', 1));
      expect(json, containsPair('forbidden_add_friend', 0));
      expect(json, containsPair('screenshot', 1));
      expect(json, containsPair('chat_pwd_on', 1));
      expect(json, containsPair('role', 2));
      expect(json, containsPair('member_count', 18));
      expect(json, containsPair('forbidden_expir_time', 123456));
      expect(json, containsPair('created_at', '2026-03-31T10:20:30Z'));
      expect(json, containsPair('updated_at', '2026-04-01T11:22:33Z'));
    });
  });

  group('GroupMember', () {
    test('fromJson supports member_* aliases from group member payloads', () {
      final member = GroupMember.fromJson({
        'channel_id': 'g-10001',
        'member_uid': 'u_alias',
        'member_name': 'test4',
        'member_avatar': 'https://example.com/test4.png',
        'member_remark': '好友 test4',
        'role': 0,
      });

      expect(member.groupNo, 'g-10001');
      expect(member.uid, 'u_alias');
      expect(member.name, 'test4');
      expect(member.avatar, 'https://example.com/test4.png');
      expect(member.remark, '好友 test4');
    });

    test('fromJson falls back to username when member_name is absent', () {
      final member = GroupMember.fromJson({
        'channel_id': 'g-10002',
        'member_uid': 'u_username_only',
        'username': 'test5',
        'role': 0,
      });

      expect(member.groupNo, 'g-10002');
      expect(member.uid, 'u_username_only');
      expect(member.name, 'test5');
    });

    test('exposes owner/admin role helpers', () {
      final owner = GroupMember.fromJson({
        'group_no': 'g-10001',
        'uid': 'u_owner',
        'role': 1,
      });
      final admin = GroupMember.fromJson({
        'group_no': 'g-10001',
        'uid': 'u_admin',
        'role': 2,
      });
      final normal = GroupMember.fromJson({
        'group_no': 'g-10001',
        'uid': 'u_member',
        'role': 0,
      });

      expect(owner.isOwner, isTrue);
      expect(owner.isAdmin, isFalse);
      expect(admin.isAdmin, isTrue);
      expect(admin.isOwner, isFalse);
      expect(normal.isNormal, isTrue);
    });

    test(
      'GroupMember moderation helpers expose blacklist and active mute state',
      () {
        const blacklistStatusWireValue = 2;
        expect(GroupMemberStatus.blacklist, blacklistStatusWireValue);

        final member = GroupMember.fromJson({
          'group_no': 'g-10001',
          'uid': 'u_target',
          'role': 0,
          'status': blacklistStatusWireValue,
          'forbidden_expir_time': 2000000000,
        });

        expect(member.isBlacklisted, isTrue);
        expect(
          member.isMutedAt(
            DateTime.fromMillisecondsSinceEpoch(1900000000 * 1000),
          ),
          isTrue,
        );
        expect(
          member.isMutedAt(
            DateTime.fromMillisecondsSinceEpoch(2100000000 * 1000),
          ),
          isFalse,
        );
      },
    );
  });
}
