import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PWA install metadata keeps readable Chinese app copy', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final index = File('web/index.html').readAsStringSync();

    expect(manifest['name'], '信息平权');
    expect(manifest['short_name'], '信息平权');
    expect(manifest['description'], '信息平权');
    expect(manifest['id'], '/');
    expect(manifest['scope'], '/');
    expect(manifest['lang'], 'zh-CN');
    expect(manifest['dir'], 'ltr');
    expect(
      manifest['categories'],
      containsAll(['communication', 'productivity']),
    );
    expect(index, contains('<html lang="zh-CN">'));
    expect(
      index,
      contains('name="viewport" content="width=device-width, initial-scale=1"'),
    );
    expect(index, contains('name="theme-color" content="#0EA5E9"'));
    expect(index, contains('<title>信息平权</title>'));
    expect(index, contains('content="信息平权"'));
    expect(index, contains('apple-mobile-web-app-title" content="信息平权"'));

    const mojibakeSnippets = <String>['淇℃伅骞虫潈', '娣団剝浼?', '楠炶櫕娼?', '閻ц缍?'];
    for (final snippet in mojibakeSnippets) {
      expect(manifest.toString(), isNot(contains(snippet)));
      expect(index, isNot(contains(snippet)));
    }
  });

  test(
    'web entrypoint only clears legacy Flutter caches when explicitly requested',
    () {
      final index = File('web/index.html').readAsStringSync();

      expect(index, contains('wkMaybeClearLegacyFlutterServiceWorkers'));
      expect(index, contains('wk_reset_sw'));
      expect(index, contains('loadBootstrap();'));
      expect(index, contains('fontFallbackBaseUrl'));
      expect(index, contains('assets/flutter-font-fallback/'));
      expect(index, contains('navigator.serviceWorker.getRegistrations'));
      expect(index, contains('caches.keys'));
      expect(index, contains('!shouldResetLegacyWorkers'));
      expect(index, isNot(contains('wkClearLegacyFlutterServiceWorkers')));
      expect(
        index,
        isNot(contains('<script src="flutter_bootstrap.js" async></script>')),
      );
    },
  );

  test('web entrypoint registers a lightweight offline PWA worker', () {
    final index = File('web/index.html').readAsStringSync();
    final worker = File('web/wk_pwa_service_worker.js');
    final offlinePage = File('web/offline.html');

    expect(index, contains('wkRegisterPwaServiceWorker'));
    expect(index, contains('wk_pwa_service_worker.js'));
    expect(index, contains('navigator.serviceWorker.register'));
    expect(worker.existsSync(), isTrue);
    expect(offlinePage.existsSync(), isTrue);

    final workerSource = worker.readAsStringSync();
    expect(workerSource, contains('WK_PWA_CACHE'));
    expect(workerSource, contains('offline.html'));
    expect(workerSource, contains("event.request.mode !== 'navigate'"));
    expect(workerSource, contains("addEventListener('notificationclick'"));
    expect(workerSource, contains("event.notification.close()"));
    expect(workerSource, contains(".matchAll({ type: 'window'"));
    expect(workerSource, contains("client.postMessage"));
    expect(workerSource, contains("clients.openWindow"));
    expect(workerSource, isNot(contains('main.dart.js')));
    expect(workerSource, isNot(contains('canvaskit')));

    final offlineHtml = offlinePage.readAsStringSync();
    expect(offlineHtml, contains('<html lang="zh-CN">'));
    expect(offlineHtml, contains('信息平权'));
    expect(offlineHtml, contains('离线'));
  });

  test('custom Flutter bootstrap does not register a service worker', () {
    final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(bootstrap, contains('_flutter.loader.load'));
    expect(bootstrap, contains("canvasKitBaseUrl: 'canvaskit/'"));
    expect(
      bootstrap,
      contains("fontFallbackBaseUrl: 'assets/flutter-font-fallback/'"),
    );
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
  });

  test('web self-hosts Flutter emoji fallback font shards', () {
    const fallbackRoot = 'web/assets/flutter-font-fallback/notocoloremoji/v32';
    for (var index = 0; index <= 11; index += 1) {
      final file = File(
        '$fallbackRoot/Yq6P-KqIXTD0t4D9z1ESnKM3-HpFabsE4tq3luCC7p-aXxcn.$index.woff2',
      );
      expect(file.existsSync(), isTrue, reason: file.path);
      expect(file.lengthSync(), greaterThan(0), reason: file.path);
    }
  });
}
