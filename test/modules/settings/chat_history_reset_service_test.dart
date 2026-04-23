import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/settings/chat_history_reset_service.dart';

void main() {
  test(
    'clearAll clears each channel message history before conversations',
    () async {
      final calls = <String>[];
      final service = ChatHistoryResetService(
        loadTargets: () async => const <ChatHistoryTarget>[
          ChatHistoryTarget(channelId: 'u_alice', channelType: 1),
          ChatHistoryTarget(channelId: 'g_design', channelType: 2),
        ],
        clearChannelMessages: (channelId, channelType) async {
          calls.add('message:$channelType:$channelId');
        },
        clearAllConversations: () async {
          calls.add('conversation:all');
        },
      );

      await service.clearAll();

      expect(calls, <String>[
        'message:1:u_alice',
        'message:2:g_design',
        'conversation:all',
      ]);
    },
  );

  test(
    'clearAll still clears conversations when there are no targets',
    () async {
      final calls = <String>[];
      final service = ChatHistoryResetService(
        loadTargets: () async => const <ChatHistoryTarget>[],
        clearChannelMessages: (channelId, channelType) async {
          calls.add('message:$channelType:$channelId');
        },
        clearAllConversations: () async {
          calls.add('conversation:all');
        },
      );

      await service.clearAll();

      expect(calls, <String>['conversation:all']);
    },
  );
}
