import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/channel_member.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/entity/reminder.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/avatar_utils.dart';
import '../../data/models/chat_session.dart';
import '../../data/models/friend.dart';
import '../../data/models/group.dart';
import '../../data/models/user.dart';
import '../../data/models/wk_custom_content.dart';
import '../../data/providers/channel_provider.dart';
import '../../data/providers/conversation_provider.dart';
import '../../data/providers/user_provider.dart';
import '../../service/api/group_api.dart';
import '../../service/im/im_service.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_conversation_item.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_main_top_bar.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_screen_popup_menu.dart';
import '../../widgets/wk_status_view.dart';
import '../../widgets/wk_web_ui_tokens.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/home_slots.dart';
import '../../wukong_base/msg/draft_manager.dart';
import '../../wukong_base/msg/msg_content_type.dart';
import '../../wukong_login/pc_login_management_page.dart';
import '../../wukong_uikit/search/add_friends_page.dart';
import '../../wukong_uikit/search/global_search_page.dart';
import '../../wukong_scan/scan_page.dart';
import '../chat/chat_page.dart';
import '../chat/chat_password_runtime.dart';
import '../chat/message_content_preview.dart';
import '../chat/robot_message_identity.dart';
import '../customer_service/customer_service_identity.dart';
import '../contacts/create_group_page.dart';
import '../home/home_surface_contract.dart';
import '../home/home_surface_kernel.dart';
import '../home/home_top_menu_slot_assembly.dart';
import '../vip/vip_guard.dart';
import 'conversation_activity_registry.dart';
import 'conversation_list_item_loader.dart';
import 'conversation_metadata_resolver.dart';
import 'conversation_list_refresh_controller.dart';
import 'widgets/conversation_action_sheet.dart';

const String _androidSystemTeamId = 'u_10000';
const String _androidFileHelperId = 'fileHelper';

@immutable
class ConversationSendStatus {
  final bool showSingleTick;
  final bool showDoubleTick;
  final bool showSending;
  final bool showSendFailed;

  const ConversationSendStatus({
    this.showSingleTick = false,
    this.showDoubleTick = false,
    this.showSending = false,
    this.showSendFailed = false,
  });
}

@visibleForTesting
ConversationSendStatus resolveConversationSendStatus(
  WKMsg? msg, {
  required String currentUid,
}) {
  if (msg == null || msg.isDeleted == 1) {
    return const ConversationSendStatus();
  }

  final normalizedCurrentUid = currentUid.trim();
  final fromUid = msg.fromUID.trim();
  if (normalizedCurrentUid.isEmpty || fromUid != normalizedCurrentUid) {
    return const ConversationSendStatus();
  }

  final status = msg.status;
  final hasServerIdentity =
      msg.messageID.trim().isNotEmpty || msg.messageSeq > 0;
  final readedCount = msg.wkMsgExtra?.readedCount ?? 0;
  final receiptEnabled = msg.setting.receipt == 1;
  final shouldTreatAsSuccess =
      status == WKSendMsgResult.sendSuccess ||
      (status == WKSendMsgResult.sendLoading && hasServerIdentity);

  if (shouldTreatAsSuccess) {
    return ConversationSendStatus(
      showSingleTick: !receiptEnabled || readedCount <= 0,
      showDoubleTick: receiptEnabled && readedCount > 0,
    );
  }

  if (status == WKSendMsgResult.sendLoading) {
    return const ConversationSendStatus(showSending: true);
  }

  return const ConversationSendStatus(showSendFailed: true);
}

@visibleForTesting
bool resolveConversationForbiddenState({
  required WKChannel? channel,
  required WKChannelMember? currentMember,
}) {
  if (channel == null || channel.forbidden != 1) {
    return false;
  }
  return currentMember?.role == 0;
}

@immutable
class ConversationPreferredInfo {
  final String title;
  final String? avatarUrl;
  final int vipLevel;
  final String? category;
  final bool personalInfoKnown;

  const ConversationPreferredInfo({
    required this.title,
    required this.avatarUrl,
    this.vipLevel = 0,
    this.category,
    this.personalInfoKnown = false,
  });
}

@visibleForTesting
Map<String, ConversationPreferredInfo>
buildPreferredPersonalConversationInfoMap(
  Iterable<Friend> friends, {
  Iterable<CustomerServiceAccount> customerServices =
      const <CustomerServiceAccount>[],
}) {
  final infos = <String, ConversationPreferredInfo>{};
  for (final friend in friends) {
    final uid = friend.uid.trim();
    if (uid.isEmpty) {
      continue;
    }
    infos[uid] = ConversationPreferredInfo(
      title: _resolveFriendTitle(friend),
      avatarUrl: _resolveConversationAvatar(friend.avatar),
      vipLevel: friend.vipLevel,
      category: normalizePublicAccountCategory(friend.category),
      personalInfoKnown: true,
    );
  }
  for (final service in customerServices) {
    final uid = service.uid.trim();
    if (uid.isEmpty) {
      continue;
    }
    final existing = infos[uid];
    final existingTitle = existing?.title.trim() ?? '';
    final serviceName = service.name.trim();
    infos[uid] = ConversationPreferredInfo(
      title: _firstNonEmptyText([
        (existingTitle.isNotEmpty && existingTitle != uid)
            ? existingTitle
            : null,
        serviceName,
        existingTitle,
        uid,
      ]),
      avatarUrl:
          existing?.avatarUrl ?? _resolveConversationAvatar(service.avatar),
      vipLevel: existing?.vipLevel ?? 0,
      category: customerServiceCategory,
      personalInfoKnown: true,
    );
  }
  return infos;
}

