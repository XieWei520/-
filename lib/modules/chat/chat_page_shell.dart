import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/config/im_config.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/models/call.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/friend.dart';
import '../../data/models/user.dart';
import '../../data/providers/conversation_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../service/api/group_api.dart';
import '../../service/api/message_api.dart';
import '../../service/api/user_api.dart';
import '../../wukong_uikit/group/group_detail_page.dart';
import '../customer_service/customer_service_badge.dart';
import '../customer_service/customer_service_identity.dart';
import '../search/presentation/chat_search_entry_page.dart';
import '../search/presentation/message_record_search_page.dart';
import '../../widgets/chat_background_surface.dart';
import '../../widgets/liquid_glass_panel.dart';
import '../../widgets/liquid_glass_tokens.dart';
import '../../widgets/wk_colors.dart';
import '../../wukong_robot/models/robot.dart';
import '../../wukong_robot/robot_service.dart';
import '../../wukong_uikit/setting/setting_preferences.dart';
import 'chat_call_navigation.dart';
import 'chat_channel_settings.dart';
import 'chat_flame_message_runtime.dart';
import 'chat_frame_jank_monitor.dart';
import 'chat_conversation_extra_gateway.dart';
import 'panes/chat_composer_pane.dart';
import 'panes/chat_header_pane.dart';
import 'panes/chat_overlay_coordinator.dart';
import 'panes/chat_viewport_pane.dart';
import 'chat_scene_models.dart';
import 'chat_scene_providers.dart';
import 'chat_viewport_controller.dart';
import 'chat_details_page.dart';
import 'forward_message_page.dart';
import 'message_content_preview.dart';
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

