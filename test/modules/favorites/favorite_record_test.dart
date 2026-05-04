import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/favorites/favorite_record.dart';

void main() {
  test('file favorites expose Chinese labels and open targets', () {
    final record = FavoriteRecord.fromMap(<String, dynamic>{
      'id': 'file-1',
      'sender_name': 'Alice',
      'content_type': 5,
      'created_at': '2026-04-01T08:00:00Z',
      'content': <String, dynamic>{
        'name': '需求说明.pdf',
        'url': '/v1/file/download/needs.pdf',
      },
    });

    expect(record.content, '需求说明.pdf');
    expect(record.subtitle, contains('文件'));
    expect(record.openUrl, isNotEmpty);
    expect(record.canOpenExternally, isTrue);
  });

  test('location favorites prefer title and address summary', () {
    final record = FavoriteRecord.fromMap(<String, dynamic>{
      'id': 'location-1',
      'sender_name': 'Bob',
      'content_type': 6,
      'created_at': '2026-04-01T08:00:00Z',
      'content': <String, dynamic>{
        'title': '上海中心',
        'address': '上海市浦东新区陆家嘴银城中路501号',
      },
    });

    expect(record.content, '上海中心');
    expect(record.subtitle, contains('位置'));
  });

  test('card favorites prefer display name and Chinese type label', () {
    final record = FavoriteRecord.fromMap(<String, dynamic>{
      'id': 'card-1',
      'sender_name': 'Carol',
      'content_type': 7,
      'created_at': '2026-04-01T08:00:00Z',
      'content': <String, dynamic>{'name': '张三', 'uid': 'u_zhangsan'},
    });

    expect(record.content, '张三');
    expect(record.subtitle, contains('名片'));
  });
  test('android absolute local path is treated as local file target', () {
    final record = FavoriteRecord.fromMap(<String, dynamic>{
      'id': 'local-file-1',
      'sender_name': 'Alice',
      'content_type': 5,
      'content': <String, dynamic>{
        'local_path': '/storage/emulated/0/Download/demo.pdf',
      },
    });

    expect(record.openLocalPath, '/storage/emulated/0/Download/demo.pdf');
    expect(record.canOpenExternally, isTrue);
    expect(record.openUrl, isNull);
  });

  test(
    'favorite payload maps message_seq and order_seq into record fields',
    () {
      final record = FavoriteRecord.fromMap(<String, dynamic>{
        'id': 'route-1',
        'sender_name': 'Alice',
        'content_type': 1,
        'content': 'hello',
        'channel_id': 'group-1',
        'channel_type': 2,
        'message_seq': 1234,
        'order_seq': 5678,
      });

      expect(record.messageSeq, 1234);
      expect(record.orderSeq, 5678);
    },
  );
}