@visibleForTesting
Map<String, ConversationPreferredInfo> buildPreferredGroupConversationInfoMap(
  Iterable<GroupInfo> groups,
) {
  final infos = <String, ConversationPreferredInfo>{};
  for (final group in groups) {
    final groupNo = group.groupNo.trim();
    if (groupNo.isEmpty) {
      continue;
    }
    infos[groupNo] = ConversationPreferredInfo(
      title: _resolveGroupTitle(group),
      avatarUrl: _resolveConversationAvatar(group.avatar),
    );
  }
  return infos;
}

@visibleForTesting
String resolveConversationHeaderTitle(int connectionStatus) {
  switch (connectionStatus) {
    case WKConnectStatus.connecting:
      return '连接中...';
    case WKConnectStatus.syncMsg:
      return '同步中...';
    case WKConnectStatus.noNetwork:
    case WKConnectStatus.fail:
      return '未连接';
    default:
      return '聊天';
  }
}

@visibleForTesting
SurfaceReliabilityState resolveConversationSurfaceReliability(
  int connectionStatus,
) {
  switch (connectionStatus) {
    case WKConnectStatus.success:
    case WKConnectStatus.syncCompleted:
      return SurfaceReliabilityState.healthy;
    case WKConnectStatus.connecting:
    case WKConnectStatus.syncMsg:
      return SurfaceReliabilityState.stale;
    default:
      return SurfaceReliabilityState.degraded;
  }
}

final preferredPersonalConversationInfoProvider =
    Provider<Map<String, ConversationPreferredInfo>>((ref) {
      final friends = ref.watch(
        friendListProvider.select(
          (state) => state.valueOrNull ?? const <Friend>[],
        ),
      );
      final customerServices = ref.watch(
        customerServiceConversationAccountsProvider.select(
          (state) => state.valueOrNull ?? const <CustomerServiceAccount>[],
        ),
      );
      return buildPreferredPersonalConversationInfoMap(
        friends,
        customerServices: customerServices,
      );
    });

final customerServiceConversationAccountsProvider =
    FutureProvider<List<CustomerServiceAccount>>((ref) async {
      try {
        return await UserApi.instance.getCustomerServices();
      } catch (_) {
        return const <CustomerServiceAccount>[];
      }
    });

final preferredGroupConversationInfoProvider =
    Provider<Map<String, ConversationPreferredInfo>>((ref) {
      final groups = ref.watch(
        myGroupListProvider.select(
          (state) => state.valueOrNull ?? const <GroupInfo>[],
        ),
      );
      return buildPreferredGroupConversationInfoMap(groups);
    });

final conversationListItemLoaderProvider =
    Provider.autoDispose<ConversationListItemLoader>((ref) {
      final loader = ConversationListItemLoader();
      ref.onDispose(loader.dispose);
      return loader;
    });

final conversationMetadataResolverProvider =
    Provider.autoDispose<ConversationMetadataResolver>((ref) {
      final resolver = ConversationMetadataResolver();
      ref.onDispose(resolver.clear);
      return resolver;
    });

final conversationListItemDataProvider = FutureProvider.autoDispose
    .family<WKConversationItemData, ConversationListItemRequest>((
      ref,
      request,
    ) {
      final loader = ref.watch(conversationListItemLoaderProvider);
      final metadataResolver = ref.watch(conversationMetadataResolverProvider);
      final currentUid = WKIM.shared.options.uid?.trim() ?? '';
      return loader.load(
        request.requestKey,
        () => resolveConversationListItemData(
          request,
          currentUid: currentUid,
          personalUserInfoLoader: (uid) => metadataResolver.loadPersonalInfo(
            uid,
            (resolvedUid) => UserApi.instance
                .getUserInfo(resolvedUid)
                .then<UserInfo?>((user) => user, onError: (_, _) => null),
          ),
          groupInfoLoader: (groupNo) => metadataResolver.loadGroupInfo(
            groupNo,
            (resolvedGroupNo) => GroupApi.instance
                .getGroupInfo(resolvedGroupNo)
                .then<GroupInfo?>((group) => group, onError: (_, _) => null),
          ),
        ),
        cacheKey: conversationRowKey(
          request.conversation.channelID,
          request.conversation.channelType,
        ),
      );
    });

@visibleForTesting
String conversationRowKey(String channelId, int channelType) {
  return '$channelType:$channelId';
}

String conversationKeyFor(WKUIConversationMsg conversation) {
  return '${conversation.channelID}:${conversation.channelType}';
}

String conversationSelectionKeyFromRowKey(String rowKey) {
  final separatorIndex = rowKey.indexOf(':');
  if (separatorIndex < 0) {
    return rowKey;
  }
  final channelType = rowKey.substring(0, separatorIndex);
  final channelId = rowKey.substring(separatorIndex + 1);
  return '$channelId:$channelType';
}

String _conversationRowKeyOf(WKUIConversationMsg conversation) {
  return conversationRowKey(conversation.channelID, conversation.channelType);
}

String _conversationRowOrderSignature(List<WKUIConversationMsg> conversations) {
  if (conversations.isEmpty) {
    return '';
  }
  return conversations.map(_conversationRowKeyOf).join('|');
}

Map<String, WKUIConversationMsg> _conversationRowMap(
  List<WKUIConversationMsg> conversations,
) {
  return <String, WKUIConversationMsg>{
    for (final conversation in conversations)
      _conversationRowKeyOf(conversation): conversation,
  };
}

