import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_message_action_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_message_favorite_registry.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  group('ChatMessageActionController', () {
    test(
      'favorite delegates to gateway and exposes success feedback',
      () async {
        final gateway = _FakeChatSceneGateway();
        final controller = ChatMessageActionController(
          gateway: gateway,
          favoriteRegistry: _FakeFavoriteRegistry(),
        );
        addTearDown(controller.dispose);
        final message = WKMsg()
          ..messageID = 'mid-1'
          ..clientMsgNO = 'client-1'
          ..channelID = 'g1'
          ..channelType = WKChannelType.group
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('hello');

        await controller.favorite(message);

        expect(gateway.favoriteCalls, <String>['client-1']);
        expect(controller.state.feedbackMessage, '\u5df2\u6536\u85cf');
      },
    );

    test(
      'copy uses edited visible content and exposes Android-style feedback',
      () async {
        final copiedTexts = <String>[];
        final controller = ChatMessageActionController(
          gateway: _FakeChatSceneGateway(),
          favoriteRegistry: _FakeFavoriteRegistry(),
          clipboardSink: (text) async => copiedTexts.add(text),
        );
        addTearDown(controller.dispose);
        final message = WKMsg()
          ..messageID = 'mid-copy'
          ..clientMsgNO = 'client-copy'
          ..channelID = 'u_copy'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('original')
          ..wkMsgExtra = (WKMsgExtra()
            ..contentEdit = '{"type":1,"content":"edited"}'
            ..messageContent = WKTextContent('edited'));

        await controller.copy(message);

        expect(copiedTexts, <String>['edited']);
        expect(controller.state.feedbackMessage, '\u5df2\u590d\u5236');
      },
    );

    test('prepareEdit exposes Android-style edit request from visible text', () {
      final controller = ChatMessageActionController(
        gateway: _FakeChatSceneGateway(),
        favoriteRegistry: _FakeFavoriteRegistry(),
      );
      addTearDown(controller.dispose);
      final message = WKMsg()
        ..messageID = 'mid-edit'
        ..clientMsgNO = 'client-edit'
        ..channelID = 'u_edit'
        ..channelType = WKChannelType.personal
        ..messageSeq = 77
        ..contentType = WkMessageContentType.text
        ..messageContent = WKTextContent('original')
        ..wkMsgExtra = (WKMsgExtra()
          ..contentEdit = '{"type":1,"content":"edited"}'
          ..messageContent = WKTextContent('edited'));

      controller.prepareEdit(message);

      expect(controller.state.editRequest, isNotNull);
      expect(controller.state.editRequest!.messageId, 'mid-edit');
      expect(controller.state.editRequest!.messageSeq, 77);
      expect(controller.state.editRequest!.initialText, 'edited');
    });

    test(
      'favorite suppresses duplicate in-flight requests for the same message',
      () async {
        final completer = Completer<void>();
        final gateway = _FakeChatSceneGateway(
          onFavorite: (message) => completer.future,
        );
        final registry = _FakeFavoriteRegistry();
        final controller = ChatMessageActionController(
          gateway: gateway,
          favoriteRegistry: registry,
        );
        addTearDown(controller.dispose);
        final message = WKMsg()
          ..messageID = 'mid-favorite'
          ..clientMsgNO = 'client-favorite'
          ..channelID = 'u_favorite'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('favorite me');

        final first = controller.favorite(message);
        final second = controller.favorite(message);

        expect(gateway.favoriteCalls, <String>['client-favorite']);
        expect(
          controller.state.busyOperationKeys,
          contains(favoriteMessageKeyOf(message)),
        );

        completer.complete();
        await Future.wait<void>(<Future<void>>[first, second]);

        final key = favoriteMessageKeyOf(message);
        expect(controller.state.busyOperationKeys, isEmpty);
        expect(controller.state.knownFavoriteKeys, contains(key));
        expect(registry.savedKeys, contains(key));
      },
    );

    test(
      'state is preloaded from favorite registry snapshot at construction time',
      () {
        final message = WKMsg()
          ..messageID = 'mid-preloaded'
          ..clientMsgNO = 'client-preloaded';
        final preloadedKey = favoriteMessageKeyOf(message);
        final controller = ChatMessageActionController(
          gateway: _FakeChatSceneGateway(),
          favoriteRegistry: _FakeFavoriteRegistry(
            seedKeys: <String>{preloadedKey},
          ),
        );
        addTearDown(controller.dispose);

        expect(controller.state.knownFavoriteKeys, contains(preloadedKey));
      },
    );

    test(
      'favorite uses restored registry state to skip duplicate post after re-entry',
      () async {
        final gateway = _FakeChatSceneGateway();
        final message = WKMsg()
          ..messageID = 'mid-known'
          ..clientMsgNO = 'client-known'
          ..channelID = 'u_known'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('already favorited');
        final registry = _FakeFavoriteRegistry(
          seedKeys: <String>{favoriteMessageKeyOf(message)},
        );
        final controller = ChatMessageActionController(
          gateway: gateway,
          favoriteRegistry: registry,
        );
        addTearDown(controller.dispose);

        await controller.favorite(message);

        expect(gateway.favoriteCalls, isEmpty);
        expect(controller.state.feedbackMessage, '\u5df2\u6536\u85cf');
      },
    );

    test(
      'favorite keeps dedup when known favorite upgrades from client key to message key',
      () async {
        const clientMsgNo = 'client-upgrade';
        const messageId = 'mid-upgrade';
        final gateway = _FakeChatSceneGateway();
        final registry = _FakeFavoriteRegistry(
          seedKeys: <String>{'cid:$clientMsgNo'},
        );
        final controller = ChatMessageActionController(
          gateway: gateway,
          favoriteRegistry: registry,
        );
        addTearDown(controller.dispose);
        final refreshed = WKMsg()
          ..messageID = messageId
          ..clientMsgNO = clientMsgNo
          ..channelID = 'u_upgrade'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('upgraded identity');

        await controller.favorite(refreshed);

        expect(gateway.favoriteCalls, isEmpty);
        expect(
          controller.state.knownFavoriteKeys,
          contains('cid:$clientMsgNo'),
        );
        expect(controller.state.knownFavoriteKeys, contains('mid:$messageId'));
      },
    );

    test(
      'favorite preserves restored dedup after client-to-server identity upgrade and re-entry',
      () async {
        const clientMsgNo = 'client-reentry-upgrade';
        const messageId = 'mid-reentry-upgrade';
        final firstGateway = _FakeChatSceneGateway();
        final registry = _FakeFavoriteRegistry(
          seedKeys: <String>{'cid:$clientMsgNo'},
        );
        final firstController = ChatMessageActionController(
          gateway: firstGateway,
          favoriteRegistry: registry,
        );
        addTearDown(firstController.dispose);
        final bridgedMessage = WKMsg()
          ..messageID = messageId
          ..clientMsgNO = clientMsgNo
          ..channelID = 'u_reentry_upgrade'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('bridge keys');

        await firstController.favorite(bridgedMessage);

        expect(firstGateway.favoriteCalls, isEmpty);
        expect(registry.savedKeys, contains('mid:$messageId'));

        final secondGateway = _FakeChatSceneGateway();
        final secondController = ChatMessageActionController(
          gateway: secondGateway,
          favoriteRegistry: registry,
        );
        addTearDown(secondController.dispose);
        final serverOnlyMessage = WKMsg()
          ..messageID = messageId
          ..clientMsgNO = ''
          ..channelID = 'u_reentry_upgrade'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('server only');

        await secondController.favorite(serverOnlyMessage);

        expect(secondGateway.favoriteCalls, isEmpty);
      },
    );

    test(
      'favorite failure clears busy state and does not persist fake favorite state',
      () async {
        final gateway = _FakeChatSceneGateway(
          onFavorite: (message) async => throw Exception('favorite failed'),
        );
        final registry = _FakeFavoriteRegistry();
        final controller = ChatMessageActionController(
          gateway: gateway,
          favoriteRegistry: registry,
        );
        addTearDown(controller.dispose);
        final message = WKMsg()
          ..messageID = 'mid-failed'
          ..clientMsgNO = 'client-failed'
          ..channelID = 'u_failed'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('favorite failure');

        await expectLater(controller.favorite(message), throwsException);

        expect(controller.state.busyOperationKeys, isEmpty);
        expect(
          controller.state.knownFavoriteKeys,
          isNot(contains(favoriteMessageKeyOf(message))),
        );
        expect(controller.state.feedbackMessage, '\u6536\u85cf\u5931\u8d25');
        expect(registry.savedKeys, isEmpty);
      },
    );

    test(
      'favorite fails fast for unsupported messages without a stable key',
      () async {
        final gateway = _FakeChatSceneGateway();
        final registry = _FakeFavoriteRegistry();
        final controller = ChatMessageActionController(
          gateway: gateway,
          favoriteRegistry: registry,
        );
        addTearDown(controller.dispose);
        final unsupported = WKMsg()
          ..messageID = ''
          ..clientMsgNO = ''
          ..channelID = 'u_unsupported'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('cannot key');

        await expectLater(
          controller.favorite(unsupported),
          throwsA(isA<UnsupportedError>()),
        );

        expect(gateway.favoriteCalls, isEmpty);
        expect(controller.state.busyOperationKeys, isEmpty);
        expect(controller.state.knownFavoriteKeys, isEmpty);
        expect(controller.state.feedbackMessage, '\u6536\u85cf\u5931\u8d25');
      },
    );

    test(
      'prepareForward ignores unsupported messages and keeps supported payloads',
      () {
        final controller = ChatMessageActionController(
          gateway: _FakeChatSceneGateway(),
        );
        addTearDown(controller.dispose);
        final supported = WKMsg()
          ..messageID = 'mid-2'
          ..clientMsgNO = 'client-2'
          ..channelID = 'u2'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.text
          ..messageContent = WKTextContent('forward me');
        final unsupported = WKMsg()
          ..messageID = 'mid-3'
          ..clientMsgNO = 'client-3'
          ..channelID = 'u2'
          ..channelType = WKChannelType.personal
          ..contentType = WkMessageContentType.unknown;

        controller.prepareForward(<WKMsg>[supported, unsupported]);

        expect(controller.state.forwardRequest, isNotNull);
        expect(controller.state.forwardRequest!.payloads, hasLength(1));
        expect(
          controller.state.forwardRequest!.payloads.single.clientMsgNo,
          'client-2',
        );
      },
    );

    test('recall tracks busy state and exposes success feedback', () async {
      final completer = Completer<void>();
      final gateway = _FakeChatSceneGateway(
        onRecall: (message) => completer.future,
      );
      final controller = ChatMessageActionController(gateway: gateway);
      addTearDown(controller.dispose);
      final message = WKMsg()
        ..messageID = 'mid-recall'
        ..clientMsgNO = 'client-recall';

      final recallFuture = controller.recall(message);

      expect(gateway.recallCalls, <String>['client-recall']);
      expect(controller.state.busyOperationKeys, contains('mid-recall'));

      completer.complete();
      await recallFuture;

      expect(controller.state.busyOperationKeys, isEmpty);
      expect(controller.state.feedbackMessage, '\u5df2\u64a4\u56de');
    });

    test(
      'recall ignores duplicate in-flight requests for the same message',
      () async {
        final completer = Completer<void>();
        final gateway = _FakeChatSceneGateway(
          onRecall: (message) => completer.future,
        );
        final controller = ChatMessageActionController(gateway: gateway);
        addTearDown(controller.dispose);
        final message = WKMsg()
          ..messageID = 'mid-recall'
          ..clientMsgNO = 'client-recall';

        final firstRecall = controller.recall(message);
        final secondRecall = controller.recall(message);

        expect(gateway.recallCalls, <String>['client-recall']);
        expect(controller.state.busyOperationKeys, contains('mid-recall'));

        completer.complete();
        await Future.wait<void>(<Future<void>>[firstRecall, secondRecall]);

        expect(controller.state.busyOperationKeys, isEmpty);
      },
    );

    test(
      'toggleReaction delegates to gateway and exposes success feedback',
      () async {
        final gateway = _FakeChatSceneGateway();
        final controller = ChatMessageActionController(gateway: gateway);
        addTearDown(controller.dispose);
        final message = WKMsg()
          ..messageID = 'mid-reaction'
          ..clientMsgNO = 'client-reaction';

        await controller.toggleReaction(message, '👍');

        expect(gateway.reactionCalls, <String>['mid-reaction:👍']);
        expect(
          controller.state.feedbackMessage,
          '\u5df2\u66f4\u65b0\u8868\u60c5\u56de\u5e94',
        );
      },
    );

    test('delete delegates to gateway and exposes success feedback', () async {
      final gateway = _FakeChatSceneGateway();
      final controller = ChatMessageActionController(gateway: gateway);
      addTearDown(controller.dispose);
      final message = WKMsg()
        ..messageID = 'mid-delete'
        ..clientMsgNO = 'client-delete';

      await controller.deleteMessage(message);

      expect(gateway.deleteCalls, <String>['client-delete']);
      expect(controller.state.feedbackMessage, '\u5df2\u5220\u9664');
    });

    test(
      'forward request defensively copies payloads and keeps them unmodifiable',
      () {
        final payloads = <ForwardPayload>[
          ForwardPayload(
            clientMsgNo: 'client-immutable',
            content: WKTextContent('hello'),
          ),
        ];
        final request = ChatForwardRequest(payloads: payloads);

        payloads.add(
          ForwardPayload(
            clientMsgNo: 'client-extra',
            content: WKTextContent('mutated'),
          ),
        );

        expect(request.payloads, hasLength(1));
        expect(
          () => request.payloads.add(
            ForwardPayload(
              clientMsgNo: 'client-throw',
              content: WKTextContent('throw'),
            ),
          ),
          throwsUnsupportedError,
        );
      },
    );

    test(
      'action state defensively copies busy operation keys and keeps them unmodifiable',
      () {
        final busyIds = <String>{'mid-1'};
        final state = ChatMessageActionState(busyOperationKeys: busyIds);

        busyIds.add('mid-2');

        expect(state.busyOperationKeys, <String>{'mid-1'});
        expect(
          () => state.busyOperationKeys.add('mid-3'),
          throwsUnsupportedError,
        );
      },
    );
  });
}

