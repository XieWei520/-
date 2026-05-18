import 'package:test/test.dart';
import 'package:wukongimfluttersdk/db/message_search_sql.dart';

void main() {
  group('message FTS search SQL', () {
    test(
        'buildMessageFtsQuery escapes double quotes and appends prefix operator',
        () {
      expect(buildMessageFtsQuery(' alpha "beta"  '), '"alpha" "beta"*');
    });

    test('empty query stays empty for caller fallback', () {
      expect(buildMessageFtsQuery('   '), '');
    });

    test('LIKE fallback pattern escapes wildcard characters', () {
      expect(buildMessageLikePattern(r' 50%_done\ok '), r'%50\%\_done\\ok%');
    });

    test('LIKE fallback pattern keeps empty keywords from scanning all rows',
        () {
      expect(buildMessageLikePattern('   '), '');
    });

    test('global FTS SQL uses message_fts and keeps channel aggregation', () {
      final sql = buildGlobalMessageFtsSearchSql();

      expect(sql, contains('message_fts'));
      expect(sql, contains('MATCH ?'));
      expect(sql, contains('GROUP BY c.channel_id, c.channel_type'));
      expect(sql, contains('ORDER BY m.created_at DESC'));
    });

    test('global LIKE fallback SQL declares wildcard escape clauses', () {
      final sql = buildGlobalMessageLikeSearchSql();

      expect(sql, contains("LIKE ? ESCAPE '\\'"));
      expect(sql, contains('GROUP BY c.channel_id, c.channel_type'));
      expect(sql, contains('ORDER BY m.created_at DESC'));
    });

    test('channel FTS SQL filters channel and deleted/revoked messages', () {
      final sql = buildChannelMessageFtsSearchSql();

      expect(sql, contains('message_fts'));
      expect(sql, contains('MATCH ?'));
      expect(sql, contains('m.channel_id=?'));
      expect(sql, contains('m.channel_type=?'));
      expect(sql, contains('is_deleted=0'));
      expect(sql, contains('revoke=0'));
    });

    test('channel LIKE fallback SQL declares wildcard escape clauses', () {
      final sql = buildChannelMessageLikeSearchSql();

      expect(sql, contains("like ? ESCAPE '\\'"));
      expect(sql, contains('channel_id=?'));
      expect(sql, contains('channel_type=?'));
      expect(sql, contains('is_deleted=0'));
      expect(sql, contains('revoke=0'));
    });
  });
}
