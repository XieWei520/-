import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_push/notification/web_message_alert_plan.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('buildWebMessageAlertPlan', () {
    test('builds a personal incoming text alert from channel display name', () {
      final message =
          _textMessage(fromUid: 'alice', channelId: 'alice', text: '你好，Web')
            ..setFrom(
              WKChannel('alice', WKChannelType.personal)
                ..channelRemark = 'Alice 备注'
                ..channelName = 'Alice',
            );

      final plan = buildWebMessageAlertPlan(message, currentUid: 'me');

      expect(plan, isNotNull);
      expect(plan!.title, 'Alice 备注');
      expect(plan.body, '你好，Web');
    });

    test('builds a group incoming alert with sender and group names', () {
      final message =
          _textMessage(
              fromUid: 'alice',
              channelId: 'group-1',
              channelType: WKChannelType.group,
              text: '群消息',
            )
            ..setMemberOfFrom(WKChannelMember()..memberName = 'Alice')
            ..setChannelInfo(
              WKChannel('group-1', WKChannelType.group)..channelName = '产品群',
            );

      final plan = buildWebMessageAlertPlan(message, currentUid: 'me');

      expect(plan, isNotNull);
      expect(plan!.title, 'Alice · 产品群');
      expect(plan.body, '群消息');
    });

    test('skips self messages and invisible internal messages', () {
      final selfMessage = _textMessage(
        fromUid: 'me',
        channelId: 'alice',
        text: '我自己发的',
      );
      final internalMessage = _textMessage(
        fromUid: 'alice',
        channelId: 'alice',
        text: '内部指令',
      )..contentType = WkMessageContentType.insideMsg;

      expect(buildWebMessageAlertPlan(selfMessage, currentUid: 'me'), isNull);
      expect(
        buildWebMessageAlertPlan(internalMessage, currentUid: 'me'),
        isNull,
      );
    });
  });
}

WKMsg _textMessage({
  required String fromUid,
  required String channelId,
  required String text,
  int channelType = WKChannelType.personal,
}) {
  final content = WKTextContent(text);
  return WKMsg()
    ..fromUID = fromUid
    ..channelID = channelId
    ..channelType = channelType
    ..contentType = WkMessageContentType.text
    ..content = text
    ..messageContent = content;
}
