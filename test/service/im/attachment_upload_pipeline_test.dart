import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/attachment_upload_pipeline.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

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
  });
}
