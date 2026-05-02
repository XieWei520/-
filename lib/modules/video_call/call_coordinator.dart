import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/call.dart';
import '../../realtime/call/call_event_mapper.dart';
import '../../realtime/call/call_state_machine.dart';
import '../../realtime/call/call_store.dart';
import '../../realtime/session/session_event_frame.dart';
import '../../service/api/call_api.dart';
import 'call_notification.dart';
import 'rtc_notification_bridge.dart';
import 'video_call_page.dart';
import 'video_call_service.dart';

typedef PendingCallsFetcher =
    Future<List<CallRoom>> Function({required bool fallback});

String _defaultCurrentUidReader() {
  return StorageUtils.getUid()?.trim() ?? '';
}

Future<List<CallRoom>> _defaultPendingCallsFetcher({required bool fallback}) {
  return CallApi.instance.getPendingCalls(fallback: fallback);
}

List<Duration> _validatedPendingBackoffSchedule(List<Duration> schedule) {
  if (schedule.isEmpty) {
    throw ArgumentError.value(schedule, 'backoffSchedule', 'must not be empty');
  }
  return schedule;
}

class PendingCallRecoveryLoop {
  PendingCallRecoveryLoop({
    required CallStore callStore,
    required PendingCallsFetcher fetchPendingCalls,
    required String Function() currentUidReader,
    this.onAcceptedRoom,
    this.enableSafetyPolling = false,
    this.degradedThreshold = const Duration(seconds: 6),
    this.safetyPollingInterval = const Duration(seconds: 2),
    List<Duration> backoffSchedule = const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
    Future<void> Function(Duration delay)? delay,
  }) : _callStore = callStore,
       _fetchPendingCalls = fetchPendingCalls,
       _currentUidReader = currentUidReader,
       _delay = delay ?? Future<void>.delayed,
       backoffSchedule = _validatedPendingBackoffSchedule(backoffSchedule);

  final CallStore _callStore;
  final PendingCallsFetcher _fetchPendingCalls;
  final String Function() _currentUidReader;
  final Future<void> Function(Duration delay) _delay;
  final void Function(CallRoom room, CallEvent event)? onAcceptedRoom;
  final bool enableSafetyPolling;
  final Duration degradedThreshold;
  final Duration safetyPollingInterval;
  final List<Duration> backoffSchedule;

  bool _started = false;
  bool _isForeground = true;
  int _attempt = 0;
  int _generation = 0;
  int? _runningGeneration;
  int? _degradationWakeGeneration;
  bool Function(Duration threshold)? _isGatewayDegradedFor;

  bool get shouldPoll {
    return _canPoll &&
        (enableSafetyPolling ||
            (_isGatewayDegradedFor?.call(degradedThreshold) ?? false));
  }

  bool get _canPoll {
    return _started &&
        _isForeground &&
        !_callStore.state.isActive &&
        _currentUidReader().isNotEmpty;
  }

  void start() {
    _started = true;
    _ensureLoop();
  }

  void stop() {
    _started = false;
    _attempt = 0;
    _degradationWakeGeneration = null;
    _generation++;
  }

  void setForeground(bool value) {
    if (_isForeground == value) {
      return;
    }
    _isForeground = value;
    _attempt = 0;
    if (_isForeground) {
      _ensureLoop();
    } else {
      _degradationWakeGeneration = null;
      _generation++;
    }
  }

  void setGatewayDegradationReader(bool Function(Duration threshold) reader) {
    _isGatewayDegradedFor = reader;
    _attempt = 0;
    _ensureLoop();
  }

  void notifyStateChanged() {
    if (shouldPoll) {
      _ensureLoop();
      return;
    }
    _attempt = 0;
    _degradationWakeGeneration = null;
    _generation++;
    _ensureLoop();
  }

  Future<int> syncOnce() async {
    return _syncOnceWhileCurrent(() => shouldPoll);
  }

  Future<int> _syncOnceForGeneration(int generation) async {
    return _syncOnceWhileCurrent(() => generation == _generation && shouldPoll);
  }

  Future<int> _syncOnceWhileCurrent(bool Function() isCurrent) async {
    if (!isCurrent()) {
      return 0;
    }
    final rooms = await _fetchPendingCalls(fallback: true);
    if (!isCurrent()) {
      return 0;
    }
    return _applyPendingRooms(rooms);
  }

