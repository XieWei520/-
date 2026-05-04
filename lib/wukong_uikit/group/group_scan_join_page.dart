import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../data/models/group.dart';
import '../../modules/chat/chat_page.dart';
import '../../service/api/group_api.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

typedef GroupScanJoinLoadGroupInfo = Future<GroupInfo> Function(String groupNo);
typedef GroupScanJoinAction = Future<void> Function(
  String groupNo,
  String authCode,
);
typedef GroupScanJoinChatPageBuilder = Widget Function(String groupNo);

@visibleForTesting
Widget buildDefaultGroupScanJoinChatPage(String groupNo) {
  return ChatPage(channelId: groupNo, channelType: WKChannelType.group);
}

class GroupScanJoinPage extends StatefulWidget {
  final String groupNo;
  final String authCode;
  final GroupScanJoinLoadGroupInfo? loadGroupInfo;
  final GroupScanJoinAction? joinGroup;
  final GroupScanJoinChatPageBuilder? buildChatPage;

  const GroupScanJoinPage({
    super.key,
    required this.groupNo,
    required this.authCode,
    this.loadGroupInfo,
    this.joinGroup,
    this.buildChatPage,
  });

  @override
  State<GroupScanJoinPage> createState() => _GroupScanJoinPageState();
}

class _GroupScanJoinPageState extends State<GroupScanJoinPage> {
  static const _titleText = '\u626b\u7801\u5165\u7fa4';
  static const _loadErrorFallback = '\u52a0\u8f7d\u7fa4\u4fe1\u606f\u5931\u8d25\u3002';
  static const _inviteOnlyHint = '\u8be5\u7fa4\u4ec5\u652f\u6301\u9080\u8bf7\u5165\u7fa4\u3002';
  static const _inviteOnlyBlocked = '\u8be5\u7fa4\u9700\u8981\u9080\u8bf7\u624d\u80fd\u52a0\u5165\u3002';
  static const _joinRejectedFallback =
      '\u670d\u52a1\u7aef\u62d2\u7edd\u4e86\u626b\u7801\u5165\u7fa4\u8bf7\u6c42\u3002';
  static const _retryText = '\u91cd\u8bd5';
  static const _joiningText = '\u52a0\u5165\u4e2d...';
  static const _joinButtonText = '\u52a0\u5165\u7fa4\u804a';

  GroupInfo? _group;
  bool _isLoading = true;
  bool _isJoining = false;
  String? _loadErrorText;
  String? _joinBlockedText;

  GroupScanJoinLoadGroupInfo get _loadGroupInfo =>
      widget.loadGroupInfo ?? GroupApi.instance.getGroupInfo;
  GroupScanJoinAction get _joinGroup =>
      widget.joinGroup ?? GroupApi.instance.scanJoinGroup;
  GroupScanJoinChatPageBuilder get _buildChatPage =>
      widget.buildChatPage ?? buildDefaultGroupScanJoinChatPage;

  bool get _inviteOnly => (_group?.invite ?? 0) == 1;
  bool get _canJoin => !_isJoining && !_inviteOnly;

  String get _displayName {
    final name = (_group?.name ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    return widget.groupNo;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadErrorText = null;
      _joinBlockedText = null;
    });

    try {
      final group = await _loadGroupInfo(widget.groupNo);
      if (!mounted) {
        return;
      }
      setState(() {
        _group = group;
        _isLoading = false;
        if ((group.invite ?? 0) == 1) {
          _joinBlockedText = _inviteOnlyBlocked;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadErrorText = _normalizeError(error, _loadErrorFallback);
      });
    }
  }

  Future<void> _handleJoin() async {
    if (!_canJoin) {
      return;
    }

    setState(() => _isJoining = true);
    try {
      await _joinGroup(widget.groupNo, widget.authCode);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => _buildChatPage(widget.groupNo)),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joinBlockedText = _normalizeError(error, _joinRejectedFallback);
      });
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: _titleText,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_group == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadErrorText ?? _loadErrorFallback,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: WKColors.color999,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                key: const ValueKey('group_scan_join_retry_button'),
                onPressed: _load,
                child: const Text(_retryText),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: WKAvatar(
              url: _group?.avatar,
              name: _displayName,
              size: 72,
              isGroup: true,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              color: WKColors.colorDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\u7fa4\u53f7: ${widget.groupNo}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: WKColors.color999),
          ),
          const SizedBox(height: 28),
          if (_inviteOnly)
            const Text(
              _inviteOnlyHint,
              key: ValueKey('group_scan_join_invite_only_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: WKColors.color999),
            )
          else if (_joinBlockedText != null)
            Text(
              _joinBlockedText!,
              key: const ValueKey('group_scan_join_error_text'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: WKColors.color999),
            ),
          if (_inviteOnly || _joinBlockedText != null)
            const SizedBox(height: 20),
          ElevatedButton(
            key: const ValueKey('group_scan_join_primary_button'),
            onPressed: _canJoin ? _handleJoin : null,
            child: Text(_isJoining ? _joiningText : _joinButtonText),
          ),
        ],
      ),
    );
  }

  String _normalizeError(Object error, String fallback) {
    final text = error.toString().trim();
    if (text.isEmpty) {
      return fallback;
    }
    if (text.startsWith('Exception: ')) {
      final normalized = text.replaceFirst('Exception: ', '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return text;
  }
}
