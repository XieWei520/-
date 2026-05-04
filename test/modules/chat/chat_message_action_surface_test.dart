import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_surface.dart';

void main() {
  group('chat message action surface', () {
    test('desktop secondary tap uses anchored context menu', () {
      final surface = resolveChatMessageActionSurface(
        platform: TargetPlatform.windows,
        isWeb: false,
        anchorPosition: const Offset(320, 240),
      );

      expect(surface, ChatMessageActionSurface.contextMenu);
    });

    test('mobile secondary tap still uses bottom sheet', () {
      final surface = resolveChatMessageActionSurface(
        platform: TargetPlatform.android,
        isWeb: false,
        anchorPosition: const Offset(320, 240),
      );

      expect(surface, ChatMessageActionSurface.bottomSheet);
    });

    test('desktop long press without anchor still uses bottom sheet', () {
      final surface = resolveChatMessageActionSurface(
        platform: TargetPlatform.windows,
        isWeb: false,
      );

      expect(surface, ChatMessageActionSurface.bottomSheet);
    });

    test('context menu position is clamped to overlay bounds', () {
      final rect = buildChatMessageContextMenuPosition(
        anchorPosition: const Offset(1200, -20),
        overlaySize: const Size(800, 600),
      );

      expect(rect.left, 800);
      expect(rect.top, 0);
      expect(rect.right, 0);
      expect(rect.bottom, 600);
    });
  });
}
