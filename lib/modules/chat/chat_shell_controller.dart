import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../data/models/chat_session.dart';
import '../../data/models/friend.dart';
import '../../data/providers/conversation_provider.dart';
import '../../wukong_robot/models/robot.dart';
import '../conversation/conversation_activity_registry.dart';
import 'chat_channel_hydration_service.dart';
import 'chat_channel_identity.dart';
import 'chat_channel_settings.dart';
import 'chat_conversation_activity_binding.dart';
import 'chat_conversation_extra_gateway.dart';
import 'chat_conversation_restore_service.dart';
import 'chat_pinned_message_resolver.dart';
import 'chat_pinned_message_state_service.dart';
import 'chat_robot_menu_state_service.dart';
import 'chat_scene_gateway.dart';
import 'chat_scene_providers.dart';
import 'chat_viewport_controller.dart';
import 'chat_viewport_models.dart';
import 'panes/chat_header_pane.dart';

typedef ChatLocalChannelLoader =
    Future<WKChannel?> Function(String channelId, int channelType);
typedef ChatChannelCacheWriter = void Function(WKChannel channel);
typedef ChatPinnedMessagesClearer =
    Future<void> Function({
      required String channelId,
      required int channelType,
    });

@immutable
class ChatShellControllerArgs {
  const ChatShellControllerArgs({
    required this.channelId,
    required this.channelType,
    this.initialAroundOrderSeq,
    this.initialLocateMessageSeq,
  });

  final String channelId;
  final int channelType;
  final int? initialAroundOrderSeq;
  final int? initialLocateMessageSeq;

  ChatSession get session {
    return ChatSession(channelId: channelId, channelType: channelType);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatShellControllerArgs &&
            other.channelId == channelId &&
            other.channelType == channelType &&
            other.initialAroundOrderSeq == initialAroundOrderSeq &&
            other.initialLocateMessageSeq == initialLocateMessageSeq;
  }

  @override
  int get hashCode {
    return Object.hash(
      channelId,
      channelType,
      initialAroundOrderSeq,
      initialLocateMessageSeq,
    );
  }
}

@immutable
class ChatShellState {
  const ChatShellState({
    this.channel,
    this.restoreAnchor,
    this.activityState = ConversationActivityState.empty,
    this.robotMenus = const <RobotMenu>[],
    this.canPinMessages = false,
    this.canClearPinnedMessages = false,
    this.pinnedMessages = const <ResolvedPinnedMessage>[],
  });

  final WKChannel? channel;
  final ChatViewportRestoreAnchor? restoreAnchor;
  final ConversationActivityState activityState;
  final List<RobotMenu> robotMenus;
  final bool canPinMessages;
  final bool canClearPinnedMessages;
  final List<ResolvedPinnedMessage> pinnedMessages;

  ChatShellState copyWith({
    WKChannel? channel,
    bool clearChannel = false,
    ChatViewportRestoreAnchor? restoreAnchor,
    bool clearRestoreAnchor = false,
    ConversationActivityState? activityState,
    List<RobotMenu>? robotMenus,
    bool? canPinMessages,
    bool? canClearPinnedMessages,
    List<ResolvedPinnedMessage>? pinnedMessages,
  }) {
    return ChatShellState(
      channel: clearChannel ? null : (channel ?? this.channel),
      restoreAnchor: clearRestoreAnchor
          ? null
          : (restoreAnchor ?? this.restoreAnchor),
      activityState: activityState ?? this.activityState,
      robotMenus: robotMenus ?? this.robotMenus,
      canPinMessages: canPinMessages ?? this.canPinMessages,
      canClearPinnedMessages:
          canClearPinnedMessages ?? this.canClearPinnedMessages,
      pinnedMessages: pinnedMessages ?? this.pinnedMessages,
    );
  }

  ChatHeaderPaneState headerState({
    required String channelId,
    required int channelType,
    String? channelName,
    String? channelCategory,
    required int initialVipLevel,
    required List<Friend> friends,
    required bool showSearchAction,
  }) {
    return resolveChatHeaderPaneState(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      channelCategory: channelCategory,
      channel: channel,
      initialVipLevel: initialVipLevel,
      friends: friends,
      showSearchAction: showSearchAction,
    );
  }

