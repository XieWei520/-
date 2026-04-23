import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group.dart';
import 'package:wukong_im_app/modules/search/presentation/message_record_search_page.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';

void main() {
  test(
    'buildAndroidGroupDetailMemberItems appends add and remove handles after members',
    () {
      final items = buildAndroidGroupDetailMemberItems(
        members: [
          GroupMember(groupNo: 'g1', uid: 'u1', name: 'Alpha', role: 1),
          GroupMember(groupNo: 'g1', uid: 'u2', name: 'Beta', role: 0),
        ],
        canAddMembers: true,
        canRemoveMembers: true,
      );

      expect(items.map((item) => item.type).toList(), const [
        AndroidGroupDetailMemberItemType.member,
        AndroidGroupDetailMemberItemType.member,
        AndroidGroupDetailMemberItemType.add,
        AndroidGroupDetailMemberItemType.remove,
      ]);
    },
  );

  test(
    'buildAndroidGroupDetailMemberItems moves owner and admins ahead of normal members',
    () {
      final items = buildAndroidGroupDetailMemberItems(
        members: [
          GroupMember(
            groupNo: 'g1',
            uid: 'u-normal-1',
            name: 'Normal 1',
            role: 0,
          ),
          GroupMember(groupNo: 'g1', uid: 'u-admin', name: 'Admin', role: 2),
          GroupMember(
            groupNo: 'g1',
            uid: 'u-normal-2',
            name: 'Normal 2',
            role: 0,
          ),
          GroupMember(groupNo: 'g1', uid: 'u-owner', name: 'Owner', role: 1),
        ],
        canAddMembers: true,
        canRemoveMembers: true,
        maxVisibleMembers: 18,
      );

      expect(
        items
            .where((item) => item.member != null)
            .map((item) => item.member!.uid)
            .toList(),
        ['u-owner', 'u-admin', 'u-normal-1', 'u-normal-2'],
      );
    },
  );

  test(
    'buildAndroidGroupDetailRows keeps Android core row order before report and clear',
    () {
      final rows = buildAndroidGroupDetailRows(
        showNickSetting: true,
        includeFeishuBot: true,
        includeDingTalkBot: true,
        includeGroupReminder: true,
      );

      expect(rows.map((row) => row.title).toList(), const [
        '群聊名称',
        '群二维码',
        '群公告',
        '备注',
        '查找聊天记录',
        '消息免打扰',
        '置顶聊天',
        '保存到通讯录',
        '我在本群的昵称',
        '显示群成员昵称',
        '飞书机器人',
        '钉钉机器人',
        '群待办 / 群提醒',
        '投诉',
        '清空聊天记录',
      ]);
    },
  );

  test('buildGroupSearchHistoryPage returns MessageRecordSearchPage', () {
    final page = buildGroupSearchHistoryPage(
      channelId: 'g1',
      channelType: 2,
      channelName: 'Group 1',
    );

    expect(page, isA<MessageRecordSearchPage>());
  });
}
