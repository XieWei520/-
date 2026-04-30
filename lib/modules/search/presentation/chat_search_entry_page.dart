import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../../wukong_uikit/group/all_members_page.dart';
import '../application/chat_keyword_search_controller.dart';
import '../application/search_providers.dart';
import '../domain/search_models.dart';
import 'chat_search_collection_page.dart';
import 'chat_search_date_page.dart';
import 'chat_search_member_page.dart';
import 'chat_search_results_page.dart';
import 'search_chat_navigation.dart';
import 'widgets/search_menu_grid.dart';

class ChatSearchEntryPage extends ConsumerStatefulWidget {
  const ChatSearchEntryPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  ConsumerState<ChatSearchEntryPage> createState() =>
      _ChatSearchEntryPageState();
}

class _ChatSearchEntryPageState extends ConsumerState<ChatSearchEntryPage> {
  final TextEditingController _textController = TextEditingController();

  ChatSearchTarget get _target => ChatSearchTarget(
    channelId: widget.channelId,
    channelType: widget.channelType,
  );

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatKeywordSearchControllerProvider(_target));
    final controller = ref.read(
      chatKeywordSearchControllerProvider(_target).notifier,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                key: const ValueKey<String>('chat-search-inline-shell'),
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey<String>('chat-search-field'),
                      controller: _textController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: controller.updateKeyword,
                      decoration: InputDecoration(
                        hintText: '搜索消息',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    key: const ValueKey<String>('chat-search-cancel'),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
            if (!state.hasKeyword)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '搜索指定内容',
                    key: const ValueKey<String>('chat-search-menu-hint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            Expanded(
              child: state.hasKeyword
                  ? _SearchResultsBody(
                      state: state,
                      onTap: _openSearchResult,
                      onRetryInitial: controller.retry,
                      onLoadMore: controller.loadMore,
                      onRetryLoadMore: () => controller.loadMore(isRetry: true),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SearchMenuGrid(
                        entries: buildDefaultSearchMenuEntries(),
                        onTap: _handleMenuTap,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearchResult(SearchMessageHit hit) async {
    final resolver = ref.read(searchLocateResolverProvider);
    final intent = resolver.fromSearchHit(
      hit,
      highlightKeyword: _textController.text.trim(),
      source: 'chat-keyword-search',
    );
    await openChatFromLocateIntent(
      context: context,
      ref: ref,
      intent: intent,
      fallbackChannelName: widget.channelName,
    );
  }

  void _handleMenuTap(SearchMenuEntry entry) {
    final Widget page = switch (entry.kind) {
      SearchMenuKind.date => ChatSearchDatePage(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: widget.channelName,
      ),
      SearchMenuKind.image => ChatSearchCollectionPage(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: widget.channelName,
        scope: SearchCollectionScope.image,
      ),
      SearchMenuKind.file => ChatSearchCollectionPage(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: widget.channelName,
        scope: SearchCollectionScope.file,
      ),
      SearchMenuKind.link => ChatSearchCollectionPage(
        channelId: widget.channelId,
        channelType: widget.channelType,
        channelName: widget.channelName,
        scope: SearchCollectionScope.link,
      ),
      SearchMenuKind.member =>
        widget.channelType == WKChannelType.group
            // Group member search now uses AllMembersPage as the picker authority.
            ? AllMembersPage(
                channelId: widget.channelId,
                channelType: widget.channelType,
                channelName: widget.channelName,
                searchMessage: true,
              )
            : ChatSearchMemberPage(
                channelId: widget.channelId,
                channelType: widget.channelType,
                channelName: widget.channelName,
              ),
    };

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}

class _SearchResultsBody extends StatelessWidget {
  const _SearchResultsBody({
    required this.state,
    required this.onTap,
    required this.onRetryInitial,
    required this.onLoadMore,
    required this.onRetryLoadMore,
  });

  final ChatKeywordSearchState state;
  final ValueChanged<SearchMessageHit> onTap;
  final VoidCallback onRetryInitial;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('chat-search-keyword-initial-retry'),
              onPressed: onRetryInitial,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (state.items.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }
    return ChatSearchResultsPage(
      items: state.items,
      onTap: onTap,
      isLoadingMore: state.isLoadingMore,
      loadMoreError: state.loadMoreError,
      onLoadMore: state.hasMore ? onLoadMore : null,
      onRetryLoadMore: state.hasMore ? onRetryLoadMore : null,
    );
  }
}
