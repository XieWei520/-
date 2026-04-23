import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/link_preview_service.dart';

void main() {
  group('LinkPreviewService', () {
    test('extractFirstUrl trims trailing punctuation', () {
      final url = LinkPreviewService.extractFirstUrl(
        '请看这个链接 https://example.com/hello-world).',
      );

      expect(url, 'https://example.com/hello-world');
    });

    test('buildFallbackPreview keeps host and path', () {
      final preview = LinkPreviewService.instance.buildFallbackPreview(
        'https://example.com/docs/path?a=1',
      );

      expect(preview.host, 'example.com');
      expect(preview.displayUrl, 'example.com/docs/path?a=1');
      expect(preview.isFallback, isTrue);
    });

    test(
      'parsePreviewDocument extracts og metadata and resolves image url',
      () {
        const document = '''
        <html>
          <head>
            <meta property="og:title" content="Example Title" />
            <meta property="og:description" content="Example Description" />
            <meta property="og:image" content="/cover.png" />
            <title>Ignored Title</title>
          </head>
        </html>
      ''';

        final preview = LinkPreviewService.instance.parsePreviewDocument(
          url: 'https://example.com/post/1',
          document: document,
        );

        expect(preview, isNotNull);
        expect(preview!.title, 'Example Title');
        expect(preview.description, 'Example Description');
        expect(preview.imageUrl, 'https://example.com/cover.png');
        expect(preview.isFallback, isFalse);
      },
    );
  });
}
