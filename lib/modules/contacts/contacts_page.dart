import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/constants/im_constants.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/friend.dart';
import '../../data/models/group.dart';
import '../../data/providers/channel_provider.dart';
import '../../data/providers/user_provider.dart';
import '../customer_service/customer_service_identity.dart';
import '../../service/api/friend_api.dart';
import '../../service/api/user_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_branded_icon.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_main_top_bar.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_screen_popup_menu.dart';
import '../../widgets/wk_status_view.dart';
import '../../widgets/wk_web_ui_tokens.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/contacts_slots.dart';
import '../../wk_endpoint/slots/home_slots.dart';
import '../../wukong_base/endpoint/entity/contacts_menu.dart';
import '../../wukong_uikit/group/saved_groups_page.dart';
import '../../wukong_uikit/search/add_friends_page.dart';
import '../../wukong_uikit/search/global_search_page.dart';
import '../../wukong_uikit/user/user_detail_page.dart';
import '../../wukong_scan/scan_page.dart';
import '../chat/chat_page.dart';
import 'contact_filter.dart';
import 'contacts_slot_assembly.dart';
import 'contacts_strings.dart';
import 'contacts_directory_controller.dart';
import 'contacts_presence_controller.dart';
import 'create_group_page.dart';
import '../moments/moments_page.dart';
import 'new_friends_page.dart';
import '../tag/tag_manage_page.dart';
import '../home/home_surface_contract.dart';
import '../home/home_surface_kernel.dart';
import '../home/home_top_menu_slot_assembly.dart';
import '../vip/vip_guard.dart';
import 'widgets/contacts_alphabet_index.dart';
import 'widgets/contacts_list_viewport.dart';

export 'new_friends_page.dart' show NewFriendsPage;

@visibleForTesting
WKBrandedIconSpec? resolveContactsHeaderIconSpec(String sid) {
  switch (sid) {
    case 'friend':
      return const WKBrandedIconSpec(
        icon: Icons.person_add_alt_1_rounded,
        startColor: Color(0xFF67B8FF),
        endColor: Color(0xFF418BFF),
      );
    case 'group':
      return const WKBrandedIconSpec(
        icon: Icons.groups_rounded,
        startColor: Color(0xFFFFA77D),
        endColor: Color(0xFFF47458),
      );
    case 'moments':
      return const WKBrandedIconSpec(
        icon: Icons.photo_library_rounded,
        startColor: Color(0xFFFFC760),
        endColor: Color(0xFFF39A35),
      );
    case 'tag':
      return const WKBrandedIconSpec(
        icon: Icons.local_offer_rounded,
        startColor: Color(0xFF59D8CF),
        endColor: Color(0xFF20B5A9),
      );
    case 'customer_service':
      return const WKBrandedIconSpec(
        icon: Icons.support_agent_rounded,
        startColor: Color(0xFF8DB2FF),
        endColor: Color(0xFF5B77E6),
      );
    default:
      return null;
  }
}

final contactsDirectoryControllerProvider =
    Provider<ContactsDirectoryController>((ref) {
      return ContactsDirectoryController();
    });

@visibleForTesting
SurfaceReliabilityState resolveContactsSurfaceReliability(
  AsyncValue<List<Friend>> friendsState,
) {
  return friendsState.when(
    loading: () => SurfaceReliabilityState.stale,
    error: (_, _) => SurfaceReliabilityState.degraded,
    data: (_) => SurfaceReliabilityState.healthy,
  );
}

@immutable
class ContactsDirectoryRequest {
  ContactsDirectoryRequest({
    required List<Friend> friends,
    required this.currentUid,
  }) : friends = List<Friend>.unmodifiable(friends);

  final List<Friend> friends;
  final String currentUid;

  bool matches(List<Friend> otherFriends, String otherCurrentUid) {
    if (currentUid != otherCurrentUid ||
        friends.length != otherFriends.length) {
      return false;
    }

    for (var index = 0; index < friends.length; index++) {
      if (!_sameFriendSnapshot(friends[index], otherFriends[index])) {
        return false;
      }
    }
    return true;
  }

