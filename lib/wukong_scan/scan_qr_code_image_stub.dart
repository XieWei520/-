import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'scan_qr_code_image_limits.dart';

final Dio _scanImageDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 12),
    responseType: ResponseType.bytes,
  ),
);

Future<Uint8List?> loadScanQrImageBytes(String imageSource) async {
  final normalizedSource = imageSource.trim();
  if (normalizedSource.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(normalizedSource);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }

  try {
    final response = await _scanImageDio.get<List<int>>(
      normalizedSource,
      options: Options(
        responseType: ResponseType.bytes,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 400,
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    if (bytes.length > maxScanQrImageBytes) {
      return null;
    }
    return Uint8List.fromList(bytes);
  } catch (_) {
    return null;
  }
}

Future<String?> defaultAnalyzeScanQrImageBytes(Uint8List imageBytes) async {
  return null;
}
