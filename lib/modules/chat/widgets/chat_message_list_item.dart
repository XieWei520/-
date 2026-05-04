import 'package:flutter/widgets.dart';
import 'package:wukongimfluttersdk/type/const.dart';

/// Wraps each message list item with a [KeyedSubtree] and optional
/// [AutomaticKeepAliveClientMixin] for media-heavy bubbles (images, video,
/// GIF, file) to avoid rebuilding expensive widgets during fast scrolling.
class ChatMessageListItem extends StatefulWidget {
  const ChatMessageListItem({
    super.key,
    required this.itemKey,
    required this.child,
    this.measurementKey,
    this.keepAlive = false,
  });

  final Key itemKey;
  final Widget child;
  final Key? measurementKey;

  /// Set true for media-heavy message types (image, video, gif, file)
  /// so the framework keeps them alive when they scroll just out of view.
  final bool keepAlive;

  @override
  State<ChatMessageListItem> createState() => _ChatMessageListItemState();
}

class _ChatMessageListItemState extends State<ChatMessageListItem>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void didUpdateWidget(covariant ChatMessageListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final measuredChild = widget.measurementKey == null
        ? widget.child
        : KeyedSubtree(key: widget.measurementKey, child: widget.child);
    return KeyedSubtree(key: widget.itemKey, child: measuredChild);
  }
}

/// Estimated heights for each message content type, used to provide
/// the scroll framework with better layout predictions before actual
/// measurement (reduces list jumping during fast scroll).
class MessageHeightEstimator {
  MessageHeightEstimator._();

  /// Default estimated height for an unknown message type.
  static const double _defaultHeight = 72.0;

  /// Padding/margin common to all bubbles (avatar row + padding).
  static const double _bubbleChrome = 16.0;

  /// Returns whether the given content type should be kept alive when
  /// scrolled just outside the visible area.
  static bool shouldKeepAlive(int contentType) {
    return contentType == WkMessageContentType.image ||
        contentType == WkMessageContentType.video ||
        contentType == WkMessageContentType.gif ||
        contentType == WkMessageContentType.file;
  }

  /// Estimate the pixel height of a message item given its content type
  /// and, optionally, some lightweight metadata (character count,
  /// image dimensions).
  static double estimate(
    int contentType, {
    int characterCount = 0,
    int mediaWidth = 0,
    int mediaHeight = 0,
  }) {
    switch (contentType) {
      case WkMessageContentType.text:
        // Rough: ~20 chars per line, 22px per line + chrome.
        final lines = (characterCount / 20).ceil().clamp(1, 30);
        return lines * 22.0 + _bubbleChrome;
      case WkMessageContentType.image:
      case WkMessageContentType.gif:
        if (mediaWidth > 0 && mediaHeight > 0) {
          // Scale to max width of 200, preserve aspect ratio.
          final scale = 200.0 / mediaWidth;
          return (mediaHeight * scale).clamp(60.0, 300.0) + _bubbleChrome;
        }
        return 200.0 + _bubbleChrome;
      case WkMessageContentType.voice:
        return 56.0 + _bubbleChrome;
      case WkMessageContentType.video:
        if (mediaWidth > 0 && mediaHeight > 0) {
          final scale = 200.0 / mediaWidth;
          return (mediaHeight * scale).clamp(80.0, 300.0) + _bubbleChrome;
        }
        return 200.0 + _bubbleChrome;
      case WkMessageContentType.location:
        return 160.0 + _bubbleChrome;
      case WkMessageContentType.file:
        return 72.0 + _bubbleChrome;
      case WkMessageContentType.card:
        return 80.0 + _bubbleChrome;
      default:
        // System messages, unknown types
        if (contentType >= 1000) {
          return 40.0; // system notice — no bubble chrome
        }
        return _defaultHeight;
    }
  }
}
