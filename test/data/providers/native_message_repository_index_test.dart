import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('app DB helper defensively creates large-history message indexes', () {
    final source = File(
      p.join('lib', 'wukong_base', 'db', 'db_helper.dart'),
    ).readAsStringSync();

    expect(
      _normalizedSql(source),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_channel_seq
ON message(channel_id, channel_type, message_seq DESC)
'''),
      ),
    );
    expect(
      _normalizedSql(source),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_channel_order_seq
ON message(channel_id, channel_type, order_seq DESC)
'''),
      ),
    );
    expect(
      _normalizedSql(source),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_client_msg_no
ON message(client_msg_no)
'''),
      ),
    );
    expect(
      _normalizedSql(source),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_message_id
ON message(message_id)
'''),
      ),
    );
  });

  test('SDK migration path creates real native message table indexes', () {
    final sdkRoot = Directory(
      p.join('..', 'TangSengDaoDao', 'WuKongIMFlutterSDK-master'),
    );
    final migrationAsset = File(
      p.join(sdkRoot.path, 'assets', '202604251100.sql'),
    ).readAsStringSync();
    final sqlManifest = File(
      p.join(sdkRoot.path, 'assets', 'sql.txt'),
    ).readAsStringSync();
    final wkDbHelperSource = File(
      p.join(sdkRoot.path, 'lib', 'db', 'wk_db_helper.dart'),
    ).readAsStringSync();

    expect(
      _normalizedSql(migrationAsset),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_channel_seq
ON message (channel_id, channel_type, message_seq DESC)
'''),
      ),
    );
    expect(
      _normalizedSql(migrationAsset),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_channel_order_seq
ON message (channel_id, channel_type, order_seq DESC)
'''),
      ),
    );
    expect(
      _normalizedSql(migrationAsset),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_client_msg_no
ON message (client_msg_no)
'''),
      ),
    );
    expect(
      _normalizedSql(migrationAsset),
      contains(
        _normalizedSql('''
CREATE INDEX IF NOT EXISTS idx_message_message_id
ON message (message_id)
'''),
      ),
    );
    expect(
      sqlManifest.split(';').map((item) => item.trim()),
      contains('202604251100'),
    );
    expect(
      wkDbHelperSource,
      contains("loadString('packages/wukongimfluttersdk/assets/sql.txt')"),
    );
    expect(
      wkDbHelperSource,
      contains(
        "loadString('packages/wukongimfluttersdk/assets/\$version.sql')",
      ),
    );
  });
}

String _normalizedSql(String source) {
  return source
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' (', '(')
      .replaceAll('( ', '(')
      .replaceAll(' )', ')')
      .trim()
      .toLowerCase();
}
