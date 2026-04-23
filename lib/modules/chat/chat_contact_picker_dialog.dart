import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/friend.dart';
import '../../data/providers/user_provider.dart';
import '../../widgets/wk_avatar.dart';

class ContactPickerDialog extends ConsumerStatefulWidget {
  const ContactPickerDialog({super.key});

  @override
  ConsumerState<ContactPickerDialog> createState() =>
      _ContactPickerDialogState();
}

class _ContactPickerDialogState extends ConsumerState<ContactPickerDialog> {
  String _keyword = '';

  @override
  Widget build(BuildContext context) {
    final friendsState = ref.watch(friendListProvider);

    return AlertDialog(
      title: const Text('选择名片'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: Column(
          children: [
            TextField(
              key: const ValueKey<String>('chat-card-search-field'),
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
                    return const Center(child: Text('暂无可发送的联系人'));
                  }
                  return ListView.separated(
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final friend = candidates[index];
                      final displayName = _displayName(friend);
                      return ListTile(
                        key: ValueKey<String>('chat-card-item-${friend.uid}'),
                        contentPadding: EdgeInsets.zero,
                        leading: WKAvatar(
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
                        onTap: () {
                          Navigator.of(context).pop(
                            <String, String>{
                              'uid': friend.uid,
                              'name': displayName,
                            },
                          );
                        },
                      );
                    },
                  );
                },
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('联系人加载失败'),
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
      ],
    );
  }

  List<Friend> _filterFriends(List<Friend> friends, String keyword) {
    final normalized = keyword.trim().toLowerCase();
    return friends.where((friend) {
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
    }).toList(growable: false);
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
