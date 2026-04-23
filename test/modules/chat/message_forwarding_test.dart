import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'buildForwardTargetsFromConversations prefers resolved channel titles and excludes source chat',
    () async {
      final source = WKUIConversationMsg()
        ..channelID = 'g1001'
        ..channelType = WKChannelType.group;
      source.setWkChannel(
        WKChannel('g1001', WKChannelType.group)..channelName = 'Design',
      );

      final group = WKUIConversationMsg()
        ..channelID = 'g2002'
        ..channelType = WKChannelType.group;
      group.setWkChannel(
        WKChannel('g2002', WKChannelType.group)..channelName = 'Product Team',
      );

      final personal = WKUIConversationMsg()
        ..channelID = 'u_bob'
        ..channelType = WKChannelType.personal;
      personal.setWkChannel(
        WKChannel('u_bob', WKChannelType.personal)
          ..channelName = 'Bob'
          ..channelRemark = 'Bobby',
      );

      final targets = await buildForwardTargetsFromConversations(
        <WKUIConversationMsg>[source, group, personal],
        excludedChannelId: 'g1001',
        excludedChannelType: WKChannelType.group,
      );

      expect(targets, hasLength(2));
      expect(
        targets.map((target) => target.displayName),
        containsAll(<String>['Product Team', 'Bobby']),
      );

      final groupTarget = targets.firstWhere(
        (target) => target.channelId == 'g2002',
      );
      expect(groupTarget.isGroup, isTrue);
      expect(groupTarget.subtitle, 'Group chat');

      final personalTarget = targets.firstWhere(
        (target) => target.channelId == 'u_bob',
      );
      expect(personalTarget.isGroup, isFalse);
      expect(personalTarget.subtitle, 'Direct chat');
      expect(personalTarget.displayName, 'Bobby');
    },
  );
}