  String title({
    required String channelId,
    required int channelType,
    String? channelName,
  }) {
    return resolveChatHeaderTitle(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      channel: channel,
    );
  }

  WKChannel? participantFallbackChannel({
    required String channelId,
    required int channelType,
    String? channelName,
  }) {
    return buildParticipantFallbackChannel(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      loadedChannel: channel,
    );
  }

  int currentUserGroupRole({required int channelType}) {
    if (channelType != WKChannelType.group) {
      return 0;
    }
    return readChannelExtraInt(channel?.remoteExtraMap, const ['role']) ?? 0;
  }
}

class ChatChannelStore {
  const ChatChannelStore({
    ChatLocalChannelLoader? loadLocalChannel,
    ChatChannelCacheWriter? saveChannel,
  }) : _loadLocalChannel = loadLocalChannel,
       _saveChannel = saveChannel;

  final ChatLocalChannelLoader? _loadLocalChannel;
  final ChatChannelCacheWriter? _saveChannel;

  Future<WKChannel?> loadLocal(String channelId, int channelType) async {
    try {
      final loader = _loadLocalChannel;
      if (loader != null) {
        return loader(channelId, channelType);
      }
      return WKIM.shared.channelManager.getChannel(channelId, channelType);
    } catch (_) {
      return null;
    }
  }

  void save(WKChannel channel) {
    final writer = _saveChannel;
    if (writer != null) {
      writer(channel);
      return;
    }
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
  }
}

final chatShellControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatShellController, ChatShellState, ChatShellControllerArgs>((
      ref,
      args,
    ) {
      final session = args.session;
      final gateway = ref.watch(chatSceneGatewayProvider(session));
      final controller = ChatShellController(
        args: args,
        messageList: ref.read(messageListProvider(session).notifier),
        conversationExtraGateway: ref.watch(
          chatConversationExtraGatewayProvider,
        ),
        sceneGateway: gateway,
        clearPinnedMessages: gateway.clearPinnedMessages,
        readCurrentDraft: () => ref.read(chatComposerProvider(session)).text,
        channelStore: ref.watch(chatShellChannelStoreProvider),
        channelHydrationService: ref.watch(
          chatShellChannelHydrationServiceProvider,
        ),
        conversationRestoreService: ref.watch(
          chatShellConversationRestoreServiceProvider,
        ),
        robotMenuStateService: ref.watch(
          chatShellRobotMenuStateServiceProvider,
        ),
        pinnedMessageStateService: ref.watch(
          chatShellPinnedMessageStateServiceProvider,
        ),
      );
      ref.listen<String>(
        chatComposerProvider(session).select((state) => state.text),
        (_, next) => controller.updateDraft(next),
      );
      controller.start();
      return controller;
    });

final chatShellChannelStoreProvider = Provider.autoDispose<ChatChannelStore>((
  ref,
) {
  return const ChatChannelStore();
});

final chatShellChannelHydrationServiceProvider =
    Provider.autoDispose<ChatChannelHydrationService>((ref) {
      return ChatChannelHydrationService();
    });

final chatShellConversationRestoreServiceProvider =
    Provider.autoDispose<ChatConversationRestoreService>((ref) {
      return ChatConversationRestoreService();
    });

final chatShellRobotMenuStateServiceProvider =
    Provider.autoDispose<ChatRobotMenuStateService>((ref) {
      return ChatRobotMenuStateService();
    });

final chatShellPinnedMessageStateServiceProvider =
    Provider.autoDispose<ChatPinnedMessageStateService>((ref) {
      return ChatPinnedMessageStateService();
    });

