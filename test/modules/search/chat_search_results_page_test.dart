import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';
import 'package:wukong_im_app/modules/search/presentation/chat_search_results_page.dart';

void main() {
  testWidgets(
    'keyword result tile exposes avatar, name, time, and content keys',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatSearchResultsPage(
            items: const <SearchMessageHit>[
              SearchMessageHit(
                channelId: 'group-1',
                channelType: 2,
                messageSeq: 42,
                orderSeq: 77,
                timestamp: 1712123456,
                contentType: 1,
                fromUid: 'u_alex',
                fromName: 'Alex',
                previewText: 'keyword result',
                channelName: 'Project Group',
              ),
            ],
            onTap: (_) {},
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('search-keyword-result-42')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-keyword-result-avatar-42')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-keyword-result-name-42')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-keyword-result-time-42')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('search-keyword-result-content-42')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'scrolling near the end triggers keyword load more and retry footer',
    (tester) async {
      var loadMoreCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatSearchResultsPage(
            items: List<SearchMessageHit>.generate(20, (index) {
              final seq = 100 + index;
              return SearchMessageHit(
                channelId: 'group-1',
                channelType: 2,
                messageSeq: seq,
                orderSeq: 70000 + seq,
                timestamp: 1712123456,
                contentType: 1,
                fromUid: 'u_alex',
                fromName: 'Alex',
                previewText: 'keyword result $seq',
                channelName: 'Project Group',
              );
            }),
            onTap: (_) {},
            onLoadMore: () {
              loadMoreCalls += 1;
            },
          ),
        ),
      );

      await tester.drag(find.byType(Scrollable), const Offset(0, -1200));
      await tester.pump();

      expect(loadMoreCalls, greaterThanOrEqualTo(1));
    },
  );

  testWidgets('load-more failure keeps visible items and offers retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ChatSearchResultsPage(
          items: const <SearchMessageHit>[
            SearchMessageHit(
              channelId: 'group-1',
              channelType: 2,
              messageSeq: 42,
              orderSeq: 77,
              timestamp: 1712123456,
              contentType: 1,
              fromUid: 'u_alex',
              fromName: 'Alex',
              previewText: 'keyword result',
              channelName: 'Project Group',
            ),
          ],
          onTap: (_) {},
          loadMoreError: 'load more failed',
          onRetryLoadMore: () {
            retried = true;
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('search-keyword-result-42')),
      findsOneWidget,
    );
    expect(find.text('Load more failed'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('chat-search-load-more-retry')),
    );
    expect(retried, isTrue);
  });
}
