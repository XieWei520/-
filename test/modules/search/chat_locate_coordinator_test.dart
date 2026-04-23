import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/search/application/chat_locate_coordinator.dart';
import 'package:wukong_im_app/modules/search/domain/search_models.dart';

void main() {
  test(
    'ChatLocateCoordinator uses existing orderSeq from ChatLocateIntent without extra lookup',
    () async {
      var resolveCalls = 0;
      final coordinator = ChatLocateCoordinator(
        resolveOrderSeq: ({
          required int messageSeq,
          required String channelId,
          required int channelType,
        }) async {
          resolveCalls += 1;
          return 0;
        },
      );

      const intent = ChatLocateIntent(
        channelId: 'group-1',
        channelType: 2,
        orderSeq: 8000,
        source: 'search-date',
        channelName: 'Project Group',
      );

      final request = await coordinator.buildOpenRequestFromIntent(intent);

      expect(request.orderSeq, 8000);
      expect(request.locateMessageSeq, isNull);
      expect(request.feedbackMessage, isNull);
      expect(resolveCalls, 0);
    },
  );

  test(
    'ChatLocateCoordinator resolves orderSeq from messageSeq when the intent has no anchor',
    () async {
      final coordinator = ChatLocateCoordinator(
        resolveOrderSeq: ({
          required int messageSeq,
          required String channelId,
          required int channelType,
        }) async {
          expect(messageSeq, 77);
          expect(channelId, 'group-1');
          expect(channelType, 2);
          return 9901;
        },
      );

      const intent = ChatLocateIntent(
        channelId: 'group-1',
        channelType: 2,
        messageSeq: 77,
        highlightKeyword: 'keyword',
        source: 'chat-keyword-search',
        channelName: 'Project Group',
      );

      final request = await coordinator.buildOpenRequestFromIntent(intent);

      expect(request.orderSeq, 9901);
      expect(request.locateMessageSeq, 77);
      expect(request.highlightKeyword, 'keyword');
    },
  );

  test(
    'ChatLocateCoordinator falls back to opening the conversation when the intent cannot resolve an anchor',
    () async {
      final coordinator = ChatLocateCoordinator(
        resolveOrderSeq: ({
          required int messageSeq,
          required String channelId,
          required int channelType,
        }) async =>
            0,
      );

      const intent = ChatLocateIntent(
        channelId: 'group-1',
        channelType: 2,
        source: 'search-date',
        channelName: 'Project Group',
      );

      final request = await coordinator.buildOpenRequestFromIntent(intent);

      expect(request.orderSeq, isNull);
      expect(
        request.feedbackMessage,
        'Unable to locate the exact message. Opened the conversation instead.',
      );
    },
  );

  test(
    'ChatLocateCoordinator resolves missing orderSeq and preserves locate metadata',
    () async {
      final coordinator = ChatLocateCoordinator(
        resolveOrderSeq: ({
          required int messageSeq,
          required String channelId,
          required int channelType,
        }) async {
          expect(messageSeq, 77);
          expect(channelId, 'group-1');
          expect(channelType, 2);
          return 9901;
        },
      );

      const hit = SearchMessageHit(
        channelId: 'group-1',
        channelType: 2,
        messageSeq: 77,
        orderSeq: 0,
        timestamp: 1712123456,
        contentType: 1,
        fromUid: 'u-alex',
        fromName: 'Alex',
        previewText: 'keyword appears here',
        channelName: 'Project Group',
      );

      final request = await coordinator.buildOpenRequest(
        hit,
        highlightKeyword: 'keyword',
        source: 'search-results',
      );

      expect(request.channelId, 'group-1');
      expect(request.channelType, 2);
      expect(request.orderSeq, 9901);
      expect(request.locateMessageSeq, 77);
      expect(request.highlightKeyword, 'keyword');
      expect(request.source, 'search-results');
      expect(request.channelName, 'Project Group');
    },
  );
}
