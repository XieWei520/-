import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_gif_content.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_sticker_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/config/api_config.dart';
import '../../core/config/im_config.dart';
import '../../core/motion/chat_motion.dart';
import '../../core/utils/platform_utils.dart';
import '../../data/models/call.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/friend.dart';
import '../../data/models/group.dart';
import '../../data/models/user.dart';
import '../../data/models/wk_custom_content.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/conversation_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../service/api/group_api.dart';
import '../../service/api/message_api.dart';
import '../../service/api/robot_api.dart';
import '../../service/api/user_api.dart';
import '../../wukong_uikit/group/group_detail_page.dart';
import '../../wukong_uikit/user/user_detail_page.dart';
import '../customer_service/customer_service_badge.dart';
import '../customer_service/customer_service_identity.dart';
import '../location/location_view_page.dart';
import '../search/presentation/chat_search_entry_page.dart';
import '../search/presentation/message_record_search_page.dart';
import '../vip/vip_badge.dart';
import '../../widgets/chat_background_surface.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_main_top_bar.dart';
import '../../widgets/wk_web_ui_tokens.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/chat_slots.dart';
import '../../wukong_robot/models/robot.dart';
import '../../wukong_robot/robot_service.dart';
import '../../wukong_base/emoji/android_emoji_catalog.dart';
import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_base/endpoint/entity/chat_toolbar_menu.dart';
import '../../wukong_base/endpoint/menu/endpoint_menu.dart';
import '../../wukong_base/msg/msg_content_type.dart';
import '../../wukong_base/views/image_viewer.dart';
import '../../wukong_base/views/mention_suggestion.dart';
import '../../wukong_scan/scan_qr_code_bridge.dart';
import '../../wukong_uikit/setting/setting_preferences.dart';
import 'chat_composer_controller.dart';
import 'chat_flame_message_runtime.dart';
import 'chat_frame_jank_monitor.dart';
import 'chat_file_opening.dart';
import 'chat_conversation_extra_gateway.dart';
import 'chat_action_definition.dart';
import 'chat_action_dispatcher.dart';
import 'chat_desktop_drop_target.dart';
import 'chat_media_action_service.dart';
import 'chat_message_action_policy.dart';
import 'chat_message_action_surface.dart';
import 'chat_message_reaction_mapping.dart';
import 'chat_mentions_controller.dart';
import 'chat_message_view_model.dart';
import 'chat_scene_gateway.dart';
import 'chat_scene_models.dart';
import 'chat_scene_providers.dart';
import 'chat_gif_panel_service.dart';
import 'chat_text_sticker_conversion.dart';
import 'chat_typing_gateway.dart';
import 'chat_toolbar_slot_assembly.dart';
import 'chat_viewport_controller.dart';
import 'chat_voice_action_service.dart';
import 'chat_details_page.dart';
import 'expression/chat_expression_models.dart';
import 'expression/chat_expression_registry.dart';
import 'forward_message_page.dart';
import 'message_content_preview.dart';
import 'robot_card_message.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_edit_preview_strip.dart';
import 'widgets/chat_expression_panel.dart';
import 'widgets/chat_message_engagement_bubble.dart';
import 'widgets/chat_message_action_sheet.dart';
import 'widgets/chat_message_list_item.dart';
import 'widgets/chat_pinned_message_banner.dart';
import 'widgets/chat_pinned_message_sheet.dart';
import 'widgets/chat_message_viewport.dart';
import 'widgets/chat_reaction_picker_popup.dart';
import 'widgets/chat_reply_preview_strip.dart';
import 'widgets/chat_search_mode_bar.dart';
import 'widgets/chat_selection_toolbar.dart';
import 'widgets/chat_voice_press_hold_button.dart';
import 'widgets/chat_voice_record_overlay.dart';
import '../conversation/conversation_activity_registry.dart';
import '../video_call/widgets/chat_calling_participants_bar.dart';

@visibleForTesting
const double olderMessageLoadExtentAfterThreshold = 300;

@visibleForTesting
bool shouldTriggerOlderMessageLoad({
  required double extentAfter,
  double threshold = olderMessageLoadExtentAfterThreshold,
}) {
  return extentAfter < threshold;
}

@visibleForTesting
bool shouldUseWarmWorkbenchStyle() {
  return PlatformUtils.isWeb || PlatformUtils.isDesktop;
}

@visibleForTesting
double chatListCacheExtent({
  required double viewportHeight,
  required TargetPlatform platform,
  required bool isWeb,
}) {
  final safeHeight = viewportHeight.isFinite && viewportHeight > 0
      ? viewportHeight
      : 800.0;
  final isDesktop =
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
  final isMobile = !isWeb && !isDesktop;
  final multiplier = isWeb
      ? 0.9
      : isDesktop
      ? 1.5
      : 0.66;
  final minExtent = isDesktop && !isWeb ? 900.0 : 600.0;
  final maxExtent = isWeb
      ? 1000.0
      : isDesktop
      ? 1600.0
      : isMobile
      ? 900.0
      : 1200.0;
  return (safeHeight * multiplier).clamp(minExtent, maxExtent).toDouble();
}