  int _applyPendingRooms(List<CallRoom> rooms) {
    var accepted = 0;
    for (final room in rooms) {
      final event = _mapRoom(room);
      if (event == null) {
        continue;
      }
      if (_callStore.apply(event)) {
        accepted++;
        onAcceptedRoom?.call(room, event);
      }
    }
    return accepted;
  }

  CallEvent? _mapRoom(CallRoom room) {
    final currentUid = _currentUidReader();
    if (currentUid.isEmpty || room.roomId.trim().isEmpty) {
      return null;
    }
    final isOutgoing = room.callerUid.trim() == currentUid;
    final isIncoming =
        !isOutgoing &&
        ((room.channelId ?? '').trim().isNotEmpty ||
            room.calleeUid.trim() == currentUid);
    if (isIncoming) {
      return CallEvent.invite(
        roomId: room.roomId,
        peerUid: _peerUid(room, incoming: true),
        peerName: _peerName(room, incoming: true),
        callType: room.callType,
      );
    }
    if (isOutgoing) {
      return CallEvent.localDial(
        roomId: room.roomId,
        peerUid: _peerUid(room, incoming: false),
        peerName: _peerName(room, incoming: false),
        callType: room.callType,
      );
    }
    return null;
  }

  String _peerUid(CallRoom room, {required bool incoming}) {
    final channelId = room.channelId?.trim() ?? '';
    if (channelId.isNotEmpty) {
      return channelId;
    }
    return incoming ? room.callerUid : room.calleeUid;
  }

  String _peerName(CallRoom room, {required bool incoming}) {
    final roomName = room.roomName?.trim() ?? '';
    if (roomName.isNotEmpty) {
      return roomName;
    }
    final fallback = _peerUid(room, incoming: incoming);
    final normalized = incoming
        ? room.callerName?.trim() ?? ''
        : room.calleeName?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  void _ensureLoop() {
    if (!shouldPoll) {
      _scheduleDegradationWakeIfNeeded();
      return;
    }
    _degradationWakeGeneration = null;
    if (_runningGeneration == _generation) {
      return;
    }
    final generation = ++_generation;
    _runningGeneration = generation;
    unawaited(_run(generation));
  }

  void _scheduleDegradationWakeIfNeeded() {
    if (!_canPoll || enableSafetyPolling || _isGatewayDegradedFor == null) {
      return;
    }
    if (_isGatewayDegradedFor?.call(degradedThreshold) ?? false) {
      _ensureLoop();
      return;
    }
    if (_degradationWakeGeneration == _generation) {
      return;
    }
    final generation = _generation;
    _degradationWakeGeneration = generation;
    unawaited(_wakeAfterDegradationThreshold(generation));
  }

  Future<void> _wakeAfterDegradationThreshold(int generation) async {
    try {
      await _delay(_degradationWakeDelay);
    } catch (error, stackTrace) {
      debugPrint('Pending call fallback degradation wake failed: $error');
      debugPrint('$stackTrace');
      if (_degradationWakeGeneration == generation) {
        _degradationWakeGeneration = null;
      }
      return;
    }
    if (_degradationWakeGeneration != generation || generation != _generation) {
      return;
    }
    _degradationWakeGeneration = null;
    if (shouldPoll) {
      _ensureLoop();
      return;
    }
    _scheduleDegradationWakeIfNeeded();
  }

  Future<void> _run(int generation) async {
    try {
      while (generation == _generation && shouldPoll) {
        try {
          final accepted = await _syncOnceForGeneration(generation);
          if (generation != _generation || !shouldPoll || accepted > 0) {
            break;
          }
        } catch (error, stackTrace) {
          debugPrint('Pending call fallback poll failed: $error');
          debugPrint('$stackTrace');
          if (generation != _generation || !shouldPoll) {
            break;
          }
        }

        final delay = _nextDelay();
        await _delay(delay);
      }
    } finally {
      if (_runningGeneration == generation) {
        _runningGeneration = null;
      }
      if (generation == _generation) {
        if (shouldPoll) {
          _ensureLoop();
        } else {
          _scheduleDegradationWakeIfNeeded();
        }
      }
    }
  }

  Duration get _degradationWakeDelay {
    if (degradedThreshold > Duration.zero) {
      return degradedThreshold;
    }
    if (safetyPollingInterval > Duration.zero) {
      return safetyPollingInterval;
    }
    return const Duration(milliseconds: 1);
  }

  Duration _nextDelay() {
    final isDegraded = _isGatewayDegradedFor?.call(degradedThreshold) ?? false;
    if (!isDegraded && enableSafetyPolling) {
      _attempt = 0;
      return safetyPollingInterval;
    }
    final delay = backoffSchedule[_attempt];
    if (_attempt < backoffSchedule.length - 1) {
      _attempt++;
    }
    return delay;
  }
}

class CallCoordinator with WidgetsBindingObserver {
  CallCoordinator({
    CallStore? callStore,
    PendingCallsFetcher? fetchPendingCalls,
    String Function()? currentUidReader,
    PendingCallRecoveryLoop? pendingRecoveryLoop,
    CallNotificationOverlay? notificationOverlay,
    RtcNotificationBridge? rtcNotificationBridge,
    VideoCallService? videoCallService,
  }) : _callStore = callStore ?? sharedCallStore,
       _currentUidReader = currentUidReader ?? _defaultCurrentUidReader,
       _notificationOverlay =
           notificationOverlay ?? CallNotificationOverlay.instance,
       _rtcNotificationBridge =
           rtcNotificationBridge ?? RtcNotificationBridge(),
       _videoCallService = videoCallService ?? VideoCallService.instance {
    _pendingRecoveryLoop =
        pendingRecoveryLoop ??
        PendingCallRecoveryLoop(
          callStore: _callStore,
          fetchPendingCalls: fetchPendingCalls ?? _defaultPendingCallsFetcher,
          currentUidReader: _currentUidReader,
          onAcceptedRoom: _handleRecoveredRoom,
        );
  }

