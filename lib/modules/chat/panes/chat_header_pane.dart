import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_session.dart';
import '../chat_scene_providers.dart';

@immutable
class ChatHeaderPaneState {
  const ChatHeaderPaneState({
    required this.title,
    this.subtitle,
    this.secondarySubtitle,
    this.avatarUrl,
    this.vipLevel = 0,
    this.tags = const <String>[],
    this.isGroup = false,
    this.showSearchAction = true,
  });

  final String title;
  final String? subtitle;
  final String? secondarySubtitle;
  final String? avatarUrl;
  final int vipLevel;
  final List<String> tags;
  final bool isGroup;
  final bool showSearchAction;
}

class ChatHeaderPane extends ConsumerWidget implements PreferredSizeWidget {
  const ChatHeaderPane({
    super.key,
    required this.session,
    required this.state,
    this.onBack,
    this.onOpenSearch,
    this.onSearchKeywordChanged,
    this.onSearchSubmitted,
    this.onCloseSearch,
    this.onOpenDetails,
    this.height = kToolbarHeight,
  });

  final ChatSession session;
  final ChatHeaderPaneState state;
  final VoidCallback? onBack;
  final VoidCallback? onOpenSearch;
  final ValueChanged<String>? onSearchKeywordChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onCloseSearch;
  final VoidCallback? onOpenDetails;
  final double height;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchMode = ref.watch(chatSearchModeControllerProvider(session));
    return AppBar(
      key: const ValueKey<String>('chat-header-pane'),
      toolbarHeight: height,
      leading: IconButton(
        key: const ValueKey<String>('chat-header-back'),
        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      ),
      title: searchMode.isActive
          ? _HeaderSearchField(
              keyword: searchMode.keyword,
              onChanged: onSearchKeywordChanged,
              onSubmitted: onSearchSubmitted,
              onClose: onCloseSearch,
            )
          : _HeaderIdentity(state: state),
      actions: searchMode.isActive
          ? const <Widget>[]
          : <Widget>[
              if (state.showSearchAction)
                IconButton(
                  key: const ValueKey<String>('chat-header-search'),
                  onPressed: onOpenSearch,
                  icon: const Icon(Icons.search),
                  tooltip: '搜索',
                ),
              IconButton(
                key: const ValueKey<String>('chat-header-details'),
                onPressed: onOpenDetails,
                icon: const Icon(Icons.more_horiz),
                tooltip: '详情',
              ),
            ],
    );
  }
}

class _HeaderIdentity extends StatelessWidget {
  const _HeaderIdentity({required this.state});

  final ChatHeaderPaneState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarFallback = state.title.trim().isEmpty
        ? ''
        : state.title.characters.first;
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundImage: state.avatarUrl == null || state.avatarUrl!.isEmpty
              ? null
              : NetworkImage(state.avatarUrl!),
          child: state.avatarUrl == null || state.avatarUrl!.isEmpty
              ? Text(avatarFallback)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      state.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (state.vipLevel > 0) ...<Widget>[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 16),
                  ],
                  for (final tag in state.tags) ...<Widget>[
                    const SizedBox(width: 4),
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(tag),
                    ),
                  ],
                ],
              ),
              if (state.subtitle != null || state.secondarySubtitle != null)
                Text(
                  <String>[
                    if (state.subtitle != null) state.subtitle!,
                    if (state.secondarySubtitle != null)
                      state.secondarySubtitle!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderSearchField extends StatelessWidget {
  const _HeaderSearchField({
    required this.keyword,
    this.onChanged,
    this.onSubmitted,
    this.onClose,
  });

  final String keyword;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: const ValueKey<String>('chat-header-search-field'),
      initialValue: keyword,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: '搜索聊天记录',
        border: InputBorder.none,
        suffixIcon: IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          tooltip: '关闭搜索',
        ),
      ),
    );
  }
}
