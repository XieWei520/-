import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/message_alert_plan.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('buildMessageAlertPlan', () {
    test('builds an incoming personal message alert', () {
      final message =
          _textMessage(fromUid: 'alice', channelId: 'alice', text: 'hello')
            ..setFrom(
              WKChannel('alice', WKChannelType.personal)
                ..channelRemark = 'Alice'
                ..channelName = 'Alice raw',
            );

      final plan = buildMessageAlertPlan(message, currentUid: 'me');

      expect(plan, isNotNull);
      expect(plan!.title, 'Alice');
      expect(plan.body, 'hello');
      expect(plan.channelId, 'alice');
      expect(plan.channelType, WKChannelType.personal);
      expect(plan.conversationKey, '${WKChannelType.personal}:alice');
    });

    test('builds a group alert with sender and group names', () {
      final message =
          _textMessage(
              fromUid: 'alice',
              channelId: 'group-1',
              channelType: WKChannelType.group,
              text: 'ship it',
            )
            ..setMemberOfFrom(WKChannelMember()..memberName = 'Alice')
            ..setChannelInfo(
              WKChannel('group-1', WKChannelType.group)
                ..channelName = 'Product',
            );

      final plan = buildMessageAlertPlan(message, currentUid: 'me');

      expect(plan, isNotNull);
      expect(plan!.title, 'Alice - Product');
      expect(plan.body, 'ship it');
      expect(plan.conversationKey, '${WKChannelType.group}:group-1');
    });

    test('skips self, muted, deleted, internal, and non-red-dot messages', () {
      final self = _textMessage(
        fromUid: 'me',
        channelId: 'alice',
        text: 'self',
      );
      final muted = _textMessage(
        fromUid: 'alice',
        channelId: 'muted',
        text: 'quiet',
      )..setChannelInfo(WKChannel('muted', WKChannelType.personal)..mute = 1);
      final deleted = _textMessage(
        fromUid: 'alice',
        channelId: 'alice',
        text: 'gone',
      )..isDeleted = 1;
      final internal = _textMessage(
        fromUid: 'alice',
        channelId: 'alice',
        text: 'cmd',
      )..contentType = WkMessageContentType.insideMsg;
      final noRedDot = _textMessage(
        fromUid: 'alice',
        channelId: 'alice',
        text: 'silent',
        redDot: false,
      );

      expect(buildMessageAlertPlan(self, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(muted, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(deleted, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(internal, currentUid: 'me'), isNull);
      expect(buildMessageAlertPlan(noRedDot, currentUid: 'me'), isNull);
    });
  });
}

WKMsg _textMessage({
  required String fromUid,
  required String channelId,
  required String text,
  int channelType = WKChannelType.personal,
  bool redDot = true,
}) {
  final content = WKTextContent(text);
  return WKMsg()
    ..fromUID = fromUid
    ..channelID = channelId
    ..channelType = channelType
    ..contentType = WkMessageContentType.text
    ..content = text
    ..messageContent = content
    ..header.redDot = redDot;
}
