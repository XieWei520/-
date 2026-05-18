import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/platform_utils.dart';
import '../../data/models/call.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/friend.dart';
import '../../data/providers/conversation_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../wukong_uikit/group/group_detail_page.dart';
import '../search/presentation/chat_search_entry_page.dart';
import '../search/presentation/message_record_search_page.dart';
import '../../widgets/chat_background_surface.dart';
import '../../widgets/liquid_glass_panel.dart';
import '../../widgets/liquid_glass_tokens.dart';
import '../../widgets/wk_colors.dart';
import '../../wukong_robot/models/robot.dart';
import '../../wukong_uikit/setting/setting_preferences.dart';
import 'chat_call_navigation.dart';
import 'chat_channel_hydration_service.dart';
import 'chat_channel_identity.dart';
import 'chat_channel_settings.dart';
import 'chat_conversation_activity_binding.dart';
import 'chat_conversation_restore_service.dart';
import 'chat_flame_message_runtime.dart';
import 'chat_frame_jank_monitor.dart';
import 'chat_conversation_extra_gateway.dart';
import 'chat_pinned_message_resolver.dart';
import 'chat_pinned_message_state_service.dart';
import 'chat_robot_menu_state_service.dart';
import 'chat_search_coordinator.dart';
import 'panes/chat_composer_pane.dart';
import 'panes/chat_header_pane.dart';
import 'panes/chat_overlay_coordinator.dart';
import 'panes/chat_viewport_pane.dart';
import 'chat_scene_providers.dart';
import 'chat_viewport_controller.dart';
import 'chat_details_page.dart';
import 'forward_message_page.dart';
import 'widgets/chat_pinned_message_banner.dart';
import 'widgets/chat_pinned_message_sheet.dart';
import 'widgets/chat_selection_toolbar.dart';
import '../conversation/conversation_activity_registry.dart';
import '../video_call/widgets/chat_calling_participants_bar.dart';

export 'chat_viewport_models.dart'
    show
        ChatViewportPersistenceSnapshot,
        ChatViewportRestoreResult,
        chatListCacheExtent,
        olderMessageLoadExtentAfterThreshold,
        shouldTriggerOlderMessageLoad;
export 'panes/chat_composer_pane.dart'
    show
        buildComposerCallToolbarButtonForTesting,
        buildComposerSendButtonForTesting,
        buildComposerToolbarButtonForTesting,
        buildFunctionItemForTesting;

import 'chat_viewport_models.dart';

@visibleForTesting
bool shouldUseWarmWorkbenchStyle() {
  return PlatformUtils.isWeb || PlatformUtils.isDesktop;
}

SnackBar _buildLiquidSnackBar(String message, {EdgeInsetsGeometry? margin}) {
  return SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: LiquidGlassColors.darkSurfaceSolid,
    margin: margin,
  );
}

@visibleForTesting
Widget buildChatInfoPage({
  required String channelId,
  required int channelType,
  String? channelName,
  VoidCallback? onSearchChatHistory,
}) {
  if (channelType == WKChannelType.group) {
    return GroupDetailPage(channelId: channelId, channelType: channelType);
  }
  return ChatDetailsPage(
    channelId: channelId,
    channelType: channelType,
    channelName: channelName,
    onSearchChatHistory: onSearchChatHistory,
  );
}

class ChatPageShell extends ConsumerStatefulWidget {
  const ChatPageShell({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.channelCategory,
    this.initialVipLevel = 0,
    this.initialAroundOrderSeq,
    this.initialLocateMessageSeq,
    this.flameRuntime,
    this.onViewportBuild,
    this.onViewportPersistenceChanged,
    this.onRestoreAnchorApplied,
  });

  final String channelId;
  final int channelType;
  final String? channelName;
  final String? channelCategory;
  final int initialVipLevel;
  final int? initialAroundOrderSeq;
  final int? initialLocateMessageSeq;
  final ChatFlameMessageRuntime? flameRuntime;
  final VoidCallback? onViewportBuild;
  final ValueChanged<ChatViewportPersistenceSnapshot>?
  onViewportPersistenceChanged;
  final ValueChanged<ChatViewportRestoreResult>? onRestoreAnchorApplied;

  @override
  ConsumerState<ChatPageShell> createState() => _ChatPageShellState();
}

