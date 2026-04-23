import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/core/constants/im_constants.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';

void main() {
  group('WKRobotCardContent', () {
    test('uses approved defaults', () {
      final content = WKRobotCardContent();

      expect(content.contentType, MsgContentType.robotCard);
      expect(content.schema, 'robot_card.v1');
      expect(content.style, 'showcase');
      expect(content.linkMode, 'whole_card');
    });

    test('decodes approved nested contract with robot alias fallback', () {
      final content =
          WKRobotCardContent().decodeJson(<String, dynamic>{
                'schema': 'robot_card.v1',
                'platform': 'feishu',
                'origin_type': 'assistant',
                'robot': <String, dynamic>{
                  'provider': 'feishu',
                  'display_name': 'Weather Robot',
                  'display_avatar': 'robots/weather/avatar.png',
                },
                'card': <String, dynamic>{
                  'style': 'compact',
                  'title': 'Weather Report',
                  'body': 'Today is sunny',
                  'badge': 'LIVE',
                  'link_url': 'https://weather.example.com',
                  'link_mode': 'external',
                },
                'plain_text': 'Weather Robot says sunny today',
              })
              as WKRobotCardContent;

      expect(content.contentType, MsgContentType.robotCard);
      expect(content.schema, 'robot_card.v1');
      expect(content.platform, 'feishu');
      expect(content.originType, 'assistant');
      expect(content.robotProvider, 'feishu');
      expect(content.robotName, 'Weather Robot');
      expect(content.robotAvatar, 'robots/weather/avatar.png');
      expect(content.style, 'compact');
      expect(content.title, 'Weather Report');
      expect(content.body, 'Today is sunny');
      expect(content.badge, 'LIVE');
      expect(content.linkUrl, 'https://weather.example.com');
      expect(content.linkMode, 'external');
      expect(content.plainText, 'Weather Robot says sunny today');
      expect(content.isClickable, isTrue);
    });

    test('encodeJson emits approved nested robot and card shape', () {
      final content = WKRobotCardContent()
        ..platform = 'feishu'
        ..originType = 'assistant'
        ..robotProvider = 'feishu'
        ..robotName = 'Weather Robot'
        ..robotAvatar = 'robots/weather/avatar.png'
        ..title = 'Weather Report'
        ..body = 'Today is sunny'
        ..badge = 'LIVE'
        ..linkUrl = 'https://weather.example.com'
        ..plainText = 'Weather Robot says sunny today';

      final encoded = content.encodeJson();

      expect(encoded['schema'], 'robot_card.v1');
      expect(encoded['platform'], 'feishu');
      expect(encoded['origin_type'], 'assistant');
      expect(encoded['plain_text'], 'Weather Robot says sunny today');

      expect(encoded['robot'], <String, dynamic>{
        'provider': 'feishu',
        'name': 'Weather Robot',
        'avatar': 'robots/weather/avatar.png',
      });
      expect(encoded['card'], <String, dynamic>{
        'style': 'showcase',
        'title': 'Weather Report',
        'body': 'Today is sunny',
        'badge': 'LIVE',
        'link_url': 'https://weather.example.com',
        'link_mode': 'whole_card',
      });

      expect(encoded.containsKey('robot_provider'), isFalse);
      expect(encoded.containsKey('title'), isFalse);
      expect(encoded.containsKey('link_url'), isFalse);
    });

    test('displayText prefers plainText then title/body', () {
      final content = WKRobotCardContent()
        ..plainText = 'Plain summary'
        ..title = 'Title'
        ..body = 'Body';

      expect(content.displayText(), 'Plain summary');

      content.plainText = '';
      expect(content.displayText(), 'Title Body');

      content.title = '';
      expect(content.displayText(), 'Body');
    });

    test('searchableWord includes robot name title body and plain text', () {
      final content = WKRobotCardContent()
        ..robotName = 'Weather Robot'
        ..title = 'Forecast'
        ..body = 'Rain expected'
        ..plainText = 'Weather summary';

      final searchable = content.searchableWord();
      expect(searchable, contains('Weather Robot'));
      expect(searchable, contains('Forecast'));
      expect(searchable, contains('Rain expected'));
      expect(searchable, contains('Weather summary'));
    });

    test(
      'MessageContentType stays aligned with MsgContentType core values',
      () {
        expect(MessageContentType.text, MsgContentType.text);
        expect(MessageContentType.image, MsgContentType.image);
        expect(MessageContentType.voice, MsgContentType.voice);
        expect(MessageContentType.video, MsgContentType.video);
        expect(MessageContentType.file, MsgContentType.file);
        expect(MessageContentType.location, MsgContentType.location);
        expect(MessageContentType.card, MsgContentType.card);
        expect(MessageContentType.robotCard, MsgContentType.robotCard);
      },
    );
  });
}