final conversationRowOrderProvider = Provider<List<String>>((ref) {
  final signature = ref.watch(
    conversationProvider.select(_conversationRowOrderSignature),
  );
  if (signature.isEmpty) {
    return const <String>[];
  }
  return signature.split('|');
});

final conversationRowMapProvider = Provider<Map<String, WKUIConversationMsg>>((
  ref,
) {
  return ref.watch(conversationProvider.select(_conversationRowMap));
});

final conversationRowProvider = Provider.family<WKUIConversationMsg?, String>((
  ref,
  key,
) {
  return ref.watch(conversationRowMapProvider.select((rows) => rows[key]));
});

final conversationSurfaceContractProvider = Provider<HomeSurfaceContract>((
  ref,
) {
  final conversations = ref.watch(conversationProvider);
  final unread = conversations.fold<int>(
    0,
    (sum, item) => sum + item.unreadCount,
  );
  return HomeSurfaceContract(
    surfaceId: HomeSurfaceId.conversations,
    badgeCount: unread,
    reliabilityState: SurfaceReliabilityState.healthy,
    prefetchHint: const HomeSurfacePrefetchHint(
      surfaceId: HomeSurfaceId.conversations,
      critical: true,
      adjacent: true,
    ),
  );
});

typedef ConversationOpenHandler =
    void Function(
      WKUIConversationMsg conversation,
      ConversationPreferredInfo? preferredInfo,
      WKConversationItemData displayData,
    );

class ConversationListPage extends ConsumerStatefulWidget {
  const ConversationListPage({
    super.key,
    this.embedded = false,
    this.selectedConversationKey,
    this.onOpenConversation,
  });

  final bool embedded;
  final String? selectedConversationKey;
  final ConversationOpenHandler? onOpenConversation;

  @override
  ConsumerState<ConversationListPage> createState() =>
      _ConversationListPageState();
}

class _ConversationListPageState extends ConsumerState<ConversationListPage> {
  bool _selectionMode = false;
  Set<String> _selectedKeys = <String>{};

  ProviderSubscription<int>? _connectionStatusSubscription;

  @override
  void initState() {
    super.initState();
    _bindKernelListeners();
  }

  void _bindKernelListeners() {
    _syncConversationReliability(ref.read(imServiceProvider).connectionStatus);
    _connectionStatusSubscription = ref.listenManual<int>(
      imServiceProvider.select((state) => state.connectionStatus),
      (previous, next) {
        if (previous == next) {
          return;
        }
        _syncConversationReliability(next);
      },
    );
  }

  void _syncConversationReliability(int connectionStatus) {
    final kernel = ref.read(homeSurfaceKernelProvider);
    final nextState = resolveConversationSurfaceReliability(connectionStatus);
    if (kernel.reliabilityFor(HomeSurfaceId.conversations) == nextState) {
      return;
    }
    kernel.markSurfaceReliability(HomeSurfaceId.conversations, nextState);
  }

