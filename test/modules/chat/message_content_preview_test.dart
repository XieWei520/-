import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/modules/chat/message_content_preview.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('buildReminderTitleFromContent truncates long text with ellipsis', () {
    final longText = List.filled(30, 'reminder').join(' ');
    final content = WKTextContent(longText);

    final title = buildReminderTitleFromContent(content, maxLength: 12);

    expect(title.endsWith('...'), isTrue);
    expect(title.length, 15);
  });

  test('buildReminderDescriptionFromContent preserves summary text', () {
    const summary = 'meeting sync in progress';
    final content = WKTextContent(summary);

    final description = buildReminderDescriptionFromContent(content);

    expect(description, summary);
  });

  test('buildReminderTitleFromContent uses fallback when content missing', () {
    final title = buildReminderTitleFromContent(null, fallback: 'todo');

    expect(title, 'todo');
  });

  test('resolveStructuredMessagePreview replaces indexed placeholders', () {
    const raw =
        '{"content":"test2 invited {0}","creator":"0a13431ca09247439ba5aaafe8f93359","creator_name":"test2","extra":[{"uid":"u_10000","name":"system"}],"type":1001,"version":1000001}';

    final preview = resolveStructuredMessagePreview(raw);

    expect(preview.text, contains('test2'));
    expect(preview.text, isNot(contains('{0}')));
    expect(preview.isSystemNotice, isTrue);
  });

  test('resolveStructuredMessagePreview localizes gif payload label', () {
    final preview = resolveStructuredMessagePreview(
      '{"type":${WkMessageContentType.gif}}',
    );

    expect(preview.text, isNotEmpty);
    expect(preview.text, startsWith('['));
    expect(preview.text, endsWith(']'));
  });

  test('resolveMessagePreview uses rich text body for typed rich text', () {
    final message = WKMsg()
      ..contentType = MsgContentType.richText
      ..messageContent = WKRichTextContent(
        title: 'Release Notes',
        body: 'Rich text body',
      );

    final preview = resolveMessagePreview(message);

    expect(preview.text, 'Rich text body');
    expect(preview.isSystemNotice, isFalse);
  });

  test(
    'resolveStructuredMessagePreview keeps rich text payload previews aligned with SDK display text',
    () {
      final preview = resolveStructuredMessagePreview(
        '{"type":${MsgContentType.richText},"title":"Release Notes","content":"Rich text body"}',
      );

      expect(preview.text, 'Rich text body');
      expect(preview.isSystemNotice, isFalse);
    },
  );

  test('resolveMessagePreview returns [贴纸] for typed sticker content', () {
    final message = WKMsg()
      ..contentType = MsgContentType.sticker
      ..messageContent = WKStickerContent();

    final preview = resolveMessagePreview(message);

    expect(preview.text, '[贴纸]');
    expect(preview.isSystemNotice, isFalse);
  });

  test('resolveStructuredMessagePreview returns [贴纸] for sticker payload', () {
    final preview = resolveStructuredMessagePreview(
      '{"type":${MsgContentType.sticker}}',
    );

    expect(preview.text, '[贴纸]');
    expect(preview.isSystemNotice, isFalse);
  });

  test('resolveMessagePreview uses plain_text for robot card content type', () {
    final message = WKMsg()
      ..contentType = MsgContentType.robotCard
      ..messageContent = (WKRobotCardContent()
        ..plainText = 'Robot concise summary'
        ..title = 'Ignored title'
        ..body = 'Ignored body');

    final preview = resolveMessagePreview(message);

    expect(preview.text, 'Robot concise summary');
    expect(preview.isSystemNotice, isFalse);
  });

  test(
    'resolveMessagePreview falls back to title/body when robot card plain_text is empty',
    () {
      final message = WKMsg()
        ..contentType = MsgContentType.robotCard
        ..messageContent = (WKRobotCardContent()
          ..plainText = ''
          ..title = 'Robot title'
          ..body = 'Robot body');

      final preview = resolveMessagePreview(message);

      expect(preview.text, 'Robot title Robot body');
      expect(preview.isSystemNotice, isFalse);
    },
  );

  test(
    'resolveMessagePreview falls back to nested card title/body for raw robot card payload without plain_text',
    () {
      final message = WKMsg()
        ..contentType = MsgContentType.robotCard
        ..content =
            '{"type":22,"robot":{"provider":"feishu","name":"Weather Robot"},"card":{"style":"showcase","title":"Robot title","body":"Robot body","link_url":"https://example.com","link_mode":"whole_card"}}';

      final preview = resolveMessagePreview(message);

      expect(preview.text, 'Robot title Robot body');
      expect(preview.isSystemNotice, isFalse);
    },
  );

  test(
    'resolveVisibleTextMessage falls back to contentEdit json when edited text content is not materialized',
    () {
      final message = WKMsg()
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('edit-001')
        ..wkMsgExtra = (WKMsgExtra()
          ..contentEdit = '{"type":1,"content":"edit-002"}');

      final visible = resolveVisibleTextMessage(message);
      final preview = resolveMessagePreview(message);

      expect(visible, 'edit-002');
      expect(preview.text, 'edit-002');
    },
  );
}
