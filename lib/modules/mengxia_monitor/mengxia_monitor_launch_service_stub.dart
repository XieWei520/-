typedef MengxiaShellExecutableResolver = Future<String?> Function();
typedef MengxiaShellProcessStarter =
    Future<void> Function(String executablePath, String workingDirectory);
typedef MengxiaShellListeningProbe = Future<bool> Function();
typedef MengxiaShellPlatformProbe = bool Function();

class MengxiaMonitorLaunchException implements Exception {
  const MengxiaMonitorLaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MengxiaMonitorLaunchService {
  const MengxiaMonitorLaunchService({
    MengxiaShellExecutableResolver? resolveExecutablePath,
    MengxiaShellProcessStarter? startProcess,
    MengxiaShellListeningProbe? isShellListening,
    MengxiaShellPlatformProbe? isSupportedPlatform,
    Duration startupTimeout = Duration.zero,
    Duration pollInterval = Duration.zero,
  });

  const MengxiaMonitorLaunchService.noop();

  Future<void> startShell() async {}

  Future<void> stopShell() async {}
}
