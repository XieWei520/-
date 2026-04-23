import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrExportUtils {
  QrExportUtils._();

  static Future<String> saveQrCodeAsPng({
    required String data,
    required String fileNamePrefix,
    int imageSize = 1024,
  }) async {
    final normalizedData = data.trim();
    if (normalizedData.isEmpty) {
      throw Exception('二维码内容为空，无法保存');
    }

    final exportDirectory = await _resolveExportDirectory();
    final safePrefix = fileNamePrefix.trim().isEmpty
        ? 'qrcode'
        : fileNamePrefix;
    final fileName =
        '${safePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final targetFile = File(path.join(exportDirectory.path, fileName));

    final painter = QrPainter(
      data: normalizedData,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(color: ui.Color(0xFF000000)),
      dataModuleStyle: const QrDataModuleStyle(color: ui.Color(0xFF000000)),
    );
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final imageDimension = imageSize.toDouble();
    final imageBounds = ui.Offset.zero & ui.Size.square(imageDimension);
    final backgroundPaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    canvas.drawRect(imageBounds, backgroundPaint);
    painter.paint(canvas, ui.Size.square(imageDimension));

    final image = await recorder.endRecording().toImage(imageSize, imageSize);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw Exception('生成二维码图片失败');
    }

    await targetFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return targetFile.path;
  }

  static Future<String> savePngBytes({
    required Uint8List bytes,
    required String fileNamePrefix,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('图片数据为空，无法保存');
    }

    final exportDirectory = await _resolveExportDirectory();
    final safePrefix = fileNamePrefix.trim().isEmpty ? 'image' : fileNamePrefix;
    final fileName =
        '${safePrefix}_${DateTime.now().millisecondsSinceEpoch}.png';
    final targetFile = File(path.join(exportDirectory.path, fileName));
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }

  static Future<Directory> _resolveExportDirectory() async {
    final downloadDirectory = await getDownloadsDirectory();
    if (downloadDirectory != null) {
      await downloadDirectory.create(recursive: true);
      return downloadDirectory;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final fallbackDirectory = Directory(
      path.join(documentsDirectory.path, 'downloads'),
    );
    if (!await fallbackDirectory.exists()) {
      await fallbackDirectory.create(recursive: true);
    }
    return fallbackDirectory;
  }
}
