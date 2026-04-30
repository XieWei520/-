import 'package:flutter/material.dart';

enum ChatMessageActionSurface { bottomSheet, contextMenu }

ChatMessageActionSurface resolveChatMessageActionSurface({
  required TargetPlatform platform,
  required bool isWeb,
  Offset? anchorPosition,
}) {
  if (anchorPosition == null) {
    return ChatMessageActionSurface.bottomSheet;
  }
  if (_isDesktopPlatform(platform) && !isWeb) {
    return ChatMessageActionSurface.contextMenu;
  }
  return ChatMessageActionSurface.bottomSheet;
}

RelativeRect buildChatMessageContextMenuPosition({
  required Offset anchorPosition,
  required Size overlaySize,
}) {
  final left = anchorPosition.dx.clamp(0.0, overlaySize.width).toDouble();
  final top = anchorPosition.dy.clamp(0.0, overlaySize.height).toDouble();
  return RelativeRect.fromLTRB(
    left,
    top,
    overlaySize.width - left,
    overlaySize.height - top,
  );
}

bool _isDesktopPlatform(TargetPlatform platform) {
  return platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
}