class _OlderMessagesLoadingIndicator extends StatelessWidget {
  const _OlderMessagesLoadingIndicator()
    : super(key: const ValueKey<String>('chat-older-loading-indicator'));

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

const String _androidSystemTeamId = 'u_10000';
const String _androidFileHelperId = 'fileHelper';
const String _fileHelperTitle = '\u6587\u4ef6\u4f20\u8f93\u52a9\u624b';
const String _systemTitle = '\u7cfb\u7edf\u901a\u77e5';
const String _voiceTooltip = '\u8bed\u97f3\u901a\u8bdd';
const String _videoTooltip = '\u89c6\u9891\u901a\u8bdd';
const String _groupCallTooltip = '\u591a\u4eba\u901a\u8bdd';
const String _officialTag = '\u5b98\u65b9';
const String _robotTag = '\u673a\u5668\u4eba';
const String _onlineSuffix = '\u5728\u7ebf';
const String _recentMinutesSuffix = '\u5206\u949f';
const String _groupMembersSuffix = '\u4e2a\u6210\u5458';
const String _groupOnlineSuffix = '\u4eba\u5728\u7ebf';
const String _emptyMessageText = '\u6682\u65e0\u6d88\u606f';
const String _replyFallbackTitle = '\u5f15\u7528\u6d88\u606f';
const String _flameExitDescription =
    '\u9000\u51fa\u804a\u5929\u7a97\u53e3\u540e\uff0c\u5df2\u8bfb\u6d88\u606f\u81ea\u52a8\u9500\u6bc1';
const String _voicePermissionDeniedFeedback =
    '\u9700\u8981\u5141\u8bb8\u9ea6\u514b\u98ce\u6743\u9650\u540e\u624d\u80fd\u53d1\u9001\u8bed\u97f3';
const String _voiceTooShortFeedback = '\u5f55\u97f3\u65f6\u95f4\u592a\u77ed';
const String _voiceStartFailedFallback =
    '\u8bed\u97f3\u5f55\u5236\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5';
const String _sendFailureRetainedFeedback =
    '\u53d1\u9001\u5931\u8d25\uff0c\u6d88\u606f\u5df2\u4fdd\u7559\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u91cd\u8bd5';
const String _retrySendFailureFeedback =
    '\u91cd\u53d1\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u518d\u8bd5';
const List<int> _flameSecondOptions = <int>[0, 10, 20, 30, 60, 120, 180];

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
        _applyChannelFlameSettings(
          channel,
          flame: group.flame ?? 0,
          flameSecond: group.flameSecond ?? 0,
        );
        if ((group.memberCount ?? 0) > 0) {
          final remoteExtra = _mutableExtraMap(channel.remoteExtraMap);
          remoteExtra['member_count'] = group.memberCount ?? 0;
          channel.remoteExtraMap = remoteExtra;
        }
      } else if (widget.channelType == WKChannelType.personal) {
        final user = await UserApi.instance.getUserInfo(
          widget.channelId,
          cancelToken: cancelToken,
        );
        _applyChannelUserIdentity(channel, user);
        _applyChannelFlameSettings(
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
        final allowMemberPinned = _readChannelExtraInt(
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
    final subtitle = _primarySubtitle();
    final secondarySubtitle = _secondarySubtitle();
    final tags = _buildTags();
    final headerVipLevel = _resolveHeaderVipLevel(
      ref.watch(
        friendListProvider.select(
          (state) => state.valueOrNull ?? const <Friend>[],
        ),
      ),
    );
    final scene = ref.watch(chatSceneControllerProvider(_chatSession));
    final searchMode = ref.watch(
      chatSearchModeControllerProvider(_chatSession),
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
    final showSearchAction =
        !isMobileWarmStyle || MediaQuery.sizeOf(context).width >= 420;

    return PopScope<void>(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          unawaited(_persistConversationExtra());
        }
      },
      child: Scaffold(
        backgroundColor: isMobileWarmStyle
            ? WKWebColors.pageWarm
            : useWarmWorkbenchStyle
            ? WKWebColors.pageWarm
            : WKColors.homeBg,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          toolbarHeight: isMobileWarmStyle ? 74 : null,
          leadingWidth: isMobileWarmStyle ? 48 : null,
          backgroundColor: isMobileWarmStyle
              ? WKWebColors.surface
              : useWarmWorkbenchStyle
              ? WKWebColors.surface
              : WKColors.homeBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            key: const ValueKey<String>('chat-back-button'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: WKReferenceAssets.image(
              WKReferenceAssets.back,
              width: 22,
              height: 22,
              tint: isMobileWarmStyle
                  ? WKWebColors.textPrimary
                  : WKColors.colorDark,
            ),
          ),
          titleSpacing: 0,
          title: searchMode.isActive
              ? ChatSearchModeBar(
                  initialKeyword: searchMode.keyword,
                  onChanged: (value) {
                    ref
                        .read(
                          chatSearchModeControllerProvider(
                            _chatSession,
                          ).notifier,
                        )
                        .updateKeyword(value);
                  },
                  onSubmitted: (_) => _openChatSearch(),
                  onClose: _closeSceneSearch,
                )
              : InkWell(
                  onTap: widget.channelType == WKChannelType.customerService
                      ? null
                      : () {},
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        WKAvatar(
                          url: _channel?.avatar,
                          name: title,
                          isGroup: widget.channelType == WKChannelType.group,
                          size: isMobileWarmStyle ? 48 : 40,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: WKColors.colorDark,
                                      ),
                                    ),
                                  ),
                                  if (headerVipLevel == 1) ...[
                                    const SizedBox(width: 6),
                                    const VipBadge(
                                      key: ValueKey<String>(
                                        'chat-header-vip-badge',
                                      ),
                                    ),
                                  ],
                                  if (tags.isNotEmpty) const SizedBox(width: 4),
                                  if (tags.isNotEmpty)
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 2,
                                      children: tags,
                                    ),
                                ],
                              ),
                              if (subtitle != null || secondarySubtitle != null)
                                Row(
                                  children: [
                                    if (subtitle != null)
                                      Flexible(
                                        child: Text(
                                          subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: WKColors.color999,
                                          ),
                                        ),
                                      ),
                                    if (secondarySubtitle != null) ...[
                                      if (subtitle != null)
                                        const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          secondarySubtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: WKColors.color999,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          actions: searchMode.isActive
              ? const <Widget>[]
              : [
                  if (showSearchAction)
                    IconButton(
                      key: const ValueKey<String>('chat-open-search'),
                      onPressed: _openSceneSearch,
                      icon: WKReferenceAssets.image(
                        WKReferenceAssets.search,
                        width: 20,
                        height: 20,
                        tint: WKColors.popupText,
                      ),
                    ),
                  if (isMobileWarmStyle)
                    WKTopBarActionButton(
                      key: const ValueKey<String>('chat-open-more'),
                      tooltip: '\u66F4\u591A',
                      onTap: _openChatInfo,
                      padding: const EdgeInsets.only(right: 16),
                      variant: WKTopBarActionButtonVariant.warmSquare,
                      size: 38,
                      child: WKReferenceAssets.image(
                        WKReferenceAssets.topMore,
                        width: 18,
                        height: 18,
                        tint: WKWebColors.action,
                      ),
                    )
                  else
                    IconButton(
                      key: const ValueKey<String>('chat-open-more'),
                      onPressed: _openChatInfo,
                      icon: WKReferenceAssets.image(
                        WKReferenceAssets.topMore,
                        width: 20,
                        height: 20,
                        tint: WKColors.popupText,
                      ),
                    ),
                ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: ChatBackgroundSurface(
                key: const ValueKey<String>('chat-background-surface'),
                option: selectedChatBackground,
                fallbackStyle: fallbackBackgroundStyle,
                fallbackColor: isMobileWarmStyle || useWarmWorkbenchStyle
                    ? WKWebColors.pageWarm
                    : null,
              ),
            ),
            _ChatKeyboardInsetTranslation(
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
                              chatSceneControllerProvider(
                                _chatSession,
                              ).notifier,
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
                    child: _ChatViewportPane(
                      session: _chatSession,
                      conversationChannel: _participantFallbackChannel(),
                      canPinMessages: _canPinMessages,
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
                  _ChatComposerPane(
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
          ],
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

    return _readChannelExtraInt(_channel?.remoteExtraMap, const [
          'vip_level',
          'vipLevel',
        ]) ??
        _readChannelExtraInt(_channel?.localExtra, const [
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
      tags.add(const _HeaderTag(label: _officialTag));
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
      tags.add(const _HeaderTag(label: _robotTag));
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
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
      await _pushGroupCallPicker(
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

class _ChatViewportPane extends ConsumerStatefulWidget {
  const _ChatViewportPane({
    required this.session,
    this.conversationChannel,
    this.canPinMessages = false,
    this.flameRuntime,
    this.onBuild,
    this.onPinnedMessageToggled,
    this.restoreAnchor,
    this.webStyle = false,
    this.onPersistenceSnapshotChanged,
    this.onRestoreAnchorApplied,
  });

  final ChatSession session;
  final WKChannel? conversationChannel;
  final bool canPinMessages;
  final ChatFlameMessageRuntime? flameRuntime;
  final VoidCallback? onBuild;
  final Future<void> Function(WKMsg message)? onPinnedMessageToggled;
  final ChatViewportRestoreAnchor? restoreAnchor;
  final bool webStyle;
  final ValueChanged<ChatViewportPersistenceSnapshot>?
  onPersistenceSnapshotChanged;
  final ValueChanged<ChatViewportRestoreResult>? onRestoreAnchorApplied;

  @override
  ConsumerState<_ChatViewportPane> createState() => _ChatViewportPaneState();
}

class _ChatViewportPaneState extends ConsumerState<_ChatViewportPane> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _listKey = GlobalKey();
  final Map<String, GlobalKey> _measurementKeys = <String, GlobalKey>{};
  late final ChatFlameMessageRuntime _flameRuntime;
  int? _restoredKeepMessageSeq;
  bool _isApplyingRestoreAnchor = false;
  Map<String, WKChannelMember> _groupMembersByUid =
      const <String, WKChannelMember>{};

  @override
  void initState() {
    super.initState();
    _flameRuntime = widget.flameRuntime ?? ChatFlameMessageRuntime();
    unawaited(_flameRuntime.sweepViewedMessages());
    if (widget.session.channelType == WKChannelType.group) {
      unawaited(_hydrateGroupMembers());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final readController = ref.read(
        chatReadControllerProvider(widget.session),
      );
      final viewport = ref.read(chatViewportProvider(widget.session));
      readController.onVisibleMessageIdsChanged(_readableMessageIds(viewport));
      unawaited(_flameRuntime.markVisibleMessages(_visibleMessages(viewport)));
      _scheduleViewportPersistenceSync();
    });
  }

  @override
  void didUpdateWidget(covariant _ChatViewportPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAnchor = oldWidget.restoreAnchor;
    final nextAnchor = widget.restoreAnchor;
    if (oldAnchor?.keepMessageSeq != nextAnchor?.keepMessageSeq ||
        oldAnchor?.keepOffsetY != nextAnchor?.keepOffsetY) {
      _restoredKeepMessageSeq = null;
      _isApplyingRestoreAnchor = false;
      _scheduleViewportPersistenceSync();
    }
  }

  @override
  void dispose() {
    unawaited(_flameRuntime.sweepViewedMessages());
    _flameRuntime.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewport = ref.watch(chatViewportProvider(widget.session));
    final currentUser = ref.watch(
      authProvider.select((state) => state.userInfo),
    );
    final readController = ref.watch(
      chatReadControllerProvider(widget.session),
    );
    final gateway = ref.watch(chatSceneGatewayProvider(widget.session));
    final listCacheExtent = chatListCacheExtent(
      viewportHeight: MediaQuery.sizeOf(context).height,
      platform: defaultTargetPlatform,
      isWeb: kIsWeb,
    );

    ref.listen<ChatViewportState>(chatViewportProvider(widget.session), (
      previous,
      next,
    ) {
      readController.onVisibleMessageIdsChanged(_readableMessageIds(next));
      unawaited(_flameRuntime.markVisibleMessages(_visibleMessages(next)));
      _scheduleViewportPersistenceSync();
    });
    ref.listen(chatMessageActionControllerProvider(widget.session), (
      previous,
      next,
    ) {
      final feedbackMessage = next.feedbackMessage?.trim() ?? '';
      if (feedbackMessage.isEmpty) {
        return;
      }
      final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
      if (scaffoldMessenger == null) {
        return;
      }
      scaffoldMessenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(feedbackMessage)));
      ref
          .read(chatMessageActionControllerProvider(widget.session).notifier)
          .clearFeedbackMessage();
    });

    return ChatMessageViewport(
      onBuild: widget.onBuild,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              shouldTriggerOlderMessageLoad(
                extentAfter: notification.metrics.extentAfter,
              )) {
            unawaited(
              ref
                  .read(chatViewportProvider(widget.session).notifier)
                  .loadOlder(),
            );
          }
          if (notification is ScrollUpdateNotification ||
              notification is UserScrollNotification ||
              notification is ScrollEndNotification) {
            _scheduleViewportPersistenceSync();
          }
          return false;
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: viewport.items.isEmpty
                  ? const Center(child: Text(_emptyMessageText))
                  : ListView.builder(
                      key: _listKey,
                      controller: _scrollController,
                      reverse: true,
                      cacheExtent: listCacheExtent,
                      itemCount: viewport.items.length,
                      findChildIndexCallback: (key) {
                        if (key is ValueKey<String>) {
                          return viewport.identityToIndex[key.value];
                        }
                        return null;
                      },
                      itemBuilder: (context, index) {
                        final item = viewport.items[index];
                        final contentType = item.message.contentType;
                        return ChatMessageListItem(
                          key: ValueKey<String>(item.identity),
                          itemKey: ValueKey<String>(item.identity),
                          measurementKey: _measurementKeyFor(item.identity),
                          keepAlive: MessageHeightEstimator.shouldKeepAlive(
                            contentType,
                          ),
                          child: ChatMessageEngagementBubble(
                            session: widget.session,
                            model: item,
                            participant: _resolveParticipantInfo(
                              item.message,
                              currentUser,
                            ),
                            statusInfo: resolveMessageStatusInfo(
                              item.message,
                              isSelf: item.isSelf,
                            ),
                            webStyle: widget.webStyle,
                            gateway: gateway,
                            onTap: _messageTapHandler(item, viewport),
                            onLongPress: () => _showMessageActionSheet(item),
                            onSecondaryTapDown: (details) =>
                                _showMessageActionSheet(
                                  item,
                                  anchorPosition: details.globalPosition,
                                ),
                            onRetrySend:
                                item.isSelf &&
                                    item.message.status ==
                                        WKSendMsgResult.sendFail
                                ? () => unawaited(
                                    _retryFailedMessage(item, gateway),
                                  )
                                : null,
                            onReactionTap: (emoji) =>
                                _toggleReaction(item, emoji),
                          ),
                        );
                      },
                    ),
            ),
            if (viewport.isLoadingMore)
              const Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(child: _OlderMessagesLoadingIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  GlobalKey _measurementKeyFor(String identity) {
    return _measurementKeys.putIfAbsent(
      identity,
      () => GlobalKey(debugLabel: 'chat-item-$identity'),
    );
  }

  MessageParticipantInfo _resolveParticipantInfo(
    WKMsg message,
    UserInfo? currentUser,
  ) {
    final fallbackGroupMember =
        widget.session.channelType == WKChannelType.group
        ? _groupMembersByUid[message.fromUID.trim()]
        : null;
    return resolveMessageParticipantInfo(
      message,
      fallbackGroupMember: fallbackGroupMember,
      fallbackSenderChannel: _fallbackSenderChannel(message),
      currentUid: currentUser?.uid,
      currentUserDisplayName: _currentUserDisplayName(currentUser),
      currentUserAvatarUrl: currentUser?.avatar,
    );
  }

  WKChannel? _fallbackSenderChannel(WKMsg message) {
    final channel = widget.conversationChannel;
    if (channel == null) {
      return null;
    }
    final senderUid = message.fromUID.trim();
    if (senderUid.isEmpty || channel.channelID.trim() != senderUid) {
      return null;
    }
    return channel;
  }

  String _currentUserDisplayName(UserInfo? user) {
    if (user == null) {
      return '';
    }
    return _firstNonEmptyText([
      user.remark,
      user.name,
      user.username,
      user.uid,
    ]);
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

  Future<void> _retryFailedMessage(
    ChatMessageViewModel model,
    ChatSceneGateway gateway,
  ) async {
    if (model.message.status != WKSendMsgResult.sendFail) {
      return;
    }
    try {
      await gateway.retryMessage(model.message);
    } catch (_) {
      _showFileOpenFeedback(_retrySendFailureFeedback);
    }
  }

  Future<void> _hydrateGroupMembers() async {
    try {
      final remoteMembers = await GroupApi.instance.getGroupMembers(
        widget.session.channelId,
      );
      final sdkMembers = remoteMembers
          .map(_toSdkGroupMember)
          .where((member) => member.memberUID.trim().isNotEmpty)
          .toList(growable: false);
      if (sdkMembers.isNotEmpty) {
        await WKIM.shared.channelMemberManager.saveOrUpdateList(sdkMembers);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _groupMembersByUid = <String, WKChannelMember>{
          for (final member in sdkMembers) member.memberUID.trim(): member,
        };
      });
    } catch (_) {
      // Keep rendering with message payload data when group members cannot load.
    }
  }

  WKChannelMember _toSdkGroupMember(GroupMember member) {
    return WKChannelMember()
      ..channelID = widget.session.channelId
      ..channelType = widget.session.channelType
      ..memberUID = member.uid
      ..memberName = member.name ?? ''
      ..memberRemark = member.remark ?? ''
      ..memberAvatar = member.avatar ?? ''
      ..role = member.role ?? 0
      ..status = member.status ?? 0
      ..version = member.version ?? 0
      ..memberInviteUID = member.inviteUid ?? ''
      ..forbiddenExpirationTime = member.forbiddenExpirTime ?? 0;
  }

  Future<void> _openMediaMessage(
    ChatMessageViewModel model,
    ChatViewportState viewport,
  ) async {
    final previewUrl = _imagePreviewUrlOf(model.message);
    if (previewUrl == null || previewUrl.isEmpty) {
      return;
    }

    final isFlame = isFlameMessage(model.message);
    if (isFlame) {
      await _flameRuntime.markViewed(model.message);
      if (!mounted) {
        return;
      }
    }

    final previewItems = isFlame
        ? <_ChatImagePreviewItem>[
            _ChatImagePreviewItem(
              identity: model.identity,
              message: model.message,
              url: previewUrl,
            ),
          ]
        : _buildImagePreviewItems(viewport);
    if (previewItems.isEmpty) {
      return;
    }

    final initialIndex = previewItems.indexWhere(
      (item) => item.identity == model.identity,
    );
    if (initialIndex == -1) {
      return;
    }

    await ImageViewerHelper.show(
      context,
      images: previewItems.map((item) => item.url).toList(growable: false),
      initialIndex: initialIndex,
      actions: isFlame
          ? const <ImageViewerAction>[]
          : _imageViewerActions(previewItems),
      enableLongPressOptions: false,
    );
  }

  VoidCallback? _messageTapHandler(
    ChatMessageViewModel model,
    ChatViewportState viewport,
  ) {
    final contentType = _resolvedMessageContentType(model);
    switch (contentType) {
      case MsgContentType.robotCard:
      case WkMessageContentType.image:
      case WkMessageContentType.file:
      case WkMessageContentType.location:
      case WkMessageContentType.card:
        return () => unawaited(_handleMessageTap(model, viewport));
      default:
        return null;
    }
  }

  Future<void> _handleMessageTap(
    ChatMessageViewModel model,
    ChatViewportState viewport,
  ) async {
    switch (_resolvedMessageContentType(model)) {
      case MsgContentType.robotCard:
        await openRobotCardLink(
          model.message,
          structuredPayload: model.structuredPayload,
        );
        return;
      case WkMessageContentType.image:
        await _openMediaMessage(model, viewport);
        return;
      case WkMessageContentType.file:
        await _openFileMessage(model);
        return;
      case WkMessageContentType.location:
        final location = _resolveLocationContent(model);
        if (location == null || !mounted) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => LocationViewPage(location: location),
          ),
        );
        return;
      case WkMessageContentType.card:
        final uid = _resolveCardUid(model);
        if (uid.isEmpty || !mounted) {
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => UserDetailPage(uid: uid)),
        );
        return;
      default:
        return;
    }
  }

  Future<void> _openFileMessage(ChatMessageViewModel model) async {
    final target = resolveChatFileOpenTarget(
      messageContent: model.message.messageContent,
      structuredPayload: model.structuredPayload,
    );
    if (target == null) {
      _showFileOpenFeedback(
        '\u5f53\u524d\u6587\u4ef6\u7f3a\u5c11\u53ef\u7528\u7684\u8def\u5f84\u6216\u4e0b\u8f7d\u5730\u5740',
      );
      return;
    }

    try {
      final opened = await openChatFileTarget(target);
      if (!opened) {
        _showFileOpenFeedback('\u6253\u5f00\u6587\u4ef6\u5931\u8d25');
      }
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '').trim();
      _showFileOpenFeedback(
        message.isEmpty ? '\u6253\u5f00\u6587\u4ef6\u5931\u8d25' : message,
      );
    }
  }

  void _showFileOpenFeedback(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.trim())));
  }

  int _resolvedMessageContentType(ChatMessageViewModel model) {
    if (model.message.contentType != WkMessageContentType.unknown) {
      return model.message.contentType;
    }
    final rawType = model.structuredPayload?['type'];
    if (rawType is num) {
      return rawType.toInt();
    }
    if (rawType is String) {
      return int.tryParse(rawType) ?? model.message.contentType;
    }
    return model.message.contentType;
  }

  WKLocationContent? _resolveLocationContent(ChatMessageViewModel model) {
    final content = model.message.messageContent;
    if (content is WKLocationContent) {
      return content;
    }

    final payload = model.structuredPayload;
    if (payload == null) {
      return null;
    }

    final latitude = _readPayloadDouble(payload, const ['latitude', 'lat']);
    final longitude = _readPayloadDouble(payload, const [
      'longitude',
      'lng',
      'lon',
    ]);
    if (latitude == null || longitude == null) {
      return null;
    }

    final location = WKLocationContent()
      ..latitude = latitude
      ..longitude = longitude
      ..title = _readPayloadString(payload, const ['title', 'name'])
      ..address = _readPayloadString(payload, const ['address']);
    return location;
  }

  String _resolveCardUid(ChatMessageViewModel model) {
    final content = model.message.messageContent;
    if (content is WKCardContent) {
      return content.uid.trim();
    }

    return _readPayloadString(model.structuredPayload, const [
      'uid',
      'user_uid',
      'from_uid',
    ]);
  }

  String _readPayloadString(Map<String, dynamic>? payload, List<String> keys) {
    if (payload == null) {
      return '';
    }
    for (final key in keys) {
      final value = payload[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  double? _readPayloadDouble(Map<String, dynamic>? payload, List<String> keys) {
    if (payload == null) {
      return null;
    }
    for (final key in keys) {
      final value = payload[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  List<_ChatImagePreviewItem> _buildImagePreviewItems(
    ChatViewportState viewport,
  ) {
    final items = <_ChatImagePreviewItem>[];
    for (final item in viewport.items) {
      if (item.message.contentType != WkMessageContentType.image) {
        continue;
      }
      if (item.message.isDeleted == 1 || item.message.wkMsgExtra?.revoke == 1) {
        continue;
      }
      if (isFlameMessage(item.message)) {
        continue;
      }
      final previewUrl = _imagePreviewUrlOf(item.message);
      if (previewUrl == null || previewUrl.isEmpty) {
        continue;
      }
      items.add(
        _ChatImagePreviewItem(
          identity: item.identity,
          message: item.message,
          url: previewUrl,
        ),
      );
    }
    return items;
  }

  List<ImageViewerAction> _imageViewerActions(
    List<_ChatImagePreviewItem> previewItems,
  ) {
    final actions = <ImageViewerAction>[
      ImageViewerAction(
        key: 'forward',
        icon: Icons.forward_outlined,
        label: '\u8f6c\u53d1',
        onPressed: (viewerContext, index) async {
          final current = previewItems[index];
          if (viewerContext.mounted) {
            Navigator.of(viewerContext).pop();
          }
          final controller = ref.read(
            chatMessageActionControllerProvider(widget.session).notifier,
          );
          controller.prepareForward(<WKMsg>[current.message]);
          final request = ref
              .read(chatMessageActionControllerProvider(widget.session))
              .forwardRequest;
          if (request == null || request.payloads.isEmpty || !mounted) {
            controller.clearTransientState();
            return;
          }
          try {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ForwardMessagePage(
                  payloads: request.payloads,
                  channelId: widget.session.channelId,
                  channelType: widget.session.channelType,
                  gateway: ref.read(chatSceneGatewayProvider(widget.session)),
                ),
              ),
            );
          } finally {
            if (mounted) {
              ref
                  .read(
                    chatMessageActionControllerProvider(
                      widget.session,
                    ).notifier,
                  )
                  .clearTransientState();
            }
          }
        },
      ),
      ImageViewerAction(
        key: 'favorite',
        icon: Icons.favorite_border,
        label: '\u6536\u85cf',
        onPressed: (_, index) async {
          await ref
              .read(
                chatMessageActionControllerProvider(widget.session).notifier,
              )
              .favorite(previewItems[index].message);
        },
      ),
      ImageViewerAction(
        key: 'show-in-chat',
        icon: Icons.chat_bubble_outline,
        label: '\u5728\u804a\u5929\u4e2d\u67e5\u770b',
        onPressed: (viewerContext, index) async {
          final targetIdentity = previewItems[index].identity;
          if (viewerContext.mounted) {
            Navigator.of(viewerContext).pop();
          }
          await Future<void>.delayed(Duration.zero);
          if (!mounted) {
            return;
          }
          await _scrollToMessageIdentity(targetIdentity);
        },
      ),
    ];
    if (EndpointManager.getInstance().hasEndpoint(ChatMenuIDs.parseQrCode)) {
      actions.add(
        ImageViewerAction(
          key: 'scan-qrcode',
          icon: Icons.qr_code_scanner_outlined,
          label: '\u8bc6\u522b\u4e8c\u7ef4\u7801',
          onPressed: (viewerContext, index) async {
            await ScanQrCodeBridge.instance.handleImageSource(
              previewItems[index].url,
            );
          },
        ),
      );
    }
    return actions;
  }

  Future<void> _scrollToMessageIdentity(String identity) async {
    final targetContext = _measurementKeys[identity]?.currentContext;
    if (targetContext == null) {
      return;
    }
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      alignment: 0.5,
      curve: Curves.easeOut,
    );
  }

  String? _imagePreviewUrlOf(WKMsg message) {
    final content = message.messageContent;
    if (content is! WKImageContent) {
      return null;
    }
    final localPath = content.localPath.trim();
    if (localPath.isNotEmpty) {
      return localPath;
    }
    final url = content.url.trim();
    if (url.isEmpty) {
      return null;
    }
    return ApiConfig.resolveMediaUrl(url);
  }

  void _scheduleViewportPersistenceSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final viewport = ref.read(chatViewportProvider(widget.session));
      final snapshot = _resolveViewportPersistenceSnapshot(viewport);
      widget.onPersistenceSnapshotChanged?.call(snapshot);
      _maybeApplyRestoreAnchor(viewport);
    });
  }

  ChatViewportPersistenceSnapshot _resolveViewportPersistenceSnapshot(
    ChatViewportState viewport,
  ) {
    if (viewport.items.isEmpty) {
      return const ChatViewportPersistenceSnapshot();
    }
    final listRenderObject = _listKey.currentContext?.findRenderObject();
    if (listRenderObject is! RenderBox) {
      return const ChatViewportPersistenceSnapshot();
    }

    final viewportHeight = listRenderObject.size.height;
    _VisibleViewportItem? firstVisible;
    var maxVisibleMessageSeq = 0;

    for (final item in viewport.items) {
      final renderObject = _measurementKeys[item.identity]?.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }
      final top = renderObject
          .localToGlobal(Offset.zero, ancestor: listRenderObject)
          .dy;
      final bottom = top + renderObject.size.height;
      if (bottom <= 0 || top >= viewportHeight) {
        continue;
      }
      final messageSeq = item.message.messageSeq;
      if (messageSeq > maxVisibleMessageSeq) {
        maxVisibleMessageSeq = messageSeq;
      }
      if (firstVisible == null || top < firstVisible.top) {
        firstVisible = _VisibleViewportItem(
          messageSeq: messageSeq,
          top: top,
          identity: item.identity,
        );
      }
    }

    if (_isAtBottom || firstVisible == null || firstVisible.messageSeq <= 0) {
      return ChatViewportPersistenceSnapshot(
        maxVisibleMessageSeq: maxVisibleMessageSeq,
      );
    }
    return ChatViewportPersistenceSnapshot(
      keepMessageSeq: firstVisible.messageSeq,
      keepOffsetY: firstVisible.top.round(),
      maxVisibleMessageSeq: maxVisibleMessageSeq,
    );
  }

  bool get _isAtBottom {
    if (!_scrollController.hasClients) {
      return true;
    }
    final position = _scrollController.position;
    return (position.pixels - position.minScrollExtent).abs() <= 1.0;
  }

  void _maybeApplyRestoreAnchor(ChatViewportState viewport) {
    final anchor = widget.restoreAnchor;
    if (anchor == null ||
        anchor.keepMessageSeq <= 0 ||
        _isApplyingRestoreAnchor ||
        _restoredKeepMessageSeq == anchor.keepMessageSeq) {
      return;
    }

    String? targetIdentity;
    for (final item in viewport.items) {
      if (item.message.messageSeq == anchor.keepMessageSeq) {
        targetIdentity = item.identity;
        break;
      }
    }
    if (targetIdentity == null) {
      return;
    }

    _isApplyingRestoreAnchor = true;
    _applyRestoreAnchor(targetIdentity, anchor);
  }

  void _applyRestoreAnchor(
    String identity,
    ChatViewportRestoreAnchor anchor, {
    int attempts = 0,
  }) {
    if (!mounted || !_scrollController.hasClients) {
      _isApplyingRestoreAnchor = false;
      return;
    }
    final currentTop = _measureItemTop(identity);
    if (currentTop == null) {
      _isApplyingRestoreAnchor = false;
      return;
    }

    final delta = currentTop - anchor.keepOffsetY;
    if (delta.abs() <= 1.0 || attempts >= 4) {
      _finishRestoreAnchor(anchor, currentTop);
      return;
    }

    final position = _scrollController.position;
    final nextOffset = (position.pixels - delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((nextOffset - position.pixels).abs() <= 1.0) {
      _finishRestoreAnchor(anchor, currentTop);
      return;
    }

    _scrollController.jumpTo(nextOffset.toDouble());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyRestoreAnchor(identity, anchor, attempts: attempts + 1);
    });
  }

  void _finishRestoreAnchor(
    ChatViewportRestoreAnchor anchor,
    double appliedTop,
  ) {
    _restoredKeepMessageSeq = anchor.keepMessageSeq;
    _isApplyingRestoreAnchor = false;
    widget.onRestoreAnchorApplied?.call(
      ChatViewportRestoreResult(
        keepMessageSeq: anchor.keepMessageSeq,
        requestedOffsetY: anchor.keepOffsetY,
        appliedOffsetY: appliedTop.round(),
      ),
    );
  }

  double? _measureItemTop(String identity) {
    final listRenderObject = _listKey.currentContext?.findRenderObject();
    final itemRenderObject = _measurementKeys[identity]?.currentContext
        ?.findRenderObject();
    if (listRenderObject is! RenderBox || itemRenderObject is! RenderBox) {
      return null;
    }
    if (!itemRenderObject.attached) {
      return null;
    }
    return itemRenderObject
        .localToGlobal(Offset.zero, ancestor: listRenderObject)
        .dy;
  }

  Iterable<WKMsg> _visibleMessages(ChatViewportState state) sync* {
    final listRenderObject = _listKey.currentContext?.findRenderObject();
    if (listRenderObject is! RenderBox) {
      return;
    }
    final viewportHeight = listRenderObject.size.height;
    for (final item in state.items) {
      final renderObject = _measurementKeys[item.identity]?.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }
      final top = renderObject
          .localToGlobal(Offset.zero, ancestor: listRenderObject)
          .dy;
      final bottom = top + renderObject.size.height;
      if (bottom <= 0 || top >= viewportHeight) {
        continue;
      }
      yield item.message;
    }
  }

  Iterable<String> _readableMessageIds(ChatViewportState state) sync* {
    for (final item in state.items) {
      if (item.isSelf) {
        continue;
      }
      if (item.message.viewed == 1 || item.message.viewedAt > 0) {
        continue;
      }
      final messageId = item.message.messageID.trim();
      if (messageId.isEmpty) {
        continue;
      }
      yield messageId;
    }
  }

  Future<void> _showMessageActionSheet(
    ChatMessageViewModel model, {
    Offset? anchorPosition,
  }) {
    final actions = buildChatMessageActionDescriptors(
      message: model.message,
      isSelf: model.isSelf,
      canRecall: model.isSelf,
      canPin: widget.canPinMessages,
    );
    final gateway = ref.read(chatSceneGatewayProvider(widget.session));
    final selectedEmoji = ChatMessageReactionMapping.selectedReactionEmoji(
      gateway.prepareReactions(model.message),
    );
    if (actions.isEmpty) {
      return Future<void>.value();
    }
    final surface = resolveChatMessageActionSurface(
      platform: defaultTargetPlatform,
      isWeb: kIsWeb,
      anchorPosition: anchorPosition,
    );
    if (surface == ChatMessageActionSurface.contextMenu) {
      return _showMessageContextMenu(
        model,
        actions: actions,
        anchorPosition: anchorPosition!,
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => ChatMessageActionSheet(
        actions: actions,
        selectedEmoji: selectedEmoji,
        onReactionSelected: (emoji) {
          unawaited(_toggleReaction(model, emoji));
        },
        onSelected: (action) {
          unawaited(_dispatchSceneAction(action, model));
        },
      ),
    );
  }

  Future<void> _showMessageContextMenu(
    ChatMessageViewModel model, {
    required List<ChatMessageActionDescriptor> actions,
    required Offset anchorPosition,
  }) async {
    final overlayBox =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    final overlaySize = overlayBox?.size ?? MediaQuery.sizeOf(context);
    final localPosition = overlayBox == null
        ? anchorPosition
        : overlayBox.globalToLocal(anchorPosition);
    final selectedAction = await showMenu<ChatSceneAction>(
      context: context,
      position: buildChatMessageContextMenuPosition(
        anchorPosition: localPosition,
        overlaySize: overlaySize,
      ),
      items: _orderedMessageActions(actions)
          .map(
            (descriptor) => PopupMenuItem<ChatSceneAction>(
              key: ValueKey<String>(
                'chat-context-action-${descriptor.action.name}',
              ),
              value: descriptor.action,
              child: Text(descriptor.label),
            ),
          )
          .toList(growable: false),
    );
    if (!mounted || selectedAction == null) {
      return;
    }
    await _dispatchSceneAction(selectedAction, model);
  }

  List<ChatMessageActionDescriptor> _orderedMessageActions(
    List<ChatMessageActionDescriptor> actions,
  ) {
    return actions.toList(growable: false)..sort((left, right) {
      final orderComparison = left.order.compareTo(right.order);
      if (orderComparison != 0) {
        return orderComparison;
      }
      return left.action.name.compareTo(right.action.name);
    });
  }

  Future<void> _openReactionPicker(ChatMessageViewModel model) async {
    final gateway = ref.read(chatSceneGatewayProvider(widget.session));
    final selectedEmoji = ChatMessageReactionMapping.selectedReactionEmoji(
      gateway.prepareReactions(model.message),
    );
    final pickedEmoji = await showChatReactionPicker(
      context: context,
      isSelf: model.isSelf,
      selectedEmoji: selectedEmoji,
    );
    if (!mounted || pickedEmoji == null) {
      return;
    }
    await _toggleReaction(model, pickedEmoji);
  }

  Future<void> _toggleReaction(ChatMessageViewModel model, String emoji) async {
    await ref
        .read(chatMessageActionControllerProvider(widget.session).notifier)
        .toggleReaction(model.message, emoji);
  }

  Future<void> _dispatchSceneAction(
    ChatSceneAction action,
    ChatMessageViewModel model,
  ) async {
    try {
      await _handleSceneAction(action, model);
    } catch (error, stackTrace) {
      debugPrint('Chat scene action failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _handleSceneAction(
    ChatSceneAction action,
    ChatMessageViewModel model,
  ) async {
    final composerController = ref.read(
      chatComposerProvider(widget.session).notifier,
    );
    final sceneController = ref.read(
      chatSceneControllerProvider(widget.session).notifier,
    );
    final messageActionController = ref.read(
      chatMessageActionControllerProvider(widget.session).notifier,
    );

    switch (action) {
      case ChatSceneAction.reply:
        composerController.setPendingReply(
          messageId: model.message.messageID,
          preview: model.previewText,
        );
        sceneController.enterReplyMode();
        return;
      case ChatSceneAction.forward:
        messageActionController.prepareForward(<WKMsg>[model.message]);
        final request = ref
            .read(chatMessageActionControllerProvider(widget.session))
            .forwardRequest;
        if (request == null || request.payloads.isEmpty) {
          return;
        }
        try {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ForwardMessagePage(
                payloads: request.payloads,
                channelId: widget.session.channelId,
                channelType: widget.session.channelType,
                gateway: ref.read(chatSceneGatewayProvider(widget.session)),
              ),
            ),
          );
        } finally {
          if (mounted) {
            ref
                .read(
                  chatMessageActionControllerProvider(widget.session).notifier,
                )
                .clearTransientState();
          }
        }
        return;
      case ChatSceneAction.copy:
        await messageActionController.copy(model.message);
        return;
      case ChatSceneAction.edit:
        messageActionController.prepareEdit(model.message);
        final request = ref
            .read(chatMessageActionControllerProvider(widget.session))
            .editRequest;
        if (request == null) {
          return;
        }
        composerController.setPendingEdit(
          messageId: request.messageId,
          messageSeq: request.messageSeq,
          initialText: request.initialText,
        );
        messageActionController.clearTransientState();
        sceneController.restoreNormal();
        return;
      case ChatSceneAction.favorite:
        await messageActionController.favorite(model.message);
        return;
      case ChatSceneAction.select:
        ref
            .read(chatSelectionControllerProvider(widget.session).notifier)
            .seed(model.identity);
        sceneController.enterSelectionMode(seedIdentity: model.identity);
        return;
      case ChatSceneAction.delete:
        await messageActionController.deleteMessage(model.message);
        return;
      case ChatSceneAction.recall:
        await messageActionController.recall(model.message);
        return;
      case ChatSceneAction.react:
        await _openReactionPicker(model);
        return;
      case ChatSceneAction.pin:
      case ChatSceneAction.unpin:
        await messageActionController.togglePinned(model.message);
        final onPinnedMessageToggled = widget.onPinnedMessageToggled;
        if (onPinnedMessageToggled != null) {
          await onPinnedMessageToggled(model.message);
        }
        return;
    }
  }
}

