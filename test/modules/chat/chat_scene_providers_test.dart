import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/chat_session.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_message_favorite_registry.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_models.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_providers.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/wukong_base/msg/reaction_manager.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

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

  test(
    'chatSceneGatewayProvider sends normal SDK messages with 30 day retention',
    () async {
      final sentMessages = <_SdkSendCall>[];
      const session = ChatSession(
        channelId: 'u_provider_sdk',
        channelType: WKChannelType.personal,
      );
      final container = ProviderContainer(
        overrides: [
          chatUseDirectWebMessageSendProvider.overrideWithValue(false),
          chatSdkMessageSenderProvider.overrideWithValue((
            content,
            channel,
            options,
          ) {
            sentMessages.add(_SdkSendCall(content, channel, options.expire));
          }),
        ],
      );
      addTearDown(container.dispose);

      final gateway = container.read(chatSceneGatewayProvider(session));

      await gateway.sendMessageContent(
        WKTextContent('provider sdk send'),
        channelId: session.channelId,
        channelType: session.channelType,
      );

      expect(sentMessages, hasLength(1));
      expect(sentMessages.single.content, isA<WKTextContent>());
      expect(sentMessages.single.channel.channelID, session.channelId);
      expect(sentMessages.single.expire, defaultChatMessageRetentionSeconds);
    },
  );

  test(
    'chatSceneGatewayProvider publishes direct web sends into chat and conversation state',
    () async {
      final sentMessages = <WKMsg>[];
      final originalUid = WKIM.shared.options.uid;
      WKIM.shared.options.uid = 'u_me';
      addTearDown(() => WKIM.shared.options.uid = originalUid);
      const session = ChatSession(
        channelId: 'u_provider_web',
        channelType: WKChannelType.personal,
      );
      final container = ProviderContainer(
        overrides: [
          chatUseDirectWebMessageSendProvider.overrideWithValue(true),
          chatOutgoingMessageSenderProvider.overrideWithValue((message) {
            sentMessages.add(message);
          }),
          conversationProvider.overrideWith(
            (ref) => ConversationNotifier(
              attachSdkListeners: false,
              loadInitialConversations: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final gateway = container.read(chatSceneGatewayProvider(session));

      await gateway.sendMessageContent(
        WKTextContent('provider web send'),
        channelId: session.channelId,
        channelType: session.channelType,
      );

      expect(sentMessages, hasLength(1));
      expect(sentMessages.single.content, contains('provider web send'));
      expect(sentMessages.single.expireTime, defaultChatMessageRetentionSeconds);
      expect(
        sentMessages.single.expireTimestamp,
        sentMessages.single.timestamp + defaultChatMessageRetentionSeconds,
      );
      final chatMessages = container.read(messageListProvider(session));
      expect(chatMessages, hasLength(1));
      expect(chatMessages.single.status, WKSendMsgResult.sendSuccess);
      expect(chatMessages.single.clientMsgNO, sentMessages.single.clientMsgNO);
      final conversations = container.read(conversationProvider);
      expect(conversations, hasLength(1));
      expect(conversations.single.channelID, session.channelId);
      expect(conversations.single.unreadCount, 0);
      expect(conversations.single.clientMsgNo, sentMessages.single.clientMsgNO);
    },
  );

  test(
    'chatSceneGatewayProvider publishes direct web media sends into chat state',
    () async {
      final sentMessages = <WKMsg>[];
      final originalUid = WKIM.shared.options.uid;
      WKIM.shared.options.uid = 'u_me';
      addTearDown(() => WKIM.shared.options.uid = originalUid);
      const session = ChatSession(
        channelId: 'u_provider_media',
        channelType: WKChannelType.personal,
      );
      final container = ProviderContainer(
        overrides: [
          chatUseDirectWebMessageSendProvider.overrideWithValue(true),
          chatOutgoingMessageSenderProvider.overrideWithValue((message) {
            sentMessages.add(message);
          }),
          chatSdkMessageSenderProvider.overrideWithValue((
            content,
            channel,
            options,
          ) {
            throw StateError('sdk sender should not be used for web media');
          }),
          conversationProvider.overrideWith(
            (ref) => ConversationNotifier(
              attachSdkListeners: false,
              loadInitialConversations: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final gateway = container.read(chatSceneGatewayProvider(session));
      final content = WKImageContent(320, 240)
        ..url = 'https://infoequity.cn/minio/chat/image.png';

      await gateway.sendMessageContent(
        content,
        channelId: session.channelId,
        channelType: session.channelType,
      );

      expect(sentMessages, hasLength(1));
      expect(sentMessages.single.content, contains('/minio/chat/image.png'));
      final chatMessages = container.read(messageListProvider(session));
      expect(chatMessages, hasLength(1));
      expect(chatMessages.single.status, WKSendMsgResult.sendSuccess);
      expect(chatMessages.single.clientMsgNO, sentMessages.single.clientMsgNO);
      expect(
        container.read(conversationProvider).single.clientMsgNo,
        sentMessages.single.clientMsgNO,
      );
    },
  );

  test(
    'chatSceneGatewayProvider retries failed direct web sends in place',
    () async {
      final sentMessages = <WKMsg>[];
      var failNextSend = true;
      final originalUid = WKIM.shared.options.uid;
      WKIM.shared.options.uid = 'u_me';
      addTearDown(() => WKIM.shared.options.uid = originalUid);
      const session = ChatSession(
        channelId: 'u_provider_web_retry',
        channelType: WKChannelType.personal,
      );
      final container = ProviderContainer(
        overrides: [
          chatUseDirectWebMessageSendProvider.overrideWithValue(true),
          chatOutgoingMessageSenderProvider.overrideWithValue((message) {
            if (failNextSend) {
              throw StateError('offline');
            }
            sentMessages.add(message);
          }),
          conversationProvider.overrideWith(
            (ref) => ConversationNotifier(
              attachSdkListeners: false,
              loadInitialConversations: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final gateway = container.read(chatSceneGatewayProvider(session));

      await expectLater(
        gateway.sendMessageContent(
          WKTextContent('retry web send'),
          channelId: session.channelId,
          channelType: session.channelType,
        ),
        throwsStateError,
      );

      final failedMessage = container.read(messageListProvider(session)).single;
      expect(failedMessage.status, WKSendMsgResult.sendFail);
      final clientMsgNo = failedMessage.clientMsgNO;

      failNextSend = false;
      await gateway.retryMessage(failedMessage);

      expect(sentMessages, hasLength(1));
      expect(sentMessages.single.clientMsgNO, clientMsgNo);
      expect(
        container.read(messageListProvider(session)).single.status,
        WKSendMsgResult.sendSuccess,
      );
      expect(
        container.read(conversationProvider).single.clientMsgNo,
        clientMsgNo,
      );
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
    int? expireSeconds,
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

class _SdkSendCall {
  const _SdkSendCall(this.content, this.channel, this.expire);

  final WKMessageContent content;
  final WKChannel channel;
  final int? expire;
}
