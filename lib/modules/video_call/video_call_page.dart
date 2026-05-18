import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/models/call.dart';
import '../../service/api/call_api.dart';
import 'multi_value_listenable_rebuilder.dart';
import 'video_call_service.dart';

String resolveCallDisplayTitle({
  required String channelId,
  String? channelName,
}) {
  final normalizedName = channelName?.trim() ?? '';
  if (normalizedName.isNotEmpty) {
    return normalizedName;
  }
  final normalizedId = channelId.trim();
  if (normalizedId.isNotEmpty) {
    return normalizedId;
  }
  return 'Unknown';
}

String resolveCallAvatarLabel(String title) {
  final normalized = title.trim();
  if (normalized.isEmpty) {
    return '?';
  }
  return normalized.substring(0, 1).toUpperCase();
}

bool shouldRenderRemoteVideo({
  required CallType callType,
  required CallState callState,
  required bool renderersInitialized,
}) {
  return callType == CallType.video &&
      callState == CallState.connected &&
      renderersInitialized;
}

bool shouldRenderLocalPreview({
  required CallType callType,
  required bool showIncomingActions,
  required bool renderersInitialized,
}) {
  return callType == CallType.video &&
      !showIncomingActions &&
      renderersInitialized;
}

bool shouldShowLocalCameraPlaceholder({
  required bool isCameraOff,
  required bool localVideoAvailable,
}) {
  return isCameraOff || !localVideoAvailable;
}

bool shouldCloseCallPageForState(CallState state) {
  return state == CallState.ended;
}

bool shouldRequestCallRouteClose({
  required CallState state,
  required bool closeAlreadyRequested,
}) {
  return shouldCloseCallPageForState(state) && !closeAlreadyRequested;
}

class VideoCallPage extends StatefulWidget {
  final String channelId;
  final String? channelName;
  final CallType callType;
  final int channelType;
  final List<CallParticipant> groupParticipants;
  final bool autoStart;
  final bool isIncoming;
  final CallRoom? incomingRoom;

  const VideoCallPage({
    super.key,
    required this.channelId,
    this.channelName,
    required this.callType,
    this.channelType = 1,
    this.groupParticipants = const <CallParticipant>[],
    this.autoStart = true,
    this.isIncoming = false,
    this.incomingRoom,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  final VideoCallService _callService = VideoCallService.instance;
  CallState _callState = CallState.idle;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _incomingAccepted = false;
  bool _shouldReleaseCallOnDispose = true;
  bool _closeRequested = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _initCall();
    }
  }

  Future<void> _initCall() async {
    if (widget.isIncoming) {
      setState(() => _callState = CallState.ringing);
      return;
    }
    await _startCall();
  }

