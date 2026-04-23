import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../../data/models/user.dart';
import '../../../widgets/wk_avatar.dart';
import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_design_tokens.dart';
import '../../../widgets/wk_reference_assets.dart';
import '../../../wukong_uikit/search/add_friends_page.dart';
import '../../chat/chat_page.dart';
import '../application/global_search_controller.dart';
import '../application/search_providers.dart';
import '../domain/search_models.dart';
import 'global_search_channel_results_page.dart';
import 'search_chat_navigation.dart';
import 'widgets/global_search_channel_tile.dart';
import 'widgets/global_search_find_user_row.dart';
import 'widgets/global_search_message_tile.dart';

class GlobalSearchPage extends ConsumerStatefulWidget {
  const GlobalSearchPage({
    super.key,
    this.initialQuery,
    this.onOpenSearchUser,
    this.onOpenUserChat,
    this.onOpenGroupChat,
  });

  final String? initialQuery;
  final ValueChanged<String>? onOpenSearchUser;
  final ValueChanged<User>? onOpenUserChat;
  final ValueChanged<Map<String, dynamic>>? onOpenGroupChat;

  @override
  ConsumerState<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends ConsumerState<GlobalSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(globalSearchControllerProvider.notifier)
            .updateKeyword(initialQuery);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(globalSearchControllerProvider);
    final controller = ref.read(globalSearchControllerProvider.notifier);

    return Scaffold(
      backgroundColor: WKColors.homeBg,
      body: Column(
        children: [
          ColoredBox(
            color: WKColors.homeBg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                child: Row(
                  key: const ValueKey<String>('global-search-inline-shell'),
                  children: [
                    Expanded(
                      child: _buildSearchBar(
                        state: state,
                        onChanged: controller.updateKeyword,
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const ValueKey<String>('global-search-cancel'),
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: WKFontFamily.primary,
                              fontSize: 16,
                              color: WKColors.color999,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: _buildBody(
              state: state,
              onRetryInitial: controller.retry,
              onLoadMore: controller.loadMore,
              onRetryLoadMore: () => controller.loadMore(isRetry: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar({
    required GlobalSearchState state,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 5),
            child: WKReferenceAssets.image(
              WKReferenceAssets.search,
              width: 18,
              height: 18,
              tint: WKColors.popupText,
            ),
          ),
          Expanded(
            child: TextField(
              key: const ValueKey<String>('global-search-field'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              maxLines: 1,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 14,
                color: WKColors.colorDark,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: 'Search',
                hintStyle: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 14,
                  color: WKColors.color999,
                ),
              ),
              onChanged: onChanged,
            ),
          ),
          if (state.hasKeyword)
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey<String>('global-search-clear'),
                onTap: () {
                  _searchController.clear();
                  onChanged('');
                },
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, size: 16, color: WKColors.color999),
                ),
              ),
            ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildBody({
    required GlobalSearchState state,
    required VoidCallback onRetryInitial,
    required Future<void> Function() onLoadMore,
    required VoidCallback onRetryLoadMore,
  }) {
    if (!state.hasKeyword) {
      return const SizedBox.shrink();
    }

    final hasResults =
        state.users.isNotEmpty ||
        state.groups.isNotEmpty ||
        state.messages.isNotEmpty;
    if (state.isLoading && !hasResults) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && !hasResults) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('global-search-initial-retry'),
              onPressed: onRetryInitial,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          onLoadMore();
        }
        return false;
      },
      child: ListView(
        key: const ValueKey<String>('global-search-results-list'),
        padding: EdgeInsets.zero,
        children: _buildResultsChildren(state, onRetryLoadMore),
      ),
    );
  }

  List<Widget> _buildResultsChildren(
    GlobalSearchState state,
    VoidCallback onRetryLoadMore,
  ) {
    final children = <Widget>[
      const SizedBox(height: 1),
      if (state.users.isNotEmpty) ...[
        _buildSectionHeader(
          key: const ValueKey<String>('global-search-section-users'),
          title: 'Contacts',
        ),
        ...state.users.map(_buildUserRow),
      ],
      if (state.groups.isNotEmpty) ...[
        _buildSectionHeader(
          key: const ValueKey<String>('global-search-section-groups'),
          title: 'Groups',
        ),
        ...state.groups.map(_buildGroupRow),
      ],
      GlobalSearchFindUserRow(
        keyword: state.keyword.trim(),
        onTap: () => _openSearchUser(state.keyword.trim()),
      ),
      if (state.messages.isNotEmpty) ...[
        _buildSectionHeader(
          key: const ValueKey<String>('global-search-section-messages'),
          title: 'Messages',
        ),
        ...state.messages.map(_buildMessageRow),
      ],
      if (state.isLoadingMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (state.loadMoreError != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Load more failed'),
                const SizedBox(height: 12),
                FilledButton(
                  key: const ValueKey<String>('global-search-load-more-retry'),
                  onPressed: onRetryLoadMore,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
    ];

    return children;
  }

  Widget _buildSectionHeader({required Key key, required String title}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: WKColors.colorLine),
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 12,
              color: WKColors.colorDark,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 15),
          child: Divider(height: 1, thickness: 1, color: WKColors.colorLine),
        ),
      ],
    );
  }

