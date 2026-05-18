import 'dart:io' show Platform;

import 'desktop_shell_contract.dart';

DesktopShellService createPlatformDesktopShellService() =>
    const IoDesktopShellService();

class IoDesktopShellService extends DesktopShellService {
  const IoDesktopShellService();

  @override
  Future<void> minimizeToTray() async {
    if (!Platform.isWindows) {
      return;
    }
    // Keep this no-op until a reviewed tray dependency is added.
  }

  @override
  Future<void> setBadgeCount(int count) async {
    if (!Platform.isWindows) {
      return;
    }
    // Windows badge overlays require native runner or plugin integration.
  }

  @override
  Future<void> flashTaskbar() async {
    if (!Platform.isWindows) {
      return;
    }
    // Hook `window_manager` or Win32 FlashWindowEx here after dependency review.
  }
}
