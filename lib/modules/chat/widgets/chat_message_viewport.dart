import 'package:flutter/widgets.dart';

class ChatMessageViewport extends StatelessWidget {
  const ChatMessageViewport({
    super.key,
    required this.child,
    this.onBuild,
  });

  final Widget child;
  final VoidCallback? onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild?.call();
    return RepaintBoundary(child: child);
  }
}
