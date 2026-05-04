import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wukongimfluttersdk/type/const.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/call.dart';
import '../../realtime/call/call_state_machine.dart';
import '../../realtime/call/call_store.dart';
import '../../service/api/call_api.dart';
import 'call_session_service.dart';
import '../conversation/conversation_activity_registry.dart';
import 'call_conversation_record_service.dart';
import 'call_history_service.dart';

enum CallState { idle, calling, ringing, connected, ended }

typedef SignalFetcher =
    Future<List<CallSignal>> Function(String roomId, {required bool fallback});

String _defaultCurrentUidReader() {
  return StorageUtils.getUid()?.trim() ?? '';
}

Future<List<CallSignal>> _defaultSignalFetcher(
  String roomId, {
  required bool fallback,
}) {
  return CallApi.instance.getSignals(roomId, fallback: fallback);
}

List<Duration> _validatedSignalBackoffSchedule(List<Duration> schedule) {
  if (schedule.isEmpty) {
    throw ArgumentError.value(schedule, 'backoffSchedule', 'must not be empty');
  }
  return schedule;
}

typedef CallAsyncErrorHandler =
    void Function(Object error, StackTrace stackTrace);

void fireAndForgetCall(
  Future<void> Function() action, {
  required String debugLabel,
  CallAsyncErrorHandler? onError,
}) {
  unawaited(_runCallGuarded(action, debugLabel: debugLabel, onError: onError));
}

Future<void> _runCallGuarded(
  Future<void> Function() action, {
  required String debugLabel,
  CallAsyncErrorHandler? onError,
}) async {
  try {
    await action();
  } catch (error, stackTrace) {
    if (onError != null) {
      onError(error, stackTrace);
      return;
    }
    debugPrint('$debugLabel failed: $error');
    debugPrint('$stackTrace');
  }
}

bool supportsSpeakerphoneRouting({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
}) {
  if (isWeb) {
    return false;
  }
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  return resolvedPlatform == TargetPlatform.android ||
      resolvedPlatform == TargetPlatform.iOS;
}

class LocalMediaCaptureResolution {
  const LocalMediaCaptureResolution({
    required this.acceptsStream,
    required this.localVideoAvailable,
    required this.retryNextCandidate,
  });

  final bool acceptsStream;
  final bool localVideoAvailable;
  final bool retryNextCandidate;
}

List<Map<String, dynamic>> buildUserMediaConstraintCandidates({
  required bool videoEnabled,
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
}) {
  if (!videoEnabled) {
    return const <Map<String, dynamic>>[
      <String, dynamic>{'audio': true, 'video': false},
    ];
  }

  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final prefersMobileConstraints =
      isWeb ||
      resolvedPlatform == TargetPlatform.android ||
      resolvedPlatform == TargetPlatform.iOS;
  if (prefersMobileConstraints) {
    return const <Map<String, dynamic>>[
      <String, dynamic>{
        'audio': true,
        'video': <String, dynamic>{
          'facingMode': 'user',
          'width': 960,
          'height': 540,
        },
      },
    ];
  }

  return const <Map<String, dynamic>>[
    <String, dynamic>{
      'audio': true,
      'video': <String, dynamic>{'width': 960, 'height': 540},
    },
    <String, dynamic>{
      'audio': true,
      'video': <String, dynamic>{
        'width': <String, dynamic>{'ideal': 960},
        'height': <String, dynamic>{'ideal': 540},
      },
    },
    <String, dynamic>{'audio': true, 'video': true},
  ];
}

LocalMediaCaptureResolution resolveLocalMediaCapture({
  required bool videoRequested,
  required int audioTrackCount,
  required int videoTrackCount,
}) {
  if (!videoRequested) {
    return const LocalMediaCaptureResolution(
      acceptsStream: true,
      localVideoAvailable: false,
      retryNextCandidate: false,
    );
  }

  if (videoTrackCount > 0) {
    return const LocalMediaCaptureResolution(
      acceptsStream: true,
      localVideoAvailable: true,
      retryNextCandidate: false,
    );
  }

  if (audioTrackCount > 0) {
    return const LocalMediaCaptureResolution(
      acceptsStream: true,
      localVideoAvailable: false,
      retryNextCandidate: false,
    );
  }

  return const LocalMediaCaptureResolution(
    acceptsStream: false,
    localVideoAvailable: false,
    retryNextCandidate: true,
  );
}

bool shouldAddRecvOnlyVideoTransceiver({
  required bool enableVideo,
  required bool localVideoAvailable,
}) {
  return enableVideo && !localVideoAvailable;
}

bool shouldContinueRoomSetup({
  required CallRoom? currentRoom,
  required String roomId,
  required CallSessionState storeState,
}) {
  return currentRoom != null &&
      currentRoom.roomId == roomId &&
      storeState.roomId == roomId &&
      storeState.isActive;
}

CallState resolveAcceptedIncomingUiState(CallState currentState) {
  return currentState == CallState.connected
      ? CallState.connected
      : CallState.ringing;
}

class BufferedRemoteSignalQueue {
  final Map<String, List<_BufferedRemoteSignal>> _eventsByRoom =
      <String, List<_BufferedRemoteSignal>>{};
  int _nextSequence = 0;

  void add(RemoteSignalCallEvent event) {
    final roomId = event.roomId.trim();
    if (roomId.isEmpty) {
      return;
    }
    _eventsByRoom
        .putIfAbsent(roomId, () => <_BufferedRemoteSignal>[])
        .add(_BufferedRemoteSignal(sequence: _nextSequence++, event: event));
  }

  List<RemoteSignalCallEvent> take(String roomId) {
    final buffered =
        _eventsByRoom.remove(roomId.trim()) ?? <_BufferedRemoteSignal>[];
    buffered.sort((left, right) {
      final priority = _priority(
        left.event.signalType,
      ).compareTo(_priority(right.event.signalType));
      if (priority != 0) {
        return priority;
      }
      return left.sequence.compareTo(right.sequence);
    });
    return buffered.map((item) => item.event).toList();
  }

