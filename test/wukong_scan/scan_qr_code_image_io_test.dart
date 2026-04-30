import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_scan/scan_qr_code_image_io.dart';
import 'package:wukong_im_app/wukong_scan/scan_qr_code_image_limits.dart';

void main() {
  test('loadScanQrImageBytes rejects malformed remote image urls', () async {
    expect(await loadScanQrImageBytes('https://'), isNull);
  });

  test(
    'loadScanQrImageBytes rejects oversized remote image responses',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        final chunk = List<int>.filled(1024 * 1024, 1);
        try {
          for (
            var sent = 0;
            sent <= maxScanQrImageBytes;
            sent += chunk.length
          ) {
            request.response.add(chunk);
            await request.response.flush();
          }
          await request.response.close();
        } catch (_) {
          // The client is expected to abort when the size limit is crossed.
        }
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });

      final result = await loadScanQrImageBytes(
        'http://${server.address.host}:${server.port}/qr.png',
      );

      expect(result, isNull);
    },
  );

  test('loadScanQrImageBytes rejects oversized local image files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'wk_scan_qr_large_local',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final image = File('${tempDir.path}${Platform.pathSeparator}large.png');
    await image.writeAsBytes(List<int>.filled(maxScanQrImageBytes + 1, 1));

    expect(await loadScanQrImageBytes(image.path), isNull);
  });
}