  static final CallCoordinator instance = CallCoordinator();

  final CallStore _callStore;
  final String Function() _currentUidReader;
  final CallNotificationOverlay _notificationOverlay;
  final RtcNotificationBridge _rtcNotificationBridge;
  final VideoCallService _videoCallService;
  late final PendingCallRecoveryLoop _pendingRecoveryLoop;

  final Map<String, CallRoom> _knownRooms = <String, CallRoom>{};
  StreamSubscription<CallEvent>? _eventSubscription;
  StreamSubscription<CallSessionState>? _stateSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  bool _started = false;
  bool _isForeground = true;
  String? _overlayRoomId;
  String? _activeIncomingPageRoomId;
  Route<void>? _activeIncomingPageRoute;

  void start(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _rtcNotificationBridge.registerEndpoints();
    if (_started) {
      return;
    }
    _started = true;
    _eventSubscription = _callStore.events.listen(_handleCallEvent);
    _stateSubscription = _callStore.stream.listen(_handleCallState);
    WidgetsBinding.instance.addObserver(this);
    _pendingRecoveryLoop.start();
    _pendingRecoveryLoop.setForeground(_isForeground);
    _pendingRecoveryLoop.notifyStateChanged();
    _showOverlayForCurrentInviteIfNeeded();
  }

  void stop() {
    if (!_started) {
      _navigatorKey = null;
      return;
    }
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _pendingRecoveryLoop.stop();
    _cancelRtcNotification();
    _notificationOverlay.dismiss();
    _overlayRoomId = null;
    _dismissIncomingPageForRoom(_activeIncomingPageRoomId ?? '');
    _activeIncomingPageRoomId = null;
    _activeIncomingPageRoute = null;
    _knownRooms.clear();
    if (_videoCallService.hasActiveCallOrPendingSetup) {
      fireAndForgetCall(
        _videoCallService.endCall,
        debugLabel: 'call coordinator stop/endCall',
      );
    } else {
      _callStore.reset();
    }
    unawaited(_eventSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    _eventSubscription = null;
    _stateSubscription = null;
    _navigatorKey = null;
  }

  void setGatewayDegradationReader(bool Function(Duration threshold) reader) {
    _pendingRecoveryLoop.setGatewayDegradationReader(reader);
  }

  Future<void> handleSessionFrame(SessionEventFrame frame) async {
    final mapper = CallEventMapper(currentUid: _currentUidReader());
    final event = mapper.mapFrame(frame);
    if (event == null) {
      return;
    }
    _rememberRoomFromFrame(frame, event);
    _callStore.apply(event);
    _pendingRecoveryLoop.notifyStateChanged();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_isForeground == isForeground) {
      return;
    }
    _isForeground = isForeground;
    _pendingRecoveryLoop.setForeground(isForeground);
    if (!isForeground) {
      _notificationOverlay.dismiss();
      _overlayRoomId = null;
      return;
    }
    _cancelRtcNotification();
    _showOverlayForCurrentInviteIfNeeded();
  }

