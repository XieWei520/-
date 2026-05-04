import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../data/models/call.dart';
import 'group_call_service.dart';
import 'video_call_page.dart';

class GroupCallMemberPickerPage extends StatefulWidget {
  const GroupCallMemberPickerPage({
    super.key,
    required this.channelId,
    required this.channelType,
    this.channelName,
    this.videoCallAutoStart = true,
    this.service,
  });

  final String channelId;
  final int channelType;
  final String? channelName;
  final bool videoCallAutoStart;
  final GroupCallService? service;

  @override
  State<GroupCallMemberPickerPage> createState() =>
      _GroupCallMemberPickerPageState();
}

class _GroupCallMemberPickerPageState extends State<GroupCallMemberPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  final LinkedHashMap<String, GroupCallMemberCandidate> _selectedMembers =
      LinkedHashMap<String, GroupCallMemberCandidate>();

  List<GroupCallMemberCandidate> _members = const <GroupCallMemberCandidate>[];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSubmitting = false;
  bool _hasMore = false;
  int _page = 1;
  int _maxSelectableCount = 9;

  GroupCallService get _service => widget.service ?? GroupCallService();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    unawaited(_loadPage(reset: true));
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    unawaited(_loadPage(reset: true));
  }

  Future<void> _loadPage({required bool reset}) async {
    final requestPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final page = await _service.loadMembers(
        channelId: widget.channelId,
        channelType: widget.channelType,
        keyword: _searchController.text.trim(),
        page: requestPage,
        pageSize: 100,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _page = page.page;
        _hasMore = page.hasMore;
        _maxSelectableCount = page.maxSelectableCount;
        _members = reset
            ? page.items
            : <GroupCallMemberCandidate>[
                ..._members,
                ...page.items.where(
                  (item) =>
                      !_members.any((existing) => existing.uid == item.uid),
                ),
              ];
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      _showMessage(error.toString().replaceFirst('Exception: ', '').trim());
    }
  }

  Future<void> _confirm() async {
    if (_isSubmitting || _selectedMembers.isEmpty) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await _service.createGroupCall(
        channelId: widget.channelId,
        channelType: widget.channelType,
        selectedMembers: _selectedMembers.values.toList(growable: false),
      );
      if (!mounted) {
        return;
      }
      final feedback = result.feedbackMessage?.trim() ?? '';
      if (feedback.isNotEmpty) {
        _showMessage(feedback);
      }
      if (!result.shouldClose) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VideoCallPage(
            channelId: widget.channelId,
            channelType: widget.channelType,
            channelName: widget.channelName ?? '多人通话',
            callType: CallType.video,
            autoStart: widget.videoCallAutoStart,
            groupParticipants: _selectedMembers.values
                .map((item) {
                  return CallParticipant(
                    uid: item.uid,
                    name: item.displayName,
                    role: 1,
                    inviteStatus: 0,
                  );
                })
                .toList(growable: false),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _toggleMember(GroupCallMemberCandidate candidate) {
    final isSelected = _selectedMembers.containsKey(candidate.uid);
    if (!isSelected && _selectedMembers.length >= _maxSelectableCount) {
      _showMessage('最多选择 $_maxSelectableCount 人');
      return;
    }
    setState(() {
      if (isSelected) {
        _selectedMembers.remove(candidate.uid);
      } else {
        _selectedMembers[candidate.uid] = candidate;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.channelName ?? '').trim().isEmpty ? '选择成员' : '多人通话';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            key: const ValueKey('group-call-confirm-button'),
            onPressed: _selectedMembers.isEmpty || _isSubmitting
                ? null
                : _confirm,
            child: Text(
              _selectedMembers.isEmpty
                  ? '确定'
                  : '确定(${_selectedMembers.length})',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('group-call-search-field'),
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索成员',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_selectedMembers.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _selectedMembers.values
                    .map(
                      (member) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: InputChip(
                          label: Text(member.displayName),
                          onDeleted: () => _toggleMember(member),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _members.isEmpty
                ? const Center(child: Text('暂无可选成员'))
                : ListView(
                    children: [
                      for (final member in _members)
                        CheckboxListTile(
                          key: ValueKey('group-call-member-${member.uid}'),
                          value: _selectedMembers.containsKey(member.uid),
                          title: Text(member.displayName),
                          subtitle: member.remark?.trim().isNotEmpty == true
                              ? Text(member.remark!)
                              : null,
                          onChanged: (_) => _toggleMember(member),
                        ),
                      if (_hasMore)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: OutlinedButton(
                            key: const ValueKey('group-call-load-more-button'),
                            onPressed: _isLoadingMore
                                ? null
                                : () => unawaited(_loadPage(reset: false)),
                            child: Text(_isLoadingMore ? '加载中...' : '加载更多'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
