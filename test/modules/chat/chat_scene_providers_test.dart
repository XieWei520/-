import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/modules/chat/chat_message_favorite_registry.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_models.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test(
    'chatSceneControllerProvider builds a normal scene state for a session',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      const session = ChatSession(
        channelId: 'u_provider',
        channelType: WKChannelType.personal,
      );

      final state = container.read(chatSceneControllerProvider(session));

      expect(state.mode, ChatSceneMode.normal);
      expect(state.actionMessageIdentity, isNull);
      expect(state.selectionSeedIdentity, isNull);
      expect(state.searchAnchorOrderSeq, 0);
      expect(state.searchKeyword, isEmpty);
    },
  );

  test(
    'chatMessageActionControllerProvider injects favorite registry snapshot',
    () {
      const preloadedKey = 'mid:preloaded-from-provider';
      const session = ChatSession(
        channelId: 'u_provider_registry',
        channelType: WKChannelType.personal,
      );
      final container = ProviderContainer(
        overrides: [
          chatSceneGatewayProvider.overrideWith(
            (ref, _) => _FakeChatSceneGateway(),
          ),
          chatMessageFavoriteRegistryProvider.overrideWithValue(
            _FakeFavoriteRegistry(seedKeys: <String>{preloadedKey}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(
        chatMessageActionControllerProvider(session),
      );

      expect(state.knownFavoriteKeys, contains(preloadedKey));
    },
  );
}

class _FakeFavoriteRegistry implements ChatMessageFavoriteRegistry {
  _FakeFavoriteRegistry({Set<String> seedKeys = const <String>{}})
    : _keys = <String>{...seedKeys};

  final Set<String> _keys;

  @override
  bool contains(String key) => _keys.contains(key);

  @override
  Future<void> markFavorited(String key) async {
    _keys.add(key);
  }

  @override
  Set<String> snapshot() => Set<String>.unmodifiable(_keys);
}

class _FakeChatSceneGateway extends ChatSceneGateway {
  @override
  Future<void> addFavorite(WKMsg message) async {}

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
  Future<void> recallMessage(WKMsg message) async {}

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<void> sendMessageContent(
    WKMessageContent content, {
    required String channelId,
    required int channelType,
    String? channelName,
  }) async {}

  @override
  Future<void> toggleReaction(WKMsg message, String emoji) async {}

  @override
  List<MessageReaction> prepareReactions(WKMsg message) {
    return const <MessageReaction>[];
  }

  @override
  Stream<ReactionUpdate> watchReactionUpdates() {
    return const Stream<ReactionUpdate>.empty();
  }
}
