import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'scan_qr_code_image_limits.dart';

Future<Uint8List?> loadScanQrImageBytes(String imageSource) async {
  final normalizedSource = imageSource.trim();
  if (normalizedSource.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(normalizedSource);
  final scheme = uri?.scheme.toLowerCase();
  if (uri != null &&
      (scheme == 'http' || scheme == 'https') &&
      uri.host.trim().isNotEmpty) {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode >= 400) {
        return null;
      }
      if (response.contentLength > maxScanQrImageBytes) {
        return null;
      }
      return _readBoundedResponseBytes(response);
    } catch (_) {
      return null;
    } finally {
      try {
        client.close();
      } catch (_) {}
    }
  } else if (scheme == 'http' || scheme == 'https') {
    return null;
  }

  final path = normalizedSource.startsWith('file://')
      ? Uri.parse(normalizedSource).toFilePath()
      : normalizedSource;
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  if (await file.length() > maxScanQrImageBytes) {
    return null;
  }
  return file.readAsBytes();
}

Future<Uint8List?> _readBoundedResponseBytes(HttpClientResponse response) {
  final completer = Completer<Uint8List?>();
  final builder = BytesBuilder(copy: false);
  var totalBytes = 0;
  late final StreamSubscription<List<int>> subscription;

  void complete(Uint8List? bytes) {
    if (!completer.isCompleted) {
      completer.complete(bytes);
    }
  }

  subscription = response.listen(
    (chunk) {
      if (completer.isCompleted) {
        return;
      }
      totalBytes += chunk.length;
      if (totalBytes > maxScanQrImageBytes) {
        subscription.cancel().catchError((_) {});
        complete(null);
        return;
      }
      builder.add(chunk);
    },
    onError: (_) => complete(null),
    onDone: () => complete(builder.takeBytes()),
    cancelOnError: true,
  );
  return completer.future;
}

Future<String?> defaultAnalyzeScanQrImageBytes(Uint8List imageBytes) async {
  if (imageBytes.isEmpty) {
    return null;
  }

  final tempFile = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'wk_qr_${DateTime.now().microsecondsSinceEpoch}.png',
  );
  final controller = MobileScannerController(autoStart: false);
  try {
    await tempFile.writeAsBytes(imageBytes, flush: true);
    final capture = await controller.analyzeImage(tempFile.path);
    if (capture == null) {
      return null;
    }
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue?.trim() ?? '';
      if (rawValue.isNotEmpty) {
        return rawValue;
      }
      final displayValue = barcode.displayValue?.trim() ?? '';
      if (displayValue.isNotEmpty) {
        return displayValue;
      }
    }
    return null;
  } finally {
    controller.dispose();
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}
