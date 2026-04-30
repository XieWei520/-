import 'package:flutter/material.dart';

import '../../widgets/wk_avatar.dart';

class SelectableGroupMember {
  final String uid;
  final String title;
  final String subtitle;
  final String? avatar;
  final String? badge;

  const SelectableGroupMember({
    required this.uid,
    required this.title,
    required this.subtitle,
    this.avatar,
    this.badge,
  });
}

Future<List<String>?> openGroupMemberPicker(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required String emptyText,
  required List<SelectableGroupMember> candidates,
}) async {
  if (candidates.isEmpty) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(emptyText)));
    return null;
  }

  return Navigator.of(context).push<List<String>>(
    MaterialPageRoute(
      builder: (_) => GroupMemberPickerPage(
        title: title,
        submitLabel: submitLabel,
        emptyText: emptyText,
        candidates: candidates,
      ),
    ),
  );
}

class GroupMemberPickerPage extends StatefulWidget {
  final String title;
  final String submitLabel;
  final String emptyText;
  final List<SelectableGroupMember> candidates;

  const GroupMemberPickerPage({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.emptyText,
    required this.candidates,
  });

  @override
  State<GroupMemberPickerPage> createState() => _GroupMemberPickerPageState();
}

class _GroupMemberPickerPageState extends State<GroupMemberPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';

  List<SelectableGroupMember> get _filteredCandidates {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return widget.candidates;
    }

    return widget.candidates
        .where((candidate) {
          final values = <String>[
            candidate.uid,
            candidate.title,
            candidate.subtitle,
            candidate.badge ?? '',
          ];
          return values.any(
            (value) => value.toLowerCase().contains(normalizedQuery),
          );
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCandidates = _filteredCandidates;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            key: const ValueKey<String>('group-member-picker-submit'),
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.of(context).pop(_selected.toList()),
            child: Text('${widget.submitLabel}(${_selected.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索成员',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: filteredCandidates.isEmpty
                ? Center(
                    child: Text(
                      widget.emptyText,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredCandidates.length,
                    itemBuilder: (context, index) {
                      final candidate = filteredCandidates[index];
                      final isSelected = _selected.contains(candidate.uid);
                      final title = candidate.title.isEmpty
                          ? candidate.uid
                          : candidate.title;

                      return CheckboxListTile(
                        key: ValueKey<String>(
                          'selectable-member-${candidate.uid}',
                        ),
                        value: isSelected,
                        onChanged: (_) {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(candidate.uid);
                            } else {
                              _selected.add(candidate.uid);
                            }
                          });
                        },
                        secondary: WKAvatar(
                          url: candidate.avatar,
                          name: title,
                          size: 40,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if ((candidate.badge ?? '').isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withAlpha(26),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  candidate.badge!,
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          candidate.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