  void clear(String roomId) {
    _eventsByRoom.remove(roomId.trim());
  }

  int _priority(CallSignalType signalType) {
    return switch (signalType) {
      CallSignalType.offer => 0,
      CallSignalType.answer => 1,
      CallSignalType.hangup => 2,
      CallSignalType.control => 3,
      CallSignalType.iceCandidate => 4,
    };
  }
}

class _BufferedRemoteSignal {
  const _BufferedRemoteSignal({required this.sequence, required this.event});

  final int sequence;
  final RemoteSignalCallEvent event;
}

class SignalRecoveryLoop {
  SignalRecoveryLoop({
    required CallStore callStore,
    required SignalFetcher fetchSignals,
    required bool Function(RemoteSignalCallEvent event) applyRemoteSignal,
    required String Function() currentUidReader,
    this.degradedThreshold = const Duration(seconds: 4),
    List<Duration> backoffSchedule = const <Duration>[
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
    Future<void> Function(Duration delay)? delay,
  }) : _callStore = callStore,
       _fetchSignals = fetchSignals,
       _applyRemoteSignal = applyRemoteSignal,
       _currentUidReader = currentUidReader,
       _delay = delay ?? Future<void>.delayed,
       backoffSchedule = _validatedSignalBackoffSchedule(backoffSchedule);

  final CallStore _callStore;
  final SignalFetcher _fetchSignals;
  final bool Function(RemoteSignalCallEvent event) _applyRemoteSignal;
  final String Function() _currentUidReader;
  final Future<void> Function(Duration delay) _delay;
  final Duration degradedThreshold;
  final List<Duration> backoffSchedule;

  final Map<String, Set<String>> _seenSignals = <String, Set<String>>{};

  bool _started = false;
  bool _isForeground = true;
  int _attempt = 0;
  int _generation = 0;
  int? _runningGeneration;
  String? _trackedRoomId;
  bool Function(Duration threshold)? _isGatewayDegradedFor;

  bool get shouldPoll {
    return _started &&
        _isForeground &&
        _callStore.state.isActive &&
        _callStore.state.roomId.isNotEmpty &&
        _currentUidReader().isNotEmpty &&
        (_isGatewayDegradedFor?.call(degradedThreshold) ?? false);
  }

  void start() {
    _started = true;
    notifyStateChanged();
  }

  void stop() {
    _started = false;
    _attempt = 0;
    _generation++;
    _clearTrackedRoom();
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
      _generation++;
    }
  }

  void setGatewayDegradationReader(bool Function(Duration threshold) reader) {
    _isGatewayDegradedFor = reader;
    _attempt = 0;
    _ensureLoop();
  }

  void notifyStateChanged() {
    final roomId = _callStore.state.roomId;
    if (_trackedRoomId != roomId) {
      _clearTrackedRoom();
      _trackedRoomId = roomId.isEmpty ? null : roomId;
      _attempt = 0;
    }
    if (shouldPoll) {
      _ensureLoop();
      return;
    }
    _attempt = 0;
    _generation++;
  }

  void recordLiveSignal(RemoteSignalCallEvent event) {
    final roomId = event.roomId.trim();
    if (roomId.isEmpty) {
      return;
    }
    _seenSignals
        .putIfAbsent(roomId, () => <String>{})
        .add(
          _eventKey(
            roomId: roomId,
            fromUid: event.fromUid,
            signalType: event.signalType,
            payload: event.payload,
          ),
        );
  }

  Future<int> syncOnce() async {
    if (!shouldPoll) {
      return 0;
    }

    final roomId = _callStore.state.roomId;
    final currentUid = _currentUidReader();
    if (roomId.isEmpty || currentUid.isEmpty) {
      return 0;
    }

    final signals = await _fetchSignals(roomId, fallback: true);
    final seen = _seenSignals.putIfAbsent(roomId, () => <String>{});
    var accepted = 0;
    for (final signal in signals) {
      final fromUid = signal.fromUid.trim();
      if (fromUid.isEmpty || fromUid == currentUid) {
        continue;
      }
      final key = _eventKey(
        roomId: roomId,
        fromUid: fromUid,
        signalType: signal.signalType,
        payload: signal.payload,
      );
      if (!seen.add(key)) {
        continue;
      }
      final event = RemoteSignalCallEvent(
        roomId: roomId,
        fromUid: fromUid,
        signalType: signal.signalType,
        payload: Map<String, dynamic>.from(signal.payload),
      );
      if (_applyRemoteSignal(event)) {
        accepted++;
      }
    }
    return accepted;
  }

  void _ensureLoop() {
    if (!shouldPoll || _runningGeneration != null) {
      return;
    }
    final generation = ++_generation;
    _runningGeneration = generation;
    unawaited(_run(generation));
  }

  Future<void> _run(int generation) async {
    try {
      while (generation == _generation && shouldPoll) {
        try {
          await syncOnce();
          if (!shouldPoll) {
            break;
          }
        } catch (error, stackTrace) {
          debugPrint('Signal fallback poll failed: $error');
          debugPrint('$stackTrace');
          if (!shouldPoll) {
            break;
          }
        }

        final delay = backoffSchedule[_attempt];
        if (_attempt < backoffSchedule.length - 1) {
          _attempt++;
        }
        await _delay(delay);
      }
    } finally {
      if (_runningGeneration == generation) {
        _runningGeneration = null;
      }
      if (shouldPoll) {
        _ensureLoop();
      }
    }
  }

  void _clearTrackedRoom() {
    final roomId = _trackedRoomId;
    if (roomId == null) {
      return;
    }
    _seenSignals.remove(roomId);
    _trackedRoomId = null;
  }

  String _eventKey({
    required String roomId,
    required String fromUid,
    required CallSignalType signalType,
    required Map<String, dynamic> payload,
  }) {
    return '$roomId|$fromUid|${signalType.value}|${jsonEncode(payload)}';
  }
}