  @override
  void dispose() {
    _connectionStatusSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationRowKeys = ref.watch(conversationRowOrderProvider);
    final personalInfos = ref.watch(preferredPersonalConversationInfoProvider);
    final groupInfos = ref.watch(preferredGroupConversationInfoProvider);
    final availableKeys = {
      for (final rowKey in conversationRowKeys)
        conversationSelectionKeyFromRowKey(rowKey),
    };
    if (_selectedKeys.any((key) => !availableKeys.contains(key))) {
      _selectedKeys = _selectedKeys.where(availableKeys.contains).toSet();
      if (_selectedKeys.isEmpty && _selectionMode) {
        _selectionMode = false;
      }
    }

    final content = Column(
      children: [
        _ConversationListHeader(
          selectionMode: _selectionMode,
          selectedCount: _selectedKeys.length,
          canDeleteSelection: _selectedKeys.isNotEmpty,
          onClearSelection: _clearSelection,
          onDeleteSelected: () =>
              _deleteSelected(ref.read(conversationProvider)),
          onOpenDeviceManager: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PCLoginManagementPage()),
            );
          },
          onOpenGlobalSearch: () => _openGlobalSearch(context),
          onShowTopMenu: (anchorContext) => _showTopMenu(
            context,
            anchorContext,
            ref.read(conversationProvider),
          ),
        ),
        Expanded(
          child: conversationRowKeys.isEmpty
              ? const WKEmptyView(
                  icon: Icons.forum_outlined,
                  message: '暂时还没有会话',
                  subMessage: '登录并开始聊天后，会话会显示在这里。',
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(conversationProvider.notifier).refreshNow();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: WKSpace.xl),
                    itemCount: conversationRowKeys.length,
                    separatorBuilder: (_, _) => Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 75),
                      color: WKColors.homeBg,
                    ),
                    itemBuilder: (context, index) {
                      final conversationKey = conversationRowKeys[index];
                      return _ConversationTile(
                        key: ValueKey(conversationKey),
                        conversationKey: conversationKey,
                        personalInfos: personalInfos,
                        groupInfos: groupInfos,
                        selectionMode: _selectionMode,
                        selectedConversationKeys: _selectedKeys,
                        webSelectedConversationKey:
                            widget.selectedConversationKey,
                        webStyle: widget.embedded,
                        onTap: (conversation, preferredInfo, displayData) {
                          if (_selectionMode) {
                            _toggleConversationSelection(conversation);
                            return;
                          }
                          if (widget.onOpenConversation != null) {
                            widget.onOpenConversation!(
                              conversation,
                              preferredInfo,
                              displayData,
                            );
                            return;
                          }
                          final displayTitle = displayData.title.trim();
                          final fallbackTitle =
                              displayTitle.isEmpty ||
                                  displayTitle == conversation.channelID ||
                                  displayTitle == 'Loading conversation...'
                              ? null
                              : displayTitle;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                channelId: conversation.channelID,
                                channelType: conversation.channelType,
                                channelName:
                                    preferredInfo?.title ?? fallbackTitle,
                                channelCategory:
                                    preferredInfo?.category ??
                                    displayData.category,
                                initialVipLevel: displayData.vipLevel,
                              ),
                            ),
                          );
                        },
                        onLongPress: (conversation) {
                          if (_selectionMode) {
                            _toggleConversationSelection(conversation);
                            return;
                          }
                          unawaited(
                            _showConversationMenu(context, ref, conversation),
                          );
                        },
                      );
                    },
                  ),
                ),
        ),
      ],
    );

    if (widget.embedded) {
      return Material(
        key: const ValueKey<String>('conversation-list-embedded'),
        color: WKWebColors.surface,
        child: content,
      );
    }

    return Scaffold(backgroundColor: WKColors.homeBg, body: content);
  }

  Future<void> _showTopMenu(
    BuildContext context,
    BuildContext anchorContext,
    List<WKUIConversationMsg> conversations,
  ) async {
    final registry = ref.read(slotRegistryProvider);
    final items = resolveHomeTopMenuItems(
      registry,
      HomeTopMenuContext(
        hasConversations: conversations.isNotEmpty,
        openCreateGroup: () => unawaited(_openCreateGroupPage()),
        openAddFriend: () => unawaited(_openAddFriendPage()),
        openScan: () => unawaited(_openScanPage()),
        enterMultiSelect: _toggleSelectionMode,
        clearAllConversations: () => unawaited(_confirmClearAll(conversations)),
      ),
    );
    final action = await showWKScreenPopupMenu<HomeTopMenuItem>(
      context: context,
      anchorContext: anchorContext,
      items: items
          .map((item) => item.toPopupMenuItem())
          .toList(growable: false),
    );
    if (!mounted || action == null) {
      return;
    }

    action.onSelected();
  }

  Future<void> _openCreateGroupPage() async {
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final group = await Navigator.of(context).push<GroupInfo>(
      MaterialPageRoute(builder: (_) => const CreateGroupPage()),
    );
    if (group == null || !mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: group.groupNo,
          channelType: WKChannelType.group,
          channelName: group.name ?? group.groupNo,
        ),
      ),
    );
  }

  Future<void> _openAddFriendPage() async {
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddFriendsPage()));
  }

  Future<void> _openScanPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ScanPage()));
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedKeys = <String>{};
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedKeys = <String>{};
    });
  }

  void _toggleConversationSelection(WKUIConversationMsg conversation) {
    final key = _conversationKey(conversation);
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys = _selectedKeys.where((item) => item != key).toSet();
      } else {
        _selectedKeys = {..._selectedKeys, key};
      }
      if (_selectedKeys.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelected(List<WKUIConversationMsg> conversations) async {
    final targets = conversations
        .where((item) => _selectedKeys.contains(_conversationKey(item)))
        .map(
          (item) => ChatSession(
            channelId: item.channelID,
            channelType: item.channelType,
          ),
        )
        .toList();
    if (targets.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: WKColors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WKRadius.lg),
          ),
          title: const Text('删除选中的会话'),
          content: Text('确定删除选中的 ${targets.length} 个会话吗？本地草稿也会一并删除。'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除', style: TextStyle(color: WKColors.danger)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(conversationProvider.notifier).deleteConversations(targets);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _selectedKeys = <String>{};
    });
  }

  Future<void> _confirmClearAll(List<WKUIConversationMsg> conversations) async {
    if (conversations.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: WKColors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WKRadius.lg),
          ),
          title: const Text('清空全部会话'),
          content: const Text('确定清空全部会话吗？本地草稿也会一并删除。'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('清空', style: TextStyle(color: WKColors.danger)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(conversationProvider.notifier).clearAllConversations();
    if (!mounted) {
      return;
    }
    setState(() {
      _selectionMode = false;
      _selectedKeys = <String>{};
    });
  }

  void _openGlobalSearch(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GlobalSearchPage()));
  }

  Future<void> _showConversationMenu(
    BuildContext context,
    WidgetRef ref,
    WKUIConversationMsg conversation,
  ) async {
    final channel = await conversation.getWkChannel();
    if (!mounted || !context.mounted) {
      return;
    }
    final isPinned = (channel?.top ?? 0) == 1;
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return ConversationActionSheet(
          isPinned: isPinned,
          onPinChanged: (nextPinned) async {
            await ref
                .read(conversationProvider.notifier)
                .setTop(
                  conversation.channelID,
                  conversation.channelType,
                  nextPinned,
                );
          },
          onMute: () async {
            await ref
                .read(conversationProvider.notifier)
                .setMute(
                  conversation.channelID,
                  conversation.channelType,
                  true,
                );
          },
          onDelete: () async {
            await ref
                .read(conversationProvider.notifier)
                .deleteConversation(
                  conversation.channelID,
                  conversation.channelType,
                );
          },
        );
      },
    );
  }

  static String _conversationKey(WKUIConversationMsg conversation) {
    return conversationKeyFor(conversation);
  }
}

class _ConversationListHeader extends ConsumerWidget {
  const _ConversationListHeader({
    required this.selectionMode,
    required this.selectedCount,
    required this.canDeleteSelection,
    required this.onClearSelection,
    required this.onDeleteSelected,
    required this.onOpenDeviceManager,
    required this.onOpenGlobalSearch,
    required this.onShowTopMenu,
  });

