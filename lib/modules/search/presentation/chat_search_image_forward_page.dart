import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../../data/providers/conversation_provider.dart';
import '../../chat/message_forwarding.dart';
import '../domain/search_models.dart';
import '../../../wukong_base/views/user_avatar.dart';

typedef SearchForwardTargetResolver =
    Future<List<ForwardTarget>> Function(List<WKUIConversationMsg> conversations);
typedef SearchForwardSubmitCallback =
    Future<void> Function(List<ForwardTarget> targets, SearchMediaItem item);

class ChatSearchImageForwardPage extends ConsumerStatefulWidget {
  const ChatSearchImageForwardPage({
    super.key,
    required this.item,
    this.resolveTargets,
    this.onSubmitTargets,
  });

  final SearchMediaItem item;
  final SearchForwardTargetResolver? resolveTargets;
  final SearchForwardSubmitCallback? onSubmitTargets;

  @override
  ConsumerState<ChatSearchImageForwardPage> createState() =>
      _ChatSearchImageForwardPageState();
}

class _ChatSearchImageForwardPageState
    extends ConsumerState<ChatSearchImageForwardPage> {
  String _query = '';
  final Set<String> _selectedTargetKeys = <String>{};
  List<WKUIConversationMsg>? _cachedConversations;
  Future<List<ForwardTarget>>? _targetsFuture;

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationProvider);
    final targetsFuture = _resolveTargets(conversations);

    return Scaffold(
      appBar: AppBar(title: const Text('Forward')),
      body: FutureBuilder<List<ForwardTarget>>(
        future: targetsFuture,
        builder: (context, snapshot) {
          final targets = snapshot.data ?? const <ForwardTarget>[];
          final filteredTargets = filterForwardTargets(targets, _query);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  key: const ValueKey<String>('search-forward-search-field'),
                  onChanged: (value) {
                    setState(() {
                      _query = value;
                    });
                  },
                  decoration: const InputDecoration(
                    hintText: 'Search chats',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting &&
                        targets.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : targets.isEmpty
                    ? const Center(child: Text('No chats available'))
                    : filteredTargets.isEmpty
                    ? const Center(child: Text('No matches'))
                    : ListView.builder(
                        itemCount: filteredTargets.length,
                        itemBuilder: (context, index) {
                          final target = filteredTargets[index];
                          return ListTile(
                            key: ValueKey<String>(
                              'search-forward-target-${target.key}',
                            ),
                            leading: WKUserAvatar(
                              key: ValueKey<String>(
                                'search-forward-avatar-${target.key}',
                              ),
                              avatarUrl: target.avatarUrl,
                              name: target.displayName,
                              size: 40,
                            ),
                            title: Text(target.displayName),
                            subtitle: target.subtitle.isEmpty
                                ? null
                                : Text(target.subtitle),
                            trailing: _selectedTargetKeys.contains(target.key)
                                ? Icon(
                                    Icons.check_circle,
                                    key: ValueKey<String>(
                                      'search-forward-selected-${target.key}',
                                    ),
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            onTap: () => _toggleTarget(target),
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const ValueKey<String>('search-forward-confirm-button'),
                      onPressed: _selectedTargetKeys.isEmpty
                          ? null
                          : () => _submitSelectedTargets(targets),
                      child: Text(
                        _selectedTargetKeys.isEmpty
                            ? 'Forward'
                            : 'Forward (${_selectedTargetKeys.length})',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleTarget(ForwardTarget target) {
    setState(() {
      if (_selectedTargetKeys.contains(target.key)) {
        _selectedTargetKeys.remove(target.key);
      } else {
        _selectedTargetKeys.add(target.key);
      }
    });
  }

  Future<void> _submitSelectedTargets(List<ForwardTarget> targets) async {
    final selectedTargets = targets
        .where((target) => _selectedTargetKeys.contains(target.key))
        .toList(growable: false);
    if (selectedTargets.isEmpty) {
      return;
    }

    if (widget.onSubmitTargets != null) {
      await widget.onSubmitTargets!(selectedTargets, widget.item);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    await _forward(context, selectedTargets);
  }

  Future<void> _forward(
    BuildContext context,
    List<ForwardTarget> targets,
  ) async {
    final content = await _buildMessageContent();
    if (content == null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Forward unavailable')));
      return;
    }

    for (var index = 0; index < targets.length; index++) {
      final target = targets[index];
      final contentToSend = index == 0
          ? content
          : (cloneMessageContentForForward(content) ?? content);
      final channel = WKChannel(target.channelId, target.channelType)
        ..channelName = target.displayName;
      WKIM.shared.messageManager.sendMessage(contentToSend, channel);
    }

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          targets.length == 1 ? 'Forwarded' : 'Forwarded to ${targets.length} chats',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<WKImageContent?> _buildMessageContent() async {
    final clientMsgNo = widget.item.hit.clientMsgNo?.trim() ?? '';
    if (clientMsgNo.isNotEmpty) {
      final originalMessage = await WKIM.shared.messageManager.getWithClientMsgNo(
        clientMsgNo,
      );
      final clonedContent = cloneMessageContentForForward(
        originalMessage?.messageContent,
      );
      if (clonedContent is WKImageContent) {
        return clonedContent;
      }
    }

    final content = WKImageContent(0, 0);
    final mediaUrl = widget.item.mediaUrl?.trim() ?? '';
    if (mediaUrl.isEmpty) {
      return null;
    }
    if (mediaUrl.startsWith('/') || mediaUrl.startsWith('file://')) {
      content.localPath = mediaUrl.startsWith('file://')
          ? mediaUrl.substring(7)
          : mediaUrl;
    } else {
      content.url = mediaUrl;
    }
    return content;
  }

  Future<List<ForwardTarget>> _resolveTargets(
    List<WKUIConversationMsg> conversations,
  ) {
    if (_targetsFuture != null && identical(_cachedConversations, conversations)) {
      return _targetsFuture!;
    }
    _cachedConversations = conversations;
    _targetsFuture =
        widget.resolveTargets?.call(conversations) ??
        buildForwardTargetsFromConversations(
          conversations,
          excludedChannelId: widget.item.hit.channelId,
          excludedChannelType: widget.item.hit.channelType,
        );
    return _targetsFuture!;
  }
}
