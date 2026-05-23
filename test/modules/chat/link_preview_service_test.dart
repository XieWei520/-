import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/link_preview.dart';
import 'package:wukong_im_app/modules/chat/link_preview_service.dart';

void main() {
  group('LinkPreviewService', () {
    test('extractFirstUrl trims trailing punctuation', () {
      final url = LinkPreviewService.extractFirstUrl(
        '请看这个链接 https://example.com/hello-world).',
      );

      expect(url, 'https://example.com/hello-world');
    });

    test('classifyDirectMediaUrl detects supported audio links', () {
      const supportedAudioUrls = <String>[
        'https://cdn.example.com/audio/notice.mp3',
        'https://cdn.example.com/audio/notice.m4a?token=abc',
        'https://cdn.example.com/audio/notice.aac#clip',
        'https://cdn.example.com/audio/notice.wav?download=1#play',
        'https://cdn.example.com/audio/notice.ogg',
      ];

      for (final url in supportedAudioUrls) {
        expect(
          LinkPreviewService.classifyDirectMediaUrl(url),
          DirectMediaType.audio,
          reason: url,
        );
      }
    });

    test('classifyDirectMediaUrl detects supported video links', () {
      const supportedVideoUrls = <String>[
        'https://cdn.example.com/video/demo.mp4',
        'https://cdn.example.com/video/demo.mov?token=abc',
        'https://cdn.example.com/video/demo.m4v#preview',
        'https://cdn.example.com/video/demo.webm?download=1#play',
      ];

      for (final url in supportedVideoUrls) {
        expect(
          LinkPreviewService.classifyDirectMediaUrl(url),
          DirectMediaType.video,
          reason: url,
        );
      }
    });

    test('classifyDirectMediaUrl keeps non-media links generic', () {
      const genericUrls = <String?>[
        null,
        '',
        'ftp://cdn.example.com/audio/notice.mp3',
        'https://example.com/docs/audio',
        'https://example.com/download?file=notice.mp3',
        'https://example.com/archive.mp3.zip',
      ];

      for (final url in genericUrls) {
        expect(
          LinkPreviewService.classifyDirectMediaUrl(url),
          DirectMediaType.none,
          reason: url,
        );
      }
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

    test('parsePreviewDocument clips long metadata with readable ellipsis', () {
      final preview = LinkPreviewService.instance.parsePreviewDocument(
        url: 'https://example.com/post/long',
        document:
            '<html><head><meta property="og:title" content="${'A' * 120}" /></head></html>',
      );

      expect(preview, isNotNull);
      expect(preview!.title, hasLength(80));
      expect(preview.title.endsWith('...'), isTrue);
      expect(preview.title, isNot(contains('鈥')));
      expect(preview.title, isNot(contains('?')));
    });

    test(
      'preview metadata cache is bounded and evicts least recently used',
      () async {
        final service = LinkPreviewService.instance;
        service.clearCacheForTesting();
        addTearDown(service.clearCacheForTesting);

        for (var i = 0; i < LinkPreviewService.maxPreviewCacheEntries; i++) {
          final url = 'https://example.com/post/$i';
          service.setPreviewForTesting(
            url,
            LinkPreview(
              url: url,
              host: 'example.com',
              displayUrl: 'example.com/post/$i',
              title: 'Post $i',
              description: '',
            ),
          );
        }

        await service.getPreview('https://example.com/post/0');
        service.setPreviewForTesting(
          'https://example.com/post/extra',
          const LinkPreview(
            url: 'https://example.com/post/extra',
            host: 'example.com',
            displayUrl: 'example.com/post/extra',
            title: 'Extra',
            description: '',
          ),
        );

        expect(
          service.cachedPreviewCountForTesting,
          LinkPreviewService.maxPreviewCacheEntries,
        );
        expect(
          service.hasCachedPreviewForTesting('https://example.com/post/0'),
          isTrue,
        );
        expect(
          service.hasCachedPreviewForTesting('https://example.com/post/1'),
          isFalse,
        );
        expect(
          service.hasCachedPreviewForTesting('https://example.com/post/extra'),
          isTrue,
        );
      },
    );
  });
}