  final bool selectionMode;
  final int selectedCount;
  final bool canDeleteSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelected;
  final VoidCallback onOpenDeviceManager;
  final VoidCallback onOpenGlobalSearch;
  final Future<void> Function(BuildContext anchorContext) onShowTopMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(
      imServiceProvider.select((state) => state.connectionStatus),
    );
    final titleKey = ValueKey<String>(
      selectionMode ? 'selected_$selectedCount' : 'status_$connectionStatus',
    );

    return WKMainTopBar(
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.linear,
        switchOutCurve: Curves.linear,
        layoutBuilder: (currentChild, previousChildren) {
          return ClipRect(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                ...previousChildren,
                ...(currentChild == null
                    ? const <Widget>[]
                    : <Widget>[currentChild]),
              ],
            ),
          );
        },
        transitionBuilder: (child, animation) {
          final isCurrent = child.key == titleKey;
          final offsetTween = Tween<Offset>(
            begin: isCurrent ? const Offset(0, -1) : const Offset(0, 1),
            end: Offset.zero,
          );
          return ClipRect(
            child: SlideTransition(
              position: offsetTween.animate(animation),
              child: child,
            ),
          );
        },
        child: Text(
          selectionMode
              ? '已选中 $selectedCount 项'
              : resolveConversationHeaderTitle(connectionStatus),
          key: titleKey,
        ),
      ),
      leading: selectionMode
          ? WKTopBarActionButton(
              tooltip: '取消选择',
              padding: const EdgeInsets.only(left: 8),
              onTap: onClearSelection,
              child: const Icon(Icons.close, color: WKColors.popupText),
            )
          : null,
      actions: selectionMode
          ? [
              WKTopBarActionButton(
                tooltip: '删除已选会话',
                onTap: canDeleteSelection ? onDeleteSelected : null,
                child: Icon(
                  Icons.delete_outline,
                  color: canDeleteSelection
                      ? WKColors.popupText
                      : WKColors.textTertiary,
                ),
              ),
            ]
          : [
              WKTopBarActionButton(
                tooltip: '设备管理',
                padding: const EdgeInsets.only(right: 24),
                onTap: onOpenDeviceManager,
                child: WKReferenceAssets.image(
                  WKReferenceAssets.device,
                  width: 20,
                  height: 20,
                  tint: WKColors.popupText,
                ),
              ),
              WKTopBarActionButton(
                tooltip: '搜索',
                padding: const EdgeInsets.only(right: 29),
                onTap: onOpenGlobalSearch,
                child: WKReferenceAssets.image(
                  WKReferenceAssets.search,
                  width: 18,
                  height: 18,
                  tint: WKColors.popupText,
                ),
              ),
              Builder(
                builder: (buttonContext) {
                  return WKTopBarActionButton(
                    tooltip: '更多',
                    onTap: () => onShowTopMenu(buttonContext),
                    child: WKReferenceAssets.image(
                      WKReferenceAssets.add,
                      width: 18,
                      height: 18,
                      tint: WKColors.popupText,
                    ),
                  );
                },
              ),
            ],
    );
  }
}

String _resolveFriendTitle(Friend friend) {
  final remark = (friend.remark ?? '').trim();
  if (remark.isNotEmpty) {
    return remark;
  }
  final name = (friend.name ?? '').trim();
  if (name.isNotEmpty) {
    return name;
  }
  return friend.uid;
}

ConversationPreferredInfo? _mergePersonalPreferredInfo(
  ConversationPreferredInfo? base,
  WKConversationItemData? cached, {
  required String channelId,
}) {
  if (cached == null) {
    return base;
  }

  final cachedTitle = cached.title.trim();
  final cachedAvatar = cached.avatarUrl?.trim() ?? '';
  final cachedCategory = normalizePublicAccountCategory(cached.category);
  final baseTitle = base?.title.trim() ?? '';
  final baseAvatar = base?.avatarUrl?.trim() ?? '';
  final baseCategory = normalizePublicAccountCategory(base?.category);
  final title = _firstNonEmptyText([
    baseTitle,
    cachedTitle == channelId.trim() ? null : cachedTitle,
    cachedTitle,
  ]);
  final avatarUrl = _firstNonEmptyText([baseAvatar, cachedAvatar]);
  final vipLevel = (base?.vipLevel ?? 0) != 0
      ? base!.vipLevel
      : cached.vipLevel;
  final category = _firstNonEmptyText([baseCategory, cachedCategory]);
  final personalInfoKnown =
      (base?.personalInfoKnown ?? false) || cached.personalInfoKnown;

  if (title.isEmpty &&
      avatarUrl.isEmpty &&
      vipLevel == 0 &&
      category.isEmpty &&
      !personalInfoKnown) {
    return base;
  }

  return ConversationPreferredInfo(
    title: title.isEmpty ? channelId : title,
    avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
    vipLevel: vipLevel,
    category: category.isEmpty ? null : category,
    personalInfoKnown: personalInfoKnown,
  );
}

String _resolveGroupTitle(GroupInfo group) {
  final remark = (group.remark ?? '').trim();
  if (remark.isNotEmpty) {
    return remark;
  }
  final name = (group.name ?? '').trim();
  if (name.isNotEmpty) {
    return name;
  }
  return group.groupNo;
}

class _ConversationTile extends ConsumerWidget {
  final String conversationKey;
  final Map<String, ConversationPreferredInfo> personalInfos;
  final Map<String, ConversationPreferredInfo> groupInfos;
  final void Function(
    WKUIConversationMsg conversation,
    ConversationPreferredInfo? preferredInfo,
    WKConversationItemData displayData,
  )
  onTap;
  final void Function(WKUIConversationMsg conversation) onLongPress;
  final bool selectionMode;
  final Set<String> selectedConversationKeys;
  final String? webSelectedConversationKey;
  final bool webStyle;

