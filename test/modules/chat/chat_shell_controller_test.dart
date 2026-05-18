import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/repositories/message_repository.dart';
import 'package:wukong_im_app/data/providers/conversation_provider.dart';
import 'package:wukong_im_app/modules/chat/chat_channel_hydration_service.dart';
import 'package:wukong_im_app/modules/chat/chat_conversation_extra_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_pinned_message_state_service.dart';
import 'package:wukong_im_app/modules/chat/chat_robot_menu_state_service.dart';
import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/modules/chat/chat_shell_controller.dart';
import 'package:wukong_im_app/modules/chat/chat_viewport_models.dart';
import 'package:wukong_im_app/modules/chat/message_forwarding.dart';
import 'package:wukong_im_app/service/api/message_api.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads around requested message and exposes restore anchor', () async {
    final repository = _RecordingMessageRepository();
    final controller = _buildController(
      messageRepository: repository,
      args: const ChatShellControllerArgs(
        channelId: 'g_demo',
        channelType: WKChannelType.group,
        initialAroundOrderSeq: 42,
        initialLocateMessageSeq: 7,
      ),
    );
    addTearDown(controller.dispose);

    await controller.loadInitialMessages();

    expect(repository.calls, <String>['around:g_demo:2:42:50']);
    expect(controller.state.restoreAnchor?.aroundOrderSeq, 7000);
  });

  test(
    'refreshes pinned messages and clears them through the gateway',
    () async {
      final clearCalls = <String>[];
      final gateway = _FakeChatSceneGateway(
        pinnedSnapshot: PinnedMessageSyncSnapshot(
          pinnedMessages: <PinnedMessageEntry>[
            _entry(messageId: 'mid-1', messageSeq: 8),
          ],
          messages: <WKSyncMsg>[
            _syncMessage(
              messageId: 'mid-1',
              messageSeq: 8,
              content: 'Pinned message',
            ),
          ],
        ),
        onClearPinnedMessages: ({required channelId, required channelType}) {
          clearCalls.add('$channelType:$channelId');
          return Future<void>.value();
        },
      );
      final controller = _buildController(
        sceneGateway: gateway,
        clearPinnedMessages: gateway.clearPinnedMessages,
        pinnedMessageStateService: ChatPinnedMessageStateService(
          groupInfoLoader: (_) async =>
              throw StateError('use channel fallback policy'),
        ),
        channelStore: ChatChannelStore(
          loadLocalChannel: (_, _) async =>
              WKChannel('g_demo', WKChannelType.group)
                ..remoteExtraMap = <String, dynamic>{
                  'allow_member_pinned_message': 1,
                },
        ),
      );
      addTearDown(controller.dispose);

      await controller.loadChannel();
      await controller.refreshPinnedUiState();

      expect(controller.state.canPinMessages, isTrue);
      expect(controller.state.canClearPinnedMessages, isFalse);
      expect(
        controller.state.pinnedMessages.single.previewText,
        'Pinned message',
      );

      await controller.clearPinnedMessages();

      expect(clearCalls, <String>['2:g_demo']);
    },
  );

  test('records viewport snapshot and persists draft once', () async {
    final gateway = _FakeConversationExtraGateway();
    final controller = _buildController(
      conversationExtraGateway: gateway,
      readCurrentDraft: () => 'draft text',
    );
    addTearDown(controller.dispose);

    controller
      ..updateDraft('draft text')
      ..recordViewportPersistenceSnapshot(
        const ChatViewportPersistenceSnapshot(
          keepMessageSeq: 11,
          keepOffsetY: 120,
          maxVisibleMessageSeq: 35,
        ),
      );

    await controller.persistConversationExtra();
    await controller.persistConversationExtra();

    expect(gateway.saveCalls, hasLength(1));
    expect(gateway.saveCalls.single.browseTo, 35);
    expect(gateway.saveCalls.single.keepMessageSeq, 11);
    expect(gateway.saveCalls.single.keepOffsetY, 120);
    expect(gateway.saveCalls.single.draft, 'draft text');
  });
}

ChatShellController _buildController({
  ChatShellControllerArgs args = const ChatShellControllerArgs(
    channelId: 'g_demo',
    channelType: WKChannelType.group,
  ),
  MessageRepository? messageRepository,
  ChatConversationExtraGateway? conversationExtraGateway,
  ChatSceneGateway? sceneGateway,
  ChatPinnedMessagesClearer? clearPinnedMessages,
  String Function()? readCurrentDraft,
  ChatChannelStore? channelStore,
  ChatChannelHydrationService? channelHydrationService,
  ChatRobotMenuStateService? robotMenuStateService,
  ChatPinnedMessageStateService? pinnedMessageStateService,
}) {
  final gateway = sceneGateway ?? _FakeChatSceneGateway();
  return ChatShellController(
    args: args,
    messageList: MessageListNotifier(
      args.channelId,
      args.channelType,
      messageRepository: messageRepository ?? _RecordingMessageRepository(),
      autoLoad: false,
    ),
    conversationExtraGateway:
        conversationExtraGateway ?? _FakeConversationExtraGateway(),
    sceneGateway: gateway,
    clearPinnedMessages: clearPinnedMessages ?? gateway.clearPinnedMessages,
    readCurrentDraft: readCurrentDraft ?? () => '',
    channelStore: channelStore ?? const ChatChannelStore(),
    channelHydrationService:
        channelHydrationService ??
        ChatChannelHydrationService(
          groupInfoLoader: (_, {cancelToken}) async =>
              throw StateError('unused'),
          userInfoLoader: (_, {cancelToken}) async =>
              throw StateError('unused'),
        ),
    robotMenuStateService:
        robotMenuStateService ??
        ChatRobotMenuStateService(
          loadConversationMenus:
              ({
                required channelId,
                required channelType,
                required forceRefresh,
              }) async {
                return const [];
              },
        ),
    pinnedMessageStateService:
        pinnedMessageStateService ??
        ChatPinnedMessageStateService(
          groupInfoLoader: (_) async => throw StateError('unused'),
        ),
  );
}

