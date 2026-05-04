import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../data/models/chat_session.dart';
import '../../data/providers/conversation_provider.dart';
import 'chat_message_view_model.dart';

/// Per-message selector that only triggers a rebuild when the specific
/// message's content or status changes, not when the entire list changes.
///
/// Usage in a widget:
/// ```dart
/// final model = ref.watch(
///   singleMessageProvider((session: session, identity: item.identity)),
/// );
/// ```
final singleMessageProvider = Provider.autoDispose
    .family<ChatMessageViewModel?, ({ChatSession session, String identity})>((
      ref,
      key,
    ) {
      final viewport = ref.watch(
        chatViewportProvider(key.session).select((state) {
          final index = state.identityToIndex[key.identity];
          if (index == null || index >= state.items.length) return null;
          return state.items[index];
        }),
      );
      return viewport;
    });

/// Provider that exposes only the sending status of a specific message,
/// so UI elements watching send state (progress indicators, retry buttons)
/// don't trigger a rebuild of the message content itself.
final messageSendStatusProvider = Provider.autoDispose
    .family<int, ({ChatSession session, String identity})>((ref, key) {
      final viewport = ref.watch(
        chatViewportProvider(key.session).select((state) {
          final index = state.identityToIndex[key.identity];
          if (index == null || index >= state.items.length) return 0;
          return state.items[index].message.status;
        }),
      );
      return viewport;
    });

/// Provider that exposes only the reaction list of a specific message.
final messageReactionsProvider = Provider.autoDispose
    .family<List<WKMsgReaction>, ({ChatSession session, String identity})>((
      ref,
      key,
    ) {
      final viewport = ref.watch(
        chatViewportProvider(key.session).select((state) {
          final index = state.identityToIndex[key.identity];
          if (index == null || index >= state.items.length) {
            return const <WKMsgReaction>[];
          }
          return state.items[index].message.reactionList ?? const [];
        }),
      );
      return viewport;
    });

/// Provider for the loading-more state of the viewport.
final isLoadingMoreProvider = Provider.autoDispose
    .family<bool, ChatSession>((ref, session) {
      return ref.watch(
        chatViewportProvider(session).select((state) => state.isLoadingMore),
      );
    });
