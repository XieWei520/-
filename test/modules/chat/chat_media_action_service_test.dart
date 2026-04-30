import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/modules/chat/chat_media_action_service.dart';
import 'package:wukong_im_app/modules/chat/chat_rich_text_compose_dialog.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';

void main() {
  test('ChatMediaActionService source does not import dart io directly', () {
    final source = File(
      'lib/modules/chat/chat_media_action_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("import 'dart:io'")));
    expect(source, isNot(contains("package:file_picker")));
  });

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

    test('sanitizes unsafe file metadata before sending', () {
      final factory = ChatMediaContentFactory();

      final content = factory.buildFileContent(
        localPath: ' C:/tmp/report.final.PDF ',
        name: r'..\..\report.final.PDF',
        size: -7,
      );

      expect(content.localPath, 'C:/tmp/report.final.PDF');
      expect(content.name, 'report.final.PDF');
      expect(content.size, 0);
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

    test(
      'builds dropped image content from local desktop file metadata',
      () async {
        final factory = ChatMediaContentFactory();

        final content = await factory.buildDroppedFileContent(
          const ChatDroppedFileSelection(
            localPath: ' C:/drop/photo.PNG ',
            name: 'photo.PNG',
            size: 2048,
            mimeType: 'image/png',
          ),
          loadImageDimensions: (_) async =>
              const ChatImageDimensions(width: 640, height: 360),
        );

        expect(content, isA<WKImageContent>());
        final image = content as WKImageContent;
        expect(image.localPath, 'C:/drop/photo.PNG');
        expect(image.width, 640);
        expect(image.height, 360);
      },
    );

    test(
      'keeps dropped image sendable when dimensions cannot be decoded',
      () async {
        final factory = ChatMediaContentFactory();

        final content = await factory.buildDroppedFileContent(
          const ChatDroppedFileSelection(
            localPath: 'C:/drop/corrupted.webp',
            name: 'corrupted.webp',
            size: 2048,
            mimeType: 'image/webp',
          ),
          loadImageDimensions: (_) async {
            throw StateError('decode failed');
          },
        );

        expect(content, isA<WKImageContent>());
        final image = content as WKImageContent;
        expect(image.localPath, 'C:/drop/corrupted.webp');
        expect(image.width, 0);
        expect(image.height, 0);
      },
    );

    test('builds dropped non-image content as a file message', () async {
      final factory = ChatMediaContentFactory();

      final content = await factory.buildDroppedFileContent(
        const ChatDroppedFileSelection(
          localPath: 'C:/drop/spec.final.PDF',
          name: ' spec.final.PDF ',
          size: 8192,
        ),
        loadImageDimensions: (_) async =>
            const ChatImageDimensions(width: 1, height: 1),
      );

      expect(content, isA<WKFileContent>());
      final file = content as WKFileContent;
      expect(file.localPath, 'C:/drop/spec.final.PDF');
      expect(file.name, 'spec.final.PDF');
      expect(file.size, 8192);
      expect(file.suffix, 'pdf');
    });

    test('ignores dropped files without a local path', () async {
      final factory = ChatMediaContentFactory();

      final content = await factory.buildDroppedFileContent(
        const ChatDroppedFileSelection(
          localPath: '   ',
          name: 'missing.png',
          size: 0,
          mimeType: 'image/png',
        ),
        loadImageDimensions: (_) async =>
            const ChatImageDimensions(width: 1, height: 1),
      );

      expect(content, isNull);
    });
  });

  test(
    'PlatformChatMediaActionService builds dropped files through the shared factory',
    () async {
      final service = PlatformChatMediaActionService(
        loadImageDimensions: (_) async =>
            const ChatImageDimensions(width: 128, height: 96),
      );

      final content = await service.buildDroppedFile(
        const ChatDroppedFileSelection(
          localPath: 'C:/drop/screenshot.jpg',
          name: 'screenshot.jpg',
          size: 4096,
        ),
      );

      expect(content, isA<WKImageContent>());
      final image = content as WKImageContent;
      expect(image.localPath, 'C:/drop/screenshot.jpg');
      expect(image.width, 128);
      expect(image.height, 96);
    },
  );

  testWidgets(
    'PlatformChatMediaActionService uploads byte-backed image selections before sending',
    (tester) async {
      late BuildContext viewContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              viewContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final bytes = Uint8List.fromList(<int>[1, 2, 3]);
      final uploadCalls = <String>[];
      final service = PlatformChatMediaActionService(
        pickImageFile: () async => ChatFileSelection(
          localPath: '',
          name: 'photo.png',
          size: bytes.length,
          bytes: bytes,
        ),
        uploadPickedFileBytes:
            ({
              required bytes,
              required fileName,
              required channelId,
              required channelType,
            }) async {
              uploadCalls.add(
                '$fileName:$channelId:$channelType:${bytes.length}',
              );
              return 'https://cdn.example.com/photo.png';
            },
      );

      final content = await service.pickImage(
        viewContext,
        channelId: 'room-a',
        channelType: 1,
      );

      expect(content, isNotNull);
      expect(content!.url, 'https://cdn.example.com/photo.png');
      expect(content.localPath, isEmpty);
      expect(content.width, 0);
      expect(content.height, 0);
      expect(uploadCalls, <String>['photo.png:room-a:1:3']);
    },
  );

  testWidgets(
    'PlatformChatMediaActionService uploads byte-backed file selections before sending',
    (tester) async {
      late BuildContext viewContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              viewContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final bytes = Uint8List.fromList(<int>[4, 5, 6, 7]);
      final service = PlatformChatMediaActionService(
        pickFile: () async => ChatFileSelection(
          localPath: '',
          name: 'report.final.PDF',
          size: bytes.length,
          bytes: bytes,
        ),
        uploadPickedFileBytes:
            ({
              required bytes,
              required fileName,
              required channelId,
              required channelType,
            }) async => 'https://cdn.example.com/report.final.PDF',
      );

      final content = await service.pickFile(
        viewContext,
        channelId: 'room-b',
        channelType: 2,
      );

      expect(content, isNotNull);
      expect(content!.url, 'https://cdn.example.com/report.final.PDF');
      expect(content.localPath, isEmpty);
      expect(content.name, 'report.final.PDF');
      expect(content.size, 4);
      expect(content.suffix, 'pdf');
    },
  );
}