class _RecordingMessageRepository implements MessageRepository {
  final List<String> calls = <String>[];

  @override
  Future<List<WKMsg>> loadAround(MessagePageQuery query) async {
    calls.add(
      'around:${query.channelId}:${query.channelType}:${query.anchorOrderSeq}:${query.safeLimit}',
    );
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadLatest(MessagePageQuery query) async {
    calls.add(
      'latest:${query.channelId}:${query.channelType}:${query.safeLimit}',
    );
    return const <WKMsg>[];
  }

  @override
  Future<List<WKMsg>> loadOlder(MessagePageQuery query) async {
    calls.add(
      'older:${query.channelId}:${query.channelType}:${query.anchorOrderSeq}:${query.safeLimit}',
    );
    return const <WKMsg>[];
  }
}

class _FakeConversationExtraGateway implements ChatConversationExtraGateway {
  final List<_SavedConversationExtra> saveCalls = <_SavedConversationExtra>[];

  @override
  Future<WKConversationMsgExtra?> load({
    required String channelId,
    required int channelType,
  }) async {
    return null;
  }

  @override
  Future<void> save({
    required String channelId,
    required int channelType,
    required int browseTo,
    required int keepMessageSeq,
    required int keepOffsetY,
    required String draft,
  }) async {
    saveCalls.add(
      _SavedConversationExtra(
        browseTo: browseTo,
        keepMessageSeq: keepMessageSeq,
        keepOffsetY: keepOffsetY,
        draft: draft,
      ),
    );
  }
}

class _FakeChatSceneGateway extends ChatSceneGateway {
  _FakeChatSceneGateway({
    this.pinnedSnapshot = const PinnedMessageSyncSnapshot(
      pinnedMessages: <PinnedMessageEntry>[],
      messages: <WKSyncMsg>[],
    ),
    this.onClearPinnedMessages,
  });

  final PinnedMessageSyncSnapshot pinnedSnapshot;
  final ChatPinnedMessagesClearer? onClearPinnedMessages;

  @override
  Future<void> addFavorite(WKMsg message) async {}

  @override
  Future<void> editMessage(WKMsg message, WKTextContent content) async {}

  @override
  Future<void> recallMessage(WKMsg message) async {}

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
  Future<List<ForwardTarget>> loadForwardTargets({
    required String excludedChannelId,
    required int excludedChannelType,
  }) async {
    return const <ForwardTarget>[];
  }

  @override
  Future<void> sendForwardPayloads(
    List<ForwardPayload> payloads,
    List<ForwardTarget> targets,
  ) async {}

  @override
  Future<PinnedMessageSyncSnapshot> syncPinnedMessages({
    required String channelId,
    required int channelType,
    int version = 0,
  }) async {
    return pinnedSnapshot;
  }

  @override
  Future<void> clearPinnedMessages({
    required String channelId,
    required int channelType,
  }) async {
    await onClearPinnedMessages?.call(
      channelId: channelId,
      channelType: channelType,
    );
  }
}

class _SavedConversationExtra {
  const _SavedConversationExtra({
    required this.browseTo,
    required this.keepMessageSeq,
    required this.keepOffsetY,
    required this.draft,
  });

  final int browseTo;
  final int keepMessageSeq;
  final int keepOffsetY;
  final String draft;
}

PinnedMessageEntry _entry({
  required String messageId,
  required int messageSeq,
}) {
  return PinnedMessageEntry(
    messageId: messageId,
    messageSeq: messageSeq,
    channelId: 'g_demo',
    channelType: WKChannelType.group,
    isDeleted: 0,
    version: 1,
    createdAt: '2026-04-16T00:00:00Z',
    updatedAt: '2026-04-16T00:00:00Z',
  );
}

WKSyncMsg _syncMessage({
  required String messageId,
  required int messageSeq,
  required String content,
}) {
  return WKSyncMsg()
    ..messageID = messageId
    ..messageSeq = messageSeq
    ..channelID = 'g_demo'
    ..channelType = WKChannelType.group
    ..payload = <String, dynamic>{
      'type': WkMessageContentType.text,
      'content': content,
    };
}
