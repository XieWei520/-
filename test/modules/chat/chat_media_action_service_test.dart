import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/modules/chat/chat_media_action_service.dart';
import 'package:wukong_im_app/modules/chat/chat_rich_text_compose_dialog.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';

void main() {
  group('ChatMediaContentFactory', () {
    test(
      'builds image content with the provided local path and dimensions',
      () {
        final factory = ChatMediaContentFactory();

        final content = factory.buildImageContent(
          localPath: 'C:/tmp/demo.png',
          width: 320,
          height: 180,
        );

        expect(content, isA<WKImageContent>());
        expect(content.localPath, 'C:/tmp/demo.png');
        expect(content.width, 320);
        expect(content.height, 180);
      },
    );

    test('builds file content with normalized metadata', () {
      final factory = ChatMediaContentFactory();

      final content = factory.buildFileContent(
        localPath: 'C:/tmp/spec.pdf',
        name: 'spec.pdf',
        size: 4096,
      );

      expect(content, isA<WKFileContent>());
      expect(content.localPath, 'C:/tmp/spec.pdf');
      expect(content.name, 'spec.pdf');
      expect(content.size, 4096);
      expect(content.suffix, 'pdf');
    });

    test('builds location content from the selected map result', () {
      final factory = ChatMediaContentFactory();

      final content = factory.buildLocationContent(
        const ChatLocationSelection(
          latitude: 31.2304,
          longitude: 121.4737,
          title: 'Shanghai',
          address: 'Shanghai, China',
        ),
      );

      expect(content, isA<WKLocationContent>());
      expect(content.latitude, 31.2304);
      expect(content.longitude, 121.4737);
      expect(content.title, 'Shanghai');
      expect(content.address, 'Shanghai, China');
    });

    test('builds rich text content from the compose selection payload', () {
      final factory = ChatMediaContentFactory();

      final content = factory.buildRichTextContent(
        const ChatRichTextSelection(
          title: 'Release Notes',
          body: 'Rich text body',
        ),
      );

      expect(content, isA<WKRichTextContent>());
      expect(content.title, 'Release Notes');
      expect(content.body, 'Rich text body');
    });
  });
}