class VideoCallService with WidgetsBindingObserver {
  VideoCallService({
    CallStore? callStore,
    SignalFetcher? fetchSignals,
    String Function()? currentUidReader,
    SignalRecoveryLoop? signalRecoveryLoop,
    CallSessionOrchestrator? callSessionOrchestrator,
    CallConversationRecordService? conversationRecordService,
  }) : _callStore = callStore ?? sharedCallStore,
       _currentUidReader = currentUidReader ?? _defaultCurrentUidReader,
       _conversationRecordService =
           conversationRecordService ?? CallConversationRecordService.instance,
       _callSessionOrchestrator = callSessionOrchestrator,
       _useOrchestratorForDirectCalls = callSessionOrchestrator != null,
       _signalRecoveryLoop =
           signalRecoveryLoop ??
           SignalRecoveryLoop(
             callStore: callStore ?? sharedCallStore,
             fetchSignals: fetchSignals ?? _defaultSignalFetcher,
             applyRemoteSignal: (event) =>
                 (callStore ?? sharedCallStore).apply(event),
             currentUidReader: currentUidReader ?? _defaultCurrentUidReader,
           ) {
    WidgetsBinding.instance.addObserver(this);
    _eventSubscription = _callStore.events.listen(_handleCallEvent);
    _stateSubscription = _callStore.stream.listen(_handleCallState);
    _bindCallSessionOrchestrator(_callSessionOrchestrator);
    _signalRecoveryLoop.setForeground(_isForeground);
    _signalRecoveryLoop.start();
  }

  static final VideoCallService _instance = VideoCallService();
  static VideoCallService get instance => _instance;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final CallApi _callApi = CallApi.instance;
  final CallHistoryService _historyService = CallHistoryService.instance;
  final CallStore _callStore;
  final String Function() _currentUidReader;
  final CallConversationRecordService _conversationRecordService;
  final SignalRecoveryLoop _signalRecoveryLoop;
  CallSessionOrchestrator? _callSessionOrchestrator;
  final bool _useOrchestratorForDirectCalls;
  final BufferedRemoteSignalQueue _bufferedSignals =
      BufferedRemoteSignalQueue();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  StreamSubscription<CallEvent>? _eventSubscription;
  StreamSubscription<CallSessionState>? _stateSubscription;
  StreamSubscription<CallSessionState>? _callSessionStateSubscription;

  CallRoom? _currentRoom;
  String? _currentChannelId;
  int _currentChannelType = WKChannelType.personal;
  bool _callEnded = false;
  bool _wasConnected = false;
  bool _hasRemoteDescription = false;
  bool _renderersInitialized = false;
  bool _localVideoAvailable = false;
  bool _isForeground = true;
  bool _hasPendingSetup = false;
  bool _sessionManagedCallActive = false;
  int _setupGeneration = 0;
  CallState _reportedState = CallState.idle;
  void Function(CallState state)? _onStateChanged;
  void Function(String streamId)? _onRemoteStream;

  RTCVideoRenderer get localRenderer => _localRenderer;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get renderersInitialized => _renderersInitialized;
  bool get localVideoAvailable => _localVideoAvailable;
  bool get hasActiveCallOrPendingSetup =>
      _currentRoom != null ||
      _hasPendingSetup ||
      (_callSessionOrchestrator?.state.isActive ?? false);

  void _bindCallSessionOrchestrator(CallSessionOrchestrator? orchestrator) {
    _callSessionStateSubscription?.cancel();
    _callSessionStateSubscription = orchestrator?.stream.listen(
      _handleSessionOrchestratorState,
    );
  }

  CallSessionOrchestrator _ensureCallSessionOrchestrator() {
    final existing = _callSessionOrchestrator;
    if (existing != null) {
      return existing;
    }
    final orchestrator = createDefaultCallSessionOrchestrator(
      store: _callStore,
    );
    _callSessionOrchestrator = orchestrator;
    _bindCallSessionOrchestrator(orchestrator);
    return orchestrator;
  }

  bool _shouldUseSessionOrchestratorForRoom(CallRoom room) {
    if (_useOrchestratorForDirectCalls) {
      return true;
    }
    if (room.participants.isNotEmpty) {
      return true;
    }
    if ((room.channelId ?? '').trim().isNotEmpty) {
      return true;
    }
    return (room.channelType ?? WKChannelType.personal) !=
        WKChannelType.personal;
  }

  void setGatewayDegradationReader(bool Function(Duration threshold) reader) {
    _signalRecoveryLoop.setGatewayDegradationReader(reader);
  }

  Future<void> initialize() async {
    if (_renderersInitialized) {
      return;
    }
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _localRenderer.onFirstFrameRendered = () {
      _logMedia(
        'local renderer first frame '
        'renderVideo=${_localRenderer.renderVideo} '
        'width=${_localRenderer.videoWidth} '
        'height=${_localRenderer.videoHeight}',
      );
    };
    _localRenderer.onResize = () {
      _logMedia(
        'local renderer resize '
        'renderVideo=${_localRenderer.renderVideo} '
        'width=${_localRenderer.videoWidth} '
        'height=${_localRenderer.videoHeight}',
      );
    };
    _remoteRenderer.onFirstFrameRendered = () {
      _logMedia(
        'remote renderer first frame '
        'renderVideo=${_remoteRenderer.renderVideo} '
        'width=${_remoteRenderer.videoWidth} '
        'height=${_remoteRenderer.videoHeight}',
      );
    };
    _remoteRenderer.onResize = () {
      _logMedia(
        'remote renderer resize '
        'renderVideo=${_remoteRenderer.renderVideo} '
        'width=${_remoteRenderer.videoWidth} '
        'height=${_remoteRenderer.videoHeight}',
      );
    };
    _renderersInitialized = true;
    _logMedia('renderers initialized');
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    _signalRecoveryLoop.stop();
    await _eventSubscription?.cancel();
    await _stateSubscription?.cancel();
    await _callSessionStateSubscription?.cancel();
    await endCall();
    _clearUiCallbacks();
    if (_renderersInitialized) {
      await _localRenderer.dispose();
      await _remoteRenderer.dispose();
      _renderersInitialized = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_isForeground == isForeground) {
      return;
    }
    _isForeground = isForeground;
    _signalRecoveryLoop.setForeground(isForeground);
  }

