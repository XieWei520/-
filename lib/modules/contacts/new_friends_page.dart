import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/friend.dart';
import '../../data/providers/user_provider.dart';
import '../../modules/contacts/contacts_strings.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_status_view.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../../wukong_uikit/search/add_friends_page.dart';
import '../../wukong_uikit/user/user_detail_page.dart';
import '../vip/vip_guard.dart';

class NewFriendsPage extends ConsumerStatefulWidget {
  final List<FriendRequest>? initialRequests;
  final Future<void> Function(FriendRequest request)? onApprove;
  final Future<void> Function(FriendRequest request)? onDelete;
  final VoidCallback? onOpenAddFriend;
  final ValueChanged<String>? onOpenUserDetail;

  const NewFriendsPage({
    super.key,
    this.initialRequests,
    this.onApprove,
    this.onDelete,
    this.onOpenAddFriend,
    this.onOpenUserDetail,
  });

  @override
  ConsumerState<NewFriendsPage> createState() => _NewFriendsPageState();
}

class _NewFriendsPageState extends ConsumerState<NewFriendsPage> {
  final Set<String> _deletedRequestKeys = <String>{};
  final Set<String> _approvedRequestKeys = <String>{};
  final Set<String> _handlingRequestKeys = <String>{};

  @override
  Widget build(BuildContext context) {
    final strings = resolveContactsStrings(
      locale: Localizations.maybeLocaleOf(context),
    );
    final AsyncValue<List<FriendRequest>> requestsState =
        widget.initialRequests != null
        ? AsyncValue<List<FriendRequest>>.data(widget.initialRequests!)
        : ref.watch(friendRequestListProvider);

    return WKSubPageScaffold(
      title: strings.newFriendsTitle,
      trailing: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('new-friends-add-friend-entry'),
          onTap: _openAddFriendPage,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: WKReferenceAssets.image(
              WKReferenceAssets.menuInvite,
              width: 18,
              height: 18,
              tint: WKColors.colorDark,
            ),
          ),
        ),
      ),
      body: requestsState.when(
        loading: () => WKLoadingView(message: strings.newFriendsLoading),
        error: (error, _) => WKErrorView(
          message: strings.newFriendsLoadFailed,
          subMessage: error.toString(),
          onRetry: () => ref.read(friendRequestListProvider.notifier).refresh(),
        ),
        data: (requests) => _buildContent(requests, strings),
      ),
    );
  }

  Widget _buildContent(List<FriendRequest> requests, ContactsStrings strings) {
    final friendsState = ref.watch(friendListProvider);
    final friendUids = _resolveFriendUids(friendsState);
    final friendsResolved = friendsState.hasValue;
    final visibleRequests = requests
        .where((request) => !_deletedRequestKeys.contains(_requestKey(request)))
        .toList(growable: false);

    if (visibleRequests.isEmpty) {
      return WKEmptyView(
        icon: Icons.person_add_alt,
        message: strings.newFriendsEmpty,
        subMessage: strings.newFriendsEmptyHint,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (widget.initialRequests != null) {
          return;
        }
        await ref.read(friendListProvider.notifier).refresh();
        await ref.read(friendRequestListProvider.notifier).refresh();
      },
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: visibleRequests.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          thickness: 1,
          indent: 75,
          color: WKColors.homeBg,
        ),
        itemBuilder: (context, index) {
          final request = visibleRequests[index];
          final requestKey = _requestKey(request);
          final presentation = _resolveRequestPresentation(
            request,
            friendUids: friendUids,
            locallyApproved: _approvedRequestKeys.contains(requestKey),
            friendsResolved: friendsResolved,
          );
          final isHandling = _handlingRequestKeys.contains(requestKey);

          return Builder(
            builder: (itemContext) => _NewFriendRow(
              request: request,
              isProcessed: presentation.isProcessed,
              isHandling: isHandling,
              strings: strings,
              approveActionKey: ValueKey<String>(
                'new-friend-approve-action-${request.fromUid.trim().isNotEmpty ? request.fromUid.trim() : requestKey}',
              ),
              onTap: () => _openUserDetail(request, presentation.canOpenDetail),
              onLongPress: () =>
                  _showRequestMenu(itemContext, request, strings),
              onApprove: presentation.canApprove && !isHandling
                  ? () => _approveRequest(request)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Future<void> _approveRequest(FriendRequest request) async {
    final requestKey = _requestKey(request);
    if (_handlingRequestKeys.contains(requestKey)) {
      return;
    }

    final friendsState = ref.read(friendListProvider);
    final presentation = _resolveRequestPresentation(
      request,
      friendUids: _resolveFriendUids(friendsState),
      locallyApproved: _approvedRequestKeys.contains(requestKey),
      friendsResolved: friendsState.hasValue,
    );
    if (presentation.isProcessed) {
      if (presentation.canOpenDetail) {
        setState(() => _approvedRequestKeys.add(requestKey));
      }
      return;
    }
    if (!presentation.canApprove) {
      return;
    }

    setState(() => _handlingRequestKeys.add(requestKey));

    try {
      if (widget.onApprove != null) {
        await widget.onApprove!(request);
        if (!mounted) {
          return;
        }
        setState(() => _approvedRequestKeys.add(requestKey));
        return;
      }

      final result = await ref
          .read(friendRequestListProvider.notifier)
          .handleRequest(request, true);
      if (result.shouldRefreshFriends) {
        await ref.read(friendListProvider.notifier).refresh();
      }
      if (!mounted) {
        return;
      }
      if (result.success) {
        setState(() => _approvedRequestKeys.add(requestKey));
      } else {
        _showMessage(result.message);
      }
    } finally {
      if (mounted) {
        setState(() => _handlingRequestKeys.remove(requestKey));
      }
    }
  }

  Future<void> _showRequestMenu(
    BuildContext anchorContext,
    FriendRequest request,
    ContactsStrings strings,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final anchor = anchorContext.findRenderObject() as RenderBox?;
    if (anchor == null) {
      return;
    }

    final offset = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    final action = await showMenu<_NewFriendMenuAction>(
      context: context,
      color: WKColors.surface,
      elevation: 8,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      position: RelativeRect.fromLTRB(
        offset.dx + 24,
        offset.dy + 10,
        overlay.size.width - offset.dx - anchor.size.width + 24,
        overlay.size.height - offset.dy,
      ),
      items: [
        PopupMenuItem<_NewFriendMenuAction>(
          value: _NewFriendMenuAction.delete,
          height: 42,
          child: Text(
            strings.delete,
            style: const TextStyle(fontSize: 14, color: WKColors.colorDark),
          ),
        ),
      ],
    );

    if (action == _NewFriendMenuAction.delete) {
      await _deleteRequest(request);
    }
  }

  Future<void> _deleteRequest(FriendRequest request) async {
    final requestKey = _requestKey(request);
    if (widget.onDelete != null) {
      await widget.onDelete!(request);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _deletedRequestKeys.add(requestKey);
      _approvedRequestKeys.remove(requestKey);
      _handlingRequestKeys.remove(requestKey);
    });
  }

  void _openUserDetail(FriendRequest request, bool canOpenDetail) {
    if (!canOpenDetail) {
      return;
    }

    final uid = request.fromUid.trim();
    if (uid.isEmpty) {
      return;
    }

    if (widget.onOpenUserDetail != null) {
      widget.onOpenUserDetail!(uid);
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => UserDetailPage(uid: uid)));
  }

  Future<void> _openAddFriendPage() async {
    if (!await guardVipFeature(
      context,
      entitlement: VipEntitlement.addFriend,
    )) {
      return;
    }
    if (!mounted) {
      return;
    }
    if (widget.onOpenAddFriend != null) {
      widget.onOpenAddFriend!();
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddFriendsPage()));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _requestKey(FriendRequest request) {
    final token = request.token?.trim() ?? '';
    if (token.isNotEmpty) {
      return 'token_$token';
    }
    if (request.id != 0) {
      return 'id_${request.id}';
    }
    return 'uid_${request.fromUid.trim()}';
  }
}

Set<String> _resolveFriendUids(AsyncValue<List<Friend>> friendsState) {
  return friendsState.maybeWhen(
    data: (friends) => friends
        .map((friend) => friend.uid.trim())
        .where((uid) => uid.isNotEmpty)
        .toSet(),
    orElse: () => const <String>{},
  );
}

_NewFriendRequestPresentation _resolveRequestPresentation(
  FriendRequest request, {
  required Set<String> friendUids,
  required bool locallyApproved,
  required bool friendsResolved,
}) {
  final normalizedUid = request.fromUid.trim();
  final normalizedAccepted =
      request.isPending &&
      normalizedUid.isNotEmpty &&
      friendUids.contains(normalizedUid);
  final isAccepted =
      request.isAccepted || normalizedAccepted || locallyApproved;
  return _NewFriendRequestPresentation(
    isProcessed: !request.isPending || isAccepted,
    canOpenDetail: isAccepted,
    canApprove: request.isPending && friendsResolved && !isAccepted,
  );
}

class _NewFriendRequestPresentation {
  const _NewFriendRequestPresentation({
    required this.isProcessed,
    required this.canOpenDetail,
    required this.canApprove,
  });

  final bool isProcessed;
  final bool canOpenDetail;
  final bool canApprove;
}

enum _NewFriendMenuAction { delete }

class _NewFriendRow extends StatelessWidget {
  final FriendRequest request;
  final bool isProcessed;
  final bool isHandling;
  final ContactsStrings strings;
  final Key? approveActionKey;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onApprove;

  const _NewFriendRow({
    required this.request,
    required this.isProcessed,
    required this.isHandling,
    required this.strings,
    this.approveActionKey,
    required this.onTap,
    required this.onLongPress,
    required this.onApprove,
  });

  Widget _buildAction() {
    if (isProcessed) {
      return Text(
        strings.processed,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 14,
          color: WKColors.color999,
        ),
      );
    }

    final enabled = onApprove != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: isHandling ? strings.processing : strings.approve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: approveActionKey,
          onTap: onApprove,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? WKColors.brand500 : WKColors.brand300,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isHandling ? strings.processing : strings.approve,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 14,
                color: WKColors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (request.fromName ?? request.fromUid).trim();
    final subtitle = (request.extra ?? '').trim().isEmpty
        ? strings.requestAddFriend
        : request.extra!.trim();

    return Material(
      color: WKColors.surface,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.title,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 12,
                        color: WKColors.color999,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildAction(),
            ],
          ),
        ),
      ),
    );
  }
}