  const _ConversationTile({
    super.key,
    required this.conversationKey,
    required this.personalInfos,
    required this.groupInfos,
    required this.onTap,
    required this.onLongPress,
    required this.selectionMode,
    required this.selectedConversationKeys,
    this.webSelectedConversationKey,
    this.webStyle = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationRowProvider(conversationKey));
    if (conversation == null) {
      return const SizedBox.shrink();
    }
    final conversationSelectionKey = conversationKeyFor(conversation);
    final selected = selectedConversationKeys.contains(
      conversationSelectionKey,
    );
    final webSelected = webSelectedConversationKey == conversationSelectionKey;
    final loader = ref.watch(conversationListItemLoaderProvider);
    final cachedData = loader.cachedDataFor(conversationKey);
    final basePreferredInfo = conversation.channelType == WKChannelType.group
        ? groupInfos[conversation.channelID]
        : personalInfos[conversation.channelID];
    final preferredInfo = conversation.channelType == WKChannelType.personal
        ? _mergePersonalPreferredInfo(
            basePreferredInfo,
            cachedData,
            channelId: conversation.channelID,
          )
        : basePreferredInfo;
    final refreshToken = ref.watch(
      conversationListRefreshProvider.select(
        (state) =>
            state.versionFor(conversation.channelID, conversation.channelType),
      ),
    );
    final request = ConversationListItemRequest(
      conversation: conversation,
      preferredTitle: preferredInfo?.title,
      preferredAvatarUrl: preferredInfo?.avatarUrl,
      preferredCategory: preferredInfo?.category,
      preferredVipLevel: preferredInfo?.vipLevel ?? 0,
      preferredPersonalInfoKnown: preferredInfo?.personalInfoKnown ?? false,
      refreshToken: refreshToken,
    );
    final data = ref
        .watch(conversationListItemDataProvider(request))
        .valueOrNull;
    final displayData =
        data ?? cachedData ?? _buildConversationTileFallback(request);
    final child = WKConversationItem(
      data: displayData,
      selected: webSelected,
      webStyle: webStyle,
      onTap: () => onTap(conversation, preferredInfo, displayData),
      onLongPress: () => onLongPress(conversation),
    );

    if (!selectionMode) {
      return child;
    }

    return Stack(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WKRadius.md),
            border: Border.all(
              color: selected ? WKColors.brand500 : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        ),
        Positioned(
          top: WKSpace.sm,
          right: WKSpace.sm,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(WKRadius.pill),
            ),
            child: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? WKColors.brand500 : WKColors.textTertiary,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }
}

WKConversationItemData _buildConversationTileFallback(
  ConversationListItemRequest request,
) {
  final conversation = request.conversation;
  return WKConversationItemData(
    channelId: conversation.channelID,
    channelType: conversation.channelType,
    title: (request.preferredTitle?.trim().isNotEmpty ?? false)
        ? request.preferredTitle!.trim()
        : conversation.channelID,
    avatarUrl: request.preferredAvatarUrl,
    category: request.preferredCategory,
    vipLevel: request.preferredVipLevel,
    personalInfoKnown: request.preferredPersonalInfoKnown,
    lastMsgContent: 'Loading conversation...',
    unreadCount: conversation.unreadCount,
    lastMsgTime: conversation.lastMsgTimestamp > 0
        ? DateTime.fromMillisecondsSinceEpoch(
            conversation.lastMsgTimestamp * 1000,
          )
        : null,
    isGroup: conversation.channelType == WKChannelType.group,
  );
}

@visibleForTesting
bool shouldFetchPersonalConversationUserInfo({
  required WKUIConversationMsg conversation,
  required String currentUid,
  required String resolvedTitle,
  int resolvedVipLevel = 0,
  bool preferredPersonalInfoKnown = false,
}) {
  if (conversation.channelType != WKChannelType.personal) {
    return false;
  }
  final channelId = conversation.channelID.trim();
  if (channelId.isEmpty || channelId == currentUid.trim()) {
    return false;
  }
  if (channelId == _androidSystemTeamId || channelId == _androidFileHelperId) {
    return false;
  }
  if (!preferredPersonalInfoKnown && resolvedVipLevel == 0) {
    return true;
  }
  final title = resolvedTitle.trim();
  return title.isEmpty || title == channelId;
}

