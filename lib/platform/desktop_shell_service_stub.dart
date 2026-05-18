import 'desktop_shell_contract.dart';

DesktopShellService createPlatformDesktopShellService() =>
    const StubDesktopShellService();

class StubDesktopShellService extends DesktopShellService {
  const StubDesktopShellService();

  @override
  Future<void> minimizeToTray() async {}

  @override
  Future<void> setBadgeCount(int count) async {}

  @override
  Future<void> flashTaskbar() async {}
}
