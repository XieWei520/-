typedef XiaoeShellExecutableResolver = Future<String?> Function();
typedef XiaoeShellProcessStarter =
    Future<void> Function(String executablePath, String workingDirectory);
typedef XiaoeShellListeningProbe = Future<bool> Function();
typedef XiaoeShellPlatformProbe = bool Function();

class XiaoeMonitorLaunchException implements Exception {
  const XiaoeMonitorLaunchException(this.message);

  final String message;

  @override
  String toString() => message;
}

class XiaoeMonitorLaunchService {
  const XiaoeMonitorLaunchService({
    XiaoeShellExecutableResolver? resolveExecutablePath,
    XiaoeShellProcessStarter? startProcess,
    XiaoeShellListeningProbe? isShellListening,
    XiaoeShellPlatformProbe? isSupportedPlatform,
    Duration startupTimeout = Duration.zero,
    Duration pollInterval = Duration.zero,
  });

  const XiaoeMonitorLaunchService.noop();

  Future<void> startShell() async {}

  Future<void> stopShell() async {}
}
