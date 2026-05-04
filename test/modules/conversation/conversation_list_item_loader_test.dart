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

    test('preferred category changes the request key', () {
      final first = buildConversationListItemRequestKey(
        channelId: 'cs_001',
        channelType: 1,
        clientMsgNo: 'client_1',
        unreadCount: 3,
        lastMsgTimestamp: 42,
        preferredTitle: '售后客服',
        preferredAvatarUrl: 'https://example.com/a.png',
        refreshToken: 1,
      );
      final second = buildConversationListItemRequestKey(
        channelId: 'cs_001',
        channelType: 1,
        clientMsgNo: 'client_1',
        unreadCount: 3,
        lastMsgTimestamp: 42,
        preferredTitle: '售后客服',
        preferredAvatarUrl: 'https://example.com/a.png',
        preferredCategory: 'customer_service',
        refreshToken: 1,
      );

      expect(first, isNot(second));
    });

    test('keeps the last resolved row data for loading refreshes', () async {
      final loader = ConversationListItemLoader();
      const rowKey = '1:u_vip';

      final first = await loader.load(
        'request_1',
        () async => _buildItemData('VIP Alice', vipLevel: 1),
        cacheKey: rowKey,
      );

      expect(first.title, 'VIP Alice');
      expect(loader.cachedDataFor(rowKey)?.title, 'VIP Alice');
      expect(loader.cachedDataFor(rowKey)?.vipLevel, 1);

      final completer = Completer<WKConversationItemData>();
      final refreshing = loader.load(
        'request_2',
        () => completer.future,
        cacheKey: rowKey,
      );

      expect(loader.cachedDataFor(rowKey)?.title, 'VIP Alice');
      expect(loader.cachedDataFor(rowKey)?.vipLevel, 1);

      completer.complete(_buildItemData('VIP Alice updated', vipLevel: 1));

      final updated = await refreshing;
      expect(updated.title, 'VIP Alice updated');
      expect(loader.cachedDataFor(rowKey)?.title, 'VIP Alice updated');
      expect(loader.cachedDataFor(rowKey)?.vipLevel, 1);
    });
  });
}

WKConversationItemData _buildItemData(String title, {int vipLevel = 0}) {
  return WKConversationItemData(
    channelId: title,
    channelType: 1,
    title: title,
    vipLevel: vipLevel,
  );
}