  bool _sameFriendSnapshot(Friend left, Friend right) {
    return left.uid == right.uid &&
        left.name == right.name &&
        left.avatar == right.avatar &&
        left.remark == right.remark &&
        left.status == right.status &&
        left.category == right.category &&
        left.robot == right.robot &&
        left.beDeleted == right.beDeleted &&
        left.beBlacklist == right.beBlacklist &&
        left.isUploadAvatar == right.isUploadAvatar &&
        left.createdAt == right.createdAt &&
        left.updatedAt == right.updatedAt &&
        left.vipLevel == right.vipLevel;
  }
}

class ContactsPage extends ConsumerStatefulWidget {
  final List<ContactsMenu>? headerMenus;
  final AsyncValue<List<Friend>>? friendsStateOverride;
  final AsyncValue<List<FriendRequest>>? requestsStateOverride;
  final ValueChanged<String>? onOpenContactChat;
  final ValueChanged<String>? onSetContactRemark;
  final VoidCallback? onOpenMomentsPage;
  final VoidCallback? onOpenTagManagePage;
  final VoidCallback? onOpenCustomerService;
  final ValueChanged<CustomerServiceAccount>? onOpenResolvedCustomerService;
  final Map<String, ContactPresenceState>? contactPresenceOverrides;
  final int? currentTimestampSecondsOverride;
  final bool forceWebFrameForTesting;

  const ContactsPage({
    super.key,
    this.headerMenus,
    this.friendsStateOverride,
    this.requestsStateOverride,
    this.onOpenContactChat,
    this.onSetContactRemark,
    this.onOpenMomentsPage,
    this.onOpenTagManagePage,
    this.onOpenCustomerService,
    this.onOpenResolvedCustomerService,
    this.contactPresenceOverrides,
    this.currentTimestampSecondsOverride,
    this.forceWebFrameForTesting = false,
  });

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  static const double _headerItemHeight = 60;
  static const double _headerBottomGap = 20;
  static const double _contactRowHeight = 70;
  static const double _sectionHeight = 28;

  final ScrollController _scrollController = ScrollController();
  late final String _channelRefreshListenerKey;
  ProviderSubscription<AsyncValue<List<Friend>>>?
  _friendsReliabilitySubscription;
  ContactsDirectoryRequest? _directoryRequest;
  ContactsDirectoryData? _directoryData;
  String? _sidebarLetter;
  bool _sidebarTouching = false;
  bool _isOpeningCustomerService = false;

  @override
  void initState() {
    super.initState();
    _channelRefreshListenerKey = 'contacts_page_${identityHashCode(this)}';
    _bindKernelListeners();
    if (widget.contactPresenceOverrides == null) {
      WKIM.shared.channelManager.addOnRefreshListener(
        _channelRefreshListenerKey,
        _handleChannelRefresh,
      );
    }
  }

  @override
  void didUpdateWidget(covariant ContactsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hadOverrides = oldWidget.contactPresenceOverrides != null;
    final hasOverrides = widget.contactPresenceOverrides != null;
    if (hadOverrides != hasOverrides) {
      if (hasOverrides) {
        WKIM.shared.channelManager.removeOnRefreshListener(
          _channelRefreshListenerKey,
        );
      } else {
        WKIM.shared.channelManager.addOnRefreshListener(
          _channelRefreshListenerKey,
          _handleChannelRefresh,
        );
      }
      ref.read(contactsPresenceControllerProvider.notifier).reset();
    }

    if (oldWidget.friendsStateOverride != widget.friendsStateOverride) {
      _bindKernelListeners(reset: true);
    }
  }

  @override
  void dispose() {
    _friendsReliabilitySubscription?.close();
    WKIM.shared.channelManager.removeOnRefreshListener(
      _channelRefreshListenerKey,
    );
    _scrollController.dispose();
    super.dispose();
  }

  void _bindKernelListeners({bool reset = false}) {
    if (reset) {
      _friendsReliabilitySubscription?.close();
      _friendsReliabilitySubscription = null;
    }

    final overrideState = widget.friendsStateOverride;
    if (overrideState != null) {
      _syncContactsReliability(overrideState);
      return;
    }

    _syncContactsReliability(ref.read(friendListProvider));
    _friendsReliabilitySubscription ??= ref
        .listenManual<AsyncValue<List<Friend>>>(friendListProvider, (
          previous,
          next,
        ) {
          if (previous == next) {
            return;
          }
          _syncContactsReliability(next);
        });
  }