class ChatShellController extends StateNotifier<ChatShellState> {
  ChatShellController({
    required this.args,
    required MessageListNotifier messageList,
    required ChatConversationExtraGateway conversationExtraGateway,
    required ChatSceneGateway sceneGateway,
    required ChatPinnedMessagesClearer clearPinnedMessages,
    required String Function() readCurrentDraft,
    ChatChannelStore? channelStore,
    ChatChannelHydrationService? channelHydrationService,
    ChatConversationRestoreService? conversationRestoreService,
    ChatRobotMenuStateService? robotMenuStateService,
    ChatPinnedMessageStateService? pinnedMessageStateService,
    ChatConversationActivityBinding? activityBinding,
  }) : _messageList = messageList,
       _conversationExtraGateway = conversationExtraGateway,
       _sceneGateway = sceneGateway,
       _clearPinnedMessages = clearPinnedMessages,
       _readCurrentDraft = readCurrentDraft,
       _channelStore = channelStore ?? const ChatChannelStore(),
       _channelHydrationService =
           channelHydrationService ?? ChatChannelHydrationService(),
       _conversationRestoreService =
           conversationRestoreService ?? ChatConversationRestoreService(),
       _robotMenuStateService =
           robotMenuStateService ?? ChatRobotMenuStateService(),
       _pinnedMessageStateService =
           pinnedMessageStateService ?? ChatPinnedMessageStateService(),
       _activityBinding =
           activityBinding ??
           ChatConversationActivityBinding(onChanged: (_) {}),
       super(
         ChatShellState(
           canPinMessages: supportsPinnedMessages(
             channelId: args.channelId,
             channelType: args.channelType,
           ),
         ),
       ) {
    if (activityBinding == null) {
      _activityBinding = ChatConversationActivityBinding(
        onChanged: _handleConversationActivityChanged,
      );
    }
  }

