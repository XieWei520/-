import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/coordinators/attachment_pipeline.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';

void main() {
  group('AttachmentPipeline', () {
    test('normalizes unsafe local file metadata before upload', () {
      final content = WKFileContent()
        ..localPath = r' C:\tmp\report.final.PDF '
        ..name = r'..\..\report.final.PDF'
        ..size = -9;

      const AttachmentPipeline().normalizeFileMetadata(
        content,
        localPath: content.localPath,
      );

      expect(content.name, 'report.final.PDF');
      expect(content.size, 0);
      expect(content.suffix, 'pdf');
    });
  });
}
