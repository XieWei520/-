import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/api/conversation_draft_api.dart';
import 'package:wukong_im_app/service/api/im_sync_api.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukong_im_app/service/api/reminder_api.dart';
import 'package:wukong_im_app/service/im/im_sync_orchestrator.dart';

void main() {
  group('ImSyncOrchestrator planning', () {
    test('sync completed fans out all required background sync tasks', () {
      final plan = ImSyncOrchestrator.planForSyncCompleted();

      expect(plan.reason, 'sync_completed');
      expect(plan.syncReminders, isTrue);
      expect(plan.syncSensitiveWords, isTrue);
      expect(plan.syncProhibitWords, isTrue);
      expect(plan.syncConversationExtras, isTrue);
      expect(plan.syncOfflineCommandMessages, isTrue);
    });

    test(
      'conversation sync fans out conversation extras and offline commands',
      () {
        final plan = ImSyncOrchestrator.planForConversationSync();

        expect(plan.reason, 'conversation_sync');
        expect(plan.syncReminders, isFalse);
        expect(plan.syncSensitiveWords, isFalse);
        expect(plan.syncProhibitWords, isFalse);
        expect(plan.syncConversationExtras, isTrue);
        expect(plan.syncOfflineCommandMessages, isTrue);
      },
    );

    test('runFanOutPlan dispatches only enabled task handlers', () {
      final calls = <String>[];
      final orchestrator = _orchestrator();

      orchestrator.runFanOutPlan(
        const ImSyncFanOutPlan(
          reason: 'unit',
          syncReminders: true,
          syncConversationExtras: true,
        ),
        ImSyncTaskHandlers(
          syncReminders: ({reason}) async => calls.add('reminders:$reason'),
          syncSensitiveWords: ({reason}) async =>
              calls.add('sensitive:$reason'),
          syncProhibitWords: ({reason}) async =>
              calls.add('prohibit:$reason'),
          syncConversationExtras: ({reason}) async =>
              calls.add('conversation:$reason'),
          syncOfflineCommandMessages: ({reason}) async =>
              calls.add('offline:$reason'),
        ),
      );

      expect(calls, <String>['reminders:unit', 'conversation:unit']);
    });
  });
}

ImSyncOrchestrator _orchestrator() {
  return ImSyncOrchestrator(
    syncApi: IMSyncApi.instance,
    messageApi: MessageApi.instance,
    reminderApi: ReminderApi.instance,
    conversationDraftApi: ConversationDraftApi.instance,
  );
}