  void _syncContactsReliability(AsyncValue<List<Friend>> friendsState) {
    final kernel = ref.read(homeSurfaceKernelProvider);
    final nextState = resolveContactsSurfaceReliability(friendsState);
    if (kernel.reliabilityFor(HomeSurfaceId.contacts) == nextState) {
      return;
    }
    kernel.markSurfaceReliability(HomeSurfaceId.contacts, nextState);
  }

  void _handleChannelRefresh(WKChannel channel) {
    if (!mounted || widget.contactPresenceOverrides != null) {
      return;
    }
    if (channel.channelType != WKChannelType.personal) {
      return;
    }

    final uid = channel.channelID.trim();
    if (uid.isEmpty) {
      return;
    }

    ref
        .read(contactsPresenceControllerProvider.notifier)
        .updatePresence(uid, ContactPresenceState.fromChannel(channel));
  }

  void _syncContactPresence(List<ContactsDirectoryEntry> entries) {
    if (widget.contactPresenceOverrides != null) {
      return;
    }

    final uids = entries
        .map((entry) => entry.friend.uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.contactPresenceOverrides != null) {
        return;
      }
      ref.read(contactsPresenceControllerProvider.notifier).syncPresence(uids);
    });
  }

  ContactsDirectoryData _resolveDirectory(
    List<Friend> friends,
    ContactsDirectoryController controller,
  ) {
    final currentUid = StorageUtils.getUid() ?? '';
    final cachedRequest = _directoryRequest;
    if (cachedRequest != null &&
        cachedRequest.matches(friends, currentUid) &&
        _directoryData != null) {
      return _directoryData!;
    }

    final nextRequest = ContactsDirectoryRequest(
      friends: friends,
      currentUid: currentUid,
    );
    final nextData = controller.buildDirectory(
      filterVisibleContacts(
        nextRequest.friends,
        currentUid: nextRequest.currentUid,
      ),
    );
    _directoryRequest = nextRequest;
    _directoryData = nextData;
    return nextData;
  }

  @override
  Widget build(BuildContext context) {
    final strings = resolveContactsStrings(
      locale: Localizations.maybeLocaleOf(context),
    );
    final AsyncValue<List<Friend>> friendsState =
        widget.friendsStateOverride ?? ref.watch(friendListProvider);
    final directoryController = ref.watch(contactsDirectoryControllerProvider);
    final registry = ref.read(slotRegistryProvider);
    final AsyncValue<List<FriendRequest>> requestsState =
        widget.requestsStateOverride ?? ref.watch(friendRequestListProvider);
    final requestCount = requestsState.maybeWhen(
      data: countPendingFriendRequests,
      orElse: () => 0,
    );
    final resolvedHeaderMenus =
        widget.headerMenus ??
        resolveContactsHeaderMenus(
          registry,
          ContactsHeaderSlotContext(pendingRequestCount: requestCount),
          openNewFriendsPage: _openNewFriendsPage,
          openSavedGroupsPage: _openSavedGroupsPage,
          openMomentsPage: widget.onOpenMomentsPage ?? _openMomentsPage,
          openTagManagePage: widget.onOpenTagManagePage ?? _openTagManagePage,
          openCustomerService:
              widget.onOpenCustomerService ?? _openCustomerService,
        );
    final headerMenuCount = resolvedHeaderMenus.length;
    final currentTimestampSeconds =
        widget.currentTimestampSecondsOverride ??
        (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    final body = Column(
      children: [
        _buildHeader(strings),
        Expanded(
          child: friendsState.when(
            loading: () => WKLoadingView(message: strings.contactsLoading),
            error: (error, _) => WKErrorView(
              message: strings.contactsLoadFailed,
              subMessage: error.toString(),
              onRetry: () => ref.read(friendListProvider.notifier).refresh(),
            ),
            data: (friends) {
              final directory = _resolveDirectory(friends, directoryController);
              final entries = directory.sections
                  .expand((section) => section.entries)
                  .toList(growable: false);
              _syncContactPresence(entries);
              final letters = directory.letters;
              final header = _ContactsHeaderSection(
                headerMenus: resolvedHeaderMenus,
              );

              Widget buildViewport(
                Map<String, ContactPresenceState> contactPresenceByUid,
              ) {
                return ContactsListViewport(
                  scrollController: _scrollController,
                  header: header,
                  directory: directory,
                  contactPresenceByUid: contactPresenceByUid,
                  currentTimestampSeconds: currentTimestampSeconds,
                  onTapEntry: (entry) => _openUserDetail(entry.friend.uid),
                  onLongPressEntry: (entry) =>
                      _showContactMenu(entry.friend, strings),
                );
              }

              return Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(friendListProvider.notifier).refresh();
                      await ref
                          .read(friendRequestListProvider.notifier)
                          .refresh();
                    },
                    child: widget.contactPresenceOverrides != null
                        ? buildViewport(widget.contactPresenceOverrides!)
                        : Consumer(
                            builder: (context, ref, _) {
                              final contactPresenceByUid = ref.watch(
                                contactsPresenceControllerProvider,
                              );
                              return buildViewport(contactPresenceByUid);
                            },
                          ),
                  ),
                  if (letters.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ContactsAlphabetIndex(
                            letters: letters,
                            activeLetter: _sidebarLetter,
                            isTouching: _sidebarTouching,
                            onLetterTap: (letter) {
                              setState(() {
                                _sidebarLetter = letter;
                              });
                              _jumpToSection(
                                letter,
                                directory.sections,
                                headerMenuCount,
                              );
                            },
                            onTouchingChanged: (touching) {
                              setState(() {
                                _sidebarTouching = touching;
                                if (!touching) {
                                  _sidebarLetter = null;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );

    final content = Scaffold(backgroundColor: WKColors.homeBg, body: body);
    final useWebFrame =
        widget.forceWebFrameForTesting ||
        (kIsWeb &&
            MediaQuery.sizeOf(context).width >= WKWebBreakpoints.desktopMin);

    if (!useWebFrame) {
      return content;
    }

    return Scaffold(
      key: const ValueKey<String>('contacts-web-frame'),
      backgroundColor: WKWebColors.pageWarm,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: WKWebPanel(
            key: const ValueKey<String>('contacts-web-panel'),
            margin: const EdgeInsets.all(WKSpace.md),
            child: content.body ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ContactsStrings strings) {
    return WKMainTopBar(
      title: Text(strings.contactsTitle),
      actions: [
        WKTopBarActionButton(
          tooltip: strings.searchPlaceholder,
          padding: const EdgeInsets.only(right: 29),
          onTap: _openGlobalSearch,
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
              tooltip: '鏇村',
              onTap: () => _showTopMenu(buttonContext),
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

  String _displayName(Friend friend) {
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

  void _jumpToSection(
    String section,
    List<ContactsDirectorySection> sections,
    int headerMenuCount,
  ) {
    if (!_scrollController.hasClients) {
      return;
    }

    var offset = headerMenuCount == 0
        ? 0.0
        : (_headerItemHeight * headerMenuCount) + _headerBottomGap;
    for (final directorySection in sections) {
      if (directorySection.letter == section) {
        break;
      }
      offset += _sectionHeight;
      offset += _contactRowHeight * directorySection.entries.length;
    }

    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  Future<void> _openAddFriendPage() async {
    if (!await guardVipFeature(context)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final added = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const AddFriendsPage()));

    if (added != true || !mounted) {
      return;
    }

    await ref.read(friendListProvider.notifier).refresh();
    await ref.read(friendRequestListProvider.notifier).refresh();
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

    await ref.read(myGroupListProvider.notifier).refresh();
    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: group.groupNo,
          channelType: ChannelType.group,
          channelName: group.name ?? group.groupNo,
        ),
      ),
    );
  }

  void _openGlobalSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GlobalSearchPage()));
  }

  void _openUserDetail(String uid) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => UserDetailPage(uid: uid)));
  }

  Future<void> _showContactMenu(Friend friend, ContactsStrings strings) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }

    final action = await showMenu<_ContactMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        overlay.size.width / 2,
        overlay.size.height / 3,
        overlay.size.width / 2,
        overlay.size.height / 3,
      ),
      items: [
        PopupMenuItem<_ContactMenuAction>(
          value: _ContactMenuAction.remark,
          child: Text(strings.setRemark),
        ),
        PopupMenuItem<_ContactMenuAction>(
          value: _ContactMenuAction.chat,
          child: Text(strings.sendMessage),
        ),
      ],
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ContactMenuAction.remark:
        await _setContactRemark(friend, strings);
        break;
      case _ContactMenuAction.chat:
        _openContactChat(friend);
        break;
    }
  }

  void _openContactChat(Friend friend) {
    if (widget.onOpenContactChat != null) {
      widget.onOpenContactChat!(friend.uid);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: friend.uid,
          channelType: ChannelType.personal,
          channelName: _displayName(friend),
        ),
      ),
    );
  }

  Future<void> _setContactRemark(Friend friend, ContactsStrings strings) async {
    if (widget.onSetContactRemark != null) {
      widget.onSetContactRemark!(friend.uid);
      return;
    }

    final controller = TextEditingController(text: friend.remark ?? '');
    final remark = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(strings.remarkDialogTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 20,
            decoration: InputDecoration(hintText: strings.remarkDialogHint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.cancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(strings.save),
            ),
          ],
        );
      },
    );

    if (remark == null) {
      return;
    }

    try {
      await FriendApi.instance.updateFriendRemark(friend.uid, remark);
      if (!mounted) {
        return;
      }
      await ref.read(friendListProvider.notifier).refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${strings.setRemark}失败: $error')));
    }
  }

  void _openNewFriendsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NewFriendsPage()));
  }

  void _openSavedGroupsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SavedGroupsPage()));
  }

  void _openMomentsPage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MomentsPage()));
  }

  void _openTagManagePage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TagManagePage()));
  }

  void _openCustomerService() {
    unawaited(_openCustomerServiceAsync());
  }

  Future<void> _openCustomerServiceAsync() async {
    if (_isOpeningCustomerService) {
      return;
    }
    _isOpeningCustomerService = true;
    try {
      final services = await UserApi.instance.getCustomerServices();
      if (!mounted) {
        return;
      }
      for (final service in services) {
        if (service.uid.trim().isEmpty) {
          continue;
        }
        _openCustomerServiceChat(
          channelId: service.uid.trim(),
          channelName: service.name.trim().isEmpty ? '客服' : service.name.trim(),
          resolvedService: service,
        );
        return;
      }
      _openLegacyCustomerService();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _openLegacyCustomerService();
    } finally {
      _isOpeningCustomerService = false;
    }
  }

  void _openCustomerServiceChat({
    required String channelId,
    required String channelName,
    CustomerServiceAccount? resolvedService,
    bool legacyFallback = false,
  }) {
    final service =
        resolvedService ??
        CustomerServiceAccount(uid: channelId, name: channelName);
    final onOpenResolvedCustomerService = widget.onOpenResolvedCustomerService;
    if (onOpenResolvedCustomerService != null) {
      onOpenResolvedCustomerService(service);
      return;
    }
    final normalizedChannelId = channelId.trim();
    final resolvedChannelType = legacyFallback
        ? WKChannelType.customerService
        : WKChannelType.personal;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: normalizedChannelId,
          channelType: resolvedChannelType,
          channelName: channelName,
          channelCategory: customerServiceCategory,
        ),
      ),
    );
  }

  void _openLegacyCustomerService() {
    _openCustomerServiceChat(
      channelId: 'customer_service',
      legacyFallback: true,
      channelName: '客服',
      resolvedService: const CustomerServiceAccount(
        uid: 'customer_service',
        name: '客服',
      ),
    );
  }

  Future<void> _showTopMenu(BuildContext anchorContext) async {
    final registry = ref.read(slotRegistryProvider);
    final items = resolveHomeTopMenuItems(
      registry,
      HomeTopMenuContext(
        hasConversations: true,
        openCreateGroup: () => unawaited(_openCreateGroupPage()),
        openAddFriend: () => unawaited(_openAddFriendPage()),
        openScan: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ScanPage()));
        },
        enterMultiSelect: () {},
        clearAllConversations: () {},
      ),
    );
    const allowedIds = <String>{
      'home.create_group',
      'home.add_friend',
      'home.scan',
    };
    final filteredItems = items
        .where((item) => allowedIds.contains(item.id))
        .toList(growable: false);
    final action = await showWKScreenPopupMenu<HomeTopMenuItem>(
      context: context,
      anchorContext: anchorContext,
      items: filteredItems
          .map((item) => item.toPopupMenuItem())
          .toList(growable: false),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action.enabled) {
      action.onSelected();
    }
  }
}

