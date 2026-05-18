import '../../data/models/call.dart';

enum CallLifecycleStatus {
  idle,
  invited,
  ringing,
  connecting,
  connected,
  reconnecting,
  ending,
  ended,
  failed,
}

enum CallFailureReason {
  declined,
  cancelled,
  timeout,
  iceFailed,
  tokenInvalid,
  permissionDenied,
  networkLost,
  livekitConnectFailed,
  signalingFailed,
  unknown;

  String get code {
    return switch (this) {
      CallFailureReason.declined => 'declined',
      CallFailureReason.cancelled => 'cancelled',
      CallFailureReason.timeout => 'timeout',
      CallFailureReason.iceFailed => 'ice_failed',
      CallFailureReason.tokenInvalid => 'token_invalid',
      CallFailureReason.permissionDenied => 'permission_denied',
      CallFailureReason.networkLost => 'network_lost',
      CallFailureReason.livekitConnectFailed => 'livekit_connect_failed',
      CallFailureReason.signalingFailed => 'signaling_failed',
      CallFailureReason.unknown => 'unknown',
    };
  }
}

class CallSessionState {
  const CallSessionState({
    required this.status,
    required this.roomId,
    required this.peerUid,
    required this.peerName,
    required this.callType,
    required this.direction,
    this.failureReason,
  });

  const CallSessionState.idle()
    : status = CallLifecycleStatus.idle,
      roomId = '',
      peerUid = '',
      peerName = '',
      callType = CallType.audio,
      direction = CallDirection.outgoing,
      failureReason = null;

  final CallLifecycleStatus status;
  final String roomId;
  final String peerUid;
  final String peerName;
  final CallType callType;
  final CallDirection direction;
  final CallFailureReason? failureReason;

  CallLifecycleStatus get publicStatus {
    if (status == CallLifecycleStatus.invited) {
      return CallLifecycleStatus.ringing;
    }
    return status;
  }

  bool get isTerminal =>
      status == CallLifecycleStatus.idle ||
      status == CallLifecycleStatus.ended ||
      status == CallLifecycleStatus.failed;

  bool get isActive => roomId.isNotEmpty && !isTerminal;

  CallSessionState copyWith({
    CallLifecycleStatus? status,
    String? roomId,
    String? peerUid,
    String? peerName,
    CallType? callType,
    CallDirection? direction,
    CallFailureReason? failureReason,
  }) {
    return CallSessionState(
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      peerUid: peerUid ?? this.peerUid,
      peerName: peerName ?? this.peerName,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      failureReason: failureReason ?? this.failureReason,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CallSessionState &&
        other.status == status &&
        other.roomId == roomId &&
        other.peerUid == peerUid &&
        other.peerName == peerName &&
        other.callType == callType &&
        other.direction == direction &&
        other.failureReason == failureReason;
  }

  @override
  int get hashCode => Object.hash(
    status,
    roomId,
    peerUid,
    peerName,
    callType,
    direction,
    failureReason,
  );
}

sealed class CallEvent {
  const CallEvent(this.roomId);

  final String roomId;

  const factory CallEvent.invite({
    required String roomId,
    required String peerUid,
    required String peerName,
    required CallType callType,
  }) = InviteCallEvent;

  const factory CallEvent.localDial({
    required String roomId,
    required String peerUid,
    required String peerName,
    required CallType callType,
  }) = LocalDialCallEvent;

  const factory CallEvent.localAccept({required String roomId}) =
      LocalAcceptCallEvent;

  const factory CallEvent.localConnecting({required String roomId}) =
      LocalConnectingCallEvent;

  const factory CallEvent.localConnected({required String roomId}) =
      LocalConnectedCallEvent;

  const factory CallEvent.localReconnecting({required String roomId}) =
      LocalReconnectingCallEvent;

  const factory CallEvent.localFailed({
    required String roomId,
    required CallFailureReason reason,
  }) = LocalFailedCallEvent;

  const factory CallEvent.remoteState({
    required String roomId,
    required CallRoomStatus status,
  }) = RemoteStateCallEvent;

  const factory CallEvent.remoteSignal({
    required String roomId,
    required String fromUid,
    required CallSignalType signalType,
    required Map<String, dynamic> payload,
  }) = RemoteSignalCallEvent;

  const factory CallEvent.localHangup({required String roomId}) =
      LocalHangupCallEvent;
}

class InviteCallEvent extends CallEvent {
  const InviteCallEvent({
    required String roomId,
    required this.peerUid,
    required this.peerName,
    required this.callType,
  }) : super(roomId);

  final String peerUid;
  final String peerName;
  final CallType callType;
}

class LocalDialCallEvent extends CallEvent {
  const LocalDialCallEvent({
    required String roomId,
    required this.peerUid,
    required this.peerName,
    required this.callType,
  }) : super(roomId);