Future<WKConversationItemData> resolveConversationListItemData(
  ConversationListItemRequest request, {
  required String currentUid,
  Future<UserInfo?> Function(String uid)? personalUserInfoLoader,
  Future<GroupInfo?> Function(String groupNo)? groupInfoLoader,
}) async {
  final conversation = request.conversation;
  final channelFuture = conversation.getWkChannel();
  final cachedMsgFuture = conversation.getWkMsg();
  final freshMsgFuture = WKIM.shared.messageManager.getWithClientMsgNo(
    conversation.clientMsgNo,
  );
  final remindersFuture = conversation.getReminderList();

  final channel = await channelFuture;
  final cachedMsg = await cachedMsgFuture;
  final freshMsg = await freshMsgFuture;
  final msg = resolveConversationListMessageSnapshot(
    cachedMessage: cachedMsg,
    freshMessage: freshMsg,
  );
  final reminders = await remindersFuture;

  var title = _firstNonEmptyText([
    request.preferredTitle,
    _resolveConversationTitle(conversation, channel),
  ]);
  var avatarUrl = _firstNonEmptyText([
    request.preferredAvatarUrl,
    _resolveConversationAvatar(channel?.avatar),
  ]);
  if (avatarUrl.isEmpty && conversation.channelType == WKChannelType.personal) {
    avatarUrl = buildUserAvatarUrl(conversation.channelID) ?? '';
  }
  if (title.isEmpty) {
    title = conversation.channelID;
  }
  var category = _firstNonEmptyText([
    request.preferredCategory,
    channel?.category,
  ]);
  var vipLevel = request.preferredVipLevel;
  if (vipLevel == 0) {
    vipLevel =
        _readChannelExtraInt(channel?.remoteExtraMap, const [
          'vip_level',
          'vipLevel',
        ]) ??
        _readChannelExtraInt(channel?.localExtra, const [
          'vip_level',
          'vipLevel',
        ]) ??
        0;
  }
  var personalInfoKnown = request.preferredPersonalInfoKnown;

  Future<UserInfo?> personalInfoFuture = Future<UserInfo?>.value(null);
  if (shouldFetchPersonalConversationUserInfo(
    conversation: conversation,
    currentUid: currentUid,
    resolvedTitle: title,
    resolvedVipLevel: vipLevel,
    preferredPersonalInfoKnown: personalInfoKnown,
  )) {
    final loader =
        personalUserInfoLoader ??
        (String uid) => UserApi.instance
            .getUserInfo(uid)
            .then<UserInfo?>((user) => user, onError: (_, _) => null);
    personalInfoFuture = loader(
      conversation.channelID,
    ).then<UserInfo?>((user) => user, onError: (_, _) => null);
  }

  Future<GroupInfo?> groupInfoFuture = Future<GroupInfo?>.value(null);
  if (conversation.channelType == WKChannelType.group &&
      title == conversation.channelID) {
    final loader =
        groupInfoLoader ??
        (String groupNo) => GroupApi.instance
            .getGroupInfo(groupNo)
            .then<GroupInfo?>((group) => group, onError: (_, _) => null);
    groupInfoFuture = loader(
      conversation.channelID,
    ).then<GroupInfo?>((group) => group, onError: (_, _) => null);
  }

  Future<WKChannelMember?> currentMemberFuture = Future<WKChannelMember?>.value(
    null,
  );
  if (channel?.forbidden == 1 &&
      conversation.channelType == WKChannelType.group &&
      currentUid.isNotEmpty) {
    currentMemberFuture = WKIM.shared.channelMemberManager.getMember(
      conversation.channelID,
      conversation.channelType,
      currentUid,
    );
  }

  final group = await groupInfoFuture;
  if (group != null) {
    final resolvedName = (group.name ?? '').trim();
    final resolvedAvatar = (group.avatar ?? '').trim();
    if (resolvedName.isNotEmpty) {
      title = resolvedName;
    }
    if (resolvedAvatar.isNotEmpty) {
      avatarUrl = _resolveConversationAvatar(resolvedAvatar) ?? avatarUrl;
    }
  }
  final personalInfo = await personalInfoFuture;
  if (personalInfo != null) {
    personalInfoKnown = true;
    final resolvedName = _firstNonEmptyText([
      personalInfo.remark,
      personalInfo.name,
      personalInfo.username,
    ]);
    if (resolvedName.isNotEmpty) {
      title = resolvedName;
    }
    final resolvedAvatar = (personalInfo.avatar ?? '').trim();
    if (resolvedAvatar.isNotEmpty &&
        (request.preferredAvatarUrl?.trim().isEmpty ?? true)) {
      avatarUrl = _resolveConversationAvatar(resolvedAvatar) ?? avatarUrl;
    }
    final resolvedCategory = normalizePublicAccountCategory(
      personalInfo.category,
    );
    if (resolvedCategory != null && resolvedCategory.isNotEmpty) {
      category = resolvedCategory;
    }
    if (vipLevel == 0 && personalInfo.vipLevel != 0) {
      vipLevel = personalInfo.vipLevel;
    }
  }

  final chatPasswordProtected = isChatPasswordProtectedChannel(channel);
  final preview = resolveConversationPreviewText(
    msg,
    conversationChannelType: conversation.channelType,
  );
  final draft = DraftManager().getDraft(
    conversation.channelID,
    conversation.channelType,
  );
  var hasDraft = false;
  var resolvedPreview = preview;
  if (draft != null &&
      (draft.content.trim().isNotEmpty ||
          (draft.replyMsgId?.trim().isNotEmpty ?? false))) {
    hasDraft = true;
    resolvedPreview = _resolveConversationDraftPreview(draft);
  }
  if (chatPasswordProtected) {
    resolvedPreview = chatPasswordMaskedPreview;
  }

  final reminderLabel = _resolveConversationReminderLabel(
    reminders,
    hasDraft: hasDraft,
  );
  final conversationTime = conversation.lastMsgTimestamp > 0
      ? DateTime.fromMillisecondsSinceEpoch(
          conversation.lastMsgTimestamp * 1000,
        )
      : null;
  final draftTimestamp = hasDraft ? draft?.updateTime : null;
  final draftTime = draftTimestamp != null
      ? DateTime.fromMillisecondsSinceEpoch(draftTimestamp * 1000)
      : null;
  final resolvedTime =
      (draftTime != null &&
          (conversationTime == null || draftTime.isAfter(conversationTime)))
      ? draftTime
      : conversationTime;

  final sendStatus = resolveConversationSendStatus(msg, currentUid: currentUid);
  final currentMember = await currentMemberFuture;
  final activityState = ConversationActivityRegistry.instance.getState(
    conversation.channelID,
    conversation.channelType,
  );

  return WKConversationItemData(
    channelId: conversation.channelID,
    channelType: conversation.channelType,
    title: title,
    avatarUrl: avatarUrl,
    vipLevel: vipLevel,
    lastMsgContent: resolvedPreview,
    lastMsgTime: resolvedTime,
    unreadCount: conversation.unreadCount,
    isMentionMe:
        reminders?.any(
          (item) =>
              item.type == WKMentionType.wkReminderTypeMentionMe &&
              item.done == 0,
        ) ==
        true,
    reminderLabel: reminderLabel,
    typingLabel: activityState.typingLabel,
    showTypingIndicator: activityState.isTyping,
    isGroup: conversation.channelType == WKChannelType.group,
    isMuted: channel?.mute == 1,
    isDraft: hasDraft,
    isTop: channel?.top == 1,
    isForbidden: resolveConversationForbiddenState(
      channel: channel,
      currentMember: currentMember,
    ),
    isRobot: channel?.robot == 1,
    isCalling: activityState.isCalling,
    category: category.isEmpty ? null : category,
    personalInfoKnown: personalInfoKnown,
    showSingleTick: sendStatus.showSingleTick,
    showDoubleTick: sendStatus.showDoubleTick,
    showSending: sendStatus.showSending,
    showSendFailed: sendStatus.showSendFailed,
  );
}