const String _androidSystemTeamId = 'u_10000';
const String _androidFileHelperId = 'fileHelper';
const String _fileHelperTitle = '\u6587\u4ef6\u4f20\u8f93\u52a9\u624b';
const String _systemTitle = '\u7cfb\u7edf\u901a\u77e5';
const String _officialTag = '\u5b98\u65b9';
const String _robotTag = '\u673a\u5668\u4eba';
const String _onlineSuffix = '\u5728\u7ebf';
const String _recentMinutesSuffix = '\u5206\u949f';
const String _groupMembersSuffix = '\u4e2a\u6210\u5458';
const String _groupOnlineSuffix = '\u4eba\u5728\u7ebf';
const String _emptyMessageText = '\u6682\u65e0\u6d88\u606f';

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
  ChatViewportPersistenceSnapshot _latestViewportSnapshot =
      const ChatViewportPersistenceSnapshot();
  int _browseTo = 0;
  bool _didPersistConversationExtra = false;
  CancelToken? _remoteFlameCancelToken;
  ConversationActivityState _activityState = ConversationActivityState.empty;
  List<RobotMenu> _robotMenus = const <RobotMenu>[];
  bool _canPinMessages = false;
  bool _canClearPinnedMessages = false;
  List<_ResolvedPinnedMessage> _pinnedMessages =
      const <_ResolvedPinnedMessage>[];
  ChatFrameJankMonitor? _frameJankMonitor;

  ChatSession get _chatSession =>
      ChatSession(channelId: widget.channelId, channelType: widget.channelType);

  @override
  void initState() {
    super.initState();
    _frameJankMonitor = ref.read(chatFrameJankMonitorFactoryProvider)()
      ..start();
    _canPinMessages = _supportsPinnedMessages();
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
    try {
      final extra = await ref
          .read(chatConversationExtraGatewayProvider)
          .load(channelId: widget.channelId, channelType: widget.channelType);
      if (extra == null) {
        return null;
      }
      _browseTo = extra.browseTo;

      final viewportController = ref.read(
        chatViewportProvider(_chatSession).notifier,
      );
      return viewportController.resolveConversationRestoreAnchor(extra);
    } catch (_) {
      return null;
    }
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
    try {
      final menus = await RobotService.instance.syncConversationMenus(
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
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _robotMenus = const <RobotMenu>[];
      });
    }
  }

  Future<void> _hydrateRemoteFlameSettings() async {
    if (!_shouldHydrateRemoteFlameSettings()) {
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

  bool _shouldHydrateRemoteFlameSettings() {
    if (widget.channelType == WKChannelType.group) {
      return true;
    }
    if (widget.channelType != WKChannelType.personal) {
      return false;
    }
    return _androidFixedChatTitle(widget.channelId, widget.channelType) == null;
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
    final channel =
        currentChannel ?? WKChannel(widget.channelId, widget.channelType);
    final cancelToken = _remoteFlameCancelToken = CancelToken();
    try {
      if (widget.channelType == WKChannelType.group) {
        final group = await GroupApi.instance.getGroupInfo(
          widget.channelId,
          cancelToken: cancelToken,
        );
        applyChannelFlameSettings(
          channel,
          flame: group.flame ?? 0,
          flameSecond: group.flameSecond ?? 0,
        );
        if ((group.memberCount ?? 0) > 0) {
          final remoteExtra = mutableChannelExtraMap(channel.remoteExtraMap);
          remoteExtra['member_count'] = group.memberCount ?? 0;
          channel.remoteExtraMap = remoteExtra;
        }
      } else if (widget.channelType == WKChannelType.personal) {
        final user = await UserApi.instance.getUserInfo(
          widget.channelId,
          cancelToken: cancelToken,
        );
        _applyChannelUserIdentity(channel, user);
        applyChannelFlameSettings(
          channel,
          flame: user.flame ?? 0,
          flameSecond: user.flameSecond ?? 0,
        );
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return currentChannel;
      }
      return currentChannel;
    } catch (_) {
      return currentChannel;
    } finally {
      if (identical(_remoteFlameCancelToken, cancelToken)) {
        _remoteFlameCancelToken = null;
      }
    }
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
    return channel;
  }

  void _applyChannelUserIdentity(WKChannel channel, UserInfo user) {
    final displayName = _firstNonEmptyText([
      user.remark,
      user.name,
      user.username,
    ]);
    if (displayName.isNotEmpty && displayName != channel.channelID) {
      channel.channelName = displayName;
    }
    final avatar = (user.avatar ?? '').trim();
    if (avatar.isNotEmpty) {
      channel.avatar = avatar;
    }
    final category = normalizePublicAccountCategory(user.category);
    if (category != null && category.isNotEmpty) {
      channel.category = category;
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

  Future<_PinnedUiSnapshot> _loadPinnedUiSnapshot() async {
    if (!_supportsPinnedMessages()) {
      return const _PinnedUiSnapshot(
        canPin: false,
        canClearAll: false,
        messages: <_ResolvedPinnedMessage>[],
      );
    }

    var canPin = widget.channelType == WKChannelType.personal;
    var canClearAll = false;

    if (widget.channelType == WKChannelType.group) {
      try {
        final group = await GroupApi.instance.getGroupInfo(widget.channelId);
        final canManage = _canManagePinnedMessages(group.role);
        canPin = canManage || (group.allowMemberPinnedMessage ?? 0) == 1;
        canClearAll = canManage;
      } catch (_) {
        final allowMemberPinned = readChannelExtraInt(
          _channel?.remoteExtraMap,
          const ['allow_member_pinned_message'],
        );
        canPin = allowMemberPinned == 1;
        canClearAll = false;
      }
    }

    try {
      final pinnedSnapshot = await ref
          .read(chatSceneGatewayProvider(_chatSession))
          .syncPinnedMessages(
            channelId: widget.channelId,
            channelType: widget.channelType,
            version: 0,
          );
      return _PinnedUiSnapshot(
        canPin: canPin,
        canClearAll: canClearAll,
        messages: _resolvePinnedMessages(pinnedSnapshot),
      );
    } catch (_) {
      return _PinnedUiSnapshot(
        canPin: canPin,
        canClearAll: canClearAll,
        messages: _pinnedMessages,
      );
    }
  }

  List<_ResolvedPinnedMessage> _resolvePinnedMessages(
    PinnedMessageSyncSnapshot snapshot,
  ) {
    final messagesById = <String, WKMsg>{};
    final messagesBySeq = <int, WKMsg>{};
    final payloadsById = <String, dynamic>{};
    final payloadsBySeq = <int, dynamic>{};
    for (final syncMessage in snapshot.messages) {
      final message = syncMessage.getWKMsg();
      final messageId = message.messageID.trim();
      if (messageId.isNotEmpty) {
        messagesById[messageId] = message;
        payloadsById[messageId] = syncMessage.payload;
      }
      if (message.messageSeq > 0) {
        messagesBySeq[message.messageSeq] = message;
        payloadsBySeq[message.messageSeq] = syncMessage.payload;
      }
    }

    final resolved = <_ResolvedPinnedMessage>[];
    for (final entry in snapshot.pinnedMessages) {
      if (entry.isDeleted == 1) {
        continue;
      }
      final message =
          messagesById[entry.messageId] ?? messagesBySeq[entry.messageSeq];
      if (message == null) {
        continue;
      }
      final rawPayload =
          payloadsById[entry.messageId] ?? payloadsBySeq[entry.messageSeq];
      final preview = _resolvePinnedPreviewText(message, rawPayload);
      resolved.add(
        _ResolvedPinnedMessage(
          entry: entry,
          message: message,
          previewText: preview,
        ),
      );
    }

    resolved.sort((a, b) {
      final versionCompare = b.entry.version.compareTo(a.entry.version);
      if (versionCompare != 0) {
        return versionCompare;
      }
      return b.entry.messageSeq.compareTo(a.entry.messageSeq);
    });
    return List<_ResolvedPinnedMessage>.unmodifiable(resolved);
  }

  String _resolvePinnedPreviewText(WKMsg message, dynamic rawPayload) {
    if (rawPayload is Map) {
      final payload = Map<String, dynamic>.from(rawPayload);
      final directText = (payload['content'] ?? payload['text'] ?? '')
          .toString()
          .trim();
      if (directText.isNotEmpty) {
        return directText;
      }
    }
    if (rawPayload is Map || rawPayload is List) {
      final structured = resolveStructuredMessagePreview(
        jsonEncode(rawPayload),
        fallback: _emptyMessageText,
      ).text.trim();
      if (structured.isNotEmpty) {
        return structured;
      }
    }
    final preview = resolveMessagePreview(message).text.trim();
    if (preview.isNotEmpty && preview != _emptyMessageText) {
      return preview;
    }
    return _emptyMessageText;
  }

  bool _canManagePinnedMessages(int? role) {
    return role == 1 || role == 2;
  }

  int _readCurrentUserGroupRole() {
    if (widget.channelType != WKChannelType.group) {
      return 0;
    }
    return readChannelExtraInt(_channel?.remoteExtraMap, const ['role']) ?? 0;
  }

  bool _supportsPinnedMessages() {
    if (widget.channelType == WKChannelType.group) {
      return true;
    }
    if (widget.channelType != WKChannelType.personal) {
      return false;
    }
    return _androidFixedChatTitle(widget.channelId, widget.channelType) == null;
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

  Future<void> _jumpToPinnedMessage(_ResolvedPinnedMessage item) async {
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
    _unbindConversationActivity(
      channelId: oldWidget.channelId,
      channelType: oldWidget.channelType,
    );
    setState(() {
      _robotMenus = const <RobotMenu>[];
    });
    _bindConversationActivity();
    unawaited(_loadRobotMenus(forceRefresh: true));
    setState(() {
      _canPinMessages = _supportsPinnedMessages();
      _canClearPinnedMessages = false;
      _pinnedMessages = const <_ResolvedPinnedMessage>[];
    });
    unawaited(_refreshPinnedUiState());
  }

  @override
  Widget build(BuildContext context) {
    final title = _resolveTitle();
    final headerVipLevel = _resolveHeaderVipLevel(
      ref.watch(
        friendListProvider.select(
          (state) => state.valueOrNull ?? const <Friend>[],
        ),
      ),
    );
    final scene = ref.watch(chatSceneControllerProvider(_chatSession));
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
    final showSearchAction =
        !isMobileWarmStyle || MediaQuery.sizeOf(context).width >= 420;
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
          state: ChatHeaderPaneState(
            title: title,
            subtitle: _primarySubtitle(),
            secondarySubtitle: _secondarySubtitle(),
            avatarUrl: _channel?.avatar,
            vipLevel: headerVipLevel,
            tagWidgets: _buildTags(),
            isGroup: widget.channelType == WKChannelType.group,
            showSearchAction: showSearchAction,
          ),
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
          child: _ChatKeyboardInsetTranslation(
            child: Column(
              children: [
                if (scene.mode == ChatSceneMode.selecting)
                  ChatSelectionToolbar(
                    selectedCount: selection.selectedCount,
                    onCancel: () {
                      ref
                          .read(
                            chatSelectionControllerProvider(
                              _chatSession,
                            ).notifier,
                          )
                          .clear();
                      ref
                          .read(
                            chatSceneControllerProvider(_chatSession).notifier,
                          )
                          .restoreNormal();
                    },
                    onForward: () async {
                      final List<WKMsg> selectedMessages = selection
                          .selectedIdentities
                          .map(
                            (identity) => ref
                                .read(
                                  chatViewportProvider(_chatSession).notifier,
                                )
                                .itemByIdentity(identity)
                                ?.message,
                          )
                          .whereType<WKMsg>()
                          .toList(growable: false);
                      if (selectedMessages.isEmpty) {
                        return;
                      }
                      ref
                          .read(
                            chatMessageActionControllerProvider(
                              _chatSession,
                            ).notifier,
                          )
                          .prepareForward(selectedMessages);
                      final request = ref
                          .read(
                            chatMessageActionControllerProvider(_chatSession),
                          )
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
                              gateway: ref.read(
                                chatSceneGatewayProvider(_chatSession),
                              ),
                            ),
                          ),
                        );
                      } finally {
                        if (mounted) {
                          ref
                              .read(
                                chatMessageActionControllerProvider(
                                  _chatSession,
                                ).notifier,
                              )
                              .clearTransientState();
                        }
                      }
                      if (!mounted) {
                        return;
                      }
                      if (didSubmit == true) {
                        ref
                            .read(
                              chatSelectionControllerProvider(
                                _chatSession,
                              ).notifier,
                            )
                            .clear();
                        ref
                            .read(
                              chatSceneControllerProvider(
                                _chatSession,
                              ).notifier,
                            )
                            .restoreNormal();
                      }
                    },
                  ),
                if (scene.mode != ChatSceneMode.selecting &&
                    activityState.isCalling)
                  ChatCallingParticipantsBar(state: activityState),
                if (scene.mode != ChatSceneMode.selecting &&
                    _pinnedMessages.isNotEmpty)
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
      ),
    );
  }

  void _bindConversationActivity() {
    _activityState = ConversationActivityRegistry.instance.getState(
      widget.channelId,
      widget.channelType,
    );
    ConversationActivityRegistry.instance.addConversationListener(
      widget.channelId,
      widget.channelType,
      _handleConversationActivityChanged,
    );
  }

  void _unbindConversationActivity({String? channelId, int? channelType}) {
    ConversationActivityRegistry.instance.removeConversationListener(
      channelId ?? widget.channelId,
      channelType ?? widget.channelType,
      _handleConversationActivityChanged,
    );
  }

  void _handleConversationActivityChanged() {
    if (!mounted) {
      return;
    }
    final nextState = ConversationActivityRegistry.instance.getState(
      widget.channelId,
      widget.channelType,
    );
    setState(() {
      _activityState = nextState;
    });
  }

  String _resolveTitle() {
    final fixed = _androidFixedChatTitle(widget.channelId, widget.channelType);
    if (fixed != null) {
      return fixed;
    }
    final channelName = _channel?.channelName.trim();
    if (channelName != null && channelName.isNotEmpty) {
      return channelName;
    }
    final inputName = widget.channelName?.trim();
    if (inputName != null && inputName.isNotEmpty) {
      return inputName;
    }
    return widget.channelId;
  }

  WKChannel? _participantFallbackChannel() {
    final loadedChannel = _channel;
    if (loadedChannel != null) {
      return loadedChannel;
    }
    if (widget.channelType != WKChannelType.personal) {
      return null;
    }

    final title = _firstNonEmptyText([
      _androidFixedChatTitle(widget.channelId, widget.channelType),
      widget.channelName,
    ]);
    if (title.isEmpty) {
      return null;
    }
    return WKChannel(widget.channelId, widget.channelType)..channelName = title;
  }

  String _firstNonEmptyText(Iterable<String?> values) {
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  int _resolveHeaderVipLevel(List<Friend> friends) {
    final supportsHeaderVip =
        widget.channelType == WKChannelType.personal ||
        widget.channelType == WKChannelType.customerService;
    if (!supportsHeaderVip) {
      return 0;
    }
    if (_androidFixedChatTitle(widget.channelId, widget.channelType) != null) {
      return 0;
    }
    if (widget.initialVipLevel != 0) {
      return widget.initialVipLevel;
    }

    if (widget.channelType == WKChannelType.personal) {
      final channelId = widget.channelId.trim();
      for (final friend in friends) {
        if (friend.uid.trim() == channelId) {
          return friend.vipLevel;
        }
      }
    }

    return readChannelExtraInt(_channel?.remoteExtraMap, const [
          'vip_level',
          'vipLevel',
        ]) ??
        readChannelExtraInt(_channel?.localExtra, const [
          'vip_level',
          'vipLevel',
        ]) ??
        0;
  }

  bool _showCallActions() {
    if (widget.channelType != WKChannelType.personal) {
      return false;
    }
    return widget.channelId != _androidSystemTeamId &&
        widget.channelId != _androidFileHelperId;
  }

  bool _showGroupCallAction() {
    return widget.channelType == WKChannelType.group;
  }

  List<Widget> _buildTags() {
    final tags = <Widget>[];
    final channelCategory = normalizePublicAccountCategory(_channel?.category);
    final widgetCategory = normalizePublicAccountCategory(
      widget.channelCategory,
    );
    final normalized = (channelCategory?.isNotEmpty ?? false)
        ? channelCategory!
        : widgetCategory;
    if (normalized == 'system') {
      tags.add(const ChatHeaderTag(label: _officialTag));
    }
    if (isCustomerServiceCategory(normalized)) {
      tags.add(
        const CustomerServiceBadge(
          key: ValueKey<String>('chat-header-customer-service-badge'),
          compact: true,
        ),
      );
    }
    if ((_channel?.robot ?? 0) == 1) {
      tags.add(const ChatHeaderTag(label: _robotTag));
    }
    return tags;
  }

  String? _primarySubtitle() {
    if (_channel == null) {
      return null;
    }
    if (widget.channelType == WKChannelType.personal) {
      if (_channel!.online == 1) {
        return '${_deviceLabel(_channel!.deviceFlag)}$_onlineSuffix';
      }
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final lastOffline = _channel!.lastOffline;
      if (lastOffline > 0) {
        final minutes = (nowSeconds - lastOffline) ~/ 60;
        if (minutes > 0 && minutes <= 60) {
          return '$minutes$_recentMinutesSuffix';
        }
      }
      return null;
    }

    if (widget.channelType == WKChannelType.group) {
      final memberCount = _readExtraInt(_channel!.remoteExtraMap, const [
        'memberCount',
        'member_count',
      ]);
      if (memberCount != null && memberCount > 0) {
        return '$memberCount$_groupMembersSuffix';
      }
    }
    return null;
  }

  String? _secondarySubtitle() {
    if (_channel == null || widget.channelType != WKChannelType.group) {
      return null;
    }
    final onlineCount = _readExtraInt(_channel!.remoteExtraMap, const [
      'onlineCount',
      'online_count',
    ]);
    if (onlineCount != null && onlineCount > 0) {
      return '$onlineCount$_groupOnlineSuffix';
    }
    return null;
  }

  static int? _readExtraInt(dynamic map, List<String> keys) {
    if (map is! Map) {
      return null;
    }
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static String _deviceLabel(int deviceFlag) {
    if (deviceFlag == IMConfig.deviceFlagWeb) {
      return 'Web';
    }
    if (deviceFlag == IMConfig.deviceFlagPC) {
      return 'PC';
    }
    return '\u624b\u673a';
  }

  void _handleViewportPersistenceSnapshotChanged(
    ChatViewportPersistenceSnapshot snapshot,
  ) {
    _latestViewportSnapshot = snapshot;
    if (snapshot.maxVisibleMessageSeq > _browseTo) {
      _browseTo = snapshot.maxVisibleMessageSeq;
    }
    widget.onViewportPersistenceChanged?.call(snapshot);
  }

  Future<void> _persistConversationExtra() async {
    if (_didPersistConversationExtra) {
      return;
    }
    _didPersistConversationExtra = true;

    try {
      final composerState = ref.read(chatComposerProvider(_chatSession));
      await ref
          .read(chatConversationExtraGatewayProvider)
          .save(
            channelId: widget.channelId,
            channelType: widget.channelType,
            browseTo: _browseTo > _latestViewportSnapshot.maxVisibleMessageSeq
                ? _browseTo
                : _latestViewportSnapshot.maxVisibleMessageSeq,
            keepMessageSeq: _latestViewportSnapshot.keepMessageSeq,
            keepOffsetY: _latestViewportSnapshot.keepOffsetY,
            draft: composerState.text,
          );
    } catch (_) {
      // Conversation extra persistence is best-effort on exit.
    }
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
    final anchor = ref
        .read(chatViewportProvider(_chatSession).notifier)
        .firstVisibleOrderSeq;
    ref
        .read(chatSearchModeControllerProvider(_chatSession).notifier)
        .open(anchorOrderSeq: anchor);
    ref
        .read(chatSceneControllerProvider(_chatSession).notifier)
        .enterSearchMode(anchorOrderSeq: anchor);
  }

  void _closeSceneSearch() {
    ref.read(chatSearchModeControllerProvider(_chatSession).notifier).close();
    ref
        .read(chatSceneControllerProvider(_chatSession).notifier)
        .restoreNormal();
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

class _PinnedUiSnapshot {
  const _PinnedUiSnapshot({
    required this.canPin,
    required this.canClearAll,
    required this.messages,
  });

  final bool canPin;
  final bool canClearAll;
  final List<_ResolvedPinnedMessage> messages;
}

class _ResolvedPinnedMessage {
  const _ResolvedPinnedMessage({
    required this.entry,
    required this.message,
    required this.previewText,
  });

  final PinnedMessageEntry entry;
  final WKMsg message;
  final String previewText;
}

String? _androidFixedChatTitle(String channelId, int channelType) {
  if (channelType != WKChannelType.personal) {
    return null;
  }
  if (channelId == _androidSystemTeamId) {
    return _systemTitle;
  }
  if (channelId == _androidFileHelperId) {
    return _fileHelperTitle;
  }
  return null;
}
