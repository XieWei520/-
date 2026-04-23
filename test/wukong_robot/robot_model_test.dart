import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_robot/models/robot.dart';

void main() {
  group('Robot model parity', () {
    test('Robot.fromJson preserves sync metadata and robot menus', () {
      final robot = Robot.fromJson(<String, dynamic>{
        'robot_id': 'robot-gif',
        'username': 'gif',
        'name': 'GIF Bot',
        'placeholder': 'Search GIFs',
        'inline_on': 1,
        'status': 1,
        'version': 42,
        'menus': <Map<String, dynamic>>[
          <String, dynamic>{
            'robot_id': 'robot-gif',
            'cmd': '/wave',
            'remark': 'Wave hello',
            'type': 'command',
          },
        ],
      });

      expect(robot.robotId, 'robot-gif');
      expect(robot.username, 'gif');
      expect(robot.placeholder, 'Search GIFs');
      expect(robot.inlineOn, isTrue);
      expect(robot.status, 1);
      expect(robot.version, 42);
      expect(robot.menus, hasLength(1));
      expect(robot.menus.first.robotId, 'robot-gif');
      expect(robot.menus.first.cmd, '/wave');
      expect(robot.menus.first.remark, 'Wave hello');
      expect(robot.menus.first.type, 'command');
    });

    test('RobotInlineQueryResult keeps inline query identifiers', () {
      final result = RobotInlineQueryResult.fromJson(<String, dynamic>{
        'id': 'gif-1',
        'type': 'gif',
        'inline_query_sid': 'sid-123',
        'thumb_url': 'https://cdn.example.com/thumb.gif',
        'url': 'https://cdn.example.com/full.gif',
      });

      expect(result.inlineQuerySid, 'sid-123');
      expect(result.thumbnailUrl, 'https://cdn.example.com/thumb.gif');
      expect(result.contentUrl, 'https://cdn.example.com/full.gif');
      expect(result.isGif, isTrue);
    });
  });
}
