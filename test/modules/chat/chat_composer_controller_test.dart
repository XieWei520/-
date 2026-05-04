import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_composer_controller.dart';
import 'package:wukong_im_app/wukong_base/msg/draft_manager.dart';

void main() {
  test('restores draft text and reply state on initialize', () async {
    final fakeDraftManager = FakeDraftStore(
      draft: MessageDraft(
        channelId: 'u_demo',
        channelType: 1,
        content: 'draft hello',
        updateTime: 1,
        replyMsgId: 'mid:reply',
        replyContent: 'quoted',
      ),
    );

    final controller = ChatComposerController(
      channelId: 'u_demo',
      channelType: 1,
      draftStore: fakeDraftManager,
    );

    await controller.initialize();

    expect(controller.state.text, 'draft hello');
    expect(controller.state.pendingReplyMessageId, 'mid:reply');
    expect(controller.state.pendingReplyPreview, 'quoted');
    controller.dispose();
  });

  test('debounces duplicate draft writes', () async {
    final fakeDraftManager = FakeDraftStore();
    final controller = ChatComposerController(
      channelId: 'u_demo',
      channelType: 1,
      draftStore: fakeDraftManager,
    );

    controller.updateText('hello');
    controller.updateText('hello');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(fakeDraftManager.saveCalls, 1);
    controller.dispose();
  });

  test('retries persist after a failed save', () async {
    final fakeDraftManager = FakeDraftStore(failSaveCount: 1);
    final controller = ChatComposerController(
      channelId: 'u_demo',
      channelType: 1,
      draftStore: fakeDraftManager,
    );

    controller.updateText('retry me');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(fakeDraftManager.saveCalls, 1);
    expect(fakeDraftManager.successfulSaveCalls, 0);

    controller.updateText('retry me');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(fakeDraftManager.saveCalls, 2);
    expect(fakeDraftManager.successfulSaveCalls, 1);
    expect(fakeDraftManager.savedContent, 'retry me');
    controller.dispose();
  });

  test(
    'automatically retries failed saves without requiring another edit',
    () async {
      final fakeDraftManager = FakeDraftStore(failSaveCount: 1);
      final controller = ChatComposerController(
        channelId: 'u_demo',
        channelType: 1,
        draftStore: fakeDraftManager,
      );
      addTearDown(controller.dispose);

      controller.updateText('auto retry');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(fakeDraftManager.saveCalls, 1);
      expect(fakeDraftManager.successfulSaveCalls, 0);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(fakeDraftManager.saveCalls, 2);
      expect(fakeDraftManager.successfulSaveCalls, 1);
      expect(fakeDraftManager.savedContent, 'auto retry');
    },
  );

  test('flushes pending draft on dispose before debounce fires', () async {
    final fakeDraftManager = FakeDraftStore();
    final controller = ChatComposerController(
      channelId: 'u_demo',
      channelType: 1,
      draftStore: fakeDraftManager,
    );

    controller.updateText('draft before close');
    controller.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(fakeDraftManager.saveCalls, 1);
    expect(fakeDraftManager.savedContent, 'draft before close');
  });

  test('persists reply-only changes without changing text', () async {
    final fakeDraftManager = FakeDraftStore();
    final controller = ChatComposerController(
      channelId: 'u_demo',
      channelType: 1,
      draftStore: fakeDraftManager,
    );

    controller.setPendingReply(messageId: 'mid:reply', preview: 'quoted');
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(fakeDraftManager.saveCalls, 1);
    expect(fakeDraftManager.savedContent, '');
    expect(fakeDraftManager.savedReplyMessageId, 'mid:reply');
    expect(fakeDraftManager.savedReplyContent, 'quoted');

    controller.clearPendingReply();
    await Future<void>.delayed(const Duration(milliseconds: 350));

    expect(fakeDraftManager.saveCalls, 2);
    expect(fakeDraftManager.savedReplyMessageId, isNull);
    expect(fakeDraftManager.savedReplyContent, isNull);
    controller.dispose();
  });

  test(
    'persists state changes that would collide under pipe-joined signatures',
    () async {
      final fakeDraftManager = FakeDraftStore(
        draft: MessageDraft(
          channelId: 'u_demo',
          channelType: 1,
          content: 'a|b',
          updateTime: 1,
          replyMsgId: 'c',
        ),
      );
      final controller = ChatComposerController(
        channelId: 'u_demo',
        channelType: 1,
        draftStore: fakeDraftManager,
      );

      await controller.initialize();
      controller.setPendingReply(messageId: 'b|c', preview: null);
      controller.updateText('a');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(fakeDraftManager.saveCalls, 1);
      expect(fakeDraftManager.savedContent, 'a');
      expect(fakeDraftManager.savedReplyMessageId, 'b|c');
      expect(fakeDraftManager.savedReplyContent, isNull);
      controller.dispose();
    },
  );

  test(
    'serializes saves so stale drafts cannot overwrite newer state',
    () async {
      final fakeDraftManager = SequencedDraftStore();
      final controller = ChatComposerController(
        channelId: 'u_demo',
        channelType: 1,
        draftStore: fakeDraftManager,
      );

      controller.updateText('first');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(fakeDraftManager.startedContents, ['first']);
      expect(fakeDraftManager.maxConcurrentSaves, 1);

      controller.updateText('second');
      await Future<void>.delayed(const Duration(milliseconds: 350));

      expect(fakeDraftManager.startedContents, ['first']);
      expect(fakeDraftManager.maxConcurrentSaves, 1);

      fakeDraftManager.completeNext();
      await Future<void>.delayed(Duration.zero);

      expect(fakeDraftManager.startedContents, ['first', 'second']);

      fakeDraftManager.completeNext();
      await Future<void>.delayed(Duration.zero);

      expect(fakeDraftManager.completedContents, ['first', 'second']);
      expect(fakeDraftManager.savedContent, 'second');
      controller.dispose();
    },
  );

  test('consumeSubmission trims text and clears reply after success', () async {
    final controller = ChatComposerController(
      channelId: 'group-1',
      channelType: 2,
    );
    addTearDown(controller.dispose);

    controller.updateText('  hello team  ');
    controller.setPendingReply(messageId: 'mid-1', preview: 'original');

    final payload = controller.buildSubmissionPayload();

    expect(payload.text, 'hello team');
    expect(payload.replyMessageId, 'mid-1');
    expect(payload.replyPreview, 'original');

    controller.markSubmitSucceeded();

    expect(controller.state.text, '');
    expect(controller.state.pendingReplyMessageId, isNull);
    expect(controller.state.pendingReplyPreview, isNull);
  });

  test(
    'selectExpressionCategory keeps the face panel open while switching categories in place',
    () {
      final controller = ChatComposerController(
        channelId: 'u_expression_state',
        channelType: 1,
      );
      addTearDown(controller.dispose);

      controller.toggleFacePanel(initialCategoryId: 'emoji:0');
      controller.selectExpressionCategory('sticker:android_sample_motion');

      expect(controller.state.showFacePanel, isTrue);
      expect(
        controller.state.activeExpressionCategoryId,
        'sticker:android_sample_motion',
      );

      controller.selectExpressionCategory('gif');

      expect(controller.state.showFacePanel, isTrue);
      expect(controller.state.activeExpressionCategoryId, 'gif');
    },
  );
}

