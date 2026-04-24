import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_item_loader.dart';
import 'package:wukong_im_app/widgets/wk_conversation_item.dart';

void main() {
  group('conversation list item loader', () {
    test(
      'reuses the same in-flight future for an identical request key',
      () async {
        final loader = ConversationListItemLoader();
        final completer = Completer<WKConversationItemData>();
        var loadCalls = 0;

        final first = loader.load('conversation_a', () {
          loadCalls += 1;
          return completer.future;
        });
        final second = loader.load('conversation_a', () async {
          loadCalls += 1;
          return _buildItemData('second');
        });

        expect(identical(first, second), isTrue);
        expect(loadCalls, 1);

        completer.complete(_buildItemData('first'));

        final resolved = await second;
        expect(resolved.title, 'first');
      },
    );

    test('refresh token changes the request key', () {
      final first = buildConversationListItemRequestKey(
        channelId: 'u_demo',
        channelType: 1,
        clientMsgNo: 'client_1',
        unreadCount: 3,
        lastMsgTimestamp: 42,
        preferredTitle: 'Alice',
        preferredAvatarUrl: 'https://example.com/a.png',
        refreshToken: 1,
      );
      final second = buildConversationListItemRequestKey(
        channelId: 'u_demo',
        channelType: 1,
        clientMsgNo: 'client_1',
        unreadCount: 3,
        lastMsgTimestamp: 42,
        preferredTitle: 'Alice',
        preferredAvatarUrl: 'https://example.com/a.png',
        refreshToken: 2,
      );

      expect(first, isNot(second));
    });

    test('identical preferred metadata keeps the request key stable', () {
      final first = buildConversationListItemRequestKey(
        channelId: 'u_alice',
        channelType: 1,
        clientMsgNo: 'client_1',
        unreadCount: 0,
        lastMsgTimestamp: 100,
        preferredTitle: 'Alice',
        preferredAvatarUrl: 'https://example.com/a.png',
        preferredCategory: 'customer_service',
        preferredVipLevel: 1,
        refreshToken: 7,
      );
      final second = buildConversationListItemRequestKey(
        channelId: ' u_alice ',
        channelType: 1,
        clientMsgNo: ' client_1 ',
        unreadCount: 0,
        lastMsgTimestamp: 100,
        preferredTitle: ' Alice ',
        preferredAvatarUrl: ' https://example.com/a.png ',
        preferredCategory: ' CUSTOMER_SERVICE ',
        preferredVipLevel: 1,
        refreshToken: 7,
      );

      expect(first, second);
    });
  });
}

WKConversationItemData _buildItemData(String title) {
  return WKConversationItemData(channelId: title, channelType: 1, title: title);
}