class _ChatImagePreviewItem {
  const _ChatImagePreviewItem({
    required this.identity,
    required this.message,
    required this.url,
  });

  final String identity;
  final WKMsg message;
  final String url;
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

@immutable
class ChatViewportPersistenceSnapshot {
  const ChatViewportPersistenceSnapshot({
    this.keepMessageSeq = 0,
    this.keepOffsetY = 0,
    this.maxVisibleMessageSeq = 0,
  });

  final int keepMessageSeq;
  final int keepOffsetY;
  final int maxVisibleMessageSeq;
}

@immutable
class ChatViewportRestoreResult {
  const ChatViewportRestoreResult({
    required this.keepMessageSeq,
    required this.requestedOffsetY,
    required this.appliedOffsetY,
  });

  final int keepMessageSeq;
  final int requestedOffsetY;
  final int appliedOffsetY;
}

@immutable
class _VisibleViewportItem {
  const _VisibleViewportItem({
    required this.messageSeq,
    required this.top,
    required this.identity,
  });

  final int messageSeq;
  final double top;
  final String identity;
}

class _ChatComposerPane extends ConsumerStatefulWidget {
  const _ChatComposerPane({
    required this.session,
    this.channel,
    this.robotMenus = const <RobotMenu>[],
    required this.showCallActions,
    required this.showGroupCallAction,
    this.webStyle = false,
    required this.onAudioCallTap,
    required this.onVideoCallTap,
    required this.onGroupCallTap,
  });

