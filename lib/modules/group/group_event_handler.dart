import 'dart:convert';

import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import 'group_controller.dart';

/// Handles group system messages (1002-1009) and updates local state.
class GroupEventHandler {
  GroupEventHandler._();
  static final GroupEventHandler instance = GroupEventHandler._();

  bool _initialized = false;

  /// Register this handler to listen for incoming messages.
  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WKIM.shared.messageManager.addOnNewMsgListener('group_event_handler',
        (List<WKMsg> messages) {
      for (final msg in messages) {
        _handleMessage(msg);
      }
    });
  }

  void dispose() {
    if (!_initialized) return;
    _initialized = false;
    WKIM.shared.messageManager.removeNewMsgListener('group_event_handler');
  }

  void _handleMessage(WKMsg msg) {
    final type = msg.contentType;
    if (type < GroupSystemMsgType.memberJoin ||
        type > GroupSystemMsgType.memberApprove) {
      return;
    }

    // Parse the system message content
    Map<String, dynamic>? data;
    try {
      if (msg.content.isNotEmpty) {
        data = jsonDecode(msg.content) as Map<String, dynamic>?;
      }
    } catch (_) {}

    switch (type) {
      case GroupSystemMsgType.memberJoin:
        _onMemberJoin(msg, data);
        break;
      case GroupSystemMsgType.memberQuit:
        _onMemberQuit(msg, data);
        break;
      case GroupSystemMsgType.nameUpdated:
        _onNameUpdated(msg, data);
        break;
      case GroupSystemMsgType.systemInfo:
        // Generic group system info — no local state update needed
        break;
      case GroupSystemMsgType.memberRemoved:
        _onMemberRemoved(msg, data);
        break;
      case GroupSystemMsgType.noticeUpdated:
        _onNoticeUpdated(msg, data);
        break;
      case GroupSystemMsgType.avatarUpdated:
        _onAvatarUpdated(msg, data);
        break;
      case GroupSystemMsgType.memberApprove:
        // Forward to approval notifier for UI handling
        _onMemberApprove(msg, data);
        break;
    }
  }

  void _onMemberJoin(WKMsg msg, Map<String, dynamic>? data) {
    // Trigger channel refresh to update member list
    _refreshChannel(msg.channelID, msg.channelType);
  }

  void _onMemberQuit(WKMsg msg, Map<String, dynamic>? data) {
    _refreshChannel(msg.channelID, msg.channelType);
  }

  void _onMemberRemoved(WKMsg msg, Map<String, dynamic>? data) {
    // Check if current user was removed
    final removedUids = data?['uids'] as List<dynamic>? ?? [];
    final currentUid = WKIM.shared.options.uid;
    if (removedUids.contains(currentUid)) {
      // Current user was removed from the group
      WKIM.shared.conversationManager.deleteMsg(
        msg.channelID,
        msg.channelType,
      );
    }
    _refreshChannel(msg.channelID, msg.channelType);
  }

  void _onNameUpdated(WKMsg msg, Map<String, dynamic>? data) {
    final newName = data?['name'] as String?;
    if (newName != null && newName.isNotEmpty) {
      WKIM.shared.channelManager.fetchChannelInfo(
        msg.channelID,
        msg.channelType,
      );
    }
  }

  void _onNoticeUpdated(WKMsg msg, Map<String, dynamic>? data) {
    _refreshChannel(msg.channelID, msg.channelType);
  }

  void _onAvatarUpdated(WKMsg msg, Map<String, dynamic>? data) {
    _refreshChannel(msg.channelID, msg.channelType);
  }

  void _onMemberApprove(WKMsg msg, Map<String, dynamic>? data) {
    // Refresh channel so the group info is up-to-date
    _refreshChannel(msg.channelID, msg.channelType);
  }

  void _refreshChannel(String channelID, int channelType) {
    WKIM.shared.channelManager.fetchChannelInfo(channelID, channelType);
  }
}
