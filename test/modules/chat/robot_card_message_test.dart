import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/modules/chat/robot_card_message.dart';
import 'package:wukong_im_app/widgets/robot_message_card.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('resolveRobotCardViewData returns whole-card link state', () {
    final message = WKMsg()
      ..channelType = WKChannelType.group
      ..contentType = MsgContentType.robotCard
      ..messageContent = (WKRobotCardContent()
        ..robotProvider = 'feishu'
        ..robotName = 'Feishu Robot'
        ..title = 'Message Notice'
        ..body = 'feishu-link-test-001'
        ..badge = 'LINK'
        ..linkUrl = 'https://example.com/detail'
        ..plainText = 'Message Notice feishu-link-test-001');

    final data = resolveRobotCardViewData(message);

    expect(data, isNotNull);
    expect(data!.robotProvider, 'feishu');
    expect(data.title, 'Message Notice');
    expect(data.body, 'feishu-link-test-001');
    expect(data.badge, 'LINK');
    expect(data.linkUrl, 'https://example.com/detail');
    expect(data.isClickable, isTrue);
  });

  test('resolveRobotCardLaunchUri rejects invalid or empty links', () {
    final message = WKMsg()
      ..channelType = WKChannelType.group
      ..contentType = MsgContentType.robotCard
      ..messageContent = (WKRobotCardContent()
        ..robotProvider = 'dingtalk'
        ..robotName = 'DingTalk Robot'
        ..title = 'Alert'
        ..body = 'dingtalk-alert-test-001'
        ..badge = 'NOTICE'
        ..linkUrl = 'not-a-http-link');

    expect(resolveRobotCardLaunchUri(message), isNull);
  });

  test('resolveRobotCardViewData keeps card visible when link missing', () {
    final message = WKMsg()
      ..channelType = WKChannelType.group
      ..contentType = MsgContentType.robotCard
      ..messageContent = (WKRobotCardContent()
        ..robotName = 'Feishu Robot'
        ..title = 'No Link Card'
        ..body = 'still-visible-001'
        ..badge = 'NOTICE'
        ..linkUrl = '  '
        ..plainText = 'No Link Card still-visible-001');

    final data = resolveRobotCardViewData(message);

    expect(data, isNotNull);
    expect(data!.isClickable, isFalse);
    expect(resolveRobotCardLaunchUri(message), isNull);
  });

  testWidgets(
    'RobotMessageCard renders premium fields and only fires tap when clickable',
    (tester) async {
      final clickableData = RobotCardViewData(
        robotProvider: 'feishu',
        robotName: 'Feishu Robot',
        robotAvatar: '',
        eyebrow: 'ROBOT MESSAGE',
        title: 'Message Notice',
        body: 'feishu-link-test-001',
        badge: 'LINK',
        plainText: 'Message Notice feishu-link-test-001',
        linkUrl: 'https://example.com/detail',
        linkUri: Uri.parse('https://example.com/detail'),
      );
      final passiveData = RobotCardViewData(
        robotProvider: 'dingtalk',
        robotName: 'DingTalk Robot',
        robotAvatar: '',
        eyebrow: 'ROBOT MESSAGE',
        title: 'Approval Notice',
        body: 'detail-002',
        badge: 'NOTICE',
        plainText: 'Approval Notice detail-002',
        linkUrl: '',
        linkUri: null,
      );
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                RobotMessageCard(
                  data: clickableData,
                  timeText: '13:14',
                  onTap: () => tapCount += 1,
                ),
                const SizedBox(height: 12),
                RobotMessageCard(
                  data: passiveData,
                  timeText: '13:15',
                  onTap: () => tapCount += 1,
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('robot-message-card')),
        findsNWidgets(2),
      );
      expect(find.text('Message Notice'), findsOneWidget);
      expect(find.text('feishu-link-test-001'), findsOneWidget);
      expect(find.text('LINK'), findsOneWidget);
      expect(find.textContaining('Feishu Robot'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('robot-message-card')).first,
      );
      await tester.pump();
      expect(tapCount, 1);

      await tester.tap(
        find.byKey(const ValueKey<String>('robot-message-card')).last,
      );
      await tester.pump();
      expect(tapCount, 1);
    },
  );
}