  Future<MediaStream> _getUserMedia(bool videoEnabled) async {
    Object? lastError;
    _localVideoAvailable = false;
    final candidates = buildUserMediaConstraintCandidates(
      videoEnabled: videoEnabled,
    );
    for (final constraints in candidates) {
      try {
        _logMedia(
          'request local media enableVideo=$videoEnabled '
          'constraints=${jsonEncode(constraints)}',
        );
        final stream = await navigator.mediaDevices.getUserMedia(constraints);
        final audioTrackCount = stream.getAudioTracks().length;
        final videoTrackCount = stream.getVideoTracks().length;
        final resolution = resolveLocalMediaCapture(
          videoRequested: videoEnabled,
          audioTrackCount: audioTrackCount,
          videoTrackCount: videoTrackCount,
        );
        _logMedia(
          'local media acquired stream=${stream.id} '
          'audioTracks=$audioTrackCount videoTracks=$videoTrackCount',
        );
        if (resolution.acceptsStream) {
          _localVideoAvailable = resolution.localVideoAvailable;
          if (videoEnabled && !_localVideoAvailable) {
            _logMedia(
              'camera unavailable, continuing video call with audio-only '
              'local media and recvonly remote video',
            );
          }
          return stream;
        }
        if (resolution.retryNextCandidate) {
          lastError = StateError(
            'Requested video media but no video track was returned.',
          );
          _logMedia('media stream has no video track, retrying next candidate');
          await stream.dispose();
          continue;
        }
        await stream.dispose();
      } catch (error) {
        lastError = error;
        _logMedia('local media request failed error=$error');
      }
    }

    if (lastError != null) {
      throw StateError(
        videoEnabled
            ? 'Unable to open camera and microphone: $lastError'
            : 'Unable to open microphone: $lastError',
      );
    }
    throw StateError(
      videoEnabled
          ? 'Unable to open camera and microphone.'
          : 'Unable to open microphone.',
    );
  }

  Future<void> startCall({
    required String targetUid,
    required String targetName,
    required CallType callType,
    required Function(CallState) onStateChanged,
    required Function(String) onRemoteStream,
  }) async {
    final callSessionOrchestrator = _callSessionOrchestrator;
    if (_useOrchestratorForDirectCalls && callSessionOrchestrator != null) {
      _sessionManagedCallActive = true;
      _bindUiCallbacks(
        onStateChanged: onStateChanged,
        onRemoteStream: onRemoteStream,
      );
      _reportedState = CallState.idle;
      await callSessionOrchestrator.startOutgoing(
        calleeUid: targetUid,
        calleeName: targetName,
        callType: callType,
      );
      _emitSessionState(callSessionOrchestrator.state);
      return;
    }

    final setupToken = _beginSetupAttempt();
    String? createdRoomId;
    _bindUiCallbacks(
      onStateChanged: onStateChanged,
      onRemoteStream: onRemoteStream,
    );
    _reportedState = CallState.idle;

    try {
      await initialize();
      _ensureSetupNotCanceled(setupToken);
      final room = await _callApi.createRoom(
        calleeUid: targetUid,
        calleeName: targetName,
        callType: callType,
      );
      createdRoomId = room.roomId;
      _ensureSetupNotCanceled(setupToken);
      _adoptRoom(room, channelId: targetUid);
      _callStore.apply(
        CallEvent.localDial(
          roomId: room.roomId,
          peerUid: targetUid,
          peerName: targetName,
          callType: callType,
        ),
      );
      _signalRecoveryLoop.notifyStateChanged();
      _ensureRoomSetupStillActive(setupToken, room.roomId);

      await _historyService.recordOutgoingStarted(
        room: room,
        channelId: targetUid,
        channelName: targetName,
      );
      _ensureRoomSetupStillActive(setupToken, room.roomId);

      await _setupPeerConnection(enableVideo: callType == CallType.video);
      _ensureRoomSetupStillActive(setupToken, room.roomId);
      await _drainBufferedSignals(room.roomId);
      _ensureRoomSetupStillActive(setupToken, room.roomId);

      _emitState(CallState.calling);

      final offer = await _peerConnection!.createOffer();
      _ensureRoomSetupStillActive(setupToken, room.roomId);
      await _peerConnection!.setLocalDescription(offer);
      await _sendSignal(CallSignalType.offer, <String, dynamic>{
        'sdp': offer.sdp,
        'type': offer.type,
        'call_type': callType.value,
        'target_uid': targetUid,
      });
      _emitState(CallState.ringing);
    } catch (error) {
      await _recoverFailedStart(roomId: createdRoomId, cancelServerRoom: true);
      rethrow;
    }
  }

  Future<void> startGroupCall({
    required String channelId,
    required int channelType,
    required String channelName,
    required List<CallParticipant> participants,
    required CallType callType,
    required Function(CallState) onStateChanged,
    required Function(String) onRemoteStream,
  }) async {
    final orchestrator = _ensureCallSessionOrchestrator();
    _sessionManagedCallActive = true;
    _bindUiCallbacks(
      onStateChanged: onStateChanged,
      onRemoteStream: onRemoteStream,
    );
    _reportedState = CallState.idle;
    await orchestrator.startGroupOutgoing(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      participants: participants,
      callType: callType,
    );
    _emitSessionState(orchestrator.state);
  }