  Widget _buildUserRow(SearchMemberHit user) {
    final title = _memberTitle(user);
    return Material(
      color: WKColors.surface,
      child: InkWell(
        key: ValueKey<String>('global-search-user-${user.uid}'),
        onTap: () => _openUserChat(user),
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Row(
            children: [
              WKAvatar(url: user.avatarUrl, name: title, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 14,
                    color: WKColors.colorDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupRow(SearchMessageHit group) {
    return GlobalSearchChannelTile(
      group: group,
      onTap: () => _openGroupChat(group),
    );
  }

  Widget _buildMessageRow(SearchMessageHit hit) {
    return GlobalSearchMessageTile(hit: hit, onTap: () => _openMessageHit(hit));
  }

  Future<void> _openMessageHit(SearchMessageHit hit) async {
    final keyword = _searchController.text.trim();
    if (hit.matchCount > 1) {
      if (keyword.isEmpty) {
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GlobalSearchChannelResultsPage(
            channelId: hit.channelId,
            channelType: hit.channelType,
            channelName: hit.channelName,
            keyword: keyword,
          ),
        ),
      );
      return;
    }
    final resolver = ref.read(searchLocateResolverProvider);
    final intent = resolver.fromSearchHit(
      hit,
      highlightKeyword: keyword,
      source: 'global-search',
    );

    await openChatFromLocateIntent(
      context: context,
      ref: ref,
      intent: intent,
      fallbackChannelName: hit.channelName,
    );
  }

  void _openSearchUser(String keyword) {
    if (keyword.isEmpty) {
      return;
    }
    if (widget.onOpenSearchUser != null) {
      widget.onOpenSearchUser!(keyword);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchUserPage(initialQuery: keyword)),
    );
  }

  void _openUserChat(SearchMemberHit user) {
    if (widget.onOpenUserChat != null) {
      widget.onOpenUserChat!(
        User(
          uid: user.uid,
          name: user.displayName,
          avatar: user.avatarUrl ?? '',
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: user.uid,
          channelType: WKChannelType.personal,
          channelName: _memberTitle(user),
        ),
      ),
    );
  }

  void _openGroupChat(SearchMessageHit group) {
    if (widget.onOpenGroupChat != null) {
      widget.onOpenGroupChat!(_groupToJson(group));
      return;
    }
    final groupId = group.channelId.trim();
    if (groupId.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          channelId: groupId,
          channelType: WKChannelType.group,
          channelName: globalSearchGroupTitle(group),
        ),
      ),
    );
  }

  String _memberTitle(SearchMemberHit member) {
    final name = member.displayName.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return member.uid;
  }

  Map<String, dynamic> _groupToJson(SearchMessageHit group) {
    return <String, dynamic>{
      'group_no': group.channelId,
      'name': globalSearchGroupTitle(group),
      'channel_id': group.channelId,
      'channel_type': group.channelType,
      'remark': group.previewText,
    };
  }
}
