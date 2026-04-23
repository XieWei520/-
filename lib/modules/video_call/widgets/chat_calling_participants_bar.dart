import 'package:flutter/material.dart';

import '../../../modules/conversation/conversation_activity_registry.dart';
import '../../../widgets/wk_colors.dart';

String buildCallingParticipantsLabel(ConversationActivityState state) {
  final names = state.callingParticipants
      .map((participant) => participant.name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) {
    return '\u6b63\u5728\u901a\u8bdd';
  }
  if (names.length == 1) {
    return '${names.first} \u6b63\u5728\u901a\u8bdd';
  }
  if (names.length == 2) {
    return '${names[0]}\u3001${names[1]} \u6b63\u5728\u901a\u8bdd';
  }
  return '${names[0]}\u3001${names[1]} \u7b49${names.length}\u4eba\u6b63\u5728\u901a\u8bdd';
}

class ChatCallingParticipantsBar extends StatelessWidget {
  const ChatCallingParticipantsBar({
    super.key,
    required this.state,
  });

  final ConversationActivityState state;

  @override
  Widget build(BuildContext context) {
    final roomName = state.callRoomName?.trim() ?? '';
    final label = buildCallingParticipantsLabel(state);

    return Container(
      key: const ValueKey<String>('chat-calling-participants-bar'),
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: WKColors.surface,
        border: Border(
          top: BorderSide(color: WKColors.colorLine),
          bottom: BorderSide(color: WKColors.colorLine),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.call_rounded,
            size: 18,
            color: WKColors.brand500,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: roomName.isEmpty
                ? Text(
                    label,
                    key: const ValueKey<String>(
                      'chat-calling-participants-label',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WKColors.colorDark,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        key: const ValueKey<String>(
                          'chat-calling-participants-label',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: WKColors.colorDark,
                        ),
                      ),
                      Text(
                        roomName,
                        key: const ValueKey<String>(
                          'chat-calling-participants-room',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: WKColors.color999,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
