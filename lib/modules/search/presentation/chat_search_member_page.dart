import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukong_im_app/wukong_base/views/user_avatar.dart';

import '../application/chat_keyword_search_controller.dart';
import '../application/chat_member_search_controller.dart';
import '../application/search_providers.dart';
import '../domain/search_models.dart';
import 'search_chat_navigation.dart';
import 'widgets/search_member_result_tile.dart';

class ChatSearchMemberPage extends ConsumerWidget {
  const ChatSearchMemberPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final String? channelName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ChatSearchTarget(
      channelId: channelId,
      channelType: channelType,
    );
    final state = ref.watch(chatMemberSearchControllerProvider(target));
    final controller = ref.read(
      chatMemberSearchControllerProvider(target).notifier,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('搜索成员')),
      body: SafeArea(
        child: state.isLoadingMembers && state.members.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : state.error != null && state.members.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.error!),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: controller.loadMembers,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              )
            : state.showingResults
            ? _MemberResultsBody(
                member: state.selectedMember!,
                state: state,
                onRetryInitial: controller.retryResults,
                onRetryLoadMore: () =>
                    controller.loadMoreResults(isRetry: true),
                onLoadMore: controller.loadMoreResults,
                onTapResult: (hit) => _openResult(context, ref, hit),
              )
            : ListView.builder(
                itemCount: state.members.length,
                itemBuilder: (context, index) {
                  final member = state.members[index];
                  return ListTile(
                    key: ValueKey<String>('search-member-${member.uid}'),
                    leading: WKUserAvatar(
                      avatarUrl: member.avatarUrl,
                      name: member.displayName,
                      size: 40,
                    ),
                    title: Text(member.displayName),
                    onTap: () =>
                        _openMemberResults(context, ref, controller, member),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openMemberResults(
    BuildContext context,
    WidgetRef ref,
    ChatMemberSearchController controller,
    SearchMemberHit member,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatSearchMemberResultsPage(
          channelId: channelId,
          channelType: channelType,
          channelName: channelName,
          member: member,
        ),
      ),
    );
    controller.backToMembers();
  }

  Future<void> _openResult(
    BuildContext context,
    WidgetRef ref,
    SearchMessageHit hit,
  ) async {
    final resolver = ref.read(searchLocateResolverProvider);
    final intent = resolver.fromSearchHit(
      hit,
      highlightKeyword: '',
      source: 'chat-member-search',
    );
    await openChatFromLocateIntent(
      context: context,
      ref: ref,
      intent: intent,
      fallbackChannelName: channelName,
    );
  }
}

class ChatSearchMemberResultsPage extends ConsumerStatefulWidget {
  const ChatSearchMemberResultsPage({
    super.key,
    required this.channelId,
    required this.channelType,
    required this.member,
    this.channelName,
  });

  final String channelId;
  final int channelType;
  final SearchMemberHit member;
  final String? channelName;

  @override
  ConsumerState<ChatSearchMemberResultsPage> createState() =>
      _ChatSearchMemberResultsPageState();
}

class _ChatSearchMemberResultsPageState
    extends ConsumerState<ChatSearchMemberResultsPage> {
  bool _didQueueInitialOpen = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _didQueueInitialOpen = true;
      });
      unawaited(
        ref
            .read(
              chatMemberSearchControllerProvider(
                ChatSearchTarget(
                  channelId: widget.channelId,
                  channelType: widget.channelType,
                ),
              ).notifier,
            )
            .openMember(widget.member),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = ChatSearchTarget(
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
    final state = ref.watch(chatMemberSearchControllerProvider(target));
    final controller = ref.read(
      chatMemberSearchControllerProvider(target).notifier,
    );

    return Scaffold(
      key: ValueKey<String>('search-member-results-page-${widget.member.uid}'),
      appBar: AppBar(title: Text(widget.member.displayName)),
      body: SafeArea(
        child: !_didQueueInitialOpen
            ? const Center(child: CircularProgressIndicator())
            : _MemberResultsBody(
                member: widget.member,
                state: state,
                onRetryInitial: controller.retryResults,
                onRetryLoadMore: () =>
                    controller.loadMoreResults(isRetry: true),
                onLoadMore: controller.loadMoreResults,
                onTapResult: (hit) => _openResult(context, ref, hit),
              ),
      ),
    );
  }

  Future<void> _openResult(
    BuildContext context,
    WidgetRef ref,
    SearchMessageHit hit,
  ) async {
    final resolver = ref.read(searchLocateResolverProvider);
    final intent = resolver.fromSearchHit(
      hit,
      highlightKeyword: '',
      source: 'chat-member-search',
    );
    await openChatFromLocateIntent(
      context: context,
      ref: ref,
      intent: intent,
      fallbackChannelName: widget.channelName,
    );
  }
}

class _MemberResultsBody extends StatelessWidget {
  const _MemberResultsBody({
    required this.member,
    required this.state,
    required this.onRetryInitial,
    required this.onRetryLoadMore,
    required this.onLoadMore,
    required this.onTapResult,
  });

  final SearchMemberHit member;
  final ChatMemberSearchState state;
  final VoidCallback onRetryInitial;
  final VoidCallback onRetryLoadMore;
  final VoidCallback onLoadMore;
  final ValueChanged<SearchMessageHit> onTapResult;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingResults && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state.error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetryInitial, child: const Text('重试')),
          ],
        ),
      );
    }
    if (state.results.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 240) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.builder(
        key: const ValueKey<String>('chat-member-search-results-list'),
        itemCount:
            state.results.length +
            ((state.isLoadingMore || state.loadMoreError != null) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.results.length) {
            if (state.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('加载更多失败'),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const ValueKey<String>(
                        'chat-member-search-load-more-retry',
                      ),
                      onPressed: onRetryLoadMore,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }
          final hit = state.results[index];
          return SearchMemberResultTile(
            member: member,
            hit: hit,
            onTap: () => onTapResult(hit),
          );
        },
      ),
    );
  }
}
