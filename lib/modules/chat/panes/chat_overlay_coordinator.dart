import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_session.dart';
import '../chat_scene_models.dart';
import '../chat_scene_providers.dart';

class ChatOverlayCoordinator extends ConsumerWidget {
  const ChatOverlayCoordinator({
    super.key,
    required this.session,
    required this.child,
    this.background,
    this.mediaPreview,
    this.commandPalette,
    this.selectionToolbar,
    this.topStatusBars = const <Widget>[],
    this.contentWrapper,
  });

  final ChatSession session;
  final Widget child;
  final Widget? background;
  final Widget? mediaPreview;
  final Widget? commandPalette;
  final Widget? selectionToolbar;
  final List<Widget> topStatusBars;
  final Widget Function(Widget content)? contentWrapper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(chatSceneControllerProvider(session));
    final visibleTopBars = scene.mode == ChatSceneMode.selecting
        ? <Widget>[?selectionToolbar]
        : topStatusBars;
    final content = _OverlayContent(topBars: visibleTopBars, child: child);
    return Stack(
      key: const ValueKey<String>('chat-overlay-coordinator'),
      fit: StackFit.expand,
      children: <Widget>[
        if (background != null) IgnorePointer(child: background!),
        contentWrapper?.call(content) ?? content,
        if (commandPalette != null)
          Align(alignment: Alignment.topCenter, child: commandPalette!),
        if (mediaPreview != null) Positioned.fill(child: mediaPreview!),
      ],
    );
  }
}

class _OverlayContent extends StatelessWidget {
  const _OverlayContent({required this.topBars, required this.child});

  final List<Widget> topBars;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (topBars.isEmpty) {
      return child;
    }
    return Column(
      children: <Widget>[
        ...topBars,
        Expanded(child: child),
      ],
    );
  }
}