  Future<void> acceptIncomingCall({
    required CallRoom room,
    required CallType callType,
    required Function(CallState) onStateChanged,
    required Function(String) onRemoteStream,
  }) async {
    final shouldUseSessionOrchestrator = _shouldUseSessionOrchestratorForRoom(
      room,
    );
    final callSessionOrchestrator = shouldUseSessionOrchestrator
        ? _ensureCallSessionOrchestrator()
        : null;
    if (callSessionOrchestrator != null) {
      _sessionManagedCallActive = true;
      _bindUiCallbacks(
        onStateChanged: onStateChanged,
        onRemoteStream: onRemoteStream,
      );
      _reportedState = CallState.idle;
      await callSessionOrchestrator.acceptIncoming(room: room);
      _emitSessionState(callSessionOrchestrator.state);
      return;
    }

    final setupToken = _beginSetupAttempt();
    _adoptRoom(room, channelId: room.callerUid);
    final accepted = _callStore.apply(
      CallEvent.localAccept(roomId: room.roomId),
    );
    _signalRecoveryLoop.notifyStateChanged();
    if (!accepted) {
      _releaseActiveRoom();
      throw StateError('Call session is no longer active.');
    }

    _bindUiCallbacks(
      onStateChanged: onStateChanged,
      onRemoteStream: onRemoteStream,
    );
    _reportedState = CallState.idle;

    try {
      await initialize();
      _ensureRoomSetupStillActive(setupToken, room.roomId);
      await _historyService.recordIncomingRinging(
        room: room,
        channelId: room.callerUid,
        channelName: _resolveDisplayName(room.callerName, room.callerUid),
      );
      _ensureRoomSetupStillActive(setupToken, room.roomId);

      await _setupPeerConnection(enableVideo: callType == CallType.video);
      _ensureRoomSetupStillActive(setupToken, room.roomId);
      await _drainBufferedSignals(room.roomId);
      _ensureRoomSetupStillActive(setupToken, room.roomId);

      _emitState(resolveAcceptedIncomingUiState(_reportedState));
    } catch (error) {
      await _recoverFailedStart(roomId: room.roomId, cancelServerRoom: false);
      rethrow;
    }
  }

  Future<void> rejectIncomingCall(CallRoom room) async {
    _cancelPendingSetup();
    _adoptRoom(room, channelId: room.callerUid);
    _callStore.apply(CallEvent.localHangup(roomId: room.roomId));
    _signalRecoveryLoop.notifyStateChanged();

    try {
      await _historyService.recordIncomingRinging(
        room: room,
        channelId: room.callerUid,
        channelName: _resolveDisplayName(room.callerName, room.callerUid),
      );
      await _sendSignal(CallSignalType.hangup, const <String, dynamic>{
        'reason': 'reject',
      });
      await _callApi.updateStatus(
        roomId: room.roomId,
        status: CallRoomStatus.canceled,
      );
      await _historyService.markRejected(room.roomId);
      await _recordConversationSummary(status: CallHistoryStatus.rejected);
    } finally {
      _bufferedSignals.clear(room.roomId);
      await _closeRtcResources();
      _releaseActiveRoom();
      _emitState(CallState.ended);
      _resetStoreIfMatches(room.roomId);
      _clearUiCallbacks();
    }
  }

  Future<void> _setupPeerConnection({required bool enableVideo}) async {
    _localStream?.dispose();
    _localStream = await _getUserMedia(enableVideo);
    _localRenderer.srcObject = _localStream;
    _logMedia(
      'local renderer bound stream=${_localStream?.id} '
      'renderVideo=${_localRenderer.renderVideo} '
      'width=${_localRenderer.videoWidth} '
      'height=${_localRenderer.videoHeight}',
    );
    _hasRemoteDescription = false;

    _peerConnection?.close();
    _peerConnection = await createPeerConnection(<String, dynamic>{
      'iceServers': <Map<String, String>>[
        <String, String>{'urls': 'stun:stun.l.google.com:19302'},
        <String, String>{'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });

    for (final track in _localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, _localStream!);
    }
    if (shouldAddRecvOnlyVideoTransceiver(
      enableVideo: enableVideo,
      localVideoAvailable: _localVideoAvailable,
    )) {
      try {
        await _peerConnection!.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );
        _logMedia(
          'added recvonly video transceiver because local camera is unavailable',
        );
      } catch (error) {
        _logMedia('failed to add recvonly video transceiver error=$error');
      }
    }

    try {
      await setSpeakerEnabled(true);
    } catch (_) {
      // Best-effort route alignment for the page's default speaker state.
    }

    _peerConnection!.onIceCandidate = (candidate) async {
      await _sendSignal(CallSignalType.iceCandidate, <String, dynamic>{
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'candidate': candidate.candidate,
      });
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isEmpty) {
        return;
      }
      _remoteRenderer.srcObject = event.streams.first;
      _logMedia(
        'remote renderer bound stream=${event.streams.first.id} '
        'renderVideo=${_remoteRenderer.renderVideo} '
        'width=${_remoteRenderer.videoWidth} '
        'height=${_remoteRenderer.videoHeight}',
      );
      _onRemoteStream?.call(event.streams.first.id);
      _emitState(CallState.connected);
      fireAndForgetCall(
        _markConnectedHistory,
        debugLabel: 'mark connected history from remote track',
      );
    };

    _peerConnection!.onIceConnectionState = (state) {
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        fireAndForgetCall(
          _handleTransportFailure,
          debugLabel: 'handle rtc transport failure',
        );
      }
    };
  }