class FakeDraftStore implements DraftStore {
  FakeDraftStore({this.draft, this.failSaveCount = 0});

  final MessageDraft? draft;
  int failSaveCount;
  int saveCalls = 0;
  int successfulSaveCalls = 0;
  String? savedContent;
  String? savedReplyMessageId;
  String? savedReplyContent;

  @override
  MessageDraft? getDraft(String channelId, int channelType) {
    return draft;
  }

  @override
  Future<void> saveDraft({
    required String channelId,
    required int channelType,
    required String content,
    String? replyMsgId,
    String? replyContent,
  }) async {
    saveCalls++;
    if (failSaveCount > 0) {
      failSaveCount--;
      throw Exception('save failed');
    }
    successfulSaveCalls++;
    savedContent = content;
    savedReplyMessageId = replyMsgId;
    savedReplyContent = replyContent;
  }
}

class SequencedDraftStore implements DraftStore {
  final List<String> startedContents = <String>[];
  final List<String> completedContents = <String>[];
  final List<Completer<void>> _pendingSaves = <Completer<void>>[];
  int activeSaves = 0;
  int maxConcurrentSaves = 0;
  String? savedContent;

  @override
  MessageDraft? getDraft(String channelId, int channelType) {
    return null;
  }

  @override
  Future<void> saveDraft({
    required String channelId,
    required int channelType,
    required String content,
    String? replyMsgId,
    String? replyContent,
  }) async {
    startedContents.add(content);
    activeSaves++;
    if (activeSaves > maxConcurrentSaves) {
      maxConcurrentSaves = activeSaves;
    }

    final completer = Completer<void>();
    _pendingSaves.add(completer);
    await completer.future;

    activeSaves--;
    completedContents.add(content);
    savedContent = content;
  }

  void completeNext() {
    final completer = _pendingSaves.removeAt(0);
    completer.complete();
  }
}
