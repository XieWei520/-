import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('Android conversation forbidden parity', () {
    test('shows forbidden icon only for normal group members when channel is forbidden', () {
      final channel = WKChannel('g_001', WKChannelType.group)..forbidden = 1;
      final normalMember = WKChannelMember()..role = 0;
      final managerMember = WKChannelMember()..role = 1;

      expect(
        resolveConversationForbiddenState(channel: channel, currentMember: normalMember),
        isTrue,
      );
      expect(
        resolveConversationForbiddenState(channel: channel, currentMember: managerMember),
        isFalse,
      );
      expect(
        resolveConversationForbiddenState(channel: channel, currentMember: null),
        isFalse,
      );
    });

    test('hides forbidden icon for non-forbidden channels', () {
      final channel = WKChannel('g_001', WKChannelType.group)..forbidden = 0;
      final normalMember = WKChannelMember()..role = 0;

      expect(
        resolveConversationForbiddenState(channel: channel, currentMember: normalMember),
        isFalse,
      );
    });
  });
}