  Future<void> _handleCallEvent(CallEvent event) async {
    if (event is RemoteSignalCallEvent) {
      _signalRecoveryLoop.recordLiveSignal(event);
      if (event.fromUid == _currentUidReader()) {
        return;
      }
      if (_currentRoom == null || _currentRoom!.roomId != event.roomId) {
        if (event.signalType != CallSignalType.hangup) {
          _bufferedSignals.add(event);
        }
        return;
      }
      if (_shouldBufferSignal(event)) {
        _bufferedSignals.add(event);
        return;
      }
      await _processRemoteSignal(event);
      return;
    }

    if (event is RemoteStateCallEvent) {
      if (_currentRoom == null || _currentRoom!.roomId != event.roomId) {
        return;
      }
      switch (event.status) {
        case CallRoomStatus.pending:
        case CallRoomStatus.ringing:
          _emitState(CallState.ringing);
        case CallRoomStatus.connected:
          _emitState(CallState.connected);
          await _markConnectedHistory();
        case CallRoomStatus.ended:
        case CallRoomStatus.canceled:
          await _handleRemoteTermination();
      }
    }
  }

  void _handleCallState(CallSessionState state) {
    _signalRecoveryLoop.notifyStateChanged();
    final room = _currentRoom;
    if (room == null || state.roomId != room.roomId) {
      return;
    }

    switch (state.status) {
      case CallLifecycleStatus.invited:
      case CallLifecycleStatus.ringing:
        _emitState(CallState.ringing);
      case CallLifecycleStatus.connecting:
      case CallLifecycleStatus.reconnecting:
        _emitState(CallState.calling);
      case CallLifecycleStatus.connected:
        _emitState(CallState.connected);
        fireAndForgetCall(
          _markConnectedHistory,
          debugLabel: 'mark connected history from call state',
        );
      case CallLifecycleStatus.ending:
      case CallLifecycleStatus.ended:
      case CallLifecycleStatus.failed:
      case CallLifecycleStatus.idle:
        break;
    }
  }

  void _handleSessionOrchestratorState(CallSessionState state) {
    if (!state.isActive) {
      _sessionManagedCallActive = false;
    }
    _emitSessionState(state);
  }

