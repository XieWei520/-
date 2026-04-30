import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wukong_scan/scan_qr_code_image_stub.dart';

void main() {
  test(
    'web scan image loader rejects oversized remote image responses',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.binary;
        request.response.add(List<int>.filled(8 * 1024 * 1024 + 1, 1));
        await request.response.close();
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
}
