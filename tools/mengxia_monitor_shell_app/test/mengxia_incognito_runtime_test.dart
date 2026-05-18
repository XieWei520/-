import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_incognito_runtime.dart';

void main() {
  test(
    'createMengxiaFreshSessionDirectory returns a new unique directory',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'mengxia_runtime_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });

      final first = await createMengxiaFreshSessionDirectory(base);
      final second = await createMengxiaFreshSessionDirectory(base);

      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
      expect(first.path, isNot(second.path));
      expect(first.parent.path, base.path);
      expect(second.parent.path, base.path);
    },
  );

  test(
    'destroyMengxiaFreshSessionDirectory recursively removes only the session',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'mengxia_runtime_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final sentinel = File('${base.path}${Platform.pathSeparator}keep.txt');
      await sentinel.writeAsString('outside session');
      final session = await createMengxiaFreshSessionDirectory(base);
      final nested = File(
        '${session.path}${Platform.pathSeparator}nested'
        '${Platform.pathSeparator}cookie.sqlite',
      );
      await nested.parent.create(recursive: true);
      await nested.writeAsString('must be deleted with session');

      await destroyMengxiaFreshSessionDirectory(session);

      expect(await session.exists(), isFalse);
      expect(await nested.exists(), isFalse);
      expect(await sentinel.exists(), isTrue);
    },
  );

  test(
    'destroyMengxiaFreshSessionDirectoryBestEffort retries transient locks',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'mengxia_runtime_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final session = await createMengxiaFreshSessionDirectory(base);
      final nested = File(
        '${session.path}${Platform.pathSeparator}locked'
        '${Platform.pathSeparator}cookie.sqlite',
      );
      await nested.parent.create(recursive: true);
      await nested.writeAsString('deleted after retry');
      var attempts = 0;

      final deleted = await destroyMengxiaFreshSessionDirectoryBestEffort(
        session,
        retryDelays: const <Duration>[Duration.zero, Duration.zero],
        destroy: (directory) async {
          attempts += 1;
          if (attempts < 3) {
            throw const FileSystemException('temporarily locked');
          }
          await destroyMengxiaFreshSessionDirectory(directory);
        },
      );

      expect(deleted, isTrue);
      expect(attempts, 3);
      expect(await session.exists(), isFalse);
      expect(await nested.exists(), isFalse);
    },
  );

  test('runtime privacy policy exposes no reusable browser state paths', () {
    const policy = MengxiaIncognitoRuntimePolicy.strict();

    expect(policy.reusesCookies, isFalse);
    expect(policy.reusesLocalStorage, isFalse);
    expect(policy.reusesHistory, isFalse);
    expect(policy.persistentProfileDirectory, isNull);
    expect(policy.persistentSessionDirectory, isNull);
    expect(policy.requiresManualLoginEveryLaunch, isTrue);
  });

  test(
    'snapshot file is outside disposable browser session directory',
    () async {
      final base = await Directory.systemTemp.createTemp(
        'mengxia_runtime_test_',
      );
      addTearDown(() async {
        if (await base.exists()) {
          await base.delete(recursive: true);
        }
      });
      final session = await createMengxiaFreshSessionDirectory(base);
      final snapshot = mengxiaShellSnapshotFileFor(base);

      expect(snapshot.path.startsWith(session.path), isFalse);
      expect(snapshot.path, contains('mengxia_monitor_shell'));
      expect(snapshot.path, contains('status.json'));
    },
  );
}
