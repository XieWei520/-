import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/type/const.dart';

@immutable
class CallingParticipantInfo {
  const CallingParticipantInfo({
    required this.uid,
    required this.name,
  });

  final String uid;
  final String name;

  @override
  bool operator ==(Object other) {
    return other is CallingParticipantInfo &&
        other.uid == uid &&
        other.name == name;
  }

  @override
  int get hashCode => Object.hash(uid, name);
}

@immutable
class ConversationActivityState {
  final bool isTyping;
  final String? typingLabel;
  final bool isCalling;
  final String? callRoomName;
  final List<CallingParticipantInfo> callingParticipants;

  const ConversationActivityState({
    this.isTyping = false,
    this.typingLabel,
    this.isCalling = false,
    this.callRoomName,
    this.callingParticipants = const <CallingParticipantInfo>[],
  });

  static const empty = ConversationActivityState();

  ConversationActivityState copyWith({
    bool? isTyping,
    String? typingLabel,
    bool clearTypingLabel = false,
    bool? isCalling,
    String? callRoomName,
    bool clearCallRoomName = false,
    List<CallingParticipantInfo>? callingParticipants,
    bool clearCallingParticipants = false,
  }) {
    return ConversationActivityState(
      isTyping: isTyping ?? this.isTyping,
      typingLabel: clearTypingLabel ? null : (typingLabel ?? this.typingLabel),
      isCalling: isCalling ?? this.isCalling,
      callRoomName: clearCallRoomName ? null : (callRoomName ?? this.callRoomName),
      callingParticipants: clearCallingParticipants
          ? const <CallingParticipantInfo>[]
          : (callingParticipants ?? this.callingParticipants),
    );
  }
}

class ConversationActivityRegistry {
  ConversationActivityRegistry._();

  static final ConversationActivityRegistry instance =
      ConversationActivityRegistry._();

  final Map<String, ConversationActivityState> _states =
      <String, ConversationActivityState>{};
  final Map<String, Timer> _typingTimers = <String, Timer>{};
  final Map<String, Set<VoidCallback>> _listeners = <String, Set<VoidCallback>>{};
  final Set<ValueChanged<String>> _globalListeners = <ValueChanged<String>>{};

  static String conversationKey(String channelId, int channelType) {
    return '${channelType}_${channelId.trim()}';
  }

  ConversationActivityState getState(String channelId, int channelType) {
    return _states[conversationKey(channelId, channelType)] ??
        ConversationActivityState.empty;
  }

  Set<String> getActiveCallingConversationKeys() {
    final keys = <String>{};
    _states.forEach((key, value) {
      if (value.isCalling) {
        keys.add(key);
      }
    });
    return keys;
  }

  void addConversationListener(
    String channelId,
    int channelType,
    VoidCallback listener,
  ) {
    final key = conversationKey(channelId, channelType);
    _listeners.putIfAbsent(key, () => <VoidCallback>{}).add(listener);
  }

  void removeConversationListener(
    String channelId,
    int channelType,
    VoidCallback listener,
  ) {
    final key = conversationKey(channelId, channelType);
    final listeners = _listeners[key];
    if (listeners == null) {
      return;
    }
    listeners.remove(listener);
    if (listeners.isEmpty) {
      _listeners.remove(key);
    }
  }

  void addGlobalListener(ValueChanged<String> listener) {
    _globalListeners.add(listener);
  }

  void removeGlobalListener(ValueChanged<String> listener) {
    _globalListeners.remove(listener);
  }

  Future<void> handleCommand(
    WKCMD cmd, {
    required String currentUid,
    Future<WKChannel?> Function(String channelId, int channelType)?
        channelLookup,
    Duration typingDuration = const Duration(seconds: 8),
  }) async {
    final rawParam = cmd.param;
    if (rawParam is! Map) {
      return;
    }
    final param = Map<String, dynamic>.from(rawParam);
    switch (cmd.cmd.trim()) {
      case 'wk_typing':
        await _handleTyping(
          param,
          currentUid: currentUid,
          channelLookup: channelLookup,
          typingDuration: typingDuration,
        );
        break;
      case 'sync_channel_state':
        _handleChannelState(param, currentUid: currentUid);
        break;
    }
  }

  void clearTyping(String channelId, int channelType) {
    final key = conversationKey(channelId, channelType);
    _typingTimers.remove(key)?.cancel();
    final current = _states[key] ?? ConversationActivityState.empty;
    _setState(
      channelId,
      channelType,
      current.copyWith(isTyping: false, clearTypingLabel: true),
    );
  }

  void setCallingState(
    String channelId,
    int channelType,
    bool isCalling, {
    String? callRoomName,
    List<CallingParticipantInfo>? callingParticipants,
    bool clearCallInfo = false,
  }) {
    final current = getState(channelId, channelType);
    _setState(
      channelId,
      channelType,
      current.copyWith(
        isCalling: isCalling,
        callRoomName: callRoomName,
        clearCallRoomName: clearCallInfo || !isCalling,
        callingParticipants: callingParticipants,
        clearCallingParticipants: clearCallInfo || !isCalling,
      ),
    );
  }

