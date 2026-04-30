import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/utils/wk_file_utils.dart' as top_level;
import 'package:wukong_im_app/wukong_base/utils/wk_file_utils.dart'
    as wukong_base;

void main() {
  group('WKFileUtils.getFileName', () {
    test('uses the last non-empty path segment', () {
      expect(top_level.WKFileUtils.getFileName(r'C:\drop\folder\'), 'folder');
      expect(wukong_base.WKFileUtils.getFileName('/tmp/folder/'), 'folder');
    });

    test('strips query and fragment suffixes from file-like paths', () {
      expect(
        top_level.WKFileUtils.getFileName('/tmp/report.pdf?token=secret'),
        'report.pdf',
      );
      expect(
        wukong_base.WKFileUtils.getFileName(
          'https://cdn.example.com/image.png#preview',
        ),
        'image.png',
      );
    });
  });
}
