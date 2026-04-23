import 'package:flutter/foundation.dart';

enum SearchMenuKind { date, image, file, link, member }

enum SearchCollectionScope {
  image(<int>[2]),
  file(<int>[5]),
  link(<int>[14, 1]);

  const SearchCollectionScope(this.contentTypes);
  final List<int> contentTypes;
}

@immutable
class SearchMenuEntry {
  const SearchMenuEntry({
    required this.kind,
    required this.title,
    required this.iconAsset,
    required this.key,
  });

  final SearchMenuKind kind;
  final String title;
  final String iconAsset;
  final String key;
}

@immutable
class SearchMessageHit {
  const SearchMessageHit({
    required this.channelId,
    required this.channelType,
    required this.messageSeq,
    required this.orderSeq,
    required this.timestamp,
    required this.contentType,
    required this.fromUid,
    required this.fromName,
    required this.previewText,
    this.channelName,
    this.messageId,
    this.clientMsgNo,
    this.matchCount = 1,
  });

  final String channelId;
  final int channelType;
  final int messageSeq;
  final int orderSeq;
  final int timestamp;
  final int contentType;
  final String fromUid;
  final String fromName;
  final String previewText;
  final String? channelName;
  final String? messageId;
  final String? clientMsgNo;
  final int matchCount;

  String get conversationKey => '$channelType:$channelId';
}

@immutable
class SearchMediaItem {
  const SearchMediaItem({
    required this.hit,
    required this.scope,
    required this.sectionKey,
    this.mediaUrl,
    this.fileName,
    this.linkUrl,
  });

  final SearchMessageHit hit;
  final SearchCollectionScope scope;
  final String sectionKey;
  final String? mediaUrl;
  final String? fileName;
  final String? linkUrl;
}

@immutable
class SearchMemberHit {
  const SearchMemberHit({
    required this.uid,
    required this.displayName,
    this.avatarUrl,
  });

  final String uid;
  final String displayName;
  final String? avatarUrl;
}

@immutable
class SearchDateCell {
  const SearchDateCell({
    required this.year,
    required this.month,
    required this.day,
    required this.messageCount,
    required this.anchorOrderSeq,
    required this.isToday,
    required this.isSelected,
    this.isPlaceholder = false,
    this.weekdayOffset = 0,
  });

  const SearchDateCell.placeholder({required this.weekdayOffset})
      : year = 0,
        month = 0,
        day = 0,
        messageCount = 0,
        anchorOrderSeq = 0,
        isToday = false,
        isSelected = false,
        isPlaceholder = true;

  final int year;
  final int month;
  final int day;
  final int messageCount;
  final int anchorOrderSeq;
  final bool isToday;
  final bool isSelected;
  final bool isPlaceholder;
  final int weekdayOffset;

  bool get canOpen => !isPlaceholder && messageCount > 0 && anchorOrderSeq > 0;

  String get dayKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  SearchDateCell copyWith({
    int? year,
    int? month,
    int? day,
    int? messageCount,
    int? anchorOrderSeq,
    bool? isToday,
    bool? isSelected,
    bool? isPlaceholder,
    int? weekdayOffset,
  }) {
    return SearchDateCell(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      messageCount: messageCount ?? this.messageCount,
      anchorOrderSeq: anchorOrderSeq ?? this.anchorOrderSeq,
      isToday: isToday ?? this.isToday,
      isSelected: isSelected ?? this.isSelected,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      weekdayOffset: weekdayOffset ?? this.weekdayOffset,
    );
  }
}

@immutable
class SearchDateMonthSection {
  const SearchDateMonthSection({
    required this.year,
    required this.month,
    required this.cells,
  });

  final int year;
  final int month;
  final List<SearchDateCell> cells;

  String get sectionKey => '$year-${month.toString().padLeft(2, '0')}';
}

@immutable
class ChatLocateIntent {
  const ChatLocateIntent({
    required this.channelId,
    required this.channelType,
    this.messageSeq,
    this.orderSeq,
    this.highlightKeyword = '',
    required this.source,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final int? messageSeq;
  final int? orderSeq;
  final String highlightKeyword;
  final String source;
  final String? channelName;

  factory ChatLocateIntent.fromSearchHit(
    SearchMessageHit hit, {
    required String highlightKeyword,
    required String source,
  }) {
    final resolvedOrderSeq = hit.orderSeq > 0 ? hit.orderSeq : null;
    return ChatLocateIntent(
      channelId: hit.channelId,
      channelType: hit.channelType,
      messageSeq: hit.messageSeq,
      orderSeq: resolvedOrderSeq,
      highlightKeyword: highlightKeyword,
      source: source,
      channelName: hit.channelName,
    );
  }

  factory ChatLocateIntent.fromDateCell({
    required SearchDateCell cell,
    required String channelId,
    required int channelType,
    String? channelName,
    required String source,
  }) {
    final resolvedOrderSeq = cell.anchorOrderSeq > 0 ? cell.anchorOrderSeq : null;
    return ChatLocateIntent(
      channelId: channelId,
      channelType: channelType,
      messageSeq: null,
      orderSeq: resolvedOrderSeq,
      highlightKeyword: '',
      source: source,
      channelName: channelName,
    );
  }
}
