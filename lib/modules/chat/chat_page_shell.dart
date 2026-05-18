import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

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
import '../../wukong_uikit/setting/setting_preferences.dart';
import 'chat_call_entry_coordinator.dart';
import 'chat_call_navigation.dart';
import 'chat_channel_identity.dart';
import 'chat_flame_message_runtime.dart';
import 'chat_forward_selection_collector.dart';
import 'chat_frame_jank_monitor.dart';
import 'chat_search_coordinator.dart';
import 'chat_shell_controller.dart';
import 'panes/chat_composer_pane.dart';
import 'panes/chat_header_pane.dart';
import 'panes/chat_overlay_coordinator.dart';
import 'panes/chat_viewport_pane.dart';
import 'chat_scene_providers.dart';
import 'chat_details_page.dart';
import 'forward_message_page.dart';
import 'widgets/chat_pinned_message_banner.dart';
import 'widgets/chat_pinned_message_sheet.dart';
import 'widgets/chat_selection_toolbar.dart';
import '../video_call/widgets/chat_calling_participants_bar.dart';

export 'chat_viewport_models.dart'
    show
        ChatViewportPersistenceSnapshot,
        ChatViewportRestoreResult,
        chatListCacheExtent,
        olderMessageLoadExtentAfterThreshold,
        shouldTriggerOlderMessageLoad;
export 'panes/chat_composer_controls.dart'
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
  ChatCallEntryCoordinator? _callEntryCoordinator;
  ChatFrameJankMonitor? _frameJankMonitor;

  ChatSession get _chatSession =>
      ChatSession(channelId: widget.channelId, channelType: widget.channelType);

  ChatShellControllerArgs get _controllerArgs => ChatShellControllerArgs(
    channelId: widget.channelId,
    channelType: widget.channelType,
    initialAroundOrderSeq: widget.initialAroundOrderSeq,
    initialLocateMessageSeq: widget.initialLocateMessageSeq,
  );

  @override
  void initState() {
    super.initState();
    _frameJankMonitor = ref.read(chatFrameJankMonitorFactoryProvider)()
      ..start();
  }

  Future<void> _openPinnedMessageSheet() async {
    final shellState = ref.read(chatShellControllerProvider(_controllerArgs));
    if (shellState.pinnedMessages.isEmpty) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => ChatPinnedMessageSheet(
        items: shellState.pinnedMessages
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
        canClearAll: shellState.canClearPinnedMessages,
        onSelected: (item) {
          final currentState = ref.read(
            chatShellControllerProvider(_controllerArgs),
          );
          final matched = currentState.pinnedMessages.firstWhere(
            (candidate) => candidate.entry.messageId == item.messageId,
          );
          unawaited(
            ref
                .read(chatShellControllerProvider(_controllerArgs).notifier)
                .jumpToPinnedMessage(matched),
          );
        },
        onClearAll: shellState.canClearPinnedMessages
            ? () => unawaited(
                ref
                    .read(chatShellControllerProvider(_controllerArgs).notifier)
                    .clearPinnedMessages(),
              )
            : null,
      ),
    );
  }

  Future<void> _handlePinnedMessageToggled(WKMsg message) async {
    await ref
        .read(chatShellControllerProvider(_controllerArgs).notifier)
        .handlePinnedMessageToggled(message);
  }

  @override
  void dispose() {
    _frameJankMonitor?.stop();
    _frameJankMonitor = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatPageShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId == widget.channelId &&
        oldWidget.channelType == widget.channelType) {
      return;
    }
    ref.read(chatShellControllerProvider(_controllerArgs).notifier).start();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(
      friendListProvider.select(
        (state) => state.valueOrNull ?? const <Friend>[],
      ),
    );
    final shellState = ref.watch(chatShellControllerProvider(_controllerArgs));
    final headerState = resolveChatHeaderPaneState(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      channelCategory: widget.channelCategory,
      channel: shellState.channel,
      initialVipLevel: widget.initialVipLevel,
      friends: friends,
      showSearchAction: _showSearchAction(context),
    );
    final selection = ref.watch(chatSelectionControllerProvider(_chatSession));
    final activityState = shellState.activityState;
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
            if (shellState.pinnedMessages.isNotEmpty)
              ChatPinnedMessageBanner(
                data: ChatPinnedMessageBannerData(
                  previewText: shellState.pinnedMessages.first.previewText,
                  count: shellState.pinnedMessages.length,
                ),
                onTap: _openPinnedMessageSheet,
                onClearAll: shellState.canClearPinnedMessages
                    ? () => unawaited(
                        ref
                            .read(
                              chatShellControllerProvider(
                                _controllerArgs,
                              ).notifier,
                            )
                            .clearPinnedMessages(),
                      )
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
                  canPinMessages: shellState.canPinMessages,
                  currentUserGroupRole: shellState.currentUserGroupRole(
                    channelType: widget.channelType,
                  ),
                  flameRuntime: widget.flameRuntime,
                  onBuild: widget.onViewportBuild,
                  onPinnedMessageToggled: _handlePinnedMessageToggled,
                  restoreAnchor: shellState.restoreAnchor,
                  webStyle: useWarmWorkbenchStyle,
                  onPersistenceSnapshotChanged:
                      _handleViewportPersistenceSnapshotChanged,
                  onRestoreAnchorApplied: widget.onRestoreAnchorApplied,
                ),
              ),
              ChatComposerPane(
                session: _chatSession,
                channel: shellState.channel,
                robotMenus: shellState.robotMenus,
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

  Future<void> _forwardSelectedMessages() async {
    final selection = ref.read(chatSelectionControllerProvider(_chatSession));
    final selectedMessages = _buildForwardSelectionCollector().collect(
      selection.selectedIdentities,
    );
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

  ChatForwardSelectionCollector _buildForwardSelectionCollector() {
    final viewport = ref.read(chatViewportProvider(_chatSession).notifier);
    return ChatForwardSelectionCollector(
      findMessageByIdentity: viewport.itemByIdentity,
    );
  }

  String _resolveTitle() {
    return resolveChatHeaderTitle(
      channelId: widget.channelId,
      channelType: widget.channelType,
      channelName: widget.channelName,
      channel: ref.read(chatShellControllerProvider(_controllerArgs)).channel,
    );
  }

  WKChannel? _participantFallbackChannel() {
    return ref
        .read(chatShellControllerProvider(_controllerArgs))
        .participantFallbackChannel(
          channelId: widget.channelId,
          channelType: widget.channelType,
          channelName: widget.channelName,
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
    ref
        .read(chatShellControllerProvider(_controllerArgs).notifier)
        .recordViewportPersistenceSnapshot(snapshot);
    widget.onViewportPersistenceChanged?.call(snapshot);
  }

  Future<void> _persistConversationExtra() async {
    await ref
        .read(chatShellControllerProvider(_controllerArgs).notifier)
        .persistConversationExtra();
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
    await _buildCallEntryCoordinator().runPersonalCall(
      callType,
      channelId: widget.channelId,
      channelType: widget.channelType,
      handleDecision: (decision) async {
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
      },
    );
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
    await _buildCallEntryCoordinator().runGroupCall(() async {
      await pushGroupCallPicker(
        context: context,
        ref: ref,
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: _resolveTitle(),
      );
    });
  }

  ChatCallEntryCoordinator _buildCallEntryCoordinator() {
    return _callEntryCoordinator ??= ChatCallEntryCoordinator(
      service: ref.read(chatCallEntryServiceProvider),
    );
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
    await ref
        .read(chatShellControllerProvider(_controllerArgs).notifier)
        .loadChannel();
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
