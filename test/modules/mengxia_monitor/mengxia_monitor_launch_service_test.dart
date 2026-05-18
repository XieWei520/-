import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_launch_service.dart';

void main() {
  test(
    'startShell skips process launch when shell is already listening',
    () async {
      var resolved = false;
      var started = false;
      final service = MengxiaMonitorLaunchService(
        isSupportedPlatform: () => true,
        isShellListening: () async => true,
        resolveExecutablePath: () async {
          resolved = true;
          return 'C:\\fake\\MX信息监控.exe';
        },
        startProcess: (_, _) async {
          started = true;
        },
      );

      await service.startShell();

      expect(resolved, isFalse);
      expect(started, isFalse);
    },
  );

  test(
    'startShell launches resolved shell and waits for listening port',
    () async {
      var probeCount = 0;
      var startedPath = '';
      var workingDirectory = '';
      final service = MengxiaMonitorLaunchService(
        isSupportedPlatform: () => true,
        isShellListening: () async {
          probeCount += 1;
          return probeCount >= 2;
        },
        resolveExecutablePath: () async => 'C:\\mx\\MX信息监控.exe',
        startProcess: (executablePath, directory) async {
          startedPath = executablePath;
          workingDirectory = directory;
        },
        startupTimeout: const Duration(milliseconds: 50),
        pollInterval: Duration.zero,
      );

      await service.startShell();

      expect(startedPath, 'C:\\mx\\MX信息监控.exe');
      expect(workingDirectory, 'C:\\mx');
      expect(probeCount, greaterThanOrEqualTo(2));
    },
  );

  test('startShell reports missing shell executable clearly', () async {
    final service = MengxiaMonitorLaunchService(
      isSupportedPlatform: () => true,
      isShellListening: () async => false,
      resolveExecutablePath: () async => null,
      startProcess: (_, _) async {},
    );

    await expectLater(
      service.startShell(),
      throwsA(
        isA<MengxiaMonitorLaunchException>().having(
          (error) => error.message,
          'message',
          contains('找不到“MX信息监控”壳端程序'),
        ),
      ),
    );
  });
}
