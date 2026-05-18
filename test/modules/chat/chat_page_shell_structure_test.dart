import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatPageShell stays behind controller and pane boundaries', () {
    final source = File(
      'lib/modules/chat/chat_page_shell.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains("package:dio/dio.dart")),
      reason: 'Network cancellation details belong in shell services.',
    );
    expect(
      source,
      isNot(contains('WKIM.shared')),
      reason: 'Direct SDK access belongs outside the layout container.',
    );
    expect(
      source,
      isNot(contains('ChatRobotMenuStateService')),
      reason: 'Robot menu state should be loaded through ChatShellController.',
    );
    expect(
      source,
      isNot(contains('ChatPinnedMessageStateService')),
      reason:
          'Pinned message state should be loaded through ChatShellController.',
    );
    expect(source, contains('ChatHeaderPane'));
    expect(source, contains('ChatViewportPane'));
    expect(source, contains('ChatComposerPane'));
    expect(source, contains('ChatOverlayCoordinator'));
  });
}
