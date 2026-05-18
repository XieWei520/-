import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../../core/config/api_config.dart';
import '../../../data/models/chat_session.dart';
import '../../../data/models/group.dart';
import '../../../data/models/user.dart';
import '../../../data/models/wk_custom_content.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/conversation_provider.dart';
import '../../../service/api/group_api.dart';
import '../../../widgets/liquid_glass_tokens.dart';
import '../../../widgets/message_bubble.dart';
import '../../../wukong_base/endpoint/endpoint_manager.dart';
import '../../../wukong_base/endpoint/menu/endpoint_menu.dart';
import '../../../wukong_base/msg/msg_content_type.dart';
import '../../../wukong_base/views/image_viewer.dart';
import '../../../wukong_scan/scan_qr_code_bridge.dart';
import '../../../wukong_uikit/user/user_detail_page.dart';
import '../../location/location_view_page.dart';
import '../chat_file_opening.dart';
import '../chat_flame_message_runtime.dart';
import '../chat_message_action_policy.dart';
import '../chat_message_action_surface.dart';
import '../chat_message_providers.dart';
import '../chat_message_reaction_mapping.dart';
import '../chat_message_view_model.dart';
import '../chat_scene_gateway.dart';
import '../chat_scene_providers.dart';
import '../chat_viewport_controller.dart';
import '../chat_viewport_models.dart';
import '../forward_message_page.dart';
import '../robot_card_message.dart';
import '../widgets/chat_message_action_sheet.dart';
import '../widgets/chat_message_engagement_bubble.dart';
import '../widgets/chat_message_list_item.dart';
import '../widgets/chat_message_viewport.dart';
import '../widgets/chat_reaction_picker_popup.dart';
import 'chat_viewport_support.dart';

const String _retrySendFailureFeedback =
    '\u91cd\u53d1\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u7f51\u7edc\u540e\u518d\u8bd5';

SnackBar _buildLiquidSnackBar(String message, {EdgeInsetsGeometry? margin}) {
  return SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: LiquidGlassColors.darkSurfaceSolid,
    margin: margin,
  );
}

class ChatViewportPane extends ConsumerStatefulWidget {
  const ChatViewportPane({
    super.key,
    required this.session,
    this.conversationChannel,
    this.canPinMessages = false,
    this.currentUserGroupRole = 0,
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
  final int currentUserGroupRole;
  final ChatFlameMessageRuntime? flameRuntime;
  final VoidCallback? onBuild;
  final Future<void> Function(WKMsg message)? onPinnedMessageToggled;
  final ChatViewportRestoreAnchor? restoreAnchor;
  final bool webStyle;
  final ValueChanged<ChatViewportPersistenceSnapshot>?
  onPersistenceSnapshotChanged;
  final ValueChanged<ChatViewportRestoreResult>? onRestoreAnchorApplied;

  @override
  ConsumerState<ChatViewportPane> createState() => _ChatViewportPaneState();
}

class _ChatViewportPaneState extends ConsumerState<ChatViewportPane> {
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
  void didUpdateWidget(covariant ChatViewportPane oldWidget) {
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
    final identities = ref.watch(
      chatViewportProvider(widget.session).select((state) => state.identities),
    );
    final identityToIndex = ref.watch(
      chatViewportProvider(
        widget.session,
      ).select((state) => state.identityToIndex),
    );
    final isLoadingMore = ref.watch(
      chatViewportProvider(
        widget.session,
      ).select((state) => state.isLoadingMore),
    );
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
        ..showSnackBar(_buildLiquidSnackBar(feedbackMessage));
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
              child: identities.isEmpty
                  ? const Center(child: Text(emptyMessageText))
                  : ListView.builder(
                      key: _listKey,
                      controller: _scrollController,
                      reverse: true,
                      cacheExtent: listCacheExtent,
                      itemCount: identities.length,
                      findChildIndexCallback: (key) {
                        if (key is ValueKey<String>) {
                          return identityToIndex[key.value];
                        }
                        return null;
                      },
                      itemBuilder: (context, index) {
                        final identity = identities[index];
                        return Consumer(
                          key: ValueKey<String>(identity),
                          builder: (context, ref, _) {
                            final item = ref.watch(
                              singleMessageProvider((
                                session: widget.session,
                                identity: identity,
                              )),
                            );
                            if (item == null) {
                              return const SizedBox.shrink();
                            }
                            final contentType = item.message.contentType;
                            final viewportSnapshot = ref.read(
                              chatViewportProvider(widget.session),
                            );
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
                                onTap: _messageTapHandler(
                                  item,
                                  viewportSnapshot,
                                ),
                                onLongPress: () =>
                                    _showMessageActionSheet(item),
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
                        );
                      },
                    ),
            ),
            if (isLoadingMore)
              const Positioned(
                top: 8,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: OlderMessagesLoadingIndicator(
                    key: ValueKey<String>('chat-older-loading-indicator'),
                  ),
                ),
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
        ? <ChatImagePreviewItem>[
            ChatImagePreviewItem(
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
      ..showSnackBar(_buildLiquidSnackBar(message.trim()));
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

  List<ChatImagePreviewItem> _buildImagePreviewItems(
    ChatViewportState viewport,
  ) {
    final items = <ChatImagePreviewItem>[];
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
        ChatImagePreviewItem(
          identity: item.identity,
          message: item.message,
          url: previewUrl,
        ),
      );
    }
    return items;
  }

  List<ImageViewerAction> _imageViewerActions(
    List<ChatImagePreviewItem> previewItems,
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
    VisibleViewportItem? firstVisible;
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
        firstVisible = VisibleViewportItem(
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
      canRecall: _canRecallMessage(model),
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

  bool _canRecallMessage(ChatMessageViewModel model) {
    final senderRole =
        _groupMembersByUid[model.message.fromUID.trim()]?.role ??
        ChatGroupRole.normal;
    return canRecallChatMessage(
      isSelf: model.isSelf,
      channelType: widget.session.channelType,
      currentUserGroupRole: widget.currentUserGroupRole,
      senderGroupRole: senderRole,
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