  Future<void> _handleRemoteOffer(RemoteSignalCallEvent signal) async {
    final sdp = signal.payload['sdp']?.toString();
    if (sdp == null || _peerConnection == null) {
      return;
    }
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, signal.payload['type']?.toString() ?? 'offer'),
    );
    _hasRemoteDescription = true;
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    await _sendSignal(CallSignalType.answer, <String, dynamic>{
      'sdp': answer.sdp,
      'type': answer.type,
    });
    _emitState(CallState.connected);
    await _markConnectedHistory();
    await _drainBufferedSignals(signal.roomId);
  }

  Future<void> _handleRemoteAnswer(RemoteSignalCallEvent signal) async {
    final sdp = signal.payload['sdp']?.toString();
    if (sdp == null || _peerConnection == null) {
      return;
    }
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(
        sdp,
        signal.payload['type']?.toString() ?? 'answer',
      ),
    );
    _hasRemoteDescription = true;
    await _drainBufferedSignals(signal.roomId);
  }

  Future<void> _handleRemoteCandidate(RemoteSignalCallEvent signal) async {
    final candidate = signal.payload['candidate']?.toString();
    if (candidate == null || _peerConnection == null) {
      return;
    }
    final rtcCandidate = RTCIceCandidate(
      candidate,
      signal.payload['sdpMid']?.toString(),
      signal.payload['sdpMLineIndex'] is int
          ? signal.payload['sdpMLineIndex'] as int
          : int.tryParse(signal.payload['sdpMLineIndex']?.toString() ?? ''),
    );
    await _peerConnection!.addCandidate(rtcCandidate);
  }

  Future<void> toggleMute(bool mute) async {
    final callSessionOrchestrator = _callSessionOrchestrator;
    if (_sessionManagedCallActive && callSessionOrchestrator != null) {
      await callSessionOrchestrator.setMicrophoneEnabled(!mute);
      return;
    }
    if (_localStream == null) {
      return;
    }
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !mute;
    }
  }

  Future<void> toggleCamera(bool enabled) async {
    final callSessionOrchestrator = _callSessionOrchestrator;
    if (_sessionManagedCallActive && callSessionOrchestrator != null) {
      await callSessionOrchestrator.setCameraEnabled(enabled);
      return;
    }
    if (_localStream == null) {
      return;
    }
    for (final track in _localStream!.getVideoTracks()) {
      track.enabled = enabled;
    }
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    if (!supportsSpeakerphoneRouting()) {
      return;
    }
    await Helper.setSpeakerphoneOn(enabled);
  }

  Future<void> switchCamera() async {
    if (_localStream == null) {
      return;
    }
    final tracks = _localStream!.getVideoTracks();
    if (tracks.isEmpty) {
      return;
    }
    await Helper.switchCamera(tracks.first);
  }

  Future<void> endCall({bool remote = false}) async {
    final callSessionOrchestrator = _callSessionOrchestrator;
    if (_sessionManagedCallActive && callSessionOrchestrator != null) {
      await callSessionOrchestrator.disconnect();
      _sessionManagedCallActive = false;
      _releaseActiveRoom();
      _emitState(CallState.ended);
      _clearUiCallbacks();
      return;
    }

    _cancelPendingSetup();
    final room = _currentRoom;
    if (_callEnded || room == null) {
      return;
    }
    _callEnded = true;

    if (!remote) {
      _callStore.apply(CallEvent.localHangup(roomId: room.roomId));
      _signalRecoveryLoop.notifyStateChanged();
    }

    try {
      if (!remote) {
        await _sendSignal(CallSignalType.hangup, const <String, dynamic>{
          'reason': 'local',
        });
        await _callApi.updateStatus(
          roomId: room.roomId,
          status: CallRoomStatus.ended,
        );
      }

      if (remote) {
        await _historyService.markRemoteEnded(room.roomId);
        await _recordConversationSummary(status: _resolveRemoteEndStatus(room));
      } else if (_wasConnected) {
        await _historyService.markCompleted(room.roomId);
        await _recordConversationSummary(status: CallHistoryStatus.completed);
      } else {
        await _historyService.markCanceled(room.roomId);
        await _recordConversationSummary(status: CallHistoryStatus.canceled);
      }
    } finally {
      _bufferedSignals.clear(room.roomId);
      await _closeRtcResources();
      _releaseActiveRoom();
      _emitState(CallState.ended);
      if (!remote) {
        _resetStoreIfMatches(room.roomId);
      }
      _clearUiCallbacks();
    }
  }

  Future<void> _handleRemoteTermination() async {
    final room = _currentRoom;
    if (_callEnded || room == null) {
      return;
    }
    _callEnded = true;
    _cancelPendingSetup();
    try {
      await _historyService.markRemoteEnded(room.roomId);
      await _recordConversationSummary(status: _resolveRemoteEndStatus(room));
    } finally {
      _bufferedSignals.clear(room.roomId);
      await _closeRtcResources();
      _releaseActiveRoom();
      _emitState(CallState.ended);
      _clearUiCallbacks();
    }
  }

  Future<void> _handleTransportFailure() async {
    final room = _currentRoom;
    if (_callEnded || room == null) {
      return;
    }
    _callEnded = true;
    _cancelPendingSetup();
    try {
      await _historyService.markRemoteEnded(room.roomId);
      await _recordConversationSummary(status: _resolveRemoteEndStatus(room));
    } finally {
      _bufferedSignals.clear(room.roomId);
      await _closeRtcResources();
      _releaseActiveRoom();
      _emitState(CallState.ended);
      _resetStoreIfMatches(room.roomId);
      _clearUiCallbacks();
    }
  }

  Future<void> _recoverFailedStart({
    required String? roomId,
    required bool cancelServerRoom,
  }) async {
    final normalizedRoomId = roomId?.trim() ?? '';
    if (cancelServerRoom && normalizedRoomId.isNotEmpty) {
      try {
        await _callApi.updateStatus(
          roomId: normalizedRoomId,
          status: CallRoomStatus.canceled,
        );
      } catch (_) {
        // ignored
      }
    }
    final failedRoom = _currentRoom;
    if (failedRoom != null &&
        normalizedRoomId.isNotEmpty &&
        failedRoom.roomId == normalizedRoomId) {
      final failedStatus = _resolveFailedStartStatus(failedRoom);
      try {
        switch (failedStatus) {
          case CallHistoryStatus.canceled:
            await _historyService.markCanceled(failedRoom.roomId);
          case CallHistoryStatus.missed:
            await _historyService.markMissed(failedRoom.roomId);
          case CallHistoryStatus.rejected:
            await _historyService.markRejected(failedRoom.roomId);
          case CallHistoryStatus.completed:
            await _historyService.markCompleted(failedRoom.roomId);
          case CallHistoryStatus.ringing:
          case CallHistoryStatus.connected:
            break;
        }
      } catch (_) {
        // ignored
      }
      await _recordConversationSummary(status: failedStatus);
    }
    if (normalizedRoomId.isNotEmpty) {
      _bufferedSignals.clear(normalizedRoomId);
    }
    await _closeRtcResources();
    _releaseActiveRoom();
    if (normalizedRoomId.isNotEmpty) {
      _resetStoreIfMatches(normalizedRoomId);
    }
    _clearUiCallbacks();
  }

  Future<void> _sendSignal(
    CallSignalType type,
    Map<String, dynamic> payload,
  ) async {
    final room = _currentRoom;
    if (room == null) {
      return;
    }
    try {
      await _callApi.sendSignal(
        roomId: room.roomId,
        type: type,
        payload: payload,
      );
    } catch (error) {
      debugPrint('Call signal send failed: $error');
    }
  }

  Future<void> _markConnectedHistory() async {
    final room = _currentRoom;
    if (room == null || _wasConnected) {
      return;
    }
    _wasConnected = true;
    await _historyService.markConnected(room.roomId);
  }

  Future<void> _recordConversationSummary({
    required CallHistoryStatus status,
  }) async {
    final room = _currentRoom;
    final channelId = (_currentChannelId ?? '').trim();
    if (room == null || channelId.isEmpty) {
      return;
    }

    try {
      await _conversationRecordService.recordCallSummary(
        roomId: room.roomId,
        channelId: channelId,
        channelType: _currentChannelType,
        channelName: _resolveConversationChannelName(room),
        callType: room.callType,
        direction: _resolveCallDirection(room),
        status: status,
      );
    } catch (error, stackTrace) {
      _logChatRecord('record summary failed error=$error');
      debugPrint('$stackTrace');
    }
  }

  CallHistoryStatus _resolveRemoteEndStatus(CallRoom room) {
    if (_wasConnected) {
      return CallHistoryStatus.completed;
    }
    return _resolveCallDirection(room) == CallDirection.incoming
        ? CallHistoryStatus.missed
        : CallHistoryStatus.canceled;
  }

  CallHistoryStatus _resolveFailedStartStatus(CallRoom room) {
    return _resolveCallDirection(room) == CallDirection.incoming
        ? CallHistoryStatus.missed
        : CallHistoryStatus.canceled;
  }

  CallDirection _resolveCallDirection(CallRoom room) {
    final currentUid = _currentUidReader().trim();
    if (currentUid.isNotEmpty) {
      if (room.callerUid == currentUid) {
        return CallDirection.outgoing;
      }
      if (room.calleeUid == currentUid) {
        return CallDirection.incoming;
      }
    }

    final channelId = (_currentChannelId ?? '').trim();
    if (channelId.isNotEmpty && channelId == room.callerUid) {
      return CallDirection.incoming;
    }
    return CallDirection.outgoing;
  }

  String _resolveConversationChannelName(CallRoom room) {
    if (_currentChannelType != WKChannelType.personal) {
      return _resolveDisplayName(
        room.roomName ?? room.channelId,
        (_currentChannelId ?? '').trim(),
      );
    }

    final direction = _resolveCallDirection(room);
    final fallback = (_currentChannelId ?? '').trim();
    if (direction == CallDirection.outgoing) {
      return _resolveDisplayName(room.calleeName, fallback);
    }
    return _resolveDisplayName(room.callerName, fallback);
  }

  void _logMedia(String message) {
    debugPrint('[call/media] $message');
  }

  void _logChatRecord(String message) {
    debugPrint('[call/chat-record] $message');
  }

  Future<void> _closeRtcResources() async {
    await _peerConnection?.close();
    await _localStream?.dispose();
    _peerConnection = null;
    _localStream = null;
    _localVideoAvailable = false;
    _hasRemoteDescription = false;
    if (_renderersInitialized) {
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    }
  }

  void _adoptRoom(CallRoom room, {required String channelId}) {
    _currentRoom = room;
    _currentChannelId = channelId;
    _currentChannelType =
        room.channelType ??
        (channelId == room.channelId
            ? WKChannelType.group
            : WKChannelType.personal);
    _callEnded = false;
    _hasRemoteDescription = false;
    _hasPendingSetup = false;
    _wasConnected = false;
    ConversationActivityRegistry.instance.setCallingState(
      channelId,
      _currentChannelType,
      true,
    );
  }

  @visibleForTesting
  void debugAdoptRoomForTest(
    CallRoom room, {
    required String channelId,
    bool wasConnected = false,
  }) {
    _adoptRoom(room, channelId: channelId);
    _wasConnected = wasConnected;
  }

  @visibleForTesting
  Future<void> debugRecoverFailedStartForTest({
    required String? roomId,
    required bool cancelServerRoom,
  }) {
    return _recoverFailedStart(
      roomId: roomId,
      cancelServerRoom: cancelServerRoom,
    );
  }

  void _releaseActiveRoom() {
    _cancelPendingSetup();
    final previousChannelId = _currentChannelId;
    final previousChannelType = _currentChannelType;
    final previousRoomId = _currentRoom?.roomId;
    _currentRoom = null;
    _currentChannelId = null;
    _currentChannelType = WKChannelType.personal;
    _callEnded = false;
    _hasRemoteDescription = false;
    _wasConnected = false;
    _signalRecoveryLoop.notifyStateChanged();

    if ((previousRoomId ?? '').trim().isNotEmpty) {
      _bufferedSignals.clear(previousRoomId!);
    }
    if ((previousChannelId ?? '').trim().isNotEmpty) {
      ConversationActivityRegistry.instance.setCallingState(
        previousChannelId!,
        previousChannelType,
        false,
      );
    }
  }

  void _resetStoreIfMatches(String roomId) {
    if (_callStore.state.roomId != roomId) {
      return;
    }
    _callStore.reset();
    _signalRecoveryLoop.notifyStateChanged();
  }

  void _bindUiCallbacks({
    required Function(CallState) onStateChanged,
    required Function(String) onRemoteStream,
  }) {
    _onStateChanged = onStateChanged;
    _onRemoteStream = onRemoteStream;
  }

  void _clearUiCallbacks() {
    _onStateChanged = null;
    _onRemoteStream = null;
  }

  void _emitState(CallState state) {
    if (_reportedState == state) {
      return;
    }
    _reportedState = state;
    _onStateChanged?.call(state);
  }

  void _emitSessionState(CallSessionState state) {
    switch (state.status) {
      case CallLifecycleStatus.invited:
      case CallLifecycleStatus.ringing:
        _emitState(CallState.ringing);
      case CallLifecycleStatus.connecting:
      case CallLifecycleStatus.reconnecting:
        _emitState(CallState.calling);
      case CallLifecycleStatus.connected:
        _emitState(CallState.connected);
      case CallLifecycleStatus.ending:
      case CallLifecycleStatus.ended:
      case CallLifecycleStatus.failed:
        _emitState(CallState.ended);
      case CallLifecycleStatus.idle:
        break;
    }
  }

  int _beginSetupAttempt() {
    _hasPendingSetup = true;
    _setupGeneration++;
    return _setupGeneration;
  }

  void _cancelPendingSetup() {
    _hasPendingSetup = false;
    _setupGeneration++;
  }

  void _ensureSetupNotCanceled(int setupToken) {
    if (setupToken != _setupGeneration) {
      throw StateError('Call session is no longer active.');
    }
  }

  void _ensureRoomSetupStillActive(int setupToken, String roomId) {
    _ensureSetupNotCanceled(setupToken);
    if (!shouldContinueRoomSetup(
      currentRoom: _currentRoom,
      roomId: roomId,
      storeState: _callStore.state,
    )) {
      throw StateError('Call session is no longer active.');
    }
  }

  bool _shouldBufferSignal(RemoteSignalCallEvent event) {
    return switch (event.signalType) {
      CallSignalType.offer || CallSignalType.answer => _peerConnection == null,
      CallSignalType.iceCandidate =>
        _peerConnection == null || !_hasRemoteDescription,
      CallSignalType.hangup || CallSignalType.control => false,
    };
  }

  Future<void> _processRemoteSignal(RemoteSignalCallEvent event) async {
    switch (event.signalType) {
      case CallSignalType.offer:
        await _handleRemoteOffer(event);
      case CallSignalType.answer:
        await _handleRemoteAnswer(event);
      case CallSignalType.iceCandidate:
        await _handleRemoteCandidate(event);
      case CallSignalType.hangup:
        await _handleRemoteTermination();
      case CallSignalType.control:
        break;
    }
  }

  Future<void> _drainBufferedSignals(String roomId) async {
    for (final event in _bufferedSignals.take(roomId)) {
      if (_currentRoom == null || _currentRoom!.roomId != roomId) {
        break;
      }
      if (event.fromUid == _currentUidReader()) {
        continue;
      }
      if (_shouldBufferSignal(event)) {
        _bufferedSignals.add(event);
        continue;
      }
      await _processRemoteSignal(event);
    }
  }

  String _resolveDisplayName(String? rawName, String fallback) {
    final normalized = rawName?.trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }
}
