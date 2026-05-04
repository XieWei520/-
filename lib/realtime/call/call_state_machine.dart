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

class CallSessionState {
  const CallSessionState({
    required this.status,
    required this.roomId,
    required this.peerUid,
    required this.peerName,
    required this.callType,
    required this.direction,
  });

  const CallSessionState.idle()
      : status = CallLifecycleStatus.idle,
        roomId = '',
        peerUid = '',
        peerName = '',
        callType = CallType.audio,
        direction = CallDirection.outgoing;

  final CallLifecycleStatus status;
  final String roomId;
  final String peerUid;
  final String peerName;
  final CallType callType;
  final CallDirection direction;

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
  }) {
    return CallSessionState(
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      peerUid: peerUid ?? this.peerUid,
      peerName: peerName ?? this.peerName,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
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
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(
        status,
        roomId,
        peerUid,
        peerName,
        callType,
        direction,
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

  const factory CallEvent.localAccept({
    required String roomId,
  }) = LocalAcceptCallEvent;

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

  const factory CallEvent.localHangup({
    required String roomId,
  }) = LocalHangupCallEvent;
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

class RemoteStateCallEvent extends CallEvent {
  const RemoteStateCallEvent({
    required String roomId,
    required this.status,
  }) : super(roomId);

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
    final canStartSession = event is InviteCallEvent || event is LocalDialCallEvent;
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
          status: CallLifecycleStatus.invited,
          roomId: event.roomId,
          peerUid: event.peerUid,
          peerName: event.peerName,
          callType: event.callType,
          direction: CallDirection.incoming,
        ),
      LocalDialCallEvent() => CallSessionState(
          status: CallLifecycleStatus.ringing,
          roomId: event.roomId,
          peerUid: event.peerUid,
          peerName: event.peerName,
          callType: event.callType,
          direction: CallDirection.outgoing,
        ),
      LocalAcceptCallEvent() => current.copyWith(
          status: CallLifecycleStatus.connecting,
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
          status: current.direction == CallDirection.outgoing
              ? CallLifecycleStatus.ringing
              : CallLifecycleStatus.invited,
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
      CallSignalType.offer || CallSignalType.answer => current.copyWith(
          status: CallLifecycleStatus.connecting,
        ),
      CallSignalType.hangup => current.copyWith(
          status: CallLifecycleStatus.ended,
        ),
      CallSignalType.iceCandidate || CallSignalType.control => current,
    };
  }
}
