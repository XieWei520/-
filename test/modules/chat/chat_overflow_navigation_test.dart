import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_details_page.dart';
import 'package:wukong_im_app/modules/chat/chat_page_shell.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_entry_page.dart';
import 'package:wukong_im_app/modules/search/presentation/message_record_search_page.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_page.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('buildChatInfoPage routes group channels to GroupDetailPage', () {
    final page = buildChatInfoPage(
      channelId: 'g_overflow',
      channelType: WKChannelType.group,
      channelName: 'Overflow Group',
    );

    expect(page, isA<GroupDetailPage>());
  });

  test('buildChatInfoPage routes personal channels to ChatDetailsPage', () {
    final page = buildChatInfoPage(
      channelId: 'u_overflow',
      channelType: WKChannelType.personal,
      channelName: 'Overflow User',
    );

    expect(page, isA<ChatDetailsPage>());
  });

  testWidgets(
    'MessageRecordSearchPage stays a thin wrapper over ChatSearchEntryPage',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const MaterialApp(
            home: MessageRecordSearchPage(
              channelId: 'u_overflow',
              channelType: WKChannelType.personal,
              channelName: 'Overflow User',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MessageRecordSearchPage), findsOneWidget);
      expect(find.byType(ChatSearchEntryPage), findsOneWidget);
    },
  );

  testWidgets(
    'chat overflow more button is mounted and opens personal detail page',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const MaterialApp(
            home: ChatPageShell(
              channelId: 'u_overflow',
              channelType: WKChannelType.personal,
              channelName: 'Overflow User',
            ),
          ),
        ),
      );
      await tester.pump();

      final moreButton = find.byKey(const ValueKey<String>('chat-open-more'));
      expect(moreButton, findsOneWidget);

      await tester.tap(moreButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ChatDetailsPage), findsOneWidget);
    },
  );

  testWidgets(
    'personal detail shows readable actions and opens message record page',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const MaterialApp(
            home: ChatPageShell(
              channelId: 'u_overflow',
              channelType: WKChannelType.personal,
              channelName: 'Overflow User',
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('chat-open-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ChatDetailsPage), findsOneWidget);
      expect(find.text('查找聊天记录'), findsOneWidget);
      expect(find.text('消息免打扰'), findsOneWidget);

      await tester.tap(find.text('查找聊天记录'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(MessageRecordSearchPage), findsOneWidget);
    },
  );

  testWidgets(
    'chat overflow more button opens group detail page',
    (tester) async {
      await tester.pumpWidget(
        _wrapWithProviders(
          const MaterialApp(
            home: ChatPageShell(
              channelId: 'g_overflow',
              channelType: WKChannelType.group,
              channelName: 'Overflow Group',
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey<String>('chat-open-more')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(GroupDetailPage), findsOneWidget);
    },
  );
}

Widget _wrapWithProviders(Widget child) {
  return ProviderScope(
    overrides: [
      messageListProvider.overrideWith(
        (ref, session) =>
            _EmptyMessageListNotifier(session.channelId, session.channelType),
      ),
    ],
    child: child,
  );
}

class _EmptyMessageListNotifier extends MessageListNotifier {
  _EmptyMessageListNotifier(super.channelId, super.channelType);

  @override
  Future<void> loadMessages() async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {
    state = <WKMsg>[];
  }

  @override
  Future<void> loadMore() async {}
}
