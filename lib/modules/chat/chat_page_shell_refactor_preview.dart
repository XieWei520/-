import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat_session.dart';
import '../../data/providers/conversation_provider.dart';
import 'chat_scene_providers.dart';
import 'panes/chat_panes.dart';

class ChatPageShellRefactorPreview extends ConsumerWidget {
  const ChatPageShellRefactorPreview({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.headerState,
    this.onSubmitText,
  });

  final String channelId;
  final int channelType;
  final String? channelName;
  final ChatHeaderPaneState? headerState;
  final ValueChanged<String>? onSubmitText;

  ChatSession get _session {
    return ChatSession(channelId: channelId, channelType: channelType);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = _session;
    final resolvedHeaderState =
        headerState ??
        ChatHeaderPaneState(
          title: channelName?.trim().isNotEmpty == true
              ? channelName!.trim()
              : channelId,
        );

    ref.watch(
      chatSceneControllerProvider(session).select((state) => state.mode),
    );
    ref.watch(chatComposerProvider(session).select((state) => state.text));

    return Scaffold(
      key: const ValueKey<String>('chat-page-shell-refactor-preview'),
      appBar: ChatHeaderPane(
        session: session,
        state: resolvedHeaderState,
        onOpenSearch: () {
          final anchor = ref
              .read(chatViewportProvider(session).notifier)
              .firstVisibleOrderSeq;
          ref
              .read(chatSearchModeControllerProvider(session).notifier)
              .open(anchorOrderSeq: anchor);
          ref
              .read(chatSceneControllerProvider(session).notifier)
              .enterSearchMode(anchorOrderSeq: anchor);
        },
        onSearchKeywordChanged: (keyword) {
          ref
              .read(chatSearchModeControllerProvider(session).notifier)
              .updateKeyword(keyword);
        },
        onSearchSubmitted: (_) {},
        onCloseSearch: () {
          ref.read(chatSearchModeControllerProvider(session).notifier).close();
          ref
              .read(chatSceneControllerProvider(session).notifier)
              .restoreNormal();
        },
      ),
      body: ChatOverlayCoordinator(
        session: session,
        child: Column(
          children: <Widget>[
            Expanded(
              child: ChatViewportPane(
                session: session,
                onLoadOlder: () {
                  unawaited(
                    ref
                        .read(chatViewportProvider(session).notifier)
                        .loadOlder(),
                  );
                },
              ),
            ),
            ChatComposerPane(session: session, onSubmitText: onSubmitText),
          ],
        ),
      ),
    );
  }
}
