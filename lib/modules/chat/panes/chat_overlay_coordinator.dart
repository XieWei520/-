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
    this.mediaPreview,
    this.commandPalette,
    this.selectionToolbar,
  });

  final ChatSession session;
  final Widget child;
  final Widget? mediaPreview;
  final Widget? commandPalette;
  final Widget? selectionToolbar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scene = ref.watch(chatSceneControllerProvider(session));
    return Stack(
      key: const ValueKey<String>('chat-overlay-coordinator'),
      fit: StackFit.expand,
      children: <Widget>[
        child,
        if (scene.mode == ChatSceneMode.selecting && selectionToolbar != null)
          Positioned(left: 0, top: 0, right: 0, child: selectionToolbar!),
        if (commandPalette != null)
          Align(alignment: Alignment.topCenter, child: commandPalette!),
        if (mediaPreview != null) Positioned.fill(child: mediaPreview!),
      ],
    );
  }
}
