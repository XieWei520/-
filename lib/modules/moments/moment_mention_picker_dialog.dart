import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/friend.dart';
import '../../data/providers/user_provider.dart';
import '../../widgets/wk_avatar.dart';
import 'moments_service.dart';

Future<List<MomentMention>?> showMomentMentionPickerDialog(
  BuildContext context,
) {
  return showDialog<List<MomentMention>>(
    context: context,
    builder: (_) => const _MomentMentionPickerDialog(),
  );
}

class _MomentMentionPickerDialog extends ConsumerStatefulWidget {
  const _MomentMentionPickerDialog();

  @override
  ConsumerState<_MomentMentionPickerDialog> createState() =>
      _MomentMentionPickerDialogState();
}

class _MomentMentionPickerDialogState
    extends ConsumerState<_MomentMentionPickerDialog> {
  String _keyword = '';
  final Set<String> _selectedUids = <String>{};

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendListProvider);

    return AlertDialog(
      title: const Text('选择要@的好友'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const ValueKey<String>('moment-mention-search-field'),
              decoration: const InputDecoration(
                hintText: '搜索好友',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _keyword = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: friendsState.when(
                data: (friends) {
                  final candidates = _filterFriends(friends, _keyword);
                  if (candidates.isEmpty) {
                    return const Center(child: Text('暂无可选好友'));
                  }
                  return ListView.separated(
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final friend = candidates[index];
                      final displayName = _displayName(friend);
                      final selected = _selectedUids.contains(friend.uid);
                      return CheckboxListTile(
                        key: ValueKey<String>(
                          'moment-mention-item-${friend.uid}',
                        ),
                        value: selected,
                        contentPadding: EdgeInsets.zero,
                        secondary: WKAvatar(
                          url: friend.avatar,
                          name: displayName,
                          size: 40,
                        ),
                        title: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: friend.uid == displayName
                            ? null
                            : Text(
                                friend.uid,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                        onChanged: (_) {
                          setState(() {
                            if (selected) {
                              _selectedUids.remove(friend.uid);
                            } else {
                              _selectedUids.add(friend.uid);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('好友加载失败'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          ref.read(friendListProvider.notifier).refresh();
                        },
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final friends =
                ref.read(friendListProvider).valueOrNull ?? const <Friend>[];
            final mentions = friends
                .where((friend) => _selectedUids.contains(friend.uid))
                .map(
                  (friend) => MomentMention(
                    uid: friend.uid,
                    name: _displayName(friend),
                  ),
                )
                .toList(growable: false);
            Navigator.of(context).pop(mentions);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  List<Friend> _filterFriends(List<Friend> friends, String keyword) {
    final normalized = keyword.trim().toLowerCase();
    return friends
        .where((friend) {
          if (friend.uid.trim().isEmpty || friend.isSystemAccount) {
            return false;
          }
          if (normalized.isEmpty) {
            return true;
          }
          final displayName = _displayName(friend).toLowerCase();
          final remark = friend.remark?.trim().toLowerCase() ?? '';
          final uid = friend.uid.trim().toLowerCase();
          return displayName.contains(normalized) ||
              remark.contains(normalized) ||
              uid.contains(normalized);
        })
        .toList(growable: false);
  }

  String _displayName(Friend friend) {
    final remark = friend.remark?.trim() ?? '';
    if (remark.isNotEmpty) {
      return remark;
    }
    final name = friend.name?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return friend.uid;
  }
}