  void clearAll() {
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }
    _typingTimers.clear();
    final keys = _states.keys.toList();
    _states.clear();
    for (final key in keys) {
      for (final listener in _listeners[key] ?? const <VoidCallback>{}) {
        listener();
      }
    }
  }

  Future<void> _handleTyping(
    Map<String, dynamic> param, {
    required String currentUid,
    Future<WKChannel?> Function(String channelId, int channelType)?
        channelLookup,
    required Duration typingDuration,
  }) async {
    final normalizedCurrentUid = currentUid.trim();
    final fromUid = _readString(param['from_uid']);
    if (fromUid.isEmpty || fromUid == normalizedCurrentUid) {
      return;
    }

    final channelType = _readInt(param['channel_type']);
    var channelId = _readString(param['channel_id']);
    if (channelId.isEmpty) {
      return;
    }
    if (channelType == WKChannelType.personal && channelId == normalizedCurrentUid) {
      channelId = fromUid;
    }

    var typingUserName = _readString(param['from_name']);
    if (typingUserName.isEmpty && channelLookup != null) {
      final channel = await channelLookup(fromUid, WKChannelType.personal);
      final remark = channel?.channelRemark.trim() ?? '';
      final name = channel?.channelName.trim() ?? '';
      typingUserName = remark.isNotEmpty ? remark : name;
    }
    if (typingUserName.isEmpty) {
      typingUserName = fromUid;
    }

    final typingLabel = channelType == WKChannelType.group
        ? '$typingUserName正在输入'
        : '对方正在输入';

    final key = conversationKey(channelId, channelType);
    _typingTimers.remove(key)?.cancel();
    _typingTimers[key] = Timer(
      typingDuration,
      () => clearTyping(channelId, channelType),
    );

    final current = _states[key] ?? ConversationActivityState.empty;
    _setState(
      channelId,
      channelType,
      current.copyWith(isTyping: true, typingLabel: typingLabel),
    );
  }

  void _handleChannelState(
    Map<String, dynamic> param, {
    required String currentUid,
  }) {
    final normalizedCurrentUid = currentUid.trim();
    var channelId = _readString(param['channel_id']);
    final channelType = _readInt(param['channel_type']);
    final fromUid = _readString(param['from_uid']);
    if (channelId.isEmpty) {
      return;
    }
    if (channelType == WKChannelType.personal && channelId == normalizedCurrentUid) {
      channelId = fromUid;
    }

    var isCalling = false;
    var roomName = '';
    var participants = const <CallingParticipantInfo>[];
    final callInfo = param['call_info'];
    if (callInfo is Map) {
      roomName = _readString(callInfo['room_name']);
      participants = _readCallingParticipants(callInfo['calling_participants']);
      final rawParticipants = callInfo['calling_participants'];
      if (participants.isNotEmpty) {
        isCalling = true;
      } else if (rawParticipants is String) {
        isCalling =
            rawParticipants.trim().isNotEmpty &&
            rawParticipants.trim() != '[]';
      }
    }

    final current =
        _states[conversationKey(channelId, channelType)] ??
        ConversationActivityState.empty;
    _setState(
      channelId,
      channelType,
      current.copyWith(
        isCalling: isCalling,
        callRoomName: roomName.isEmpty ? null : roomName,
        clearCallRoomName: !isCalling && roomName.isEmpty,
        callingParticipants: participants,
        clearCallingParticipants: !isCalling || participants.isEmpty,
      ),
    );
  }

  void _setState(
    String channelId,
    int channelType,
    ConversationActivityState nextState,
  ) {
    final key = conversationKey(channelId, channelType);
    final normalizedState = (!nextState.isTyping &&
            !nextState.isCalling &&
            (nextState.typingLabel?.trim().isEmpty ?? true) &&
            (nextState.callRoomName?.trim().isEmpty ?? true) &&
            nextState.callingParticipants.isEmpty)
        ? null
        : nextState;
    final previous = _states[key];
    if (normalizedState == null) {
      if (previous == null) {
        return;
      }
      _states.remove(key);
      _notifyConversation(key);
      return;
    }
    if (previous != null &&
        previous.isTyping == normalizedState.isTyping &&
        previous.isCalling == normalizedState.isCalling &&
        previous.typingLabel == normalizedState.typingLabel &&
        previous.callRoomName == normalizedState.callRoomName &&
        listEquals(
          previous.callingParticipants,
          normalizedState.callingParticipants,
        )) {
      return;
    }
    _states[key] = normalizedState;
    _notifyConversation(key);
  }

  List<CallingParticipantInfo> _readCallingParticipants(dynamic value) {
    if (value is! List) {
      return const <CallingParticipantInfo>[];
    }
    final participants = <CallingParticipantInfo>[];
    for (final item in value) {
      if (item is String) {
        final normalized = item.trim();
        if (normalized.isEmpty) {
          continue;
        }
        participants.add(
          CallingParticipantInfo(
            uid: normalized,
            name: normalized,
          ),
        );
        continue;
      }
      if (item is! Map) {
        continue;
      }
      final uid = _readString(item['uid']);
      final name = _readString(item['name']);
      if (uid.isEmpty && name.isEmpty) {
        continue;
      }
      participants.add(
        CallingParticipantInfo(
          uid: uid,
          name: name.isEmpty ? uid : name,
        ),
      );
    }
    return participants;
  }

  void _notifyConversation(String key) {
    final listeners = _listeners[key];
    if (listeners != null && listeners.isNotEmpty) {
      for (final listener in listeners.toList()) {
        listener();
      }
    }
    if (_globalListeners.isEmpty) {
      return;
    }
    for (final listener in _globalListeners.toList()) {
      listener(key);
    }
  }

  int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _readString(dynamic value) {
    if (value == null) {
      return '';
    }
    return value.toString().trim();
  }
}
