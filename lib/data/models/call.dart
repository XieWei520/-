import 'dart:convert';

/// Media type for a call room.
enum CallType {
  audio(0),
  video(1);

  final int value;
  const CallType(this.value);

  static CallType fromValue(int? value) {
    return value == 0 ? CallType.audio : CallType.video;
  }
}

enum CallDirection {
  incoming('incoming'),
  outgoing('outgoing');

  final String value;
  const CallDirection(this.value);

  static CallDirection fromValue(String? value) {
    return CallDirection.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CallDirection.outgoing,
    );
  }
}

enum CallHistoryStatus {
  ringing('ringing'),
  connected('connected'),
  completed('completed'),
  missed('missed'),
  rejected('rejected'),
  canceled('canceled');

  final String value;
  const CallHistoryStatus(this.value);

  static CallHistoryStatus fromValue(String? value) {
    return CallHistoryStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CallHistoryStatus.canceled,
    );
  }
}

/// Call room status values returned by the backend.
enum CallRoomStatus {
  pending(0),
  ringing(1),
  connected(2),
  ended(3),
  canceled(4);

  final int value;
  const CallRoomStatus(this.value);

  static CallRoomStatus fromValue(int? value) {
    return CallRoomStatus.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CallRoomStatus.pending,
    );
  }
}

/// Call signaling types exchanged between peers.
enum CallSignalType {
  offer(0),
  answer(1),
  iceCandidate(2),
  hangup(3),
  control(4);

  final int value;
  const CallSignalType(this.value);

  static CallSignalType fromValue(int? value) {
    return CallSignalType.values.firstWhere(
      (item) => item.value == value,
      orElse: () => CallSignalType.control,
    );
  }
}

/// Call room data returned from `/v1/extra/call/room`.
class CallParticipant {
  const CallParticipant({
    required this.uid,
    required this.name,
    required this.role,
    required this.inviteStatus,
  });

  final String uid;
  final String name;
  final int role;
  final int inviteStatus;

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      uid: _readString(json['uid']) ?? '',
      name:
          _readString(json['name']) ??
          _readString(json['user_name']) ??
          _readString(json['member_name']) ??
          '',
      role: _readInt(json['role']) ?? 0,
      inviteStatus: _readInt(json['invite_status']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uid': uid,
      'name': name,
      'role': role,
      'invite_status': inviteStatus,
    };
  }
}

class CallRoom {
  CallRoom({
    required this.roomId,
    required this.callerUid,
    required this.calleeUid,
    required this.callType,
    required this.status,
    this.roomName,
    this.channelId,
    this.channelType,
    this.participants = const <CallParticipant>[],
    this.callerName,
    this.calleeName,
    this.createdAt,
  });

  final String roomId;
  final String callerUid;
  final String calleeUid;
  final CallType callType;
  final CallRoomStatus status;
  final String? roomName;
  final String? channelId;
  final int? channelType;
  final List<CallParticipant> participants;
  final String? callerName;
  final String? calleeName;
  final DateTime? createdAt;

