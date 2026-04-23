import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/modules/chat/robot_message_identity.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('robot message identity parser', () {
    test('returns null for invalid json payload', () {
      expect(parseRobotMessageIdentityFromRaw('not-json'), isNull);
      expect(parseRobotMessageIdentityFromRaw('{invalid'), isNull);
    });

    test('returns null when robot map is missing', () {
      expect(
        parseRobotMessageIdentity(<String, dynamic>{
          'type': 1,
          'content': 'hi',
        }),
        isNull,
      );
    });

    test('returns null for malformed robot map instead of throwing', () {
      final payload = <String, dynamic>{
        'type': 1,
        'content': 'hi',
        'robot': <dynamic, dynamic>{1: 'bad-key'},
      };

      expect(parseRobotMessageIdentity(payload), isNull);
    });

    test('parses provider name and avatar from robot canonical keys', () {
      final identity = parseRobotMessageIdentity(<String, dynamic>{
        'type': 1,
        'content': 'Weather update',
        'robot': <String, dynamic>{
          'provider': 'feishu',
          'name': 'Weather Bot',
          'avatar': 'robots/weather/avatar-primary.png',
        },
      });

      expect(identity, isNotNull);
      expect(identity?.provider, 'feishu');
      expect(identity?.displayName, 'Weather Bot');
      expect(
        identity?.displayAvatar,
        ApiConfig.resolveMediaUrl('robots/weather/avatar-primary.png'),
      );
    });

    test('falls back to display aliases when canonical keys are absent', () {
      final identity = parseRobotMessageIdentity(<String, dynamic>{
        'type': 1,
        'content': 'Weather update',
        'robot': <String, dynamic>{
          'provider': 'feishu',
          'display_name': 'Weather Bot',
          'display_avatar': 'robots/weather/avatar.png',
        },
      });

      expect(identity, isNotNull);
      expect(identity?.provider, 'feishu');
      expect(identity?.displayName, 'Weather Bot');
      expect(
        identity?.displayAvatar,
        ApiConfig.resolveMediaUrl('robots/weather/avatar.png'),
      );
    });

    test('prefers canonical robot name and avatar over aliases', () {
      final identity = parseRobotMessageIdentity(<String, dynamic>{
        'type': 1,
        'content': 'Weather update',
        'robot': <String, dynamic>{
          'provider': 'feishu',
          'name': 'Weather Bot Primary',
          'display_name': 'Weather Bot Alias',
          'avatar': 'robots/weather/avatar-primary.png',
          'display_avatar': 'robots/weather/avatar-alias.png',
        },
      });

      expect(identity, isNotNull);
      expect(identity?.displayName, 'Weather Bot Primary');
      expect(
        identity?.displayAvatar,
        ApiConfig.resolveMediaUrl('robots/weather/avatar-primary.png'),
      );
    });

    test('resolves from message content when structured payload is absent', () {
      final message = WKMsg()
        ..channelType = WKChannelType.group
        ..contentType = WkMessageContentType.unknown
        ..content =
            '{"type":1,"content":"Rain","robot":{"provider":"dingtalk","display_name":"Rain Bot","display_avatar":"robots/rain/avatar"}}';

      final identity = resolveRobotMessageIdentityFromMessage(message);

      expect(identity, isNotNull);
      expect(identity?.provider, 'dingtalk');
      expect(identity?.displayName, 'Rain Bot');
      expect(
        identity?.displayAvatar,
        ApiConfig.resolveMediaUrl('robots/rain/avatar'),
      );
    });
  });
}