class _ChatPageShellState extends ConsumerState<ChatPageShell> {
  WKChannel? _channel;
  bool _isOpeningCallPage = false;
  ChatViewportRestoreAnchor? _restoreAnchor;
  final ChatConversationRestoreService _conversationRestoreService =
      ChatConversationRestoreService();
  final ChatRobotMenuStateService _robotMenuStateService =
      ChatRobotMenuStateService();
  CancelToken? _remoteFlameCancelToken;
  ChatConversationExtraGateway? _conversationExtraGateway;
  ProviderSubscription<String>? _draftTextSubscription;
  String _latestDraftText = '';
  ConversationActivityState _activityState = ConversationActivityState.empty;
  List<RobotMenu> _robotMenus = const <RobotMenu>[];
  bool _canPinMessages = false;
  bool _canClearPinnedMessages = false;
  List<ResolvedPinnedMessage> _pinnedMessages = const <ResolvedPinnedMessage>[];
  ChatFrameJankMonitor? _frameJankMonitor;
  late final ChatConversationActivityBinding _activityBinding;

  ChatSession get _chatSession =>
      ChatSession(channelId: widget.channelId, channelType: widget.channelType);

  @override
  void initState() {
    super.initState();
    _frameJankMonitor = ref.read(chatFrameJankMonitorFactoryProvider)()
      ..start();
    _activityBinding = ChatConversationActivityBinding(
      onChanged: _handleConversationActivityChanged,
    );
    _bindConversationPersistence();
    _canPinMessages = supportsPinnedMessages(
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
    _bindConversationActivity();
    unawaited(_loadChannel());
    unawaited(_loadRobotMenus());
    unawaited(_refreshPinnedUiState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_hydrateRemoteFlameSettings());
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadInitialMessages());
    });
  }

  Future<void> _loadInitialMessages() async {
    if (!mounted) {
      return;
    }
    final notifier = ref.read(messageListProvider(_chatSession).notifier);
    if (widget.initialAroundOrderSeq != null &&
        widget.initialAroundOrderSeq! > 0) {
      final locateMessageSeq = widget.initialLocateMessageSeq;
      if (locateMessageSeq != null && locateMessageSeq > 0 && mounted) {
        setState(() {
          _restoreAnchor = ChatViewportRestoreAnchor(
            aroundOrderSeq:
                locateMessageSeq * ChatViewportController.orderSeqFactor,
            keepOffsetY: 0,
            browseTo: 0,
          );
        });
      }
      await notifier.loadAroundOrderSeq(widget.initialAroundOrderSeq!);
      return;
    }

    final restoreAnchor = await _resolveConversationRestoreAnchor();
    if (!mounted) {
      return;
    }
    if (restoreAnchor != null) {
      setState(() {
        _restoreAnchor = restoreAnchor;
      });
      await notifier.loadAroundOrderSeq(restoreAnchor.aroundOrderSeq);
      return;
    }
    await notifier.loadMessages();
  }

  Future<ChatViewportRestoreAnchor?> _resolveConversationRestoreAnchor() async {
    final gateway = _conversationExtraGateway;
    if (gateway == null) {
      return null;
    }
    return _conversationRestoreService.resolveRestoreAnchor(
      gateway: gateway,
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
  }

  void _bindConversationPersistence() {
    _conversationExtraGateway = ref.read(chatConversationExtraGatewayProvider);
    _latestDraftText = ref.read(chatComposerProvider(_chatSession)).text;
    _draftTextSubscription?.close();
    _draftTextSubscription = ref.listenManual<String>(
      chatComposerProvider(_chatSession).select((state) => state.text),
      (_, next) {
        _latestDraftText = next;
      },
    );
  }

  Future<void> _loadChannel() async {
    final channel = await _loadLocalChannel();
    if (!mounted || channel == null) {
      return;
    }
    setState(() {
      _channel = channel;
    });
    unawaited(_loadRobotMenus(forceRefresh: true));
  }

  Future<void> _loadRobotMenus({bool forceRefresh = false}) async {
    final menus = await _robotMenuStateService.loadMenus(
      channelId: widget.channelId,
      channelType: widget.channelType,
      forceRefresh: forceRefresh,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _robotMenus = menus;
    });
  }

  Future<void> _hydrateRemoteFlameSettings() async {
    if (!shouldHydrateRemoteFlameSettings(
      channelId: widget.channelId,
      channelType: widget.channelType,
    )) {
      return;
    }
    final currentChannel = _channel ?? await _loadLocalChannel();
    final channel = await _loadRemoteFlameSettings(currentChannel);
    if (!mounted || channel == null) {
      return;
    }
    setState(() {
      _channel = channel;
    });
  }

  Future<WKChannel?> _loadLocalChannel() async {
    WKChannel? channel;
    try {
      channel = await WKIM.shared.channelManager.getChannel(
        widget.channelId,
        widget.channelType,
      );
    } catch (_) {
      // Keep rendering with widget arguments when channel lookup fails.
    }

    return channel;
  }

  Future<WKChannel?> _loadRemoteFlameSettings(WKChannel? currentChannel) async {
    final cancelToken = _remoteFlameCancelToken = CancelToken();
    try {
      final result = await ChatChannelHydrationService().hydrateRemoteChannel(
        channelId: widget.channelId,
        channelType: widget.channelType,
        currentChannel: currentChannel,
        cancelToken: cancelToken,
      );
      if (result.didHydrate && result.channel != null) {
        WKIM.shared.channelManager.addOrUpdateChannel(result.channel!);
      }
      return result.channel;
    } finally {
      if (identical(_remoteFlameCancelToken, cancelToken)) {
        _remoteFlameCancelToken = null;
      }
    }
  }

  Future<void> _refreshPinnedUiState() async {
    final snapshot = await _loadPinnedUiSnapshot();
    if (!mounted) {
      return;
    }
    setState(() {
      _canPinMessages = snapshot.canPin;
      _canClearPinnedMessages = snapshot.canClearAll;
      _pinnedMessages = snapshot.messages;
    });
  }

  Future<ChatPinnedUiSnapshot> _loadPinnedUiSnapshot() {
    return ChatPinnedMessageStateService().loadSnapshot(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channel: _channel,
      syncPinnedMessages: ref
          .read(chatSceneGatewayProvider(_chatSession))
          .syncPinnedMessages,
      previousMessages: _pinnedMessages,
    );
  }

  int _readCurrentUserGroupRole() {
    if (widget.channelType != WKChannelType.group) {
      return 0;
    }
    return readChannelExtraInt(_channel?.remoteExtraMap, const ['role']) ?? 0;
  }

  Future<void> _openPinnedMessageSheet() async {
    if (_pinnedMessages.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ChatPinnedMessageSheet(
        items: _pinnedMessages
            .map(
              (item) => ChatPinnedMessageSheetItemData(
                messageId: item.entry.messageId,
                previewText: item.previewText,
                countLabel: item.message.orderSeq > 0
                    ? '#${item.message.orderSeq}'
                    : '',
              ),
            )
            .toList(growable: false),
        canClearAll: _canClearPinnedMessages,
        onSelected: (item) {
          final matched = _pinnedMessages.firstWhere(
            (candidate) => candidate.entry.messageId == item.messageId,
          );
          unawaited(_jumpToPinnedMessage(matched));
        },
        onClearAll: _canClearPinnedMessages
            ? () => unawaited(_clearPinnedMessages())
            : null,
      ),
    );
  }

  Future<void> _jumpToPinnedMessage(ResolvedPinnedMessage item) async {
    await ref
        .read(messageListProvider(_chatSession).notifier)
        .loadAroundOrderSeq(item.message.orderSeq);
  }

  Future<void> _clearPinnedMessages() async {
    await ref
        .read(chatSceneGatewayProvider(_chatSession))
        .clearPinnedMessages(
          channelId: widget.channelId,
          channelType: widget.channelType,
        );
    await _refreshPinnedUiState();
  }

  void _toggleLocalPinnedState(WKMsg message) {
    final extra = message.wkMsgExtra ??= WKMsgExtra();
    extra.isPinned = extra.isPinned == 1 ? 0 : 1;
  }

  Future<void> _handlePinnedMessageToggled(WKMsg message) async {
    _toggleLocalPinnedState(message);
    await _refreshPinnedUiState();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _frameJankMonitor?.stop();
    _frameJankMonitor = null;
    _unbindConversationActivity();
    _draftTextSubscription?.close();
    _draftTextSubscription = null;
    _remoteFlameCancelToken?.cancel();
    _remoteFlameCancelToken = null;
    unawaited(_persistConversationExtra());
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatPageShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId == widget.channelId &&
        oldWidget.channelType == widget.channelType) {
      return;
    }
    _unbindConversationActivity();
    setState(() {
      _robotMenus = const <RobotMenu>[];
    });
    _bindConversationActivity();
    _bindConversationPersistence();
    unawaited(_loadRobotMenus(forceRefresh: true));
    setState(() {
      _canPinMessages = supportsPinnedMessages(
        channelId: widget.channelId,
        channelType: widget.channelType,
      );
      _canClearPinnedMessages = false;
      _pinnedMessages = const <ResolvedPinnedMessage>[];
    });
    unawaited(_refreshPinnedUiState());
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(
      friendListProvider.select(
        (state) => state.valueOrNull ?? const <Friend>[],
      ),
    );
    final headerState = resolveChatHeaderPaneState(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      channelCategory: widget.channelCategory,
      channel: _channel,
      initialVipLevel: widget.initialVipLevel,
      friends: friends,
      showSearchAction: _showSearchAction(context),
    );
    final selection = ref.watch(chatSelectionControllerProvider(_chatSession));
    final activityState = _activityState;
    final selectedChatBackground =
        WKSettingPreferences.getSelectedChatBackground(
          channelId: widget.channelId,
          channelType: widget.channelType,
        );
    final fallbackBackgroundStyle = WKSettingPreferences.getChatBackgroundStyle(
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
    final useWarmWorkbenchStyle = shouldUseWarmWorkbenchStyle();
    final isMobileWarmStyle =
        PlatformUtils.isMobile && MediaQuery.sizeOf(context).width < 420;
    final useLiquidShell = useWarmWorkbenchStyle;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final liquidBackgroundColor = isDarkTheme
        ? LiquidGlassColors.darkBackground
        : LiquidGlassColors.lightBackground;
    final mobileWarmBackgroundColor = isDarkTheme
        ? LiquidGlassColors.darkBackground
        : LiquidGlassColors.lightBackground;
    final shellBackgroundColor = isMobileWarmStyle
        ? mobileWarmBackgroundColor
        : useLiquidShell
        ? liquidBackgroundColor
        : WKColors.homeBg;

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(_persistConversationExtra());
        }
      },
      child: Scaffold(
        backgroundColor: shellBackgroundColor,
        resizeToAvoidBottomInset: false,
        appBar: ChatHeaderPane(
          session: _chatSession,
          state: headerState,
          productionChrome: true,
          isMobileWarmStyle: isMobileWarmStyle,
          useLiquidShell: useLiquidShell,
          enableIdentityTap:
              widget.channelType != WKChannelType.customerService,
          onBack: () => Navigator.of(context).maybePop(),
          onOpenSearch: _openSceneSearch,
          onSearchKeywordChanged: (value) {
            ref
                .read(chatSearchModeControllerProvider(_chatSession).notifier)
                .updateKeyword(value);
          },
          onSearchSubmitted: (_) => _openChatSearch(),
          onCloseSearch: _closeSceneSearch,
          onOpenDetails: _openChatInfo,
        ),
        body: ChatOverlayCoordinator(
          session: _chatSession,
          background: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (useLiquidShell)
                const LiquidGlassStage(child: SizedBox.expand()),
              ChatBackgroundSurface(
                key: const ValueKey<String>('chat-background-surface'),
                option: selectedChatBackground,
                fallbackStyle: fallbackBackgroundStyle,
                fallbackColor: isMobileWarmStyle
                    ? mobileWarmBackgroundColor
                    : useLiquidShell
                    ? liquidBackgroundColor
                    : null,
              ),
            ],
          ),
          selectionToolbar: ChatSelectionToolbar(
            selectedCount: selection.selectedCount,
            onCancel: () {
              ref
                  .read(chatSelectionControllerProvider(_chatSession).notifier)
                  .clear();
              ref
                  .read(chatSceneControllerProvider(_chatSession).notifier)
                  .restoreNormal();
            },
            onForward: _forwardSelectedMessages,
          ),
          topStatusBars: <Widget>[
            if (activityState.isCalling)
              ChatCallingParticipantsBar(state: activityState),
            if (_pinnedMessages.isNotEmpty)
              ChatPinnedMessageBanner(
                data: ChatPinnedMessageBannerData(
                  previewText: _pinnedMessages.first.previewText,
                  count: _pinnedMessages.length,
                ),
                onTap: _openPinnedMessageSheet,
                onClearAll: _canClearPinnedMessages
                    ? () => unawaited(_clearPinnedMessages())
                    : null,
              ),
          ],
          contentWrapper: (content) =>
              _ChatKeyboardInsetTranslation(child: content),
          child: Column(
            children: [
              Expanded(
                child: ChatViewportPane(
                  session: _chatSession,
                  conversationChannel: _participantFallbackChannel(),
                  canPinMessages: _canPinMessages,
                  currentUserGroupRole: _readCurrentUserGroupRole(),
                  flameRuntime: widget.flameRuntime,
                  onBuild: widget.onViewportBuild,
                  onPinnedMessageToggled: _handlePinnedMessageToggled,
                  restoreAnchor: _restoreAnchor,
                  webStyle: useWarmWorkbenchStyle,
                  onPersistenceSnapshotChanged:
                      _handleViewportPersistenceSnapshotChanged,
                  onRestoreAnchorApplied: widget.onRestoreAnchorApplied,
                ),
              ),
              ChatComposerPane(
                session: _chatSession,
                channel: _channel,
                robotMenus: _robotMenus,
                showCallActions: _showCallActions(),
                showGroupCallAction: _showGroupCallAction(),
                webStyle: useWarmWorkbenchStyle,
                onAudioCallTap: () =>
                    unawaited(_handleCallActionTap(CallType.audio)),
                onVideoCallTap: () =>
                    unawaited(_handleCallActionTap(CallType.video)),
                onGroupCallTap: () => unawaited(_openGroupCallPicker()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _bindConversationActivity() {
    _activityState = _activityBinding.bind(
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
  }

  void _unbindConversationActivity() {
    _activityBinding.unbind();
  }

  void _handleConversationActivityChanged(ConversationActivityState nextState) {
    if (!mounted) {
      return;
    }
    setState(() {
      _activityState = nextState;
    });
  }

  Future<void> _forwardSelectedMessages() async {
    final selection = ref.read(chatSelectionControllerProvider(_chatSession));
    final selectedMessages = selection.selectedIdentities
        .map(
          (identity) => ref
              .read(chatViewportProvider(_chatSession).notifier)
              .itemByIdentity(identity)
              ?.message,
        )
        .whereType<WKMsg>()
        .toList(growable: false);
    if (selectedMessages.isEmpty) {
      return;
    }
    ref
        .read(chatMessageActionControllerProvider(_chatSession).notifier)
        .prepareForward(selectedMessages);
    final request = ref
        .read(chatMessageActionControllerProvider(_chatSession))
        .forwardRequest;
    if (request == null || request.payloads.isEmpty) {
      return;
    }

    bool? didSubmit;
    try {
      didSubmit = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ForwardMessagePage(
            payloads: request.payloads,
            channelId: _chatSession.channelId,
            channelType: _chatSession.channelType,
            gateway: ref.read(chatSceneGatewayProvider(_chatSession)),
          ),
        ),
      );
    } finally {
      if (mounted) {
        ref
            .read(chatMessageActionControllerProvider(_chatSession).notifier)
            .clearTransientState();
      }
    }

    if (!mounted || didSubmit != true) {
      return;
    }
    ref.read(chatSelectionControllerProvider(_chatSession).notifier).clear();
    ref
        .read(chatSceneControllerProvider(_chatSession).notifier)
        .restoreNormal();
  }

  String _resolveTitle() {
    return resolveChatHeaderTitle(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      channel: _channel,
    );
  }

  WKChannel? _participantFallbackChannel() {
    return buildParticipantFallbackChannel(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      loadedChannel: _channel,
    );
  }

  bool _showCallActions() {
    return canShowPersonalCallActions(
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
  }

  bool _showGroupCallAction() {
    return canShowGroupCallAction(widget.channelType);
  }

  bool _showSearchAction(BuildContext context) {
    final isMobileWarmStyle =
        PlatformUtils.isMobile && MediaQuery.sizeOf(context).width < 420;
    return !isMobileWarmStyle || MediaQuery.sizeOf(context).width >= 420;
  }

  void _handleViewportPersistenceSnapshotChanged(
    ChatViewportPersistenceSnapshot snapshot,
  ) {
    _conversationRestoreService.recordViewportSnapshot(snapshot);
    widget.onViewportPersistenceChanged?.call(snapshot);
  }

  Future<void> _persistConversationExtra() async {
    if (_conversationRestoreService.hasPersisted) {
      return;
    }
    final gateway = _conversationExtraGateway;
    if (gateway == null) {
      return;
    }
    await _conversationRestoreService.persist(
      gateway: gateway,
      channelId: widget.channelId,
      channelType: widget.channelType,
      draft: _latestDraftText,
    );
  }

  void _openChatSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatSearchEntryPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
          channelName: _resolveTitle(),
        ),
      ),
    );
  }

  Future<void> _handleCallActionTap(CallType callType) async {
    if (_isOpeningCallPage) {
      return;
    }
    _isOpeningCallPage = true;
    try {
      final decision = await ref
          .read(chatCallEntryServiceProvider)
          .prepareOutgoingCall(
            callType,
            channelId: widget.channelId,
            channelType: widget.channelType,
          );
      if (!mounted) {
        return;
      }
      if (!decision.shouldStart) {
        final feedbackMessage = decision.feedbackMessage?.trim() ?? '';
        if (feedbackMessage.isNotEmpty) {
          _showCallFeedback(feedbackMessage);
        }
        return;
      }
      final decidedCallType = decision.callType ?? callType;
      final callPage = ref.read(chatCallPageBuilderProvider)(
        channelId: widget.channelId,
        channelName: _resolveTitle(),
        callType: decidedCallType,
      );
      final feedbackMessage = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute<String>(builder: (_) => callPage));
      if (!mounted) {
        return;
      }
      final normalizedFeedback = feedbackMessage?.trim() ?? '';
      if (normalizedFeedback.isNotEmpty) {
        _showCallFeedback(normalizedFeedback);
      }
    } finally {
      _isOpeningCallPage = false;
    }
  }

  void _showCallFeedback(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      _buildLiquidSnackBar(
        message,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      ),
    );
  }

  Future<void> _openGroupCallPicker() async {
    if (_isOpeningCallPage) {
      return;
    }
    _isOpeningCallPage = true;
    try {
      await pushGroupCallPicker(
        context: context,
        ref: ref,
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _resolveTitle(),
      );
    } finally {
      _isOpeningCallPage = false;
    }
  }

  Future<void> _openChatInfo() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => buildChatInfoPage(
          channelId: widget.channelId,
          channelType: widget.channelType,
          channelName: _resolveTitle(),
          onSearchChatHistory: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MessageRecordSearchPage(
                  channelId: widget.channelId,
                  channelType: widget.channelType,
                  channelName: _resolveTitle(),
                ),
              ),
            );
          },
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadChannel();
    ref.read(conversationProvider.notifier).refresh();
  }

  void _openSceneSearch() {
    _buildSearchCoordinator().open();
  }

  void _closeSceneSearch() {
    _buildSearchCoordinator().close();
  }

  ChatSearchCoordinator _buildSearchCoordinator() {
    return ChatSearchCoordinator(
      readFirstVisibleOrderSeq: () => ref
          .read(chatViewportProvider(_chatSession).notifier)
          .firstVisibleOrderSeq,
      searchModeController: ref.read(
        chatSearchModeControllerProvider(_chatSession).notifier,
      ),
      sceneController: ref.read(
        chatSceneControllerProvider(_chatSession).notifier,
      ),
    );
  }
}

class _ChatKeyboardInsetTranslation extends StatelessWidget {
  const _ChatKeyboardInsetTranslation({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = PlatformUtils.isMobile
        ? MediaQuery.viewInsetsOf(context).bottom
        : 0.0;
    return Transform.translate(
      key: const ValueKey<String>('chat-keyboard-inset-transform'),
      offset: Offset(0, -keyboardInset),
      child: child,
    );
  }
}