  Future<void> _startCall() async {
    try {
      if (widget.groupParticipants.isNotEmpty) {
        await _callService.startGroupCall(
          channelId: widget.channelId,
          channelType: widget.channelType,
          channelName: widget.channelName ?? widget.channelId,
          participants: widget.groupParticipants,
          callType: widget.callType,
          onStateChanged: _handleCallStateChanged,
          onRemoteStream: (_) {
            if (mounted) {
              setState(() {});
            }
          },
        );
        return;
      }
      await _callService.startCall(
        targetUid: widget.channelId,
        targetName: widget.channelName ?? widget.channelId,
        callType: widget.callType,
        onStateChanged: _handleCallStateChanged,
        onRemoteStream: (_) {
          if (mounted) {
            setState(() {});
          }
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pop<String>(_resolveErrorMessage(error, fallbackMessage: '发起通话失败'));
    }
  }

  Future<void> _acceptIncomingCall() async {
    final room = widget.incomingRoom;
    if (room == null) {
      return;
    }
    setState(() {
      _incomingAccepted = true;
      _callState = CallState.calling;
    });
    try {
      await _callService.acceptIncomingCall(
        room: room,
        callType: widget.callType,
        onStateChanged: _handleCallStateChanged,
        onRemoteStream: (_) {
          if (mounted) {
            setState(() {});
          }
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _incomingAccepted = false;
        _callState = CallState.ringing;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_resolveErrorMessage(error, fallbackMessage: '接听通话失败')),
        ),
      );
    }
  }

  Future<void> _rejectIncomingCall() async {
    final room = widget.incomingRoom;
    _shouldReleaseCallOnDispose = false;
    try {
      if (room != null) {
        await _callService.rejectIncomingCall(room);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _resolveErrorMessage(
                error,
                fallbackMessage: 'Reject call failed',
              ),
            ),
          ),
        );
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleCallStateChanged(CallState state) {
    if (!mounted) {
      return;
    }
    setState(() => _callState = state);
    if (shouldRequestCallRouteClose(
      state: state,
      closeAlreadyRequested: _closeRequested,
    )) {
      _requestCloseCallRoute();
    }
  }

  Future<void> _endCall() async {
    _shouldReleaseCallOnDispose = false;
    try {
      await _callService.endCall();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _resolveErrorMessage(error, fallbackMessage: 'End call failed'),
            ),
          ),
        );
      }
    }
    if (mounted && !_closeRequested) {
      _requestCloseCallRoute();
    }
  }

  void _requestCloseCallRoute() {
    if (_closeRequested) {
      return;
    }
    _closeRequested = true;
    _shouldReleaseCallOnDispose = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) {
        return;
      }
      Navigator.of(context).maybePop();
    });
  }

  void _toggleMute() {
    final next = !_isMuted;
    setState(() => _isMuted = next);
    fireAndForgetCall(
      () => _callService.toggleMute(next),
      debugLabel: 'toggle mute',
    );
  }

  void _toggleCamera() {
    final next = !_isCameraOff;
    setState(() => _isCameraOff = next);
    fireAndForgetCall(
      () => _callService.toggleCamera(!next),
      debugLabel: 'toggle camera',
    );
  }

  void _toggleSpeaker() {
    final next = !_isSpeakerOn;
    setState(() => _isSpeakerOn = next);
    fireAndForgetCall(() async {
      try {
        await _callService.setSpeakerEnabled(next);
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() => _isSpeakerOn = !next);
        rethrow;
      }
    }, debugLabel: 'toggle speaker');
  }

  void _switchCamera() {
    fireAndForgetCall(_callService.switchCamera, debugLabel: 'switch camera');
  }

  @override
  void dispose() {
    if (_shouldReleaseCallOnDispose &&
        _callState != CallState.ended &&
        (!widget.isIncoming || _incomingAccepted)) {
      fireAndForgetCall(
        _callService.endCall,
        debugLabel: 'release call on page dispose',
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = resolveCallDisplayTitle(
      channelId: widget.channelId,
      channelName: widget.channelName,
    );
    final showIncomingActions = widget.isIncoming && !_incomingAccepted;
    final showRemoteVideo = shouldRenderRemoteVideo(
      callType: widget.callType,
      callState: _callState,
      renderersInitialized: _callService.renderersInitialized,
    );
    final showLocalPreview = shouldRenderLocalPreview(
      callType: widget.callType,
      showIncomingActions: showIncomingActions,
      renderersInitialized: _callService.renderersInitialized,
    );
    final showLocalCameraPlaceholder = shouldShowLocalCameraPlaceholder(
      isCameraOff: _isCameraOff,
      localVideoAvailable: _callService.localVideoAvailable,
    );

    return MultiValueListenableRebuilder(
      listenables: <Listenable>[
        _callService.localRenderer,
        _callService.remoteRenderer,
      ],
      builder: (context) => PopScope<void>(
        canPop: !showIncomingActions,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop || !showIncomingActions) {
            return;
          }
          await _rejectIncomingCall();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                if (showRemoteVideo)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: RTCVideoView(
                        _callService.remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF1A1A2E),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.blue[700],
                              child: Text(
                                resolveCallAvatarLabel(title),
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getStateText(),
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (showLocalPreview)
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      width: 100,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: RepaintBoundary(
                        child: showLocalCameraPlaceholder
                            ? Container(
                                color: Colors.grey[800],
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.videocam_off,
                                        color: Colors.white54,
                                        size: 32,
                                      ),
                                      if (!_callService.localVideoAvailable)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: Text(
                                            '摄像头不可用',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              )
                            : RTCVideoView(
                                _callService.localRenderer,
                                mirror: true,
                                objectFit: RTCVideoViewObjectFit
                                    .RTCVideoViewObjectFitCover,
                              ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: showIncomingActions
                        ? _rejectIncomingCall
                        : _endCall,
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: showIncomingActions
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ControlButton(
                              icon: Icons.call_end,
                              label: '拒绝',
                              isDestructive: true,
                              onTap: _rejectIncomingCall,
                            ),
                            _ControlButton(
                              icon: Icons.call,
                              label: '接听',
                              isActive: true,
                              onTap: _acceptIncomingCall,
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ControlButton(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              label: _isMuted ? '取消静音' : '静音',
                              isActive: _isMuted,
                              onTap: _toggleMute,
                            ),
                            if (widget.callType == CallType.video)
                              _ControlButton(
                                icon: _isCameraOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                label: _isCameraOff ? '打开摄像头' : '关闭摄像头',
                                isActive: _isCameraOff,
                                onTap: _toggleCamera,
                              ),
                            _ControlButton(
                              icon: Icons.call_end,
                              label: '挂断',
                              isDestructive: true,
                              onTap: _endCall,
                            ),
                            if (widget.callType == CallType.video)
                              _ControlButton(
                                icon: Icons.switch_camera,
                                label: '切换摄像头',
                                onTap: _switchCamera,
                              ),
                            _ControlButton(
                              icon: _isSpeakerOn
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              label: _isSpeakerOn ? '扬声器' : '听筒',
                              isActive: _isSpeakerOn,
                              onTap: _toggleSpeaker,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getStateText() {
    switch (_callState) {
      case CallState.calling:
        return '正在连接...';
      case CallState.ringing:
        return widget.isIncoming && !_incomingAccepted ? '来电邀请' : '等待对方接听...';
      case CallState.connected:
        return '通话中';
      case CallState.ended:
        return '通话已结束';
      default:
        return '准备中...';
    }
  }

  String _resolveErrorMessage(Object error, {required String fallbackMessage}) {
    final message = switch (error) {
      CallApiException(:final message) => message,
      _ => error.toString(),
    };
    final normalized = message
        .replaceFirst(RegExp(r'^[A-Za-z]+Exception:\s*'), '')
        .trim();
    return normalized.isEmpty ? fallbackMessage : normalized;
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDestructive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDestructive
                  ? Colors.red
                  : isActive
                  ? Colors.white24
                  : Colors.white12,
            ),
            child: Icon(
              icon,
              color: isDestructive
                  ? Colors.white
                  : (isActive ? Colors.white : Colors.white70),
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
        ],
      ),
    );
  }
}