  void _handleCallEvent(CallEvent event) {
    if (event is InviteCallEvent) {
      if (!_isForeground) {
        _showRtcNotification(event);
        return;
      }
      _showIncomingInvite(event);
      return;
    }
    if (event is RemoteStateCallEvent &&
        (event.status == CallRoomStatus.ended ||
            event.status == CallRoomStatus.canceled)) {
      _cancelRtcNotification();
      _dismissOverlayForRoom(event.roomId);
      _dismissIncomingPageForRoom(event.roomId);
      _knownRooms.remove(event.roomId);
      return;
    }
    if (event is RemoteSignalCallEvent &&
        event.signalType == CallSignalType.hangup) {
      _cancelRtcNotification();
      _dismissOverlayForRoom(event.roomId);
      _dismissIncomingPageForRoom(event.roomId);
      return;
    }
    if (event is LocalHangupCallEvent) {
      _cancelRtcNotification();
      _dismissOverlayForRoom(event.roomId);
      _dismissIncomingPageForRoom(event.roomId);
    }
  }

  void _handleCallState(CallSessionState state) {
    _pendingRecoveryLoop.notifyStateChanged();
    if (state.status != CallLifecycleStatus.invited) {
      _cancelRtcNotification();
    }
    if (state.status == CallLifecycleStatus.invited) {
      _showOverlayForCurrentInviteIfNeeded();
      return;
    }
    if (!state.isActive) {
      _dismissOverlayForRoom(state.roomId);
      _dismissIncomingPageForRoom(state.roomId);
      if (state.roomId.isNotEmpty) {
        _knownRooms.remove(state.roomId);
      }
    }
  }

  void _handleRecoveredRoom(CallRoom room, CallEvent event) {
    _knownRooms[room.roomId] = room;
  }

  void _rememberRoomFromFrame(SessionEventFrame frame, CallEvent event) {
    final payload = frame.payload;
    final roomName = _readString(payload['room_name']);
    final channelId = _readString(payload['channel_id']);
    final channelType = _readInt(payload['channel_type']);
    final callerUid = _readString(payload['caller_uid']);
    final callerName = _readString(payload['caller_name']);
    final calleeUid = _readString(payload['callee_uid']);
    final calleeName = _readString(payload['callee_name']);
    switch (event) {
      case InviteCallEvent():
        final currentUid = _currentUidReader();
        _knownRooms[event.roomId] = CallRoom(
          roomId: event.roomId,
          callerUid: callerUid ?? event.peerUid,
          callerName: callerName ?? event.peerName,
          calleeUid: calleeUid ?? currentUid,
          callType: event.callType,
          status: CallRoomStatus.pending,
          roomName: roomName,
          channelId: channelId,
          channelType: channelType,
        );
      case LocalDialCallEvent():
        final currentUid = _currentUidReader();
        _knownRooms[event.roomId] = CallRoom(
          roomId: event.roomId,
          callerUid: callerUid ?? currentUid,
          callerName: callerName,
          calleeUid: calleeUid ?? event.peerUid,
          calleeName: calleeName ?? event.peerName,
          callType: event.callType,
          status: CallRoomStatus.pending,
          roomName: roomName,
          channelId: channelId,
          channelType: channelType,
        );
      case RemoteStateCallEvent():
        final existing = _knownRooms[event.roomId];
        _knownRooms[event.roomId] =
            (existing ??
                    CallRoom(
                      roomId: event.roomId,
                      callerUid: callerUid ?? '',
                      calleeUid: calleeUid ?? '',
                      callType: existing?.callType ?? _callStore.state.callType,
                      status: event.status,
                    ))
                .copyWith(
                  status: event.status,
                  roomName: roomName,
                  channelId: channelId,
                  channelType: channelType,
                  callerUid: callerUid,
                  callerName: callerName,
                  calleeUid: calleeUid,
                  calleeName: calleeName,
                );
      case RemoteSignalCallEvent():
      case LocalAcceptCallEvent():
      case LocalHangupCallEvent():
        break;
    }

    if (frame.kind == 'call.invite' &&
        !_knownRooms.containsKey(frame.aggregateId) &&
        event is InviteCallEvent) {
      _knownRooms[event.roomId] = _buildIncomingRoomFromEvent(event);
    }
  }

  void _showOverlayForCurrentInviteIfNeeded() {
    final state = _callStore.state;
    if (!_isForeground || state.status != CallLifecycleStatus.invited) {
      return;
    }
    final room = _knownRooms[state.roomId];
    if (room == null) {
      return;
    }
    _showIncomingInvite(
      InviteCallEvent(
        roomId: room.roomId,
        peerUid: _eventPeerUid(room),
        peerName: _eventPeerName(room),
        callType: room.callType,
      ),
    );
  }

