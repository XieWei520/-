import 'dart:typed_data';

class QrExportUtils {
  QrExportUtils._();

  static Future<String> saveQrCodeAsPng({
    required String data,
    required String fileNamePrefix,
    int imageSize = 1024,
  }) {
    if (data.trim().isEmpty) {
      throw Exception('二维码内容为空，无法保存');
    }
    return Future<String>.error(UnsupportedError('当前平台不支持保存二维码到本地文件'));
  }

  static Future<String> savePngBytes({
    required Uint8List bytes,
    required String fileNamePrefix,
  }) {
    if (bytes.isEmpty) {
      throw Exception('图片数据为空，无法保存');
    }
    return Future<String>.error(UnsupportedError('当前平台不支持保存图片到本地文件'));
  }
}
