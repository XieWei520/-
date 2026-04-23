import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';

import '../domain/search_models.dart';

@immutable
class SearchDateBucket {
  const SearchDateBucket({
    required this.dayKey,
    required this.messageCount,
    required this.anchorOrderSeq,
  });

  final String dayKey;
  final int messageCount;
  final int anchorOrderSeq;
}

class SearchLocalTimelineDataSource {
  Future<List<SearchDateBucket>> loadDateBuckets({
    required String channelId,
    required int channelType,
  }) async {
    final Database? db = WKDBHelper.shared.getDB();
    if (db == null) {
      return const <SearchDateBucket>[];
    }

    final rows = await db.rawQuery(_loadDateBucketsSql, <Object?>[
      channelId,
      channelType,
    ]);

    return rows
        .map(
          (row) => SearchDateBucket(
            dayKey: row['day_key']?.toString() ?? '',
            messageCount: _readInt(row['message_count']),
            anchorOrderSeq: _readInt(row['anchor_order_seq']),
          ),
        )
        .where((bucket) => bucket.dayKey.isNotEmpty)
        .toList(growable: false);
  }
}

const String _loadDateBucketsSql = '''
SELECT
  strftime('%Y-%m-%d', datetime(${WKDBConst.tableMessage}.timestamp, 'unixepoch', 'localtime')) AS day_key,
  COUNT(*) AS message_count,
  MAX(${WKDBConst.tableMessage}.order_seq) AS anchor_order_seq
FROM ${WKDBConst.tableMessage}
LEFT JOIN ${WKDBConst.tableMessageExtra}
  ON ${WKDBConst.tableMessage}.message_id = ${WKDBConst.tableMessageExtra}.message_id
WHERE ${WKDBConst.tableMessage}.channel_id = ?
  AND ${WKDBConst.tableMessage}.channel_type = ?
  AND ${WKDBConst.tableMessage}.is_deleted = 0
  AND IFNULL(${WKDBConst.tableMessageExtra}.revoke, 0) = 0
  AND IFNULL(${WKDBConst.tableMessageExtra}.is_mutual_deleted, 0) = 0
GROUP BY day_key
ORDER BY day_key ASC
''';

List<SearchDateMonthSection> buildDateCalendarSections({
  required List<SearchDateBucket> buckets,
  required DateTime now,
}) {
  if (buckets.isEmpty) {
    return const <SearchDateMonthSection>[];
  }

  final sortedBuckets = List<SearchDateBucket>.from(
    buckets,
  )..sort((left, right) => left.dayKey.compareTo(right.dayKey));
  final bucketByDay = <String, SearchDateBucket>{
    for (final bucket in sortedBuckets) bucket.dayKey: bucket,
  };

  final firstDay = DateTime.parse(sortedBuckets.first.dayKey);
  final startMonth = DateTime(firstDay.year, firstDay.month);
  final endMonth = DateTime(now.year, now.month);
  final sections = <SearchDateMonthSection>[];

  for (
    var current = startMonth;
    !_isAfterMonth(current, endMonth);
    current = DateTime(current.year, current.month + 1)
  ) {
    sections.add(
      SearchDateMonthSection(
        year: current.year,
        month: current.month,
        cells: _buildMonthCells(
          year: current.year,
          month: current.month,
          bucketByDay: bucketByDay,
          now: now,
        ),
      ),
    );
  }

  return sections;
}

bool _isAfterMonth(DateTime left, DateTime right) {
  if (left.year != right.year) {
    return left.year > right.year;
  }
  return left.month > right.month;
}

List<SearchDateCell> _buildMonthCells({
  required int year,
  required int month,
  required Map<String, SearchDateBucket> bucketByDay,
  required DateTime now,
}) {
  final cells = <SearchDateCell>[];
  final firstWeekdayOffset = DateTime(year, month, 1).weekday % 7;
  for (var offset = 0; offset < firstWeekdayOffset; offset++) {
    cells.add(SearchDateCell.placeholder(weekdayOffset: offset));
  }

  final daysInMonth = DateTime(year, month + 1, 0).day;
  for (var day = 1; day <= daysInMonth; day++) {
    final dayKey =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final bucket = bucketByDay[dayKey];
    final isToday = now.year == year && now.month == month && now.day == day;
    cells.add(
      SearchDateCell(
        year: year,
        month: month,
        day: day,
        messageCount: bucket?.messageCount ?? 0,
        anchorOrderSeq: bucket?.anchorOrderSeq ?? 0,
        isToday: isToday,
        isSelected: isToday,
      ),
    );
  }

  return cells;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}