class _FakeChatSceneGateway extends ChatSceneGateway {
  _FakeChatSceneGateway({this.onRecall, this.onFavorite});

  final List<String> favoriteCalls = <String>[];
  final List<String> recallCalls = <String>[];
  final List<String> reactionCalls = <String>[];
  final List<String> deleteCalls = <String>[];
  final Future<void> Function(WKMsg message)? onRecall;
  final Future<void> Function(WKMsg message)? onFavorite;

  @override
  Future<void> addFavorite(WKMsg message) async {
    favoriteCalls.add(message.clientMsgNO);
    await onFavorite?.call(message);
  }

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {}

  @override
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  Future<void> recallMessage(WKMsg message) async {
    recallCalls.add(message.clientMsgNO);
    await onRecall?.call(message);
  }

  @override
  Future<void> deleteSelfMessage(WKMsg message) async {
    deleteCalls.add(message.clientMsgNO);
  }

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {
    reactionCalls.add('${message.messageID}:$emoji');
  }

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return const <MessageReaction>[];
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() {
    return const Stream<ReactionUpdate>.empty();
  }
}

class _FakeFavoriteRegistry implements ChatMessageFavoriteRegistry {
  _FakeFavoriteRegistry({Set<String> seedKeys = const <String>{}})
    : _keys = {...seedKeys};

  final Set<String> _keys;
  Set<String> get savedKeys => Set<String>.unmodifiable(_keys);

  @override
  bool contains(String key) => _keys.contains(key);

  @override
  Future<void> markFavorited(String key) async {
    _keys.add(key);
  }

  @override
  Set<String> snapshot() => Set<String>.unmodifiable(_keys);
}
