Future<List<Map<String, Object?>>> runSearchDateBucketBackgroundQuery({
  required String databasePath,
  required String sql,
  required List<Object?> arguments,
}) {
  throw UnsupportedError('Background SQLite date bucket query is unavailable.');
}
