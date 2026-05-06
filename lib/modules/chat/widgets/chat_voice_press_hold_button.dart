import 'dart:async';

import 'package:flutter/material.dart';

import '../chat_voice_feedback_service.dart';

class ChatVoicePressHoldButton extends StatefulWidget {
  const ChatVoicePressHoldButton({
    super.key,
    required this.isRecording,
    required this.onHoldStart,
    required this.onCancelZoneChanged,
    required this.onHoldRelease,
    required this.onHoldAbort,
    this.onFeedbackEvent,
    this.cancelTriggerDistance = 72,
  });

  final bool isRecording;
  final Future<void> Function() onHoldStart;
  final ValueChanged<bool> onCancelZoneChanged;
  final Future<void> Function(bool isInCancelZone) onHoldRelease;
  final Future<void> Function() onHoldAbort;
  final ValueChanged<ChatVoiceFeedbackEvent>? onFeedbackEvent;
  final double cancelTriggerDistance;

  @override
  State<ChatVoicePressHoldButton> createState() =>
      _ChatVoicePressHoldButtonState();
}

class _ChatVoicePressHoldButtonState extends State<ChatVoicePressHoldButton> {
  static const double _buttonHeight = 48;
  static const String _cancelTitle = '\u677e\u624b\u53d6\u6d88';
  static const String _sendTitle = '\u677e\u624b\u53d1\u9001';
  static const String _idleTitle = '\u6309\u4f4f\u8bf4\u8bdd';

  Offset? _startGlobalPosition;
  bool _isHolding = false;
  bool _isInCancelZone = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.isRecording && _isHolding;
    final danger = active && _isInCancelZone;

    final titleText = danger
        ? _cancelTitle
        : (active ? _sendTitle : _idleTitle);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: _handleHoldStart,
      onLongPressMoveUpdate: _handleHoldMove,
      onLongPressEnd: _handleHoldEnd,
      onLongPressCancel: _handleHoldAbort,
      child: SizedBox(
        height: _buttonHeight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: danger
                  ? const Color(0xFFFF7E9D)
                  : (active
                        ? scheme.primary.withValues(alpha: 0.8)
                        : scheme.outlineVariant),
            ),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: danger
                  ? const <Color>[Color(0xFF81253B), Color(0xFFB6314F)]
                  : (active
                        ? <Color>[
                            scheme.primaryContainer,
                            scheme.primaryContainer.withValues(alpha: 0.72),
                          ]
                        : <Color>[
                            scheme.surfaceContainerHighest,
                            scheme.surfaceContainerHigh,
                          ]),
            ),
          ),
          child: Text(
            titleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: danger ? const Color(0xFFFFEFF3) : scheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _handleHoldStart(LongPressStartDetails details) {
    _startGlobalPosition = details.globalPosition;
    _setHoldingState(value: true, inCancelZone: false, notify: true);
    unawaited(widget.onHoldStart());
  }

  void _handleHoldMove(LongPressMoveUpdateDetails details) {
    if (!_isHolding) {
      return;
    }
    final start = _startGlobalPosition;
    if (start == null) {
      return;
    }
    final dragUpDistance = start.dy - details.globalPosition.dy;
    final inCancelZone = dragUpDistance >= widget.cancelTriggerDistance;
    if (inCancelZone == _isInCancelZone) {
      return;
    }
    _setHoldingState(
      value: _isHolding,
      inCancelZone: inCancelZone,
      notify: true,
    );
  }

  void _handleHoldEnd(LongPressEndDetails details) {
    if (!_isHolding) {
      return;
    }
    final isInCancelZone = _isInCancelZone;
    _setHoldingState(value: false, inCancelZone: false, notify: false);
    unawaited(widget.onHoldRelease(isInCancelZone));
  }

  void _handleHoldAbort() {
    if (!_isHolding) {
      return;
    }
    _setHoldingState(value: false, inCancelZone: false, notify: false);
    unawaited(widget.onHoldAbort());
  }

  void _setHoldingState({
    required bool value,
    required bool inCancelZone,
    required bool notify,
  }) {
    final zoneChanged = _isInCancelZone != inCancelZone;
    _isHolding = value;
    _isInCancelZone = inCancelZone;

    if (notify && zoneChanged) {
      widget.onCancelZoneChanged(inCancelZone);
      widget.onFeedbackEvent?.call(
        inCancelZone
            ? ChatVoiceFeedbackEvent.enterCancelZone
            : ChatVoiceFeedbackEvent.leaveCancelZone,
      );
    }
    if (mounted) {
      setState(() {});
    }
  }
}