enum _ContactMenuAction { remark, chat }

class LegacyNewFriendsPage extends ConsumerWidget {
  const LegacyNewFriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = resolveContactsStrings(
      locale: Localizations.maybeLocaleOf(context),
    );
    final requestsState = ref.watch(friendRequestListProvider);

    return Scaffold(
      backgroundColor: WKColors.homeBg,
      appBar: AppBar(title: Text(strings.newFriendsTitle)),
      body: requestsState.when(
        loading: () => WKLoadingView(message: strings.newFriendsLoading),
        error: (error, _) => WKErrorView(
          message: strings.newFriendsLoadFailed,
          subMessage: error.toString(),
          onRetry: () => ref.read(friendRequestListProvider.notifier).refresh(),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return WKEmptyView(
              icon: Icons.person_add_alt,
              message: strings.newFriendsEmpty,
              subMessage: strings.newFriendsEmptyHint,
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(friendRequestListProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: WKSpace.xl),
              itemCount: requests.length,
              separatorBuilder: (_, _) =>
                  Container(height: 15, color: WKColors.homeBg),
              itemBuilder: (context, index) {
                final request = requests[index];
                final title = (request.fromName ?? request.fromUid).trim();
                final subtitle = (request.extra ?? '').trim().isEmpty
                    ? strings.requestAddFriend
                    : request.extra!.trim();

                return Container(
                  color: WKColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      WKAvatar(url: request.fromAvatar, name: title, size: 50),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: WKFontFamily.title,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: WKColors.colorDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontFamily: WKFontFamily.primary,
                                fontSize: 13,
                                color: WKColors.color999,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: request.isPending
                            ? () async {
                                final result = await ref
                                    .read(friendRequestListProvider.notifier)
                                    .handleRequest(request, false);
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                              }
                            : null,
                        child: const Text('鎷掔粷'),
                      ),
                      ElevatedButton(
                        onPressed: request.isPending
                            ? () async {
                                final result = await ref
                                    .read(friendRequestListProvider.notifier)
                                    .handleRequest(request, true);
                                if (result.shouldRefreshFriends) {
                                  await ref
                                      .read(friendListProvider.notifier)
                                      .refresh();
                                }
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.message)),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(52, 34),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: Text(strings.approve),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ContactsHeaderSection extends StatelessWidget {
  const _ContactsHeaderSection({required this.headerMenus});

  final List<ContactsMenu> headerMenus;

  @override
  Widget build(BuildContext context) {
    if (headerMenus.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var index = 0; index < headerMenus.length; index++)
          _ContactsHeaderItem(
            menu: headerMenus[index],
            showBottomGap: index == headerMenus.length - 1,
          ),
      ],
    );
  }
}

class _ContactsHeaderItem extends StatelessWidget {
  final ContactsMenu menu;
  final bool showBottomGap;

  const _ContactsHeaderItem({required this.menu, this.showBottomGap = false});

  @override
  Widget build(BuildContext context) {
    final title = (menu.text ?? menu.sid).trim();
    final normalizedUid = menu.uid?.trim() ?? '';
    final showAvatar = normalizedUid.isNotEmpty;
    final showDot = menu.showRedDot;
    final brandedIconSpec = resolveContactsHeaderIconSpec(menu.sid);

    return Column(
      children: [
        Material(
          color: WKColors.surface,
          child: InkWell(
            key: ValueKey('contacts-header-${menu.sid}'),
            onTap: () => menu.onClick?.call(menu.sid),
            highlightColor: WKColors.screenBgSelected,
            splashColor: WKColors.screenBgSelected,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                children: [
                  if (brandedIconSpec != null)
                    buildWKBrandedIcon(brandedIconSpec)
                  else if ((menu.imgResource ?? '').trim().isNotEmpty)
                    WKReferenceAssets.image(
                      menu.imgResource!,
                      width: 40,
                      height: 40,
                    )
                  else
                    const SizedBox(width: 40, height: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 16,
                        color: WKColors.colorDark,
                      ),
                    ),
                  ),
                  if (showAvatar)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        WKAvatar(name: normalizedUid, size: 40),
                        if (showDot)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              key: ValueKey('contacts-header-dot-${menu.sid}'),
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: WKColors.reminderColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    )
                  else if (menu.badgeNum > 0)
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: WKColors.reminderColor,
                        borderRadius: BorderRadius.circular(WKRadius.pill),
                      ),
                      child: Text(
                        menu.badgeNum > 99 ? '99+' : '${menu.badgeNum}',
                        style: const TextStyle(
                          fontFamily: WKFontFamily.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: WKColors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showBottomGap) Container(height: 20, color: WKColors.homeBg),
      ],
    );
  }
}