  final ChatShellControllerArgs args;
  final MessageListNotifier _messageList;
  final ChatConversationExtraGateway _conversationExtraGateway;
  final ChatSceneGateway _sceneGateway;
  final ChatPinnedMessagesClearer _clearPinnedMessages;
  final String Function() _readCurrentDraft;
  final ChatChannelStore _channelStore;
  final ChatChannelHydrationService _channelHydrationService;
  final ChatConversationRestoreService _conversationRestoreService;
  final ChatRobotMenuStateService _robotMenuStateService;
  final ChatPinnedMessageStateService _pinnedMessageStateService;
  late ChatConversationActivityBinding _activityBinding;
  CancelToken? _remoteFlameCancelToken;
  String _latestDraftText = '';
  bool _started = false;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    _latestDraftText = _readCurrentDraft();
    _bindConversationActivity();
    unawaited(loadChannel());
    unawaited(loadRobotMenus());
    unawaited(refreshPinnedUiState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(hydrateRemoteFlameSettings());
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(loadInitialMessages());
      }
    });
  }

  void updateDraft(String draft) {
    _latestDraftText = draft;
  }

  Future<void> loadInitialMessages() async {
    final aroundOrderSeq = args.initialAroundOrderSeq;
    if (aroundOrderSeq != null && aroundOrderSeq > 0) {
      final locateMessageSeq = args.initialLocateMessageSeq;
      if (locateMessageSeq != null && locateMessageSeq > 0 && mounted) {
        state = state.copyWith(
          restoreAnchor: ChatViewportRestoreAnchor(
            aroundOrderSeq:
                locateMessageSeq * ChatViewportController.orderSeqFactor,
            keepOffsetY: 0,
            browseTo: 0,
          ),
        );
      }
      await _messageList.loadAroundOrderSeq(aroundOrderSeq);
      return;
    }

    final restoreAnchor = await _resolveConversationRestoreAnchor();
    if (!mounted) {
      return;
    }
    if (restoreAnchor != null) {
      state = state.copyWith(restoreAnchor: restoreAnchor);
      await _messageList.loadAroundOrderSeq(restoreAnchor.aroundOrderSeq);
      return;
    }
    await _messageList.loadMessages();
  }

  Future<void> loadChannel() async {
    final channel = await _channelStore.loadLocal(
      args.channelId,
      args.channelType,
    );
    if (!mounted || channel == null) {
      return;
    }
    state = state.copyWith(channel: channel);
    unawaited(loadRobotMenus(forceRefresh: true));
  }

  Future<void> loadRobotMenus({bool forceRefresh = false}) async {
    final menus = await _robotMenuStateService.loadMenus(
      channelId: args.channelId,
      channelType: args.channelType,
      forceRefresh: forceRefresh,
    );
    if (!mounted) {
      return;
    }
    state = state.copyWith(robotMenus: menus);
  }

  Future<void> hydrateRemoteFlameSettings() async {
    if (!shouldHydrateRemoteFlameSettings(
      channelId: args.channelId,
      channelType: args.channelType,
    )) {
      return;
    }
    final currentChannel =
        state.channel ??
        await _channelStore.loadLocal(args.channelId, args.channelType);
    final channel = await _loadRemoteFlameSettings(currentChannel);
    if (!mounted || channel == null) {
      return;
    }
    state = state.copyWith(channel: channel);
  }

  Future<void> refreshPinnedUiState() async {
    final snapshot = await _pinnedMessageStateService.loadSnapshot(
      channelId: args.channelId,
      channelType: args.channelType,
      channel: state.channel,
      syncPinnedMessages: _sceneGateway.syncPinnedMessages,
      previousMessages: state.pinnedMessages,
    );
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      canPinMessages: snapshot.canPin,
      canClearPinnedMessages: snapshot.canClearAll,
      pinnedMessages: snapshot.messages,
    );
  }

  Future<void> jumpToPinnedMessage(ResolvedPinnedMessage item) {
    return _messageList.loadAroundOrderSeq(item.message.orderSeq);
  }

  Future<void> clearPinnedMessages() async {
    await _clearPinnedMessages(
      channelId: args.channelId,
      channelType: args.channelType,
    );
    await refreshPinnedUiState();
  }

  Future<void> handlePinnedMessageToggled(WKMsg message) async {
    _toggleLocalPinnedState(message);
    await refreshPinnedUiState();
    if (mounted) {
      state = state.copyWith();
    }
  }

  void recordViewportPersistenceSnapshot(
    ChatViewportPersistenceSnapshot snapshot,
  ) {
    _conversationRestoreService.recordViewportSnapshot(snapshot);
  }

  Future<void> persistConversationExtra() async {
    if (_conversationRestoreService.hasPersisted) {
      return;
    }
    await _conversationRestoreService.persist(
      gateway: _conversationExtraGateway,
      channelId: args.channelId,
      channelType: args.channelType,
      draft: _latestDraftText,
    );
  }

  Future<ChatViewportRestoreAnchor?> _resolveConversationRestoreAnchor() {
    return _conversationRestoreService.resolveRestoreAnchor(
      gateway: _conversationExtraGateway,
      channelId: args.channelId,
      channelType: args.channelType,
    );
  }

  Future<WKChannel?> _loadRemoteFlameSettings(WKChannel? currentChannel) async {
    final cancelToken = _remoteFlameCancelToken = CancelToken();
    try {
      final result = await _channelHydrationService.hydrateRemoteChannel(
        channelId: args.channelId,
        channelType: args.channelType,
        currentChannel: currentChannel,
        cancelToken: cancelToken,
      );
      if (result.didHydrate && result.channel != null) {
        _channelStore.save(result.channel!);
      }
      return result.channel;
    } finally {
      if (identical(_remoteFlameCancelToken, cancelToken)) {
        _remoteFlameCancelToken = null;
      }
    }
  }

  void _bindConversationActivity() {
    final activityState = _activityBinding.bind(
      channelId: args.channelId,
      channelType: args.channelType,
    );
    state = state.copyWith(activityState: activityState);
  }

  void _handleConversationActivityChanged(ConversationActivityState nextState) {
    if (!mounted) {
      return;
    }
    state = state.copyWith(activityState: nextState);
  }

  void _toggleLocalPinnedState(WKMsg message) {
    final extra = message.wkMsgExtra ??= WKMsgExtra();
    extra.isPinned = extra.isPinned == 1 ? 0 : 1;
  }

  @override
  void dispose() {
    _activityBinding.dispose();
    _remoteFlameCancelToken?.cancel();
    _remoteFlameCancelToken = null;
    unawaited(persistConversationExtra());
    super.dispose();
  }
}
