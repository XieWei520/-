import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';

void main() {
  test('SearchCollectionScope maps to expected content types', () {
    expect(SearchCollectionScope.image.contentTypes, <int>[2]);
    expect(SearchCollectionScope.file.contentTypes, <int>[5]);
    expect(SearchCollectionScope.link.contentTypes, <int>[14, 1]);
  });

  test(
    'SearchDateCell placeholder is non-navigable while active cell is navigable',
    () {
      const placeholder = SearchDateCell.placeholder(weekdayOffset: 3);
      const active = SearchDateCell(
        year: 2026,
        month: 4,
        day: 3,
        messageCount: 2,
        anchorOrderSeq: 99,
        isToday: false,
        isSelected: false,
      );

      expect(placeholder.isPlaceholder, isTrue);
      expect(placeholder.canOpen, isFalse);
      expect(active.isPlaceholder, isFalse);
      expect(active.canOpen, isTrue);
    },
  );

  test(
    'SearchMessageHit conversationKey combines channel type and channel id',
    () {
      const hit = SearchMessageHit(
        channelId: 'team-42',
        channelType: 3,
        messageSeq: 12,
        orderSeq: 34,
        timestamp: 1712123456,
        contentType: 2,
        fromUid: 'u100',
        fromName: 'Alex',
        previewText: 'preview',
      );

      expect(hit.conversationKey, '3:team-42');
    },
  );

  test('ChatLocateIntent factories normalize search hits and date cells', () {
    const hit = SearchMessageHit(
      channelId: 'group-1',
      channelType: 2,
      messageSeq: 77,
      orderSeq: 9901,
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

    final fromHit = ChatLocateIntent.fromSearchHit(
      hit,
      highlightKeyword: 'keyword',
      source: 'chat-keyword-search',
    );
    final fromDate = ChatLocateIntent.fromDateCell(
      cell: cell,
      channelId: 'group-1',
      channelType: 2,
      channelName: 'Project Group',
      source: 'search-date',
    );

    expect(fromHit.messageSeq, 77);
    expect(fromHit.orderSeq, 9901);
    expect(fromHit.highlightKeyword, 'keyword');
    expect(fromHit.source, 'chat-keyword-search');

    expect(fromDate.messageSeq, isNull);
    expect(fromDate.orderSeq, 8000);
    expect(fromDate.highlightKeyword, '');
    expect(fromDate.source, 'search-date');
    expect(fromDate.channelName, 'Project Group');

    const hitWithZeroAnchor = SearchMessageHit(
      channelId: 'group-1',
      channelType: 2,
      messageSeq: 99,
      orderSeq: 0,
      timestamp: 1712123456,
      contentType: 1,
      fromUid: 'u-alex',
      fromName: 'Alex',
      previewText: 'keyword appears here',
    );
    final zeroAnchorHitIntent = ChatLocateIntent.fromSearchHit(
      hitWithZeroAnchor,
      highlightKeyword: 'keyword',
      source: 'chat-keyword-search',
    );
    expect(zeroAnchorHitIntent.orderSeq, isNull);

    const cellWithZeroAnchor = SearchDateCell(
      year: 2026,
      month: 4,
      day: 3,
      messageCount: 8,
      anchorOrderSeq: 0,
      isToday: false,
      isSelected: false,
    );
    final zeroAnchorDateIntent = ChatLocateIntent.fromDateCell(
      cell: cellWithZeroAnchor,
      channelId: 'group-1',
      channelType: 2,
      source: 'search-date',
    );
    expect(zeroAnchorDateIntent.orderSeq, isNull);
  });

  test('SearchDateCell copyWith and dayKey support selected-day updates', () {
    const cell = SearchDateCell(
      year: 2026,
      month: 4,
      day: 3,
      messageCount: 8,
      anchorOrderSeq: 8000,
      isToday: true,
      isSelected: true,
    );

    final changed = cell.copyWith(isSelected: false);

    expect(cell.dayKey, '2026-04-03');
    expect(changed.dayKey, '2026-04-03');
    expect(changed.isSelected, isFalse);
    expect(changed.anchorOrderSeq, 8000);
    expect(changed.messageCount, 8);
  });
}
