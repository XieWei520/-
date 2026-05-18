import 'package:sqflite/sqflite.dart';

const List<String> wkSqlitePerformancePragmas = [
  'PRAGMA journal_mode=WAL',
  'PRAGMA synchronous=NORMAL',
  'PRAGMA busy_timeout=3000',
];

Future<void> applyWkSqlitePerformancePragmas(DatabaseExecutor db) async {
  for (final pragma in wkSqlitePerformancePragmas) {
    await db.rawQuery(pragma);
  }
}
