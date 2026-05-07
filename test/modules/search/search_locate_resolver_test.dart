import 'package:flutter_test/flutter_test.dart';

import 'package:wukong_im_app/modules/search/data/search_locate_resolver.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';

void main() {
  test(
    'SearchLocateResolver converts search hits and date cells into locate intents',
    () {
      const resolver = SearchLocateResolver();
      const hit = SearchMessageHit(
        channelId: 'group-1',
        channelType: 2,
        messageSeq: 77,
        orderSeq: 0,
        timestamp: 1712123456,
        contentType: 1,
        fromUid: 'u-alex',
        fromName: 'Alex',
        previewText: 'keyword appears here',
        channelName: 'Project Group',
      );
      const cell = SearchDateCell(
        year: 2026,
        month: 4,
        day: 3,
        messageCount: 8,
        anchorOrderSeq: 8000,
        isToday: false,
        isSelected: false,
      );

      final searchIntent = resolver.fromSearchHit(
        hit,
        highlightKeyword: 'keyword',
        source: 'chat-member-search',
      );
      final dateIntent = resolver.fromDateCell(
        cell: cell,
        channelId: 'group-1',
        channelType: 2,
        channelName: 'Project Group',
        source: 'search-date',
      );

      expect(searchIntent.messageSeq, 77);
      expect(searchIntent.orderSeq, isNull);
      expect(searchIntent.highlightKeyword, 'keyword');
      expect(dateIntent.messageSeq, isNull);
      expect(dateIntent.orderSeq, 8000);
      expect(dateIntent.channelName, 'Project Group');
    },
  );
}
