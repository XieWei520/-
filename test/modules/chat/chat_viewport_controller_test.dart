import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/chat_viewport_controller.dart';
import 'package:wukong_im_app/modules/conversation/chat_timeline_controller.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatViewportController', () {
    test('inserts new messages without rebuilding unrelated identities', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final first = WKMsg()
        ..messageID = 'm1'
        ..contentType = WkMessageContentType.text;
      final second = WKMsg()
        ..messageID = 'm2'
        ..contentType = WkMessageContentType.text;

      controller.replaceAll([first]);
      controller.applyIncoming([second]);

      expect(controller.state.items.map((item) => item.identity).toList(), [
        'mid:m2',
        'mid:m1',
      ]);
    });

    test('patches existing message in place when refresh arrives', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final pending = WKMsg()
        ..clientMsgNO = 'c1'
        ..status = WKSendMsgResult.sendLoading
        ..contentType = WkMessageContentType.text;
      final delivered = WKMsg()
        ..clientMsgNO = 'c1'
        ..messageID = 'm1'
        ..status = WKSendMsgResult.sendSuccess
        ..contentType = WkMessageContentType.text;

      controller.replaceAll([pending]);
      controller.applyRefresh(delivered);

      expect(controller.state.items.single.identity, 'mid:m1');
      expect(
        controller.state.items.single.message.status,
        WKSendMsgResult.sendSuccess,
      );
    });

    test('patches by sequence keys when identity changes on refresh', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final pending = WKMsg()
        ..channelID = 'c1'
        ..channelType = 1
        ..orderSeq = 9
        ..messageSeq = 10
        ..status = WKSendMsgResult.sendLoading
        ..contentType = WkMessageContentType.text;
      final delivered = WKMsg()
        ..channelID = 'c1'
        ..channelType = 1
        ..orderSeq = 9
        ..messageSeq = 10
        ..messageID = 'm1'
        ..status = WKSendMsgResult.sendSuccess
        ..contentType = WkMessageContentType.text;

      controller.replaceAll([pending]);
      controller.applyRefresh(delivered);

      expect(controller.state.items, hasLength(1));
      expect(controller.state.items.single.identity, 'mid:m1');
      expect(
        controller.state.items.single.message.status,
        WKSendMsgResult.sendSuccess,
      );
    });

    test('firstVisibleOrderSeq returns the first rendered order sequence', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final first = WKMsg()
        ..messageID = 'm1'
        ..orderSeq = 11
        ..contentType = WkMessageContentType.text;
      final second = WKMsg()
        ..messageID = 'm2'
        ..orderSeq = 12
        ..contentType = WkMessageContentType.text;

      controller.replaceAll(<WKMsg>[first, second]);

      expect(controller.firstVisibleOrderSeq, 11);
    });

    test('itemByIdentity returns the mapped viewport model', () {
      final controller = ChatViewportController(
        mapper: ChatMessageMapper(),
        currentUid: 'u_self',
      );
      final first = WKMsg()
        ..messageID = 'm1'
        ..orderSeq = 11
        ..contentType = WkMessageContentType.text;

      controller.replaceAll(<WKMsg>[first]);

      expect(controller.itemByIdentity('mid:m1')?.identity, 'mid:m1');
      expect(controller.itemByIdentity('mid:missing'), isNull);
    });

    test(
      'resolves Android conversation restore anchor from keepMessageSeq and keepOffsetY',
      () {
        final dynamic controller = ChatViewportController(
          mapper: ChatMessageMapper(),
          currentUid: 'u_self',
        );
        final extra = WKConversationMsgExtra()
          ..browseTo = 1
          ..keepMessageSeq = 88
          ..keepOffsetY = 420;

        final dynamic anchor = controller.resolveConversationRestoreAnchor(
          extra,
        );

        expect(anchor, isNotNull);
        expect(anchor.aroundOrderSeq, 88000);
        expect(anchor.keepOffsetY, 420);
        expect(anchor.browseTo, 1);
      },
    );
  });

  group('ChatTimelineController', () {
    test(
      'appends older page items to tail without remapping existing items',
      () {
        final controller = ChatTimelineController(
          mapper: ChatMessageMapper(),
          currentUid: 'u_self',
        );
        final newest = WKMsg()
          ..messageID = 'm2'
          ..orderSeq = 12
          ..contentType = WkMessageContentType.text;
        final older = WKMsg()
          ..messageID = 'm1'
          ..orderSeq = 11
          ..contentType = WkMessageContentType.text;
        final oldest = WKMsg()
          ..messageID = 'm0'
          ..orderSeq = 10
          ..contentType = WkMessageContentType.text;

        controller.replaceAll(<WKMsg>[newest, older]);
        final beforeNewestModel = controller.state.items.first;

        controller.appendOlder(<WKMsg>[oldest]);

        expect(controller.state.items.map((item) => item.identity).toList(), [
          'mid:m2',
          'mid:m1',
          'mid:m0',
        ]);
        expect(
          identical(controller.state.items.first, beforeNewestModel),
          isTrue,
        );
      },
    );
  });

  group('ChatViewport bridge decision', () {
    test('classifies appended older-page messages for incremental append', () {
      final previous = [
        WKMsg()
          ..messageID = 'm3'
          ..contentType = WkMessageContentType.text,
        WKMsg()
          ..messageID = 'm2'
          ..contentType = WkMessageContentType.text,
      ];
      final next = [
        WKMsg()
          ..messageID = 'm3'
          ..contentType = WkMessageContentType.text,
        WKMsg()
          ..messageID = 'm2'
          ..contentType = WkMessageContentType.text,
        WKMsg()
          ..messageID = 'm1'
          ..contentType = WkMessageContentType.text,
      ];

      final decision = decideChatTimelineSync(
        previous: previous,
        next: next,
        initial: false,
      );

      expect(decision.mode, ChatTimelineSyncMode.olderPage);
      expect(decision.olderPage.map((item) => item.messageID).toList(), ['m1']);
      expect(decision.incoming, isEmpty);
      expect(decision.refreshed, isNull);
    });

    test('falls back to replaceAll for mixed prepend and shifted refresh', () {
      final previous = [
        WKMsg()
          ..clientMsgNO = 'c1'
          ..status = WKSendMsgResult.sendLoading
          ..contentType = WkMessageContentType.text,
        WKMsg()
          ..messageID = 'old'
          ..status = WKSendMsgResult.sendSuccess
          ..contentType = WkMessageContentType.text,
      ];
      final next = [
        WKMsg()
          ..messageID = 'new'
          ..status = WKSendMsgResult.sendSuccess
          ..contentType = WkMessageContentType.text,
        WKMsg()
          ..clientMsgNO = 'c1'
          ..messageID = 'm1'
          ..status = WKSendMsgResult.sendSuccess
          ..contentType = WkMessageContentType.text,
        WKMsg()
          ..messageID = 'old'
          ..status = WKSendMsgResult.sendSuccess
          ..contentType = WkMessageContentType.text,
      ];

      final decision = decideChatTimelineSync(
        previous: previous,
        next: next,
        initial: false,
      );

      expect(decision.mode, ChatTimelineSyncMode.replaceAll);
      expect(decision.incoming, isEmpty);
      expect(decision.refreshed, isNull);
    });

    test('classifies metadata-only localExtraMap update as refresh', () {
      final previous = [
        WKMsg()
          ..messageID = 'm1'
          ..contentType = WkMessageContentType.text
          ..localExtraMap = {'key': 'v1'},
      ];
      final next = [
        WKMsg()
          ..messageID = 'm1'
          ..contentType = WkMessageContentType.text
          ..localExtraMap = {'key': 'v2'},
      ];

      final decision = decideChatTimelineSync(
        previous: previous,
        next: next,
        initial: false,
      );

      expect(decision.mode, ChatTimelineSyncMode.refresh);
      expect(decision.refreshed, isNotNull);
      expect(decision.refreshed!.messageID, 'm1');
    });

    test('classifies wkMsgExtra read-count update as refresh', () {
      final previousExtra = WKMsgExtra()..readedCount = 1;
      final nextExtra = WKMsgExtra()..readedCount = 2;
      final previous = [
        WKMsg()
          ..messageID = 'm1'
          ..contentType = WkMessageContentType.text
          ..wkMsgExtra = previousExtra,
      ];
      final next = [
        WKMsg()
          ..messageID = 'm1'
          ..contentType = WkMessageContentType.text
          ..wkMsgExtra = nextExtra,
      ];

      final decision = decideChatTimelineSync(
        previous: previous,
        next: next,
        initial: false,
      );

      expect(decision.mode, ChatTimelineSyncMode.refresh);
      expect(decision.refreshed, isNotNull);
      expect(decision.refreshed!.messageID, 'm1');
    });

    test('classifies reaction content update with same length as refresh', () {
      final previousReaction = WKMsgReaction()
        ..uid = 'u1'
        ..emoji = 'emoji_old'
        ..seq = 1;
      final nextReaction = WKMsgReaction()
        ..uid = 'u1'
        ..emoji = 'emoji_new'
        ..seq = 1;
      final previous = [
        WKMsg()
          ..messageID = 'm1'
          ..contentType = WkMessageContentType.text
          ..reactionList = [previousReaction],
      ];
      final next = [
        WKMsg()
          ..messageID = 'm1'
          ..contentType = WkMessageContentType.text
          ..reactionList = [nextReaction],
      ];

      final decision = decideChatTimelineSync(
        previous: previous,
        next: next,
        initial: false,
      );

      expect(decision.mode, ChatTimelineSyncMode.refresh);
      expect(decision.refreshed, isNotNull);
      expect(decision.refreshed!.messageID, 'm1');
    });
  });
}
