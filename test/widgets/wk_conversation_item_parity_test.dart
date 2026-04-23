import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/widgets/wk_conversation_item.dart';
import 'package:wukong_im_app/widgets/wk_colors.dart';
import 'package:wukong_im_app/widgets/wk_reference_assets.dart';

void main() {
  Widget wrapWithApp(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets(
    'conversation item uses Android organization and robot tag labels',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          WKConversationItem(
            data: const WKConversationItemData(
              channelId: 'org_robot',
              channelType: 1,
              title: 'Org Robot',
              category: 'organization',
              isRobot: true,
            ),
          ),
        ),
      );

      expect(find.text('全员'), findsOneWidget);
      expect(find.text('机器人'), findsOneWidget);
      expect(find.text('Bot'), findsNothing);
    },
  );

  testWidgets(
    'conversation item shows compact vip badge for personal vip chats',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const WKConversationItem(
            data: WKConversationItemData(
              channelId: 'u_vip',
              channelType: 1,
              title: 'VIP Alice',
              vipLevel: 1,
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('conversation-vip-badge-u_vip')),
        findsOneWidget,
      );
      expect(find.text('VIP商家'), findsOneWidget);
    },
  );

  testWidgets(
    'conversation item keeps vip badge directly after the contact name',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const WKConversationItem(
            data: WKConversationItemData(
              channelId: 'u_vip',
              channelType: 1,
              title: 'VIP Alice',
              vipLevel: 1,
            ),
          ),
        ),
      );

      final titleFinder = find.text('VIP Alice');
      final badgeFinder = find.byKey(
        const ValueKey<String>('conversation-vip-badge-u_vip'),
      );
      final titleWidget = tester.widget<Text>(titleFinder);
      final titleRect = tester.getRect(titleFinder);
      final badgeRect = tester.getRect(badgeFinder);
      final textPainter = TextPainter(
        text: TextSpan(text: titleWidget.data, style: titleWidget.style),
        maxLines: titleWidget.maxLines,
        textDirection: TextDirection.ltr,
      )..layout();

      final gap = badgeRect.left - (titleRect.left + textPainter.width);
      expect(gap, lessThanOrEqualTo(20));
    },
  );

  testWidgets(
    'conversation item normalizes customer service aliases to 客服 tag',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const WKConversationItem(
            data: WKConversationItemData(
              channelId: 'u_cs',
              channelType: 1,
              title: '客服 Alice',
              category: 'customerService',
            ),
          ),
        ),
      );

      expect(find.text('客服'), findsOneWidget);
      expect(find.text('官方'), findsNothing);
    },
  );

  testWidgets(
    'conversation item renders Android reminder prefixes separately and keeps preview text gray',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const WKConversationItem(
            data: WKConversationItemData(
              channelId: 'draft_with_reminders',
              channelType: 1,
              title: 'Reminder Chat',
              lastMsgContent: '草稿内容',
              reminderLabel: '[有人@你] [草稿] [进群申请]',
              isDraft: true,
            ),
          ),
        ),
      );

      expect(find.text('[有人@你]'), findsOneWidget);
      expect(find.text('[草稿]'), findsOneWidget);
      expect(find.text('[进群申请]'), findsOneWidget);
      expect(find.text('草稿内容'), findsOneWidget);

      final previewText = tester.widget<Text>(find.text('草稿内容'));
      expect(previewText.style?.color, WKColors.textSecondary);
      expect(previewText.style?.fontWeight, FontWeight.w400);
    },
  );

  testWidgets('conversation item uses Android 22dp send status icon size', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithApp(
        const WKConversationItem(
          data: WKConversationItemData(
            channelId: 'send_status_size',
            channelType: 1,
            title: 'Send Status',
            showSingleTick: true,
          ),
        ),
      ),
    );

    final sendStatusIcon = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              WKReferenceAssets.sendSingle,
    );

    expect(sendStatusIcon, findsOneWidget);
    expect(tester.getSize(sendStatusIcon), const Size(22, 22));
  });

  testWidgets(
    'conversation item keeps reminders visible while showing Android typing state',
    (tester) async {
      await tester.pumpWidget(
        wrapWithApp(
          const WKConversationItem(
            data: WKConversationItemData(
              channelId: 'typing_state',
              channelType: 1,
              title: 'Typing Chat',
              reminderLabel: '[有人@你]',
              showTypingIndicator: true,
              typingLabel: '对方正在输入',
            ),
          ),
        ),
      );

      expect(find.text('[有人@你]'), findsOneWidget);
      expect(find.text('对方正在输入'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('conversation_typing_dots')),
        findsOneWidget,
      );
    },
  );
}
