import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/local_attachment_file_io.dart';

void main() {
  test(
    'local attachment probes trim paths and return safe fallbacks',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'wk_local_attachment',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final file = File('${tempDir.path}${Platform.pathSeparator}voice.aac');
      await file.writeAsBytes(<int>[1, 2, 3, 4]);

      expect(await localAttachmentFileExists(' ${file.path} '), isTrue);
      expect(await localAttachmentFileLength(' ${file.path} '), 4);
      expect(await localAttachmentFileExists('   '), isFalse);
      expect(
        await localAttachmentFileLength(
          '${tempDir.path}${Platform.pathSeparator}missing.aac',
        ),
        isNull,
      );
    },
  );
}
