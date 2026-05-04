import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/utils/qr_export_file_naming.dart';

void main() {
  test('qr export prefix removes path traversal and invalid characters', () {
    expect(safeQrExportFilePrefix('../group/card'), 'card');
    expect(safeQrExportFilePrefix(r'..\bad\group:42'), 'group_42');
  });

  test(
    'qr export png name uses a safe fallback and strips duplicate png suffix',
    () {
      expect(
        qrExportPngFileName(
          fileNamePrefix: '',
          timestampMs: 42,
          fallbackPrefix: 'qrcode',
        ),
        'qrcode_42.png',
      );
      expect(
        qrExportPngFileName(
          fileNamePrefix: 'profile.png',
          timestampMs: 42,
          fallbackPrefix: 'image',
        ),
        'profile_42.png',
      );
    },
  );
}
