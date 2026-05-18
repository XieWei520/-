import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/platform/desktop_shell_service.dart';

void main() {
  test('DesktopShellService default implementation is safe to call', () async {
    final service = createDesktopShellService();

    await service.minimizeToTray();
    await service.setBadgeCount(3);
    await service.setBadgeCount(0);
    await service.flashTaskbar();
  });

  test('DesktopShellService resolves composer keyboard policy', () {
    final service = createDesktopShellService();

    expect(
      service.resolveComposerKeyboardIntent(
        isEnter: true,
        isShiftPressed: false,
      ),
      ComposerKeyboardIntent.send,
    );
    expect(
      service.resolveComposerKeyboardIntent(
        isEnter: true,
        isShiftPressed: true,
      ),
      ComposerKeyboardIntent.newline,
    );
    expect(
      service.resolveComposerKeyboardIntent(
        isEnter: false,
        isShiftPressed: true,
      ),
      ComposerKeyboardIntent.none,
    );
  });

  test(
    'DesktopShellService keeps platform APIs behind conditional imports',
    () {
      final source = File(
        'lib/platform/desktop_shell_service.dart',
      ).readAsStringSync();
      final contractSource = File(
        'lib/platform/desktop_shell_contract.dart',
      ).readAsStringSync();

      expect(source, contains("if (dart.library.js_interop)"));
      expect(source, contains("if (dart.library.io)"));
      expect(contractSource, contains('window_manager'));
      expect(contractSource, contains('bitsdojo_window'));
      expect(contractSource, contains('tray_manager'));
    },
  );
}
