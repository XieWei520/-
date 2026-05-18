import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_session.dart';
import '../../../data/providers/conversation_provider.dart';

class ChatViewportPane extends ConsumerWidget {
  const ChatViewportPane({
    super.key,
    required this.session,
    this.onLoadOlder,
    this.emptyBuilder,
    this.messageBuilder,
    this.loadingOlderBuilder,
  });

  final ChatSession session;
  final VoidCallback? onLoadOlder;
  final WidgetBuilder? emptyBuilder;
  final Widget Function(BuildContext context, String identity)? messageBuilder;
  final WidgetBuilder? loadingOlderBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identities = ref.watch(
      chatViewportProvider(session).select((state) => state.identities),
    );
    final isLoadingMore = ref.watch(
      chatViewportProvider(session).select((state) => state.isLoadingMore),
    );

    return RepaintBoundary(
      key: const ValueKey<String>('chat-viewport-pane'),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              notification.metrics.extentAfter < 300) {
            onLoadOlder?.call();
          }
          return false;
        },
        child: identities.isEmpty
            ? (emptyBuilder?.call(context) ?? const Center(child: Text('暂无消息')))
            : ListView.builder(
                key: const ValueKey<String>('chat-viewport-list'),
                reverse: true,
                itemCount: identities.length + (isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (isLoadingMore && index == identities.length) {
                    return loadingOlderBuilder?.call(context) ??
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                  }
                  final identity = identities[index];
                  return messageBuilder?.call(context, identity) ??
                      ListTile(
                        key: ValueKey<String>('chat-preview-message-$identity'),
                        title: Text(identity),
                      );
                },
              ),
      ),
    );
  }
}