  final ChatSession session;
  final WKChannel? channel;
  final List<RobotMenu> robotMenus;
  final bool showCallActions;
  final bool showGroupCallAction;
  final bool webStyle;
  final VoidCallback onAudioCallTap;
  final VoidCallback onVideoCallTap;
  final VoidCallback onGroupCallTap;

  @override
  ConsumerState<_ChatComposerPane> createState() => _ChatComposerPaneState();
}

class _ChatComposerPaneState extends ConsumerState<_ChatComposerPane> {
  final TextEditingController _textController = TextEditingController();
  late final ChatTextStickerConversion _textStickerConversion;
  ChatVoiceActionService? _voiceService;
  int _lastTypingReportAtSeconds = 0;
  WKChannel? _channel;
  double? _flameSliderValue;
  Robot? _activeInlineRobot;
  String? _robotInlinePlaceholder;
  List<RobotInlineQueryResult> _robotGifResults =
      const <RobotInlineQueryResult>[];
  List<ChatGifPanelResult> _panelGifResults = const <ChatGifPanelResult>[];
  String? _panelGifErrorText;
  Future<ChatExpressionRegistrySnapshot>? _expressionRegistryFuture;
  int _robotInlineRequestToken = 0;
  bool _isSubmittingComposer = false;

  @override
  void initState() {
    super.initState();
    _channel = widget.channel;
    _textStickerConversion = ChatTextStickerConversion();
  }

  @override
  void didUpdateWidget(covariant _ChatComposerPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != oldWidget.channel && widget.channel != null) {
      _channel = widget.channel;
      _flameSliderValue = null;
    }
    if (widget.session != oldWidget.session) {
      _clearRobotInlineState();
      _panelGifResults = const <ChatGifPanelResult>[];
      _panelGifErrorText = null;
      _expressionRegistryFuture = null;
    }
  }

  @override
  void dispose() {
    final voiceService = _voiceService;
    if (voiceService != null &&
        _isVoiceSessionActive(voiceService.recordingStateListenable.value)) {
      unawaited(voiceService.cancelRecording());
    }
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composerState = ref.watch(chatComposerProvider(widget.session));
    final composerController = ref.read(
      chatComposerProvider(widget.session).notifier,
    );
    final mentionsState = ref.watch(
      chatMentionsControllerProvider(widget.session),
    );
    final mentionsController = ref.read(
      chatMentionsControllerProvider(widget.session).notifier,
    );
    final voiceService = ref.watch(chatVoiceActionServiceProvider);
    _voiceService = voiceService;
    final registry = ref.read(slotRegistryProvider);
    final slotContext = ChatToolbarSlotContext(
      isGroup: widget.session.channelType == WKChannelType.group,
      showVoiceInput: composerState.showVoiceInput,
      showEmojiPanel: composerState.showFacePanel,
      showFunctionPanel: composerState.showFunctionPanel,
      isMobile: PlatformUtils.isMobile,
      isDesktop: PlatformUtils.isDesktop,
      isWeb: PlatformUtils.isWeb,
    );
    final toolbarItems = resolveChatToolbarItems(registry, slotContext);
    final functionItems = resolveChatFunctionItems(registry, slotContext);
    final currentChannel = _channel ?? widget.channel;
    final flameEnabled = _isChannelFlameEnabled(currentChannel);

    _syncText(composerState.text);

    final composer = Stack(
      children: [
        ChatComposer(
          header: _buildComposerHeader(composerState, composerController),
          robotInlineHeader: _buildRobotInlineHeader(
            composerState,
            mentionsState,
            composerController,
            mentionsController,
          ),
          webStyle: widget.webStyle,
          showToolbarRow: true,
          inputRow: _buildComposerInputRow(
            composerState: composerState,
            composerController: composerController,
            mentionsController: mentionsController,
            voiceService: voiceService,
            flameEnabled: flameEnabled,
          ),
          toolbarRow: _buildComposerToolbarRow(
            composerState: composerState,
            composerController: composerController,
            mentionsController: mentionsController,
            toolbarItems: toolbarItems,
          ),
          panel: _buildPanel(
            composerState,
            functionItems,
            currentChannel,
            composerController,
            mentionsController,
          ),
        ),
        ValueListenableBuilder<ChatVoiceRecordingState>(
          valueListenable: voiceService.recordingStateListenable,
          builder: (context, voiceState, _) {
            return ChatVoiceRecordOverlay(state: voiceState);
          },
        ),
      ],
    );
    return ChatDesktopDropTarget(
      enabled: PlatformUtils.isDesktop,
      onFilesDropped: (files) => _handleDroppedFiles(files, composerController),
      child: composer,
    );
  }

  Widget? _buildComposerHeader(
    ChatComposerState composerState,
    ChatComposerController composerController,
  ) {
    if (composerState.pendingEditMessageId != null) {
      return ChatEditPreviewStrip(
        previewText: composerState.pendingEditPreview?.trim().isNotEmpty == true
            ? composerState.pendingEditPreview!.trim()
            : composerState.text.trim(),
        onClose: () {
          composerController.clearPendingEdit(clearText: true);
          ref
              .read(chatSceneControllerProvider(widget.session).notifier)
              .restoreNormal();
        },
      );
    }
    if (composerState.pendingReplyMessageId != null) {
      return ChatReplyPreviewStrip(
        previewText:
            composerState.pendingReplyPreview?.trim().isNotEmpty == true
            ? composerState.pendingReplyPreview!.trim()
            : _replyFallbackTitle,
        onClose: () {
          composerController.clearPendingReply();
          ref
              .read(chatSceneControllerProvider(widget.session).notifier)
              .restoreNormal();
        },
      );
    }
    return null;
  }

