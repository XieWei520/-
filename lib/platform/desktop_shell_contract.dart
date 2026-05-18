enum ComposerKeyboardIntent { none, send, newline }

/// Cross-platform shell boundary for desktop/web integration.
///
/// Recommended native follow-ups:
/// - `window_manager` or `bitsdojo_window` for Windows window minimize/focus.
/// - `tray_manager` or `system_tray` for Windows tray lifecycle.
/// - Win32 runner integration for a real taskbar flash implementation.
abstract class DesktopShellService {
  const DesktopShellService();

  Future<void> minimizeToTray();

  Future<void> setBadgeCount(int count);

  Future<void> flashTaskbar();

  ComposerKeyboardIntent resolveComposerKeyboardIntent({
    required bool isEnter,
    required bool isShiftPressed,
  }) {
    if (!isEnter) {
      return ComposerKeyboardIntent.none;
    }
    return isShiftPressed
        ? ComposerKeyboardIntent.newline
        : ComposerKeyboardIntent.send;
  }
}