  factory CallRoom.fromJson(Map<String, dynamic> json) {
    return CallRoom(
      roomId: _readString(json['room_id']) ?? '',
      callerUid: _readString(json['caller_uid']) ?? '',
      calleeUid: _readString(json['callee_uid']) ?? '',
      callType: CallType.fromValue(_readInt(json['call_type'])),
      status: CallRoomStatus.fromValue(_readInt(json['status'])),
      roomName: _readString(json['room_name']),
      channelId: _readString(json['channel_id']),
      channelType: _readInt(json['channel_type']),
      participants: _readParticipants(json['participants']),
      callerName: _readString(json['caller_name']),
      calleeName: _readString(json['callee_name']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  CallRoom copyWith({
    String? roomId,
    String? callerUid,
    String? calleeUid,
    CallType? callType,
    CallRoomStatus? status,
    String? roomName,
    bool clearRoomName = false,
    String? channelId,
    bool clearChannelId = false,
    int? channelType,
    bool clearChannelType = false,
    List<CallParticipant>? participants,
    String? callerName,
    bool clearCallerName = false,
    String? calleeName,
    bool clearCalleeName = false,
    DateTime? createdAt,
    bool clearCreatedAt = false,
  }) {
    return CallRoom(
      roomId: roomId ?? this.roomId,
      callerUid: callerUid ?? this.callerUid,
      calleeUid: calleeUid ?? this.calleeUid,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      roomName: clearRoomName ? null : (roomName ?? this.roomName),
      channelId: clearChannelId ? null : (channelId ?? this.channelId),
      channelType: clearChannelType ? null : (channelType ?? this.channelType),
      participants: participants ?? this.participants,
      callerName: clearCallerName ? null : (callerName ?? this.callerName),
      calleeName: clearCalleeName ? null : (calleeName ?? this.calleeName),
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

String? _readString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString().trim() ?? '');
}

List<CallParticipant> _readParticipants(dynamic value) {
  if (value is! List) {
    return const <CallParticipant>[];
  }
  return value
      .whereType<Object?>()
      .map((item) {
        if (item is Map<String, dynamic>) {
          return CallParticipant.fromJson(item);
        }
        if (item is Map) {
          return CallParticipant.fromJson(Map<String, dynamic>.from(item));
        }
        return null;
      })
      .whereType<CallParticipant>()
      .toList(growable: false);
}

/// Single call signal entry.
class CallSignal {
  CallSignal({
    required this.fromUid,
    required this.signalType,
    required this.payload,
    this.createdAt,
  });

  final String fromUid;
  final CallSignalType signalType;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  factory CallSignal.fromJson(Map<String, dynamic> json) {
    return CallSignal(
      fromUid: json['from_uid']?.toString() ?? '',
      signalType: CallSignalType.fromValue(json['signal_type'] as int?),
      payload: _parsePayload(json['payload']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  static Map<String, dynamic> _parsePayload(dynamic raw) {
    if (raw == null) {
      return <String, dynamic>{};
    }
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    final text = raw.toString().trim();
    if (text.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // ignored
    }
    return <String, dynamic>{'value': text};
  }
}

class CallHistoryEntry {
  CallHistoryEntry({
    required this.roomId,
    required this.channelId,
    required this.channelName,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.avatar,
  });

  final String roomId;
  final String channelId;
  final String channelName;
  final CallType callType;
  final CallDirection direction;
  final CallHistoryStatus status;
  final int startedAt;
  final int? connectedAt;
  final int? endedAt;
  final String? avatar;

  int? get durationSeconds {
    final started = connectedAt ?? startedAt;
    final ended = endedAt;
    if (ended == null || ended <= started) {
      return null;
    }
    return ((ended - started) / 1000).floor();
  }

  CallHistoryEntry copyWith({
    String? roomId,
    String? channelId,
    String? channelName,
    CallType? callType,
    CallDirection? direction,
    CallHistoryStatus? status,
    int? startedAt,
    int? connectedAt,
    bool clearConnectedAt = false,
    int? endedAt,
    bool clearEndedAt = false,
    String? avatar,
    bool clearAvatar = false,
  }) {
    return CallHistoryEntry(
      roomId: roomId ?? this.roomId,
      channelId: channelId ?? this.channelId,
      channelName: channelName ?? this.channelName,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      connectedAt: clearConnectedAt ? null : (connectedAt ?? this.connectedAt),
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      avatar: clearAvatar ? null : (avatar ?? this.avatar),
    );
  }

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawType = json['call_type'];
    final callType = rawType is String
        ? CallType.fromValue(int.tryParse(rawType))
        : CallType.fromValue(rawType as int?);
    return CallHistoryEntry(
      roomId: json['room_id']?.toString() ?? '',
      channelId: json['channel_id']?.toString() ?? '',
      channelName: json['channel_name']?.toString() ?? '',
      callType: callType,
      direction: CallDirection.fromValue(json['direction']?.toString()),
      status: CallHistoryStatus.fromValue(json['status']?.toString()),
      startedAt: _readTimestamp(json['started_at']),
      connectedAt: _readNullableTimestamp(json['connected_at']),
      endedAt: _readNullableTimestamp(json['ended_at']),
      avatar: json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'channel_id': channelId,
      'channel_name': channelName,
      'call_type': callType.value,
      'direction': direction.value,
      'status': status.value,
      'started_at': startedAt,
      if (connectedAt != null) 'connected_at': connectedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if ((avatar ?? '').trim().isNotEmpty) 'avatar': avatar,
    };
  }

  static int _readTimestamp(dynamic value) {
    final parsed = _readNullableTimestamp(value);
    return parsed ?? DateTime.now().millisecondsSinceEpoch;
  }

  static int? _readNullableTimestamp(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