  Widget? _buildRobotInlineHeader(
    ChatComposerState composerState,
    ChatMentionsState mentionsState,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final headers = <Widget>[];
    if (!composerState.showVoiceInput &&
        mentionsState.isActive &&
        mentionsState.suggestions.isNotEmpty) {
      headers.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MentionSuggestionOverlay(
              suggestions: mentionsState.suggestions,
              selectedIndex: 0,
              onSelected: (suggestion) {
                final selectionBaseOffset =
                    _textController.selection.baseOffset;
                final cursorOffset = selectionBaseOffset < 0
                    ? _textController.text.length
                    : selectionBaseOffset;
                final result = mentionsController.applySelection(
                  _textController.text,
                  cursorOffset: cursorOffset,
                  suggestion: suggestion,
                );
                _applyComposerValue(
                  TextEditingValue(
                    text: result.text,
                    selection: TextSelection.collapsed(
                      offset: result.cursorOffset,
                    ),
                  ),
                  composerController,
                  mentionsController,
                  reportTyping: false,
                );
              },
            ),
          ),
        ),
      );
    }
    if (!composerState.showVoiceInput &&
        _robotGifResults.isEmpty &&
        _robotInlinePlaceholder?.trim().isNotEmpty == true) {
      headers.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey<String>('chat-robot-placeholder'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: WKColors.surfaceSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _robotInlinePlaceholder!.trim(),
                style: const TextStyle(
                  fontSize: 12,
                  color: WKColors.color999,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }
    if (headers.isEmpty) {
      return null;
    }
    return Column(mainAxisSize: MainAxisSize.min, children: headers);
  }

  Widget _buildComposerInputRow({
    required ChatComposerState composerState,
    required ChatComposerController composerController,
    required ChatMentionsController mentionsController,
    required ChatVoiceActionService voiceService,
    required bool flameEnabled,
  }) {
    final canSend =
        composerState.text.trim().isNotEmpty && !_isSubmittingComposer;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileWarmStyle =
            PlatformUtils.isMobile && constraints.maxWidth < 420;
        final compact =
            constraints.maxWidth.isFinite && constraints.maxWidth < 360;
        final gap = compact ? 6.0 : 8.0;
        final actionExtent = isMobileWarmStyle
            ? _mobileComposerActionButtonExtent
            : compact
            ? 42.0
            : _composerActionButtonExtent;
        final iconExtent = isMobileWarmStyle
            ? _mobileComposerActionIconExtent
            : compact
            ? 22.0
            : _composerActionIconExtent;
        final sendWidth = isMobileWarmStyle
            ? _mobileComposerSendButtonWidth
            : actionExtent;
        final sendHeight = actionExtent;
        final inputRadius = BorderRadius.circular(isMobileWarmStyle ? 14 : 24);
        late final Widget inlineActionButton;
        if (isMobileWarmStyle) {
          inlineActionButton = _ComposerToolbarButton(
            key: const ValueKey<String>('chat-compose-plus-button'),
            asset: WKReferenceAssets.chatAdd,
            extent: actionExtent,
            artworkExtent: iconExtent,
            fit: BoxFit.contain,
            warmStyle: true,
            onTap: composerController.toggleFunctionPanel,
          );
        } else if (flameEnabled) {
          inlineActionButton = _ComposerToolbarButton(
            key: const ValueKey<String>('chat-flame-toggle-button'),
            asset: WKReferenceAssets.flameSmall,
            extent: actionExtent,
            artworkExtent: iconExtent,
            fit: BoxFit.contain,
            onTap: composerController.toggleFlamePanel,
          );
        } else {
          inlineActionButton = _ComposerToolbarButton(
            key: const ValueKey<String>('chat-compose-rich-text-button'),
            asset: WKReferenceAssets.chatRichEdit,
            extent: actionExtent,
            artworkExtent: iconExtent,
            fit: BoxFit.contain,
            onTap: () => unawaited(
              _executeChatAction(
                ChatActionId.composeRichText,
                composerController,
              ),
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: composerState.showVoiceInput
                  ? ValueListenableBuilder<ChatVoiceRecordingState>(
                      valueListenable: voiceService.recordingStateListenable,
                      builder: (context, voiceState, _) {
                        return ChatVoicePressHoldButton(
                          key: const ValueKey<String>(
                            'chat-voice-record-button',
                          ),
                          isRecording: _isVoiceSessionActive(voiceState),
                          onHoldStart: _startVoiceRecording,
                          onCancelZoneChanged: voiceService.setCancelCandidate,
                          onHoldRelease: (isInCancelZone) =>
                              _finishVoiceRecording(
                                composerController,
                                shouldSend: !isInCancelZone,
                              ),
                          onHoldAbort: _cancelVoiceRecording,
                        );
                      },
                    )
                  : CallbackShortcuts(
                      bindings: <ShortcutActivator, VoidCallback>{
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          shift: true,
                        ): () => _insertTextAtCursor(
                          '\n',
                          composerController,
                          mentionsController,
                        ),
                        const SingleActivator(
                          LogicalKeyboardKey.numpadEnter,
                          shift: true,
                        ): () => _insertTextAtCursor(
                          '\n',
                          composerController,
                          mentionsController,
                        ),
                        const SingleActivator(LogicalKeyboardKey.enter): () =>
                            _handleKeyboardSend(
                              composerController,
                              mentionsController,
                            ),
                        const SingleActivator(
                          LogicalKeyboardKey.numpadEnter,
                        ): () => _handleKeyboardSend(
                          composerController,
                          mentionsController,
                        ),
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: isMobileWarmStyle ? actionExtent : 0,
                        ),
                        child: TextField(
                          key: const ValueKey<String>('chat-input-field'),
                          controller: _textController,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontFamily: WKFontFamily.primary,
                                fontFamilyFallback:
                                    WKTypography.fontFamilyFallback,
                              ),
                          onTap: composerController.hidePanels,
                          onChanged: (value) => _handleTextChanged(
                            value,
                            composerController,
                            mentionsController,
                          ),
                          decoration: InputDecoration(
                            hintText: '\u8f93\u5165\u6d88\u606f',
                            isDense: isMobileWarmStyle,
                            border: OutlineInputBorder(
                              borderRadius: inputRadius,
                              borderSide: isMobileWarmStyle
                                  ? const BorderSide(
                                      color: WKWebColors.borderWarm,
                                      width: 1.2,
                                    )
                                  : BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: inputRadius,
                              borderSide: isMobileWarmStyle
                                  ? const BorderSide(
                                      color: WKWebColors.borderWarm,
                                      width: 1.2,
                                    )
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: inputRadius,
                              borderSide: isMobileWarmStyle
                                  ? const BorderSide(
                                      color: WKWebColors.action,
                                      width: 1.4,
                                    )
                                  : BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isMobileWarmStyle
                                ? WKWebColors.surface
                                : WKColors.surfaceSoft,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isMobileWarmStyle
                                  ? 16
                                  : compact
                                  ? 12
                                  : 16,
                              vertical: isMobileWarmStyle ? 14 : 8,
                            ),
                          ),
                          maxLines: isMobileWarmStyle ? 3 : 4,
                          minLines: 1,
                        ),
                      ),
                    ),
            ),
            SizedBox(width: gap),
            inlineActionButton,
            if (!composerState.showVoiceInput) ...[
              SizedBox(width: gap),
              _ComposerSendButton(
                enabled: canSend,
                width: sendWidth,
                height: sendHeight,
                iconExtent: iconExtent,
                warmStyle: isMobileWarmStyle,
                onTap: canSend
                    ? () => _handleSendPressed(
                        composerController,
                        mentionsController,
                      )
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  void _handleKeyboardSend(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    if (_isSubmittingComposer || _textController.text.trim().isEmpty) {
      return;
    }
    unawaited(_handleSendPressed(composerController, mentionsController));
  }

  Widget _buildComposerToolbarRow({
    required ChatComposerState composerState,
    required ChatComposerController composerController,
    required ChatMentionsController mentionsController,
    required List<ChatToolBarMenu> toolbarItems,
  }) {
    final toolbarButtons = <Widget>[];
    var insertedCallButtons = false;

    void addButton(Widget button) {
      if (toolbarButtons.isNotEmpty) {
        toolbarButtons.add(const SizedBox(width: 8));
      }
      toolbarButtons.add(button);
    }

    void addCallButtons() {
      if (insertedCallButtons) {
        return;
      }
      insertedCallButtons = true;
      if (widget.showCallActions) {
        addButton(
          _ComposerCallToolbarButton(
            key: const ValueKey<String>('chat-call-audio-button'),
            decorationKey: const ValueKey<String>('chat-call-audio-decoration'),
            tooltip: _voiceTooltip,
            asset: WKReferenceAssets.chatCallVoice,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF36E6B3), Color(0xFF16A76C)],
            ),
            onTap: widget.onAudioCallTap,
          ),
        );
        addButton(
          _ComposerCallToolbarButton(
            key: const ValueKey<String>('chat-call-video-button'),
            decorationKey: const ValueKey<String>('chat-call-video-decoration'),
            tooltip: _videoTooltip,
            asset: WKReferenceAssets.chatCallVideo,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF8C7BFF), Color(0xFFFF6FB1)],
            ),
            onTap: widget.onVideoCallTap,
          ),
        );
      }
      if (widget.showGroupCallAction) {
        addButton(
          _ComposerCallToolbarButton(
            key: const ValueKey<String>('chat-group-call-button'),
            decorationKey: const ValueKey<String>('chat-call-group-decoration'),
            tooltip: _groupCallTooltip,
            asset: WKReferenceAssets.chatCallVideo,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
            ),
            onTap: widget.onGroupCallTap,
          ),
        );
      }
    }

    for (var index = 0; index < toolbarItems.length; index++) {
      final item = toolbarItems[index];
      if (item.sid == 'wk_chat_toolbar_more') {
        addCallButtons();
      }
      addButton(
        _ComposerToolbarButton(
          key: ValueKey<String>('chat-toolbar-${item.sid}'),
          asset: item.icon ?? '',
          onTap: () => unawaited(
            _handleToolbarTap(item, composerController, mentionsController),
          ),
        ),
      );
      if (item.sid == 'wk_chat_toolbar_album') {
        addCallButtons();
      }
    }

    addCallButtons();

    if (widget.robotMenus.isNotEmpty) {
      addButton(
        _ComposerToolbarButton(
          key: const ValueKey<String>('chat-robot-menu-button'),
          asset: composerState.showRobotMenuPanel
              ? WKReferenceAssets.chatMenuClose
              : WKReferenceAssets.chatMenu,
          onTap: composerController.toggleRobotMenuPanel,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: toolbarButtons),
      ),
    );
  }

  void _syncText(String nextText) {
    if (_textController.text == nextText) {
      return;
    }
    _textController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _handleTextChanged(
    String value,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    composerController.updateText(value);
    final selectionBaseOffset = _textController.selection.baseOffset;
    final cursorOffset = selectionBaseOffset < 0
        ? value.length
        : selectionBaseOffset;
    unawaited(
      mentionsController.updateFromText(value, cursorOffset: cursorOffset),
    );
    unawaited(_handleRobotInlineInput(value));
    _reportTypingIfNeeded(value);
  }

  void _applyComposerValue(
    TextEditingValue value,
    ChatComposerController composerController,
    ChatMentionsController mentionsController, {
    bool reportTyping = true,
  }) {
    _textController.value = value;
    composerController.updateText(value.text);
    final selectionBaseOffset = value.selection.baseOffset;
    final cursorOffset = selectionBaseOffset < 0
        ? value.text.length
        : selectionBaseOffset;
    unawaited(
      mentionsController.updateFromText(value.text, cursorOffset: cursorOffset),
    );
    unawaited(_handleRobotInlineInput(value.text));
    if (reportTyping) {
      _reportTypingIfNeeded(value.text);
    }
  }

  void _insertEmoji(
    String emoji,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    _insertTextAtCursor(emoji, composerController, mentionsController);
  }

  void _insertTextAtCursor(
    String insertedText,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final currentValue = _textController.value;
    final selection = currentValue.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, currentValue.text.length).toInt()
        : currentValue.text.length;
    final end = selection.isValid
        ? selection.end.clamp(0, currentValue.text.length).toInt()
        : currentValue.text.length;
    final replaceStart = start < end ? start : end;
    final replaceEnd = start < end ? end : start;
    final nextText = currentValue.text.replaceRange(
      replaceStart,
      replaceEnd,
      insertedText,
    );
    _applyComposerValue(
      TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(
          offset: replaceStart + insertedText.length,
        ),
      ),
      composerController,
      mentionsController,
    );
  }

  void _deletePreviousComposerCharacter(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final currentValue = _textController.value;
    final selection = currentValue.selection;
    if (!selection.isValid) {
      return;
    }

    final start = selection.start.clamp(0, currentValue.text.length).toInt();
    final end = selection.end.clamp(0, currentValue.text.length).toInt();
    final replaceStart = start < end ? start : end;
    final replaceEnd = start < end ? end : start;

    if (replaceStart != replaceEnd) {
      final nextText = currentValue.text.replaceRange(
        replaceStart,
        replaceEnd,
        '',
      );
      _applyComposerValue(
        TextEditingValue(
          text: nextText,
          selection: TextSelection.collapsed(offset: replaceStart),
        ),
        composerController,
        mentionsController,
      );
      return;
    }

    if (replaceStart == 0) {
      return;
    }

    final prefix = currentValue.text.substring(0, replaceStart);
    final previousCharacter = prefix.characters.last;
    final deletionStart = replaceStart - previousCharacter.length;
    final nextText = currentValue.text.replaceRange(
      deletionStart,
      replaceStart,
      '',
    );
    _applyComposerValue(
      TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: deletionStart),
      ),
      composerController,
      mentionsController,
    );
  }

  void _reportTypingIfNeeded(String value) {
    if (value.isEmpty) {
      return;
    }
    final nowSeconds = ref.read(chatTypingNowProvider)();
    if (nowSeconds - _lastTypingReportAtSeconds < 5) {
      return;
    }
    _lastTypingReportAtSeconds = nowSeconds;
    unawaited(_sendTypingIfAllowed());
  }

  Future<void> _sendTypingIfAllowed() async {
    try {
      await ref
          .read(chatTypingGatewayProvider)
          .sendIfAllowed(
            channelId: widget.session.channelId,
            channelType: widget.session.channelType,
          );
    } catch (_) {
      // Android silently ignores typing report failures.
    }
  }

  Future<void> _handleRobotInlineInput(String value) async {
    final directive = _RobotInlineDirective.parse(value);
    if (directive == null) {
      _clearRobotInlineState();
      return;
    }

    final requestToken = ++_robotInlineRequestToken;
    Robot? robot = _activeInlineRobot;
    final normalizedUsername = directive.username.toLowerCase();
    if (robot == null || robot.username.toLowerCase() != normalizedUsername) {
      robot = _findRobotByUsername(normalizedUsername);
      if (robot == null) {
        final synced = await RobotService.instance.syncRobots(
          targets: <RobotSyncTarget>[
            RobotSyncTarget(username: normalizedUsername),
          ],
          forceRefresh: true,
        );
        if (!mounted || requestToken != _robotInlineRequestToken) {
          return;
        }
        for (final candidate in synced) {
          if (candidate.username.toLowerCase() == normalizedUsername) {
            robot = candidate;
            break;
          }
        }
      }
    }

    if (!mounted || requestToken != _robotInlineRequestToken) {
      return;
    }

    if (robot == null) {
      _clearRobotInlineState();
      return;
    }

    if (directive.isGifQuery && directive.query.isNotEmpty) {
      final results = await RobotService.instance.searchGifs(
        query: directive.query,
        username: robot.username,
        channelId: widget.session.channelId,
        channelType: widget.session.channelType,
      );
      if (!mounted || requestToken != _robotInlineRequestToken) {
        return;
      }
      setState(() {
        _activeInlineRobot = robot;
        _robotInlinePlaceholder = null;
        _robotGifResults = List<RobotInlineQueryResult>.unmodifiable(results);
      });
      return;
    }

    setState(() {
      _activeInlineRobot = robot;
      _robotInlinePlaceholder =
          directive.hasSeparator && directive.query.isEmpty
          ? robot?.placeholder?.trim()
          : null;
      _robotGifResults = const <RobotInlineQueryResult>[];
    });
  }

  Robot? _findRobotByUsername(String username) {
    for (final robot in RobotService.instance.getAllRobots()) {
      if (robot.username.toLowerCase() == username) {
        return robot;
      }
    }
    return null;
  }

  void _clearRobotInlineState() {
    _robotInlineRequestToken += 1;
    if (_activeInlineRobot == null && _robotGifResults.isEmpty) {
      return;
    }
    setState(() {
      _activeInlineRobot = null;
      _robotInlinePlaceholder = null;
      _robotGifResults = const <RobotInlineQueryResult>[];
    });
  }

  Future<void> _handleToolbarTap(
    ChatToolBarMenu item,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) async {
    switch (item.sid) {
      case 'wk_chat_toolbar_emoji':
        composerController.toggleFacePanel(initialCategoryId: 'emoji:0');
        break;
      case 'wk_chat_toolbar_mention':
        if (composerController.isVoiceInputVisible) {
          final voiceService = _voiceService;
          final voiceState = voiceService?.recordingStateListenable.value;
          if (voiceState != null && _isVoiceSessionActive(voiceState)) {
            await _cancelVoiceRecording();
          }
          composerController.toggleVoiceInput();
        }
        _insertTextAtCursor('@', composerController, mentionsController);
        break;
      case 'wk_chat_toolbar_more':
        composerController.toggleFunctionPanel();
        break;
      case 'wk_chat_toolbar_album':
        await _sendPickedContent(
          await ref
              .read(chatMediaActionServiceProvider)
              .pickImage(
                context,
                channelId: widget.session.channelId,
                channelType: widget.session.channelType,
              ),
          composerController,
        );
        break;
      case 'wk_chat_toolbar_voice':
        final voiceService = _voiceService;
        final voiceState = voiceService?.recordingStateListenable.value;
        if (voiceState == null) {
          composerController.toggleVoiceInput();
          break;
        }
        if (_isVoiceSessionActive(voiceState)) {
          await _cancelVoiceRecording();
        }
        composerController.toggleVoiceInput();
        break;
    }
    item.onChecked?.call(!item.isSelected);
  }

  Future<void> _handleFunctionTap(
    String sid,
    ChatComposerController composerController,
  ) async {
    switch (sid) {
      case 'chooseImg':
        await _executeChatAction(ChatActionId.chooseImage, composerController);
        return;
      case 'chooseFile':
        await _executeChatAction(ChatActionId.chooseFile, composerController);
        return;
      case 'sendLocation':
        await _executeChatAction(ChatActionId.sendLocation, composerController);
        return;
      case 'chooseCard':
        await _executeChatAction(ChatActionId.chooseCard, composerController);
        return;
      case 'composeRichText':
        await _executeChatAction(
          ChatActionId.composeRichText,
          composerController,
        );
        return;
      case 'groupCall':
        await _pushGroupCallPicker(
          context: context,
          ref: ref,
          channelId: widget.session.channelId,
          channelType: widget.session.channelType,
          channelName: _channel?.channelName.trim().isNotEmpty == true
              ? _channel!.channelName.trim()
              : null,
        );
        return;
    }
  }

  Future<void> _executeChatAction(
    ChatActionId id,
    ChatComposerController composerController,
  ) async {
    final result = await ref
        .read(chatActionDispatcherProvider)
        .dispatch(
          id,
          ChatActionDispatchContext(
            context: context,
            channelId: widget.session.channelId,
            channelType: widget.session.channelType,
          ),
        );

    if (result is ChatActionMessageResult) {
      await _sendPickedContent(result.content, composerController);
    }
  }

  Future<void> _sendPickedContent(
    WKMessageContent? content,
    ChatComposerController composerController,
  ) async {
    if (content == null) {
      return;
    }
    _applyPendingReplyToContent(content);
    await ref
        .read(chatSceneGatewayProvider(widget.session))
        .sendMessageContent(
          content,
          channelId: widget.session.channelId,
          channelType: widget.session.channelType,
        );
    composerController.hidePanels();
    composerController.clearPendingReply();
    ref
        .read(chatSceneControllerProvider(widget.session).notifier)
        .restoreNormal();
  }

  Future<void> _handleDroppedFiles(
    List<ChatDroppedFileSelection> files,
    ChatComposerController composerController,
  ) async {
    if (files.isEmpty) {
      return;
    }
    try {
      for (final file in files) {
        final content = await ref
            .read(chatMediaActionServiceProvider)
            .buildDroppedFile(file);
        await _sendPickedContent(content, composerController);
      }
    } catch (_) {
      _showSendFailureFeedback();
    }
  }

  Future<void> _handleSendPressed(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) async {
    if (_isSubmittingComposer) {
      return;
    }
    final payload = composerController.buildSubmissionPayload();
    if (payload.text.isEmpty) {
      return;
    }

    _setComposerSubmitting(true);
    try {
      final editMessageId = payload.editMessageId?.trim() ?? '';
      if (editMessageId.isEmpty) {
        final handledByTextSticker = await _textStickerConversion.tryHandle(
          text: payload.text,
          replyMessageId: payload.replyMessageId,
          conversationContext: widget.session,
        );
        if (handledByTextSticker) {
          composerController.markSubmitSucceeded();
          mentionsController.clear();
          ref
              .read(chatSceneControllerProvider(widget.session).notifier)
              .restoreNormal();
          return;
        }
      }

      final content = WKTextContent(payload.text);
      final mentionedUids = _normalizedMentionedUids(
        ref.read(chatMentionsControllerProvider(widget.session)).mentionedUids,
      );
      if (mentionedUids.isNotEmpty) {
        content.mentionInfo = WKMentionInfo()..uids = mentionedUids;
      }

      if (editMessageId.isNotEmpty) {
        final editableMessage = _findEditableMessage(
          editMessageId,
          payload.editMessageSeq,
        );
        if (editableMessage == null) {
          return;
        }
        await ref
            .read(chatSceneGatewayProvider(widget.session))
            .editMessage(editableMessage, content);
      } else {
        _applyPendingReplyToContent(content, payload: payload);

        await ref
            .read(chatSceneGatewayProvider(widget.session))
            .sendMessageContent(
              content,
              channelId: widget.session.channelId,
              channelType: widget.session.channelType,
            );
      }

      composerController.markSubmitSucceeded();
      mentionsController.clear();
      ref
          .read(chatSceneControllerProvider(widget.session).notifier)
          .restoreNormal();
    } catch (_) {
      _showSendFailureFeedback();
    } finally {
      _setComposerSubmitting(false);
    }
  }

  void _setComposerSubmitting(bool value) {
    if (_isSubmittingComposer == value) {
      return;
    }
    if (!mounted) {
      _isSubmittingComposer = value;
      return;
    }
    setState(() {
      _isSubmittingComposer = value;
    });
  }

  void _showSendFailureFeedback() {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(_sendFailureRetainedFeedback)),
      );
  }

  Future<void> _startVoiceRecording() async {
    final voiceService = _voiceService;
    if (voiceService == null) {
      return;
    }
    if (_isVoiceSessionActive(voiceService.recordingStateListenable.value)) {
      return;
    }
    final started = await voiceService.startRecording();
    if (!mounted) {
      return;
    }
    if (started) {
      return;
    }

    final state = voiceService.recordingStateListenable.value;
    final message = switch (state.phase) {
      ChatVoiceRecordingPhase.permissionDenied =>
        state.errorMessage?.trim().isNotEmpty == true
            ? state.errorMessage!.trim()
            : _voicePermissionDeniedFeedback,
      ChatVoiceRecordingPhase.sendFailed =>
        state.errorMessage?.trim().isNotEmpty == true
            ? state.errorMessage!.trim()
            : _voiceStartFailedFallback,
      _ => null,
    };
    if (message != null) {
      _showVoiceFeedback(message);
    }
  }

  Future<void> _finishVoiceRecording(
    ChatComposerController composerController, {
    required bool shouldSend,
  }) async {
    final voiceService = _voiceService;
    if (voiceService == null) {
      return;
    }
    final currentState = voiceService.recordingStateListenable.value;
    if (!_isVoiceSessionActive(currentState)) {
      // Failed starts already surfaced feedback in _startVoiceRecording.
      return;
    }
    final result = await voiceService.stopRecording(shouldSend: shouldSend);
    if (!mounted) {
      return;
    }
    switch (result) {
      case ChatVoiceReadyResult():
        await _sendPickedContent(result.content, composerController);
        return;
      case ChatVoiceDiscardedResult():
        if (result.reason == ChatVoiceDiscardReason.tooShort) {
          _showVoiceFeedback(_voiceTooShortFeedback);
        } else if (result.reason == ChatVoiceDiscardReason.permissionDenied) {
          _showVoiceFeedback(_voicePermissionDeniedFeedback);
        }
        return;
      case ChatVoiceStopFailure():
        _showVoiceFeedback(
          result.message.trim().isNotEmpty
              ? result.message.trim()
              : _voiceStartFailedFallback,
        );
        return;
    }
  }

  Future<void> _cancelVoiceRecording() async {
    final voiceService = _voiceService;
    if (voiceService == null) {
      return;
    }
    if (!_isVoiceSessionActive(voiceService.recordingStateListenable.value)) {
      return;
    }
    await voiceService.cancelRecording();
  }

  void _showVoiceFeedback(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.trim())));
  }

  bool _isVoiceSessionActive(ChatVoiceRecordingState state) {
    return state.phase == ChatVoiceRecordingPhase.recording ||
        state.phase == ChatVoiceRecordingPhase.cancelCandidate ||
        state.phase == ChatVoiceRecordingPhase.stopping;
  }

  void _applyPendingReplyToContent(
    WKMessageContent content, {
    ChatComposerSubmissionPayload? payload,
  }) {
    final replyPayload = payload ?? composerStatePayload;
    final replyReference = replyPayload.replyMessageId?.trim() ?? '';
    if (replyReference.isEmpty) {
      return;
    }
    final replyMessage = _findReplyMessage(replyReference);
    if (replyMessage != null) {
      content.reply = buildReplyForMessage(
        replyMessage,
        currentUid: WKIM.shared.options.uid ?? '',
      );
      return;
    }
    content.reply = WKReply()
      ..rootMid = replyReference
      ..messageId = replyReference
      ..payload = WKTextContent(
        replyPayload.replyPreview?.trim().isNotEmpty == true
            ? replyPayload.replyPreview!.trim()
            : _replyFallbackTitle,
      );
  }

  ChatComposerSubmissionPayload get composerStatePayload => ref
      .read(chatComposerProvider(widget.session).notifier)
      .buildSubmissionPayload();

  WKMsg? _findReplyMessage(String reference) {
    for (final item in ref.read(chatViewportProvider(widget.session)).items) {
      final message = item.message;
      if (message.messageID.trim() == reference ||
          message.clientMsgNO.trim() == reference ||
          item.identity == reference ||
          item.identity == 'mid:$reference' ||
          item.identity == 'cid:$reference') {
        return message;
      }
    }
    return null;
  }

  WKMsg? _findEditableMessage(String messageId, int? messageSeq) {
    final normalizedMessageId = messageId.trim();
    for (final item in ref.read(chatViewportProvider(widget.session)).items) {
      final message = item.message;
      if (message.messageID.trim() == normalizedMessageId) {
        return message;
      }
      if (messageSeq != null &&
          messageSeq > 0 &&
          message.messageSeq == messageSeq) {
        return message;
      }
    }
    return null;
  }

  List<String> _normalizedMentionedUids(List<String> mentionedUids) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final uid in mentionedUids) {
      final trimmed = uid.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  Widget _buildPanel(
    ChatComposerState composerState,
    List<ChatFunctionMenu> functionItems,
    WKChannel? channel,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    if (_robotGifResults.isNotEmpty) {
      return _buildRobotGifPanel(composerController);
    }

    if (composerState.showFlamePanel == true &&
        _isChannelFlameEnabled(channel)) {
      return _buildFlamePanel(channel, composerController);
    }

    if (composerState.showRobotMenuPanel == true &&
        widget.robotMenus.isNotEmpty) {
      return _buildRobotMenuPanel(composerController);
    }

    if (composerState.showFunctionPanel == true) {
      return _buildFunctionPanel(functionItems);
    }

    if (composerState.showFacePanel == true) {
      return _buildExpressionPanel(
        composerState,
        composerController,
        mentionsController,
      );
    }

    return const SizedBox.shrink(key: ValueKey<String>('panel-none'));
  }

  Widget _buildExpressionPanel(
    ChatComposerState composerState,
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
  ) {
    final expressionRegistry = ref.read(chatExpressionRegistryProvider);
    return FutureBuilder<ChatExpressionRegistrySnapshot>(
      future: _expressionRegistryFuture ??= expressionRegistry.load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Text(
                'expression load error: ${snapshot.error}',
                key: const ValueKey<String>('chat-expression-panel-error'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        return ChatExpressionPanel(
          snapshot: snapshot.data!,
          activeCategoryId: composerState.activeExpressionCategoryId,
          gifResults: _panelGifResults,
          gifErrorText: _panelGifErrorText,
          onCategorySelected: (categoryId) {
            composerController.selectExpressionCategory(categoryId);
            if (categoryId != 'gif') {
              setState(() {
                _panelGifResults = const <ChatGifPanelResult>[];
                _panelGifErrorText = null;
              });
            }
          },
          onRecentSelected: (recent) => unawaited(
            _handleRecentSelection(
              composerController,
              mentionsController,
              expressionRegistry,
              recent,
            ),
          ),
          onEmojiSelected: (entry) => unawaited(
            _handlePanelEmojiTap(
              composerController,
              mentionsController,
              expressionRegistry,
              entry,
            ),
          ),
          onStickerSelected: (_, sticker) => unawaited(
            _handleStickerTap(composerController, expressionRegistry, sticker),
          ),
          onGifQueryChanged: (query) =>
              unawaited(_handlePanelGifQueryChanged(query, composerController)),
          onGifSelected: (result) => unawaited(
            _handlePanelGifTap(composerController, expressionRegistry, result),
          ),
          onBackspaceTap: () => _deletePreviousComposerCharacter(
            composerController,
            mentionsController,
          ),
        );
      },
    );
  }

  Future<void> _handleStickerTap(
    ChatComposerController composerController,
    ChatExpressionRegistry registry,
    ChatStickerDefinition sticker,
  ) async {
    final content = WKStickerContent(
      packId: sticker.packId,
      stickerId: sticker.stickerId,
      packVersion: 1,
      title: sticker.title,
      mimeType: sticker.mimeType,
      width: sticker.width,
      height: sticker.height,
      loopCount: sticker.loopCount,
      previewKey: sticker.previewKey,
      animationKey: sticker.animationKey,
      fallbackText: sticker.fallbackText,
    );
    await _sendPickedContent(content, composerController);
    await registry.rememberSticker(sticker);
    _refreshExpressionRegistry(registry);
  }

  Future<void> _handlePanelGifTap(
    ChatComposerController composerController,
    ChatExpressionRegistry registry,
    ChatGifPanelResult result,
  ) async {
    final content = WKGifContent(width: result.width, height: result.height)
      ..url = result.url;
    await _sendPickedContent(content, composerController);
    await registry.rememberGif(
      title: result.title,
      url: result.url,
      width: result.width,
      height: result.height,
    );
    _refreshExpressionRegistry(registry);
  }

  Future<void> _handlePanelEmojiTap(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
    ChatExpressionRegistry registry,
    AndroidEmojiEntry entry,
  ) async {
    _insertEmoji(entry.tag, composerController, mentionsController);
    await registry.rememberEmoji(entry);
    _refreshExpressionRegistry(registry);
  }

  Future<void> _handleRecentSelection(
    ChatComposerController composerController,
    ChatMentionsController mentionsController,
    ChatExpressionRegistry registry,
    ChatExpressionRecentRecord recent,
  ) async {
    switch (recent.kind) {
      case ChatExpressionKind.emoji:
        _insertEmoji(recent.itemId, composerController, mentionsController);
        await registry.rememberRecent(recent);
        _refreshExpressionRegistry(registry);
        return;
      case ChatExpressionKind.sticker:
        await _handleStickerTap(
          composerController,
          registry,
          ChatStickerDefinition(
            packId: recent.categoryId.replaceFirst('sticker:', ''),
            stickerId: recent.itemId,
            title: recent.itemId,
            previewKey: recent.previewKey,
            animationKey: recent.animationKey,
            mimeType: 'image/webp',
            width: recent.width,
            height: recent.height,
            loopCount: 0,
            fallbackText: recent.displayText,
          ),
        );
        return;
      case ChatExpressionKind.gif:
        await _handlePanelGifTap(
          composerController,
          registry,
          ChatGifPanelResult(
            url: recent.gifUrl,
            width: recent.width,
            height: recent.height,
            title: recent.itemId,
          ),
        );
        return;
    }
  }

  Future<void> _handlePanelGifQueryChanged(
    String query,
    ChatComposerController composerController,
  ) async {
    composerController.updateExpressionSearchQuery(query);
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      setState(() {
        _panelGifResults = const <ChatGifPanelResult>[];
        _panelGifErrorText = null;
      });
      return;
    }

    try {
      final results = await ref
          .read(chatGifPanelServiceProvider)
          .search(normalizedQuery, session: widget.session);
      if (!mounted) {
        return;
      }
      setState(() {
        _panelGifResults = results;
        _panelGifErrorText = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _panelGifResults = const <ChatGifPanelResult>[];
        _panelGifErrorText =
            '\u52a8\u56fe\u52a0\u8f7d\u5931\u8d25\uff0c\u8bf7\u91cd\u8bd5';
      });
    }
  }

  void _refreshExpressionRegistry(ChatExpressionRegistry registry) {
    if (!mounted) {
      return;
    }
    setState(() {
      _expressionRegistryFuture = registry.load();
    });
  }

  Widget _buildRobotGifPanel(ChatComposerController composerController) {
    return Container(
      key: const ValueKey<String>('chat-robot-gif-panel'),
      width: double.infinity,
      color: WKColors.homeBg,
      constraints: const BoxConstraints(maxHeight: 220),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: GridView.builder(
        shrinkWrap: true,
        itemCount: _robotGifResults.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final result = _robotGifResults[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey<String>('chat-robot-gif-item-$index'),
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  unawaited(_handleRobotGifTap(result, composerController)),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: WKColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WKColors.layoutColorSelected),
                ),
                child: Center(
                  child: Text(
                    result.contentUrl?.trim().isNotEmpty == true
                        ? '\u52a8\u56fe'
                        : '...',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: WKColors.colorDark,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleRobotGifTap(
    RobotInlineQueryResult result,
    ChatComposerController composerController,
  ) async {
    final gifUrl = result.contentUrl?.trim() ?? '';
    if (gifUrl.isEmpty) {
      return;
    }
    final content = WKGifContent(
      width: _readRobotGifDimension(result.extraData['width']),
      height: _readRobotGifDimension(result.extraData['height']),
    )..url = gifUrl;
    await _sendPickedContent(content, composerController);
    _textController.clear();
    composerController.updateText('');
    _clearRobotInlineState();
  }

  Widget _buildRobotMenuPanel(ChatComposerController composerController) {
    return Container(
      key: const ValueKey<String>('panel-robot-menu'),
      width: double.infinity,
      color: WKColors.homeBg,
      constraints: const BoxConstraints(maxHeight: 180),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        itemCount: widget.robotMenus.length,
        separatorBuilder: (_, _) =>
            const Divider(height: 1, color: WKColors.layoutColorSelected),
        itemBuilder: (context, index) {
          final menu = widget.robotMenus[index];
          return ListTile(
            key: ValueKey<String>(
              'chat-robot-menu-item-${menu.robotId}-${menu.cmd}',
            ),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            title: Text(
              menu.remark.trim().isNotEmpty ? menu.remark.trim() : menu.cmd,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: WKColors.colorDark,
              ),
            ),
            subtitle: menu.remark.trim().isNotEmpty
                ? Text(
                    menu.cmd,
                    style: const TextStyle(
                      fontSize: 12,
                      color: WKColors.color999,
                    ),
                  )
                : null,
            onTap: () =>
                unawaited(_handleRobotMenuTap(menu, composerController)),
          );
        },
      ),
    );
  }

  Future<void> _handleRobotMenuTap(
    RobotMenu menu,
    ChatComposerController composerController,
  ) async {
    final content = WKTextContent(menu.cmd)..robotID = menu.robotId;
    final entity = WKMsgEntity()
      ..offset = 0
      ..length = menu.cmd.length
      ..type = 'bot_command';
    content.entities = <WKMsgEntity>[entity];

    await ref
        .read(chatSceneGatewayProvider(widget.session))
        .sendMessageContent(
          content,
          channelId: widget.session.channelId,
          channelType: widget.session.channelType,
          channelName: _channel?.channelName.trim().isNotEmpty == true
              ? _channel!.channelName.trim()
              : null,
        );
    composerController.hidePanels();
    ref
        .read(chatSceneControllerProvider(widget.session).notifier)
        .restoreNormal();
  }

  Widget _buildFlamePanel(
    WKChannel? channel,
    ChatComposerController composerController,
  ) {
    final flameSecond = _channelFlameSecond(channel);
    final sliderValue =
        _flameSliderValue ?? _sliderValueForFlameSecond(flameSecond);
    return Container(
      key: const ValueKey<String>('chat-flame-panel'),
      width: double.infinity,
      color: WKColors.homeBg,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    WKReferenceAssets.image(
                      WKReferenceAssets.flameSmall,
                      width: 16,
                      height: 16,
                      tint: WKColors.color999,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _flameDescription(flameSecond),
                        key: const ValueKey<String>('chat-flame-description'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: WKColors.color999,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    inactiveTrackColor: WKColors.color999.withValues(
                      alpha: 0.2,
                    ),
                    activeTrackColor: WKColors.brand500,
                    thumbColor: WKColors.brand500,
                    overlayColor: WKColors.brand500.withValues(alpha: 0.1),
                  ),
                  child: Slider(
                    key: const ValueKey<String>('chat-flame-duration-slider'),
                    value: sliderValue,
                    min: 0,
                    max: (_flameSecondOptions.length - 1).toDouble(),
                    divisions: _flameSecondOptions.length - 1,
                    onChanged: (value) {
                      setState(() {
                        _flameSliderValue = value;
                      });
                    },
                    onChangeEnd: (value) {
                      final flameSecond = _flameSecondForSliderValue(value);
                      unawaited(_updateFlameSecond(flameSecond));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            key: const ValueKey<String>('chat-flame-enabled-switch'),
            value: _isChannelFlameEnabled(channel),
            onChanged: (value) =>
                unawaited(_updateFlameEnabled(value, composerController)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFlameEnabled(
    bool enabled,
    ChatComposerController composerController,
  ) async {
    try {
      if (widget.session.channelType == WKChannelType.personal) {
        await UserApi.instance.updateUserSetting(
          widget.session.channelId,
          'flame',
          enabled ? 1 : 0,
        );
      } else {
        await GroupApi.instance.updateGroupSetting(
          widget.session.channelId,
          'flame',
          enabled ? 1 : 0,
        );
      }

      final channel =
          _channel ??
          widget.channel ??
          WKChannel(widget.session.channelId, widget.session.channelType);
      _applyChannelFlameSettings(
        channel,
        flame: enabled ? 1 : 0,
        flameSecond: _channelFlameSecond(channel),
      );
      WKIM.shared.channelManager.addOrUpdateChannel(channel);
      if (!mounted) {
        return;
      }
      setState(() {
        _channel = channel;
        _flameSliderValue = null;
      });
      if (!enabled) {
        composerController.hidePanels();
      }
    } catch (error) {
      _showFlameFeedback(error);
    }
  }

  Future<void> _updateFlameSecond(int flameSecond) async {
    try {
      if (widget.session.channelType == WKChannelType.personal) {
        await UserApi.instance.updateUserSetting(
          widget.session.channelId,
          'flame_second',
          flameSecond,
        );
      } else {
        await GroupApi.instance.updateGroupSetting(
          widget.session.channelId,
          'flame_second',
          flameSecond,
        );
      }

      final channel =
          _channel ??
          widget.channel ??
          WKChannel(widget.session.channelId, widget.session.channelType);
      _applyChannelFlameSettings(channel, flame: 1, flameSecond: flameSecond);
      WKIM.shared.channelManager.addOrUpdateChannel(channel);
      if (!mounted) {
        return;
      }
      setState(() {
        _channel = channel;
        _flameSliderValue = null;
      });
    } catch (error) {
      _showFlameFeedback(error);
    }
  }

  void _showFlameFeedback(Object error) {
    if (!mounted) {
      return;
    }
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFunctionPanel(List<ChatFunctionMenu> items) {
    final composerController = ref.read(
      chatComposerProvider(widget.session).notifier,
    );
    return Container(
      key: const ValueKey<String>('panel-more'),
      width: double.infinity,
      color: WKColors.homeBg,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in items)
            _FunctionItem(
              key: ValueKey<String>('chat-function-${item.sid}'),
              sid: item.sid,
              asset: item.icon ?? '',
              label: item.text?.trim().isNotEmpty == true
                  ? item.text!.trim()
                  : item.sid,
              onTap: () {
                final onClick = item.onClick;
                if (onClick != null) {
                  onClick(item.sid);
                  return;
                }
                unawaited(_handleFunctionTap(item.sid, composerController));
              },
            ),
        ],
      ),
    );
  }
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

bool _isChannelFlameEnabled(WKChannel? channel) {
  return (_readChannelExtraInt(channel?.remoteExtraMap, const ['flame']) ??
          _readChannelExtraInt(channel?.localExtra, const ['flame']) ??
          0) ==
      1;
}

int _channelFlameSecond(WKChannel? channel) {
  return _readChannelExtraInt(channel?.remoteExtraMap, const [
        'flame_second',
        'flameSecond',
      ]) ??
      _readChannelExtraInt(channel?.localExtra, const [
        'flame_second',
        'flameSecond',
      ]) ??
      0;
}

int? _readChannelExtraInt(dynamic map, List<String> keys) {
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

Map<String, dynamic> _mutableExtraMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return <String, dynamic>{...raw};
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return <String, dynamic>{};
}

Future<void> _pushGroupCallPicker({
  required BuildContext context,
  required WidgetRef ref,
  required String channelId,
  required int channelType,
  String? channelName,
}) {
  final page = ref.read(chatGroupCallPageBuilderProvider)(
    channelId: channelId,
    channelType: channelType,
    channelName: channelName,
  );
  return Navigator.of(
    context,
  ).push<bool>(MaterialPageRoute<bool>(builder: (_) => page));
}

void _applyChannelFlameSettings(
  WKChannel channel, {
  required int flame,
  required int flameSecond,
}) {
  final remoteExtra = _mutableExtraMap(channel.remoteExtraMap);
  remoteExtra['flame'] = flame;
  remoteExtra['flame_second'] = flameSecond;
  channel.remoteExtraMap = remoteExtra;

  final localExtra = _mutableExtraMap(channel.localExtra);
  localExtra['flame'] = flame;
  localExtra['flame_second'] = flameSecond;
  channel.localExtra = localExtra;
}

double _sliderValueForFlameSecond(int flameSecond) {
  final index = _flameSecondOptions.indexOf(flameSecond);
  return (index < 0 ? 0 : index).toDouble();
}

int _flameSecondForSliderValue(double value) {
  final index = value.round().clamp(0, _flameSecondOptions.length - 1);
  return _flameSecondOptions[index];
}

String _flameSecondLabel(int flameSecond) {
  switch (flameSecond) {
    case 0:
      return '\u9000\u51fa\u540e';
    case 10:
      return '10\u79d2';
    case 20:
      return '20\u79d2';
    case 30:
      return '30\u79d2';
    case 60:
      return '1\u5206\u949f';
    case 120:
      return '2\u5206\u949f';
    case 180:
      return '3\u5206\u949f';
    default:
      return '$flameSecond\u79d2';
  }
}

String _flameDescription(int flameSecond) {
  if (flameSecond == 0) {
    return _flameExitDescription;
  }
  return '\u6d88\u606f\u9605\u8bfb\u540e${_flameSecondLabel(flameSecond)}\u81ea\u52a8\u9500\u6bc1';
}

int _readRobotGifDimension(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  if (raw is String) {
    return int.tryParse(raw) ?? 0;
  }
  return 0;
}

class _RobotInlineDirective {
  const _RobotInlineDirective({
    required this.username,
    required this.query,
    required this.hasSeparator,
  });

  final String username;
  final String query;
  final bool hasSeparator;

  bool get isGifQuery => username == 'gif';

  static _RobotInlineDirective? parse(String rawText) {
    final text = rawText.trimLeft();
    if (!text.startsWith('@')) {
      return null;
    }

    final firstSpaceIndex = text.indexOf(' ');
    final usernamePart = firstSpaceIndex >= 0
        ? text.substring(1, firstSpaceIndex)
        : text.substring(1);
    final username = usernamePart.trim().toLowerCase();
    if (username.isEmpty) {
      return null;
    }

    final query = firstSpaceIndex >= 0
        ? text.substring(firstSpaceIndex + 1).replaceAll(' ', '')
        : '';
    return _RobotInlineDirective(
      username: username,
      query: query,
      hasSeparator: firstSpaceIndex >= 0,
    );
  }
}

class _HeaderTag extends StatelessWidget {
  const _HeaderTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: WKColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: WKColors.colorDark,
        ),
      ),
    );
  }
}

const double _composerActionButtonExtent = 48;
const double _composerActionIconExtent = 24;
const double _composerToolbarArtworkExtent = 38;
const double _composerCallIconExtent = 22;
const double _mobileComposerActionButtonExtent = 48;
const double _mobileComposerActionIconExtent = 24;
const double _mobileComposerSendButtonWidth = 60;

class _ComposerToolbarButton extends StatelessWidget {
  const _ComposerToolbarButton({
    super.key,
    required this.asset,
    this.onTap,
    this.extent = _composerActionButtonExtent,
    this.artworkExtent = _composerToolbarArtworkExtent,
    this.fit = BoxFit.fill,
    this.warmStyle = false,
  });

  final String asset;
  final VoidCallback? onTap;
  final double extent;
  final double artworkExtent;
  final BoxFit fit;
  final bool warmStyle;

  @override
  Widget build(BuildContext context) {
    final icon = IconButton(
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: extent, height: extent),
      onPressed: onTap ?? () {},
      icon: asset.trim().isEmpty
          ? SizedBox(width: artworkExtent, height: artworkExtent)
          : WKReferenceAssets.image(
              asset,
              width: artworkExtent,
              height: artworkExtent,
              fit: fit,
            ),
    );

    if (!warmStyle) {
      return SizedBox(width: extent, height: extent, child: icon);
    }

    return SizedBox(
      width: extent,
      height: extent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: WKWebColors.surfaceSoft,
          borderRadius: BorderRadius.circular(WKWebRadius.control),
          border: Border.all(color: WKWebColors.borderWarm, width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: WKWebColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: icon),
      ),
    );
  }
}

class _ComposerCallToolbarButton extends StatelessWidget {
  const _ComposerCallToolbarButton({
    super.key,
    required this.decorationKey,
    required this.tooltip,
    required this.asset,
    required this.gradient,
    required this.onTap,
  });

  final Key decorationKey;
  final String tooltip;
  final String asset;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _composerActionButtonExtent,
      height: _composerActionButtonExtent,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: onTap,
            radius: _composerActionButtonExtent / 2,
            containedInkWell: true,
            borderRadius: BorderRadius.circular(18),
            child: Center(
              child: DecoratedBox(
                key: decorationKey,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: WKReferenceAssets.image(
                      asset,
                      width: _composerCallIconExtent,
                      height: _composerCallIconExtent,
                      tint: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerSendButton extends StatefulWidget {
  const _ComposerSendButton({
    required this.enabled,
    this.onTap,
    this.width = _composerActionButtonExtent,
    this.height = _composerActionButtonExtent,
    this.iconExtent = _composerActionIconExtent,
    this.warmStyle = false,
  });

  final bool enabled;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double iconExtent;
  final bool warmStyle;

  @override
  State<_ComposerSendButton> createState() => _ComposerSendButtonState();
}

class _ComposerSendButtonState extends State<_ComposerSendButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  @override
  void didUpdateWidget(covariant _ComposerSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pressed) {
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = widget.enabled ? (_pressed ? 0.96 : 1.0) : 0.92;
    final iconColor = widget.warmStyle
        ? (widget.enabled ? Colors.white : WKWebColors.action)
        : widget.enabled
        ? WKColors.brand500
        : WKColors.popupText;

    return Listener(
      onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
      onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
      onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
      child: AnimatedScale(
        key: const ValueKey<String>('chat-send-button-motion'),
        scale: scale,
        duration: ChatMotionDurations.pressedScale.resolve(
          disableAnimations: reduceMotion,
        ),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: widget.warmStyle
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.enabled
                        ? WKWebColors.action
                        : WKWebColors.actionSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: WKWebColors.action, width: 1.2),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: WKWebColors.shadow,
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: IconButton(
                    key: const ValueKey<String>('chat-send-button'),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: widget.width,
                      height: widget.height,
                    ),
                    onPressed: widget.enabled ? widget.onTap : null,
                    icon: WKReferenceAssets.image(
                      WKReferenceAssets.chatSend,
                      width: widget.iconExtent,
                      height: widget.iconExtent,
                      tint: iconColor,
                    ),
                  ),
                )
              : IconButton(
                  key: const ValueKey<String>('chat-send-button'),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: widget.width,
                    height: widget.height,
                  ),
                  onPressed: widget.enabled ? widget.onTap : null,
                  icon: WKReferenceAssets.image(
                    WKReferenceAssets.chatSend,
                    width: widget.iconExtent,
                    height: widget.iconExtent,
                    tint: iconColor,
                  ),
                ),
        ),
      ),
    );
  }
}

