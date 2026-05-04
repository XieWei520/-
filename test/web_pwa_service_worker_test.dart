import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'PWA service worker resolves notification click targets from payloads',
    () {
      final worker = File('web/wk_pwa_service_worker.js');

      expect(worker.existsSync(), isTrue);

      final source = worker.readAsStringSync();
      expect(source, contains('function parseNotificationClickData'));
      expect(source, contains('JSON.parse'));
      expect(source, contains('function resolveNotificationClickTarget'));
      expect(source, contains('payload.url'));
      expect(source, contains('payload.click_action'));
      expect(source, contains('payload.clickAction'));
    },
  );
}
