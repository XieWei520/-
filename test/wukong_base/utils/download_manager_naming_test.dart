import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_base/utils/download_file_naming.dart';
import 'package:wukong_im_app/wukong_base/utils/download_manager.dart';

void main() {
  group('download file naming', () {
    test('uses URL path basename without query parameters', () {
      expect(
        downloadFileNameFromUrl(
          'https://cdn.example.com/files/photos/avatar.png?token=secret',
        ),
        'avatar.png',
      );
    });

    test('sanitizes traversal, separators, and blank file names', () {
      expect(safeDownloadFileName('../unsafe/avatar.png'), 'avatar.png');
      expect(safeDownloadFileName(r'..\unsafe\avatar.png'), 'avatar.png');
      expect(safeDownloadFileName(''), 'download.bin');
    });
  });

  test('getTaskByUrl returns null when the task is not tracked', () {
    final manager = DownloadManager();

    expect(manager.getTaskByUrl('https://example.com/missing.bin'), isNull);
  });
}
