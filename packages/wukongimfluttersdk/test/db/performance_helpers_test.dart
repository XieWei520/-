import 'package:sqflite/sqflite.dart';
import 'package:test/test.dart';
import 'package:wukongimfluttersdk/db/message_performance_helpers.dart';
import 'package:wukongimfluttersdk/db/sqlite_performance_options.dart';

class _ReactionLike {
  const _ReactionLike(this.messageID, this.emoji);

  final String messageID;
  final String emoji;
}

void main() {
  group('database performance helpers', () {
    test('sqlitePerformancePragmas enables WAL tuned for IM workloads', () {
      expect(wkSqlitePerformancePragmas, contains('PRAGMA journal_mode=WAL'));
      expect(
        wkSqlitePerformancePragmas,
        contains('PRAGMA synchronous=NORMAL'),
      );
      expect(
        wkSqlitePerformancePragmas,
        contains('PRAGMA busy_timeout=3000'),
      );
    });

    test('applies SQLite PRAGMAs through rawQuery for Android sqflite',
        () async {
      final executor = _AndroidLikePragmaExecutor();

      await applyWkSqlitePerformancePragmas(executor);

      expect(executor.executedSql, isEmpty);
      expect(executor.rawQuerySql, wkSqlitePerformancePragmas);
    });
    test('groupByMessageId groups reactions without nested scans', () {
      const first = _ReactionLike('m1', 'like');
      const second = _ReactionLike('m2', 'ok');
      const third = _ReactionLike('m1', 'heart');

      final grouped = groupByMessageId<_ReactionLike>(
        [first, second, third],
        (item) => item.messageID,
      );

      expect(grouped['m1']?.map((item) => item.emoji), ['like', 'heart']);
      expect(grouped['m2']?.single.emoji, 'ok');
      expect(grouped.containsKey(''), isFalse);
    });

    test('indexByNonEmptyKey builds stable lookup maps without empty keys', () {
      const first = _ReactionLike('m1', 'like');
      const duplicate = _ReactionLike('m1', 'heart');
      const blank = _ReactionLike(' ', 'ignored');

      final indexed = indexByNonEmptyKey<_ReactionLike>(
        [first, duplicate, blank],
        (item) => item.messageID,
      );

      expect(indexed['m1'], same(first));
      expect(indexed.containsKey(''), isFalse);
      expect(indexed.length, 1);
    });
  });
}

class _AndroidLikePragmaExecutor implements DatabaseExecutor {
  final List<String> executedSql = <String>[];
  final List<String> rawQuerySql = <String>[];

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) async {
    executedSql.add(sql);
    if (sql.toLowerCase().startsWith('pragma ')) {
      throw Exception(
        'Queries can be performed using SQLiteDatabase query or rawQuery methods only.',
      );
    }
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    rawQuerySql.add(sql);
    return const <Map<String, Object?>>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
