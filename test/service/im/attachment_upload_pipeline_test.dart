import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/service/im/attachment_upload_pipeline.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';

void main() {
  group('AttachmentUploadPipeline', () {
    test(
      'delegates SDK upload callback to the configured legacy uploader',
      () async {
        final calls = <WKMsg>[];
        final pipeline = AttachmentUploadPipeline(
          legacyUploader: (message) async {
            calls.add(message);
            return true;
          },
        );
        final message = WKMsg();

        final result = await pipeline.uploadMessageAttachments(message);

        expect(result, isTrue);
        expect(calls, <WKMsg>[message]);
      },
    );

    test('fails closed when no uploader has been configured yet', () async {
      final pipeline = AttachmentUploadPipeline();

      final result = await pipeline.uploadMessageAttachments(WKMsg());

      expect(result, isFalse);
    });

    test(
      'uploads media content through the configured chat file uploader',
      () async {
        final uploadedPaths = <String>[];
        final pipeline = AttachmentUploadPipeline(
          chatFileUploader:
              ({
                required String filePath,
                required String channelId,
                required int channelType,
              }) async {
                uploadedPaths.add('$channelId:$channelType:$filePath');
                return 'https://cdn.example/$filePath';
              },
          fileExists: (_) async => true,
        );
        final content = WKImageContent(320, 180)..localPath = 'C:/tmp/a.png';
        final message = WKMsg()
          ..channelID = 'chat-a'
          ..channelType = 1
          ..messageContent = content;

        final result = await pipeline.uploadMessageAttachments(message);

        expect(result, isTrue);
        expect(content.url, 'https://cdn.example/C:/tmp/a.png');
        expect(uploadedPaths, <String>['chat-a:1:C:/tmp/a.png']);
      },
    );

    test('uploads video cover after the main video file succeeds', () async {
      final uploadedPaths = <String>[];
      final pipeline = AttachmentUploadPipeline(
        chatFileUploader:
            ({
              required String filePath,
              required String channelId,
              required int channelType,
            }) async {
              uploadedPaths.add(filePath);
              return 'https://cdn.example/${uploadedPaths.length}';
            },
        fileExists: (_) async => true,
      );
      final content = WKVideoContent()
        ..localPath = 'C:/tmp/v.mp4'
        ..coverLocalPath = 'C:/tmp/v.jpg';
      final message = WKMsg()
        ..channelID = 'chat-a'
        ..channelType = 1
        ..messageContent = content;

      final result = await pipeline.uploadMessageAttachments(message);

      expect(result, isTrue);
      expect(content.url, 'https://cdn.example/1');
      expect(content.cover, 'https://cdn.example/2');
      expect(uploadedPaths, <String>['C:/tmp/v.mp4', 'C:/tmp/v.jpg']);
    });

    test(
      'uploads file content and normalizes metadata before SDK send continues',
      () async {
        final pipeline = AttachmentUploadPipeline(
          chatFileUploader:
              ({
                required String filePath,
                required String channelId,
                required int channelType,
              }) async {
                return 'https://cdn.example/file.pdf';
              },
          fileExists: (_) async => true,
          fileLength: (_) async => 4096,
        );
        final content = WKFileContent()
          ..localPath = r'C:\tmp\report.final.PDF'
          ..size = -1;
        final message = WKMsg()
          ..channelID = 'chat-a'
          ..channelType = 1
          ..messageContent = content;

        final result = await pipeline.uploadMessageAttachments(message);

        expect(result, isTrue);
        expect(content.url, 'https://cdn.example/file.pdf');
        expect(content.name, 'report.final.PDF');
        expect(content.size, 4096);
        expect(content.suffix, 'pdf');
      },
    );
  });
}