class _FunctionItem extends StatelessWidget {
  const _FunctionItem({
    super.key,
    required this.sid,
    required this.asset,
    required this.label,
    this.onTap,
  });

  final String sid;
  final String asset;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FunctionIcon(sid: sid, asset: asset),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: WKColors.colorDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FunctionIcon extends StatelessWidget {
  const _FunctionIcon({required this.sid, required this.asset});

  final String sid;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final style = _functionIconStyleForSid(sid);
    if (style == null) {
      return asset.trim().isEmpty
          ? const SizedBox(width: 40, height: 40)
          : WKReferenceAssets.image(asset, width: 40, height: 40);
    }

    return DecoratedBox(
      key: ValueKey<String>('chat-function-$sid-icon'),
      decoration: BoxDecoration(
        gradient: style.gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: style.shadowColor.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 32, height: 32),
              ),
            ),
            Positioned(
              left: -6,
              bottom: -8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 28, height: 28),
              ),
            ),
            Center(child: Icon(style.icon, size: 26, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _FunctionIconStyle {
  const _FunctionIconStyle({
    required this.icon,
    required this.gradient,
    required this.shadowColor,
  });

  final IconData icon;
  final Gradient gradient;
  final Color shadowColor;
}

_FunctionIconStyle? _functionIconStyleForSid(String sid) {
  switch (sid) {
    case 'chooseImg':
      return const _FunctionIconStyle(
        icon: Icons.photo_library_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF41D8FF), Color(0xFF4E6BFF)],
        ),
        shadowColor: Color(0xFF4E6BFF),
      );
    case 'captureImg':
      return const _FunctionIconStyle(
        icon: Icons.photo_camera_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCB5F), Color(0xFFFF6B8A)],
        ),
        shadowColor: Color(0xFFFF7A45),
      );
    case 'chooseFile':
      return const _FunctionIconStyle(
        icon: Icons.description_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB86B), Color(0xFFFF7A45)],
        ),
        shadowColor: Color(0xFFFF7A45),
      );
    case 'sendLocation':
      return const _FunctionIconStyle(
        icon: Icons.location_on_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF36E6B3), Color(0xFF16A76C)],
        ),
        shadowColor: Color(0xFF16A76C),
      );
    case 'chooseCard':
      return const _FunctionIconStyle(
        icon: Icons.badge_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB576FF), Color(0xFF7A5CFF)],
        ),
        shadowColor: Color(0xFF7A5CFF),
      );
    default:
      return null;
  }
}