  final String peerUid;
  final String peerName;
  final CallType callType;
}

class LocalAcceptCallEvent extends CallEvent {
  const LocalAcceptCallEvent({required String roomId}) : super(roomId);
}

class LocalConnectingCallEvent extends CallEvent {
  const LocalConnectingCallEvent({required String roomId}) : super(roomId);
}

class LocalConnectedCallEvent extends CallEvent {
  const LocalConnectedCallEvent({required String roomId}) : super(roomId);
}

class LocalReconnectingCallEvent extends CallEvent {
  const LocalReconnectingCallEvent({required String roomId}) : super(roomId);
}

class LocalFailedCallEvent extends CallEvent {
  const LocalFailedCallEvent({required String roomId, required this.reason})
    : super(roomId);

  final CallFailureReason reason;
}

class RemoteStateCallEvent extends CallEvent {
  const RemoteStateCallEvent({required String roomId, required this.status})
    : super(roomId);

  final CallRoomStatus status;
}

class RemoteSignalCallEvent extends CallEvent {
  const RemoteSignalCallEvent({
    required String roomId,
    required this.fromUid,
    required this.signalType,
    required this.payload,
  }) : super(roomId);

  final String fromUid;
  final CallSignalType signalType;
  final Map<String, dynamic> payload;
}

class LocalHangupCallEvent extends CallEvent {
  const LocalHangupCallEvent({required String roomId}) : super(roomId);
}

class CallStateMachine {
  const CallStateMachine();

  bool accepts(CallSessionState current, CallEvent event) {
    final canStartSession =
        event is InviteCallEvent || event is LocalDialCallEvent;
    if (current.isActive) {
      return current.roomId == event.roomId;
    }
    if (canStartSession) {
      return true;
    }
    if (current.roomId.isEmpty) {
      return false;
    }
    return false;
  }

  CallSessionState reduce(CallSessionState current, CallEvent event) {
    if (!accepts(current, event)) {
      return current;
    }

    return switch (event) {
      InviteCallEvent() => CallSessionState(
        status: CallLifecycleStatus.ringing,
        roomId: event.roomId,
        peerUid: event.peerUid,
        peerName: event.peerName,
        callType: event.callType,
        direction: CallDirection.incoming,
        failureReason: null,
      ),
      LocalDialCallEvent() => CallSessionState(
        status: CallLifecycleStatus.ringing,
        roomId: event.roomId,
        peerUid: event.peerUid,
        peerName: event.peerName,
        callType: event.callType,
        direction: CallDirection.outgoing,
        failureReason: null,
      ),
      LocalAcceptCallEvent() => current.copyWith(
        status: CallLifecycleStatus.connecting,
      ),
      LocalConnectingCallEvent() => current.copyWith(
        status: CallLifecycleStatus.connecting,
      ),
      LocalConnectedCallEvent() => current.copyWith(
        status: CallLifecycleStatus.connected,
      ),
      LocalReconnectingCallEvent() => current.copyWith(
        status: CallLifecycleStatus.reconnecting,
      ),
      LocalFailedCallEvent() => current.copyWith(
        status: CallLifecycleStatus.failed,
        failureReason: event.reason,
      ),
      RemoteStateCallEvent() => _reduceRemoteState(current, event.status),
      RemoteSignalCallEvent() => _reduceRemoteSignal(current, event.signalType),
      LocalHangupCallEvent() => current.copyWith(
        status: CallLifecycleStatus.ending,
      ),
    };
  }

  CallSessionState _reduceRemoteState(
    CallSessionState current,
    CallRoomStatus status,
  ) {
    return switch (status) {
      CallRoomStatus.pending => current.copyWith(
        status: CallLifecycleStatus.ringing,
      ),
      CallRoomStatus.ringing => current.copyWith(
        status: CallLifecycleStatus.ringing,
      ),
      CallRoomStatus.connected => current.copyWith(
        status: CallLifecycleStatus.connected,
      ),
      CallRoomStatus.ended || CallRoomStatus.canceled => current.copyWith(
        status: CallLifecycleStatus.ended,
      ),
    };
  }

  CallSessionState _reduceRemoteSignal(
    CallSessionState current,
    CallSignalType signalType,
  ) {
    return switch (signalType) {
      CallSignalType.offer => current.copyWith(
        status: CallLifecycleStatus.connecting,
      ),
      CallSignalType.answer => current.copyWith(
        status: CallLifecycleStatus.connected,
      ),
      CallSignalType.hangup => current.copyWith(
        status: CallLifecycleStatus.ended,
      ),
      CallSignalType.iceCandidate || CallSignalType.control => current,
    };
  }
}