@visibleForTesting
WKMsg? resolveConversationListMessageSnapshot({
  required WKMsg? cachedMessage,
  required WKMsg? freshMessage,
}) {
  if (cachedMessage == null) {
    return freshMessage;
  }
  if (freshMessage == null) {
    return cachedMessage;
  }
  return preferConversationMessage(cachedMessage, freshMessage);
}

String? _resolveConversationReminderLabel(
  List<WKReminder>? reminders, {
  required bool hasDraft,
}) {
  final active = reminders?.where((item) => item.done == 0).toList() ?? [];
  final labels = <String>[];

  if (active.any(
    (item) => item.type == WKMentionType.wkReminderTypeMentionMe,
  )) {
    labels.add('[Mentioned]');
  }
  if (hasDraft) {
    labels.add('[Draft]');
  }
  if (active.any(
    (item) => item.type == WKMentionType.wkApplyJoinGroupApprove,
  )) {
    labels.add('[Join request]');
  }

  if (labels.isEmpty) {
    return null;
  }
  return labels.join(' ');
}

String _resolveConversationTitle(
  WKUIConversationMsg conversation,
  WKChannel? channel,
) {
  final remark = channel?.channelRemark.trim() ?? '';
  final name = channel?.channelName.trim() ?? '';

  if (remark.isNotEmpty) {
    return remark;
  }
  if (name.isNotEmpty) {
    return name;
  }
  return conversation.channelID;
}

@visibleForTesting
String resolveConversationPreviewText(
  WKMsg? msg, {
  int? conversationChannelType,
}) {
  if (msg == null) {
    return '';
  }

  final content = resolveVisibleMessageContent(msg);
  String preview;
  switch (msg.contentType) {
    case WkMessageContentType.text:
      final resolved = resolveVisibleTextMessage(msg, fallback: '').trim();
      preview = resolved.isEmpty ? '文字消息' : resolved;
      break;
    case WkMessageContentType.image:
      preview = '[图片]';
      break;
    case WkMessageContentType.voice:
      if (content is WKVoiceContent && content.timeTrad > 0) {
        preview = '[语音] ${content.timeTrad}"';
        break;
      }
      preview = '[语音]';
      break;
    case WkMessageContentType.video:
      preview = '[视频]';
      break;
    case WkMessageContentType.location:
      preview = '[位置]';
      break;
    case WkMessageContentType.file:
      if (content is WKFileContent && content.name.trim().isNotEmpty) {
        preview = '[文件] ${content.name.trim()}';
        break;
      }
      preview = '[文件]';
      break;
    case WkMessageContentType.card:
      if (content is WKCardContent && content.name.trim().isNotEmpty) {
        preview = '[名片] ${content.name.trim()}';
        break;
      }
      preview = '[名片]';
      break;
    case MsgContentType.robotCard:
      final robotCardPreview = resolveRobotCardPlainText(msg, content: content);
      preview = robotCardPreview.isEmpty ? '新消息' : robotCardPreview;
      break;
    default:
      final raw = msg.content.trim();
      final resolved = resolveStructuredMessagePreview(raw).text.trim();
      preview = resolved.isEmpty ? '新消息' : resolved;
      break;
  }

  final channelType = conversationChannelType ?? msg.channelType;
  if (channelType == WKChannelType.group) {
    final robotDisplayName = _firstNonEmptyText([
      resolveRobotCardName(msg, content: content),
      resolveRobotMessageIdentityFromMessage(msg)?.displayName,
    ]);
    if (robotDisplayName.isNotEmpty) {
      return '$robotDisplayName: $preview';
    }
  }
  return preview;
}

String _resolveConversationDraftPreview(MessageDraft draft) {
  final content = draft.content.trim();
  if (content.isNotEmpty) {
    return content;
  }
  final replyContent = draft.replyContent?.trim() ?? '';
  if (replyContent.isNotEmpty) {
    return '回复：$replyContent';
  }
  return '未发送草稿';
}

String? _resolveConversationAvatar(String? rawAvatar) {
  final avatar = rawAvatar?.trim() ?? '';
  if (avatar.isEmpty) {
    return null;
  }
  if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
    return avatar;
  }
  return ApiConfig.resolveMediaUrl(avatar);
}

String _firstNonEmptyText(List<String?> values) {
  for (final value in values) {
    final normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
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
