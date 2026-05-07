import 'dart:async';
import 'dart:collection';

import '../../realtime/call/call_state_machine.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry.dart';
import '../../service/api/api_client.dart';

class CallTelemetryReporter implements CallTelemetry {
  CallTelemetryReporter({
    this.maxBufferedEvents = 100,
    Future<void> Function(Map<String, dynamic> payload)? transport,
  }) : _transport = transport ?? _defaultTransport;

  final int maxBufferedEvents;
  final Future<void> Function(Map<String, dynamic> payload) _transport;
  final Queue<Map<String, dynamic>> _pending = Queue<Map<String, dynamic>>();
  Future<void> _flushQueue = Future<void>.value();

  int get pendingCount => _pending.length;

  @override
  void recordCallEvent({
    required String roomId,
    required String event,
    required CallLifecycleStatus state,
    CallFailureReason? reason,
    Duration? duration,
    Map<String, dynamic>? stats,
    String? callId,
    String? uid,
  }) {
    final payload = <String, dynamic>{
      'room_id': roomId,
      if (callId != null && callId.trim().isNotEmpty) 'call_id': callId.trim(),
      if (uid != null && uid.trim().isNotEmpty) 'uid': uid.trim(),
      'event': event,
      'state': state.name,
      if (reason != null) 'reason': reason.code,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
      'sdk': 'livekit_client',
      'platform': 'flutter',
      if (stats != null && stats.isNotEmpty)
        'stats': Map<String, dynamic>.from(stats),
    };
    _pending.addLast(payload);
    _trimBuffer();
    unawaited(flush());
  }

  Future<void> flush() {
    _flushQueue = _flushQueue.then((_) async {
      if (_pending.isEmpty) {
        return;
      }
      final payload = _pending.removeFirst();
      try {
        await _transport(payload);
      } catch (_) {
        _pending.addFirst(payload);
        _trimBuffer(keepNewest: false);
      }
    });
    return _flushQueue;
  }

  void _trimBuffer({bool keepNewest = true}) {
    if (maxBufferedEvents <= 0) {
      _pending.clear();
      return;
    }
    while (_pending.length > maxBufferedEvents) {
      if (keepNewest) {
        _pending.removeFirst();
      } else {
        _pending.removeLast();
      }
    }
  }

  static Future<void> _defaultTransport(Map<String, dynamic> payload) async {
    await ApiClient.instance.post('/v1/extra/call/telemetry', data: payload);
  }
}