  void _showIncomingInvite(InviteCallEvent event) {
    if (!_started || !_isForeground) {
      return;
    }
    if (_overlayRoomId == event.roomId ||
        _activeIncomingPageRoomId == event.roomId) {
      return;
    }
    final overlayState = _navigatorKey?.currentState?.overlay;
    if (overlayState == null) {
      return;
    }
    final room =
        _knownRooms[event.roomId] ?? _buildIncomingRoomFromEvent(event);
    _knownRooms[event.roomId] = room;
    _overlayRoomId = event.roomId;
    _notificationOverlay.showIncomingCall(
      overlayState: overlayState,
      data: CallNotificationData(
        channelId: _eventPeerUid(room),
        channelName: _eventPeerName(room),
        type: CallNotificationType.incoming,
        callType: event.callType.value,
        fromUid: room.callerUid,
      ),
      onAccept: () {
        _overlayRoomId = null;
        _openIncomingCallPage(room);
      },
      onReject: () {
        _overlayRoomId = null;
        fireAndForgetCall(
          () => _videoCallService.rejectIncomingCall(room),
          debugLabel: 'reject incoming call from overlay',
        );
      },
    );
  }

  CallRoom _buildIncomingRoomFromEvent(InviteCallEvent event) {
    return CallRoom(
      roomId: event.roomId,
      callerUid: event.peerUid,
      callerName: event.peerName,
      calleeUid: _currentUidReader(),
      callType: event.callType,
      status: CallRoomStatus.pending,
    );
  }

  void _openIncomingCallPage(CallRoom room) {
    if (_activeIncomingPageRoomId == room.roomId) {
      return;
    }
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      return;
    }
    _activeIncomingPageRoomId = room.roomId;
    final channelId = (room.channelId ?? '').trim().isNotEmpty
        ? room.channelId!
        : room.callerUid;
    final channelName = _eventPeerName(room);
    final route = MaterialPageRoute<void>(
      builder: (_) => VideoCallPage(
        channelId: channelId,
        channelType: room.channelType ?? WKChannelType.personal,
        channelName: channelName,
        callType: room.callType,
        isIncoming: true,
        incomingRoom: room,
      ),
    );
    _activeIncomingPageRoute = route;
    navigator.push(route).whenComplete(() {
      if (_activeIncomingPageRoomId == room.roomId) {
        _activeIncomingPageRoomId = null;
      }
      if (_activeIncomingPageRoute == route) {
        _activeIncomingPageRoute = null;
      }
    });
  }

  void _dismissOverlayForRoom(String roomId) {
    if (roomId.isEmpty || _overlayRoomId != roomId) {
      return;
    }
    _notificationOverlay.dismiss();
    _overlayRoomId = null;
  }

  void _dismissIncomingPageForRoom(String roomId) {
    if (roomId.isEmpty || _activeIncomingPageRoomId != roomId) {
      return;
    }
    final navigator = _navigatorKey?.currentState;
    final route = _activeIncomingPageRoute;
    _activeIncomingPageRoomId = null;
    _activeIncomingPageRoute = null;
    if (navigator == null || route == null) {
      return;
    }
    if (route.isActive) {
      navigator.removeRoute(route);
    }
  }

  String _resolvePeerName(String? rawName, String fallback) {
    final normalized = rawName?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  String _eventPeerUid(CallRoom room) {
    final channelId = room.channelId?.trim() ?? '';
    return channelId.isEmpty ? room.callerUid : channelId;
  }

  String _eventPeerName(CallRoom room) {
    final roomName = room.roomName?.trim() ?? '';
    if (roomName.isNotEmpty) {
      return roomName;
    }
    return _resolvePeerName(room.callerName, room.callerUid);
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

  void _showRtcNotification(InviteCallEvent event) {
    final room = _knownRooms[event.roomId];
    fireAndForgetCall(
      () => _rtcNotificationBridge.showRtcNotification(
        RtcNotificationRequest(
          fromUid: room?.callerUid ?? event.peerUid,
          fromName: room == null ? event.peerName : _eventPeerName(room),
          callType: event.callType.value,
          roomId: event.roomId,
        ),
      ),
      debugLabel: 'show rtc notification',
    );
  }

  void _cancelRtcNotification() {
    fireAndForgetCall(
      _rtcNotificationBridge.cancelRtcNotification,
      debugLabel: 'cancel rtc notification',
    );
  }
}
