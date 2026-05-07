import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_models.dart';

void main() {
  group('ChatSceneController', () {
    test(
      'enterReplyMode switches to replying and clears action target without leave hooks',
      () {
        var leaveReplyCalls = 0;
        var leaveSelectionCalls = 0;
        var leaveSearchCalls = 0;
        final controller = ChatSceneController(
          onLeaveReplyMode: () => leaveReplyCalls++,
          onLeaveSelectionMode: () => leaveSelectionCalls++,
          onLeaveSearchMode: () => leaveSearchCalls++,
        );
        addTearDown(controller.dispose);

        controller.showActionMenuFor('mid:m1');
        controller.enterReplyMode();

        expect(controller.state.mode, ChatSceneMode.replying);
        expect(controller.state.actionMessageIdentity, isNull);
        expect(leaveReplyCalls, 0);
        expect(leaveSelectionCalls, 0);
        expect(leaveSearchCalls, 0);
      },
    );

    test(
      'enterSelectionMode from replying leaves reply mode first and stores selection seed',
      () {
        final transitions = <String>[];
        late ChatSceneController controller;
        controller = ChatSceneController(
          onLeaveReplyMode: () {
            transitions.add('leave-reply');
            transitions.add('mode-at-leave:${controller.state.mode.name}');
          },
          onLeaveSelectionMode: () => transitions.add('leave-selection'),
          onLeaveSearchMode: () => transitions.add('leave-search'),
        );
        addTearDown(controller.dispose);

        controller.enterReplyMode();
        controller.enterSelectionMode(seedIdentity: 'mid:seed');

        expect(transitions, ['leave-reply', 'mode-at-leave:replying']);
        expect(controller.state.mode, ChatSceneMode.selecting);
        expect(controller.state.selectionSeedIdentity, 'mid:seed');
      },
    );

    test(
      'enterSearchMode stores anchor and keyword then restoreNormal clears search state',
      () {
        final controller = ChatSceneController();
        addTearDown(controller.dispose);

        controller.enterSearchMode(anchorOrderSeq: 88, initialKeyword: 'wk');

        expect(controller.state.mode, ChatSceneMode.searching);
        expect(controller.state.searchAnchorOrderSeq, 88);
        expect(controller.state.searchKeyword, 'wk');

        controller.restoreNormal();

        expect(controller.state.mode, ChatSceneMode.normal);
        expect(controller.state.searchAnchorOrderSeq, 0);
        expect(controller.state.searchKeyword, '');
      },
    );

    test('enterReplyMode clears stale search anchor and keyword', () {
      final controller = ChatSceneController();
      addTearDown(controller.dispose);

      controller.enterSearchMode(anchorOrderSeq: 9, initialKeyword: 'old');
      controller.enterReplyMode();

      expect(controller.state.mode, ChatSceneMode.replying);
      expect(controller.state.searchAnchorOrderSeq, 0);
      expect(controller.state.searchKeyword, '');
    });

    test(
      'enterSelectionMode clears stale search state and enterSearchMode clears selection seed',
      () {
        final controller = ChatSceneController();
        addTearDown(controller.dispose);

        controller.enterSearchMode(anchorOrderSeq: 11, initialKeyword: 'hit');
        controller.enterSelectionMode(seedIdentity: 'mid:seed');

        expect(controller.state.mode, ChatSceneMode.selecting);
        expect(controller.state.selectionSeedIdentity, 'mid:seed');
        expect(controller.state.searchAnchorOrderSeq, 0);
        expect(controller.state.searchKeyword, '');

        controller.enterSearchMode(anchorOrderSeq: 12, initialKeyword: 'next');

        expect(controller.state.mode, ChatSceneMode.searching);
        expect(controller.state.selectionSeedIdentity, isNull);
      },
    );

    test('enterSearchMode from selecting leaves selection mode first', () {
      final transitions = <String>[];
      late ChatSceneController controller;
      controller = ChatSceneController(
        onLeaveSelectionMode: () {
          transitions.add('leave-selection');
          transitions.add('mode-at-leave:${controller.state.mode.name}');
        },
      );
      addTearDown(controller.dispose);

      controller.enterSelectionMode(seedIdentity: 'mid:seed');
      controller.enterSearchMode(anchorOrderSeq: 21, initialKeyword: 'find');

      expect(transitions, ['leave-selection', 'mode-at-leave:selecting']);
      expect(controller.state.mode, ChatSceneMode.searching);
      expect(controller.state.searchAnchorOrderSeq, 21);
    });

    test('restoreNormal from searching leaves search mode first', () {
      final transitions = <String>[];
      late ChatSceneController controller;
      controller = ChatSceneController(
        onLeaveSearchMode: () {
          transitions.add('leave-search');
          transitions.add('mode-at-leave:${controller.state.mode.name}');
        },
      );
      addTearDown(controller.dispose);

      controller.enterSearchMode(anchorOrderSeq: 33, initialKeyword: 'wk');
      controller.restoreNormal();

      expect(transitions, ['leave-search', 'mode-at-leave:searching']);
      expect(controller.state.mode, ChatSceneMode.normal);
    });

    test('restoreNormal from selecting leaves selection mode first', () {
      final transitions = <String>[];
      late ChatSceneController controller;
      controller = ChatSceneController(
        onLeaveSelectionMode: () {
          transitions.add('leave-selection');
          transitions.add('mode-at-leave:${controller.state.mode.name}');
        },
      );
      addTearDown(controller.dispose);

      controller.enterSelectionMode(seedIdentity: 'mid:seed');
      controller.restoreNormal();

      expect(transitions, ['leave-selection', 'mode-at-leave:selecting']);
      expect(controller.state.mode, ChatSceneMode.normal);
    });

    test('same-mode transitions do not fire leave hooks', () {
      final transitions = <String>[];
      final controller = ChatSceneController(
        onLeaveReplyMode: () => transitions.add('leave-reply'),
        onLeaveSelectionMode: () => transitions.add('leave-selection'),
        onLeaveSearchMode: () => transitions.add('leave-search'),
      );
      addTearDown(controller.dispose);

      controller.enterReplyMode();
      controller.enterReplyMode();
      controller.enterSelectionMode(seedIdentity: 'mid:seed');
      controller.enterSelectionMode(seedIdentity: 'mid:next');
      controller.enterSearchMode(anchorOrderSeq: 1, initialKeyword: 'wk');
      controller.enterSearchMode(anchorOrderSeq: 2, initialKeyword: 'wk2');
      controller.restoreNormal();
      controller.restoreNormal();

      expect(transitions, ['leave-reply', 'leave-selection', 'leave-search']);
    });

    test(
      'enterSelectionMode with null seed preserves existing selection seed identity',
      () {
        final controller = ChatSceneController();
        addTearDown(controller.dispose);

        controller.enterSelectionMode(seedIdentity: 'mid:seed');
        controller.enterSelectionMode();

        expect(controller.state.mode, ChatSceneMode.selecting);
        expect(controller.state.selectionSeedIdentity, 'mid:seed');
      },
    );

    test('updateSearchKeyword is a no-op outside searching mode', () {
      final controller = ChatSceneController();
      addTearDown(controller.dispose);

      controller.updateSearchKeyword('ignore-me');
      expect(controller.state.searchKeyword, '');

      controller.enterReplyMode();
      controller.updateSearchKeyword('still-ignore');
      expect(controller.state.searchKeyword, '');
    });

    test('restoreNormal clears action and selection identities', () {
      final controller = ChatSceneController();
      addTearDown(controller.dispose);

      controller.showActionMenuFor('mid:action');
      controller.enterSelectionMode(seedIdentity: 'mid:seed');
      expect(controller.state.actionMessageIdentity, isNull);
      expect(controller.state.selectionSeedIdentity, 'mid:seed');

      controller.restoreNormal();

      expect(controller.state.mode, ChatSceneMode.normal);
      expect(controller.state.actionMessageIdentity, isNull);
      expect(controller.state.selectionSeedIdentity, isNull);
    });
  });
}
