import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/favorites/favorite_record.dart';
import 'package:wukong_im_app/modules/favorites/favorite_record_navigation.dart';

void main() {
  testWidgets(
    'favorite record navigation opens chat for trusted locate routes',
    (tester) async {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'favorite-route-1',
        'sender_name': 'Alice',
        'content_type': 1,
        'content': '原消息',
        'channel_id': 'group-1',
        'channel_type': 2,
        'order_seq': 77,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    openFavoriteRecordInContext(
                      context,
                      record,
                      chatPageBuilder: (_) => const Placeholder(
                        key: ValueKey('favorite-chat-page'),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('favorite-chat-page')), findsOneWidget);
    },
  );

  testWidgets(
    'favorite record navigation opens chat when only conversation context exists',
    (tester) async {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'favorite-route-2',
        'sender_name': 'Alice',
        'content_type': 1,
        'content': '原消息',
        'channel_id': 'group-2',
        'channel_type': 2,
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    openFavoriteRecordInContext(
                      context,
                      record,
                      chatPageBuilder: (_) => const Placeholder(
                        key: ValueKey('favorite-chat-page-context-only'),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('favorite-chat-page-context-only')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'favorite record navigation can recover chat target through resolver',
    (tester) async {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'favorite-route-3',
        'sender_name': 'Alice',
        'content_type': 1,
        'content': '原消息',
        'message_id': 'message-lookup-1',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    openFavoriteRecordInContext(
                      context,
                      record,
                      routeResolver: (favorite) async {
                        expect(favorite.messageId, 'message-lookup-1');
                        return const FavoriteChatTarget(
                          channelId: 'u-recovered',
                          channelType: 1,
                          orderSeq: 128,
                        );
                      },
                      chatPageBuilder: (_) => const Placeholder(
                        key: ValueKey('favorite-chat-page-recovered'),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('favorite-chat-page-recovered')),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'favorite record navigation prefers server anchor when order_seq exists',
    (tester) async {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'favorite-route-priority-order-seq',
        'sender_name': 'Alice',
        'content_type': 1,
        'content': 'order seq route',
        'channel_id': 'group-priority',
        'channel_type': 2,
        'message_seq': 10,
        'order_seq': 88,
      });
      var resolverCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    openFavoriteRecordInContext(
                      context,
                      record,
                      routeResolver: (_) async {
                        resolverCalls += 1;
                        return const FavoriteChatTarget(
                          channelId: 'u-should-not-use',
                          channelType: 1,
                          orderSeq: 999,
                        );
                      },
                      chatPageBuilder: (_) => const Placeholder(
                        key: ValueKey('favorite-chat-page-order-seq-priority'),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('favorite-chat-page-order-seq-priority')),
        findsOneWidget,
      );
      expect(resolverCalls, 0);
    },
  );

  testWidgets(
    'favorite record navigation falls back to resolver when only message_seq exists',
    (tester) async {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'favorite-route-priority-message-seq',
        'sender_name': 'Alice',
        'content_type': 1,
        'content': 'message seq only route',
        'channel_id': 'group-legacy',
        'channel_type': 2,
        'message_seq': 22,
      });
      var resolverCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    openFavoriteRecordInContext(
                      context,
                      record,
                      routeResolver: (favorite) async {
                        resolverCalls += 1;
                        expect(favorite.messageSeq, 22);
                        return const FavoriteChatTarget(
                          channelId: 'u-fallback',
                          channelType: 1,
                          orderSeq: 666,
                        );
                      },
                      chatPageBuilder: (_) => const Placeholder(
                        key: ValueKey(
                          'favorite-chat-page-message-seq-fallback',
                        ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('favorite-chat-page-message-seq-fallback')),
        findsOneWidget,
      );
      expect(resolverCalls, 1);
    },
  );

  testWidgets(
    'favorite record navigation does not navigate when context is unmounted after resolver await',
    (tester) async {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'favorite-route-unmounted',
        'sender_name': 'Alice',
        'content_type': 1,
        'content': 'unmounted context route',
        'message_id': 'message-unmounted',
      });
      final resolverCompleter = Completer<FavoriteChatTarget?>();
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final openFuture = openFavoriteRecordInContext(
        capturedContext,
        record,
        routeResolver: (_) => resolverCompleter.future,
        chatPageBuilder: (_) =>
            const Placeholder(key: ValueKey('favorite-chat-page-unmounted')),
      );

      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      resolverCompleter.complete(
        const FavoriteChatTarget(
          channelId: 'u-unmounted',
          channelType: 1,
          orderSeq: 123,
        ),
      );

      final opened = await openFuture;
      await tester.pumpAndSettle();

      expect(opened, isFalse);
      expect(
        find.byKey(const ValueKey('favorite-chat-page-unmounted')),
        findsNothing,
      );
    },
  );
}
