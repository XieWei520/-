import '../../data/models/call.dart';
import '../session/session_event_frame.dart';
import 'call_state_machine.dart';

class CallEventMapper {
  const CallEventMapper({required this.currentUid});

  final String currentUid;

  CallEvent? mapFrame(SessionEventFrame frame) {
    return switch (frame.kind) {
      'call.invite' => _mapInvite(frame),
      'call.signal' => _mapSignal(frame),
      'call.state' => _mapState(frame),
      _ => null,
    };
  }

  CallEvent? _mapInvite(SessionEventFrame frame) {
    final payload = frame.payload;
    final roomId = _readString(payload['room_id']) ?? frame.aggregateId;
    final callerUid = _readString(payload['caller_uid']);
    final calleeUid = _readString(payload['callee_uid']);
    final channelId = _readString(payload['channel_id']);
    if (roomId.isEmpty || callerUid == null) {
      return null;
    }
    final roomName = _readString(payload['room_name']);
    final isOutgoing = currentUid.isNotEmpty && currentUid == callerUid;
    final peerUid =
        channelId ??
        (isOutgoing ? calleeUid : callerUid) ??
        (isOutgoing ? callerUid : calleeUid);
    if (peerUid == null) {
      return null;
    }
    final peerName =
        roomName ??
        _readString(
          isOutgoing ? payload['callee_name'] : payload['caller_name'],
        ) ??
        peerUid;
    final callType = CallType.fromValue(_readInt(frame.payload['call_type']));
    if (isOutgoing) {
      return CallEvent.localDial(
        roomId: roomId,
        peerUid: peerUid,
        peerName: peerName,
        callType: callType,
      );
    }
    return CallEvent.invite(
      roomId: roomId,
      peerUid: peerUid,
      peerName: peerName,
      callType: callType,
    );
  }

  CallEvent? _mapSignal(SessionEventFrame frame) {
    final roomId = _readString(frame.payload['room_id']) ?? frame.aggregateId;
    final fromUid = _readString(frame.payload['from_uid']);
    final signalTypeValue = _readInt(frame.payload['signal_type']);
    if (roomId.isEmpty || fromUid == null || signalTypeValue == null) {
      return null;
    }
    return CallEvent.remoteSignal(
      roomId: roomId,
      fromUid: fromUid,
      signalType: CallSignalType.fromValue(signalTypeValue),
      payload: _decodeNestedPayload(frame.payload['payload']),
    );
  }

  CallEvent? _mapState(SessionEventFrame frame) {
    final roomId = _readString(frame.payload['room_id']) ?? frame.aggregateId;
    final statusValue = _readInt(frame.payload['status']);
    if (roomId.isEmpty || statusValue == null) {
      return null;
    }
    return CallEvent.remoteState(
      roomId: roomId,
      status: CallRoomStatus.fromValue(statusValue),
    );
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

  Map<String, dynamic> _decodeNestedPayload(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty) {
      return const <String, dynamic>{};
    }
    try {
      final frame = SessionEventFrame.fromJson(<String, dynamic>{
        'event_id': 'nested',
        'user_seq': 0,
        'server_ts': 0,
        'kind': 'nested',
        'aggregate_id': 'nested',
        'payload': text,
      });
      return frame.payload;
    } catch (_) {
      return <String, dynamic>{'value': text};
    }
  }
}
