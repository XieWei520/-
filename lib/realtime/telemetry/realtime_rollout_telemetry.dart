import 'dart:async';

typedef RealtimeTelemetryTransport =
    Future<void> Function(List<RealtimeTelemetryEvent> events);
typedef RealtimeTelemetryClock = DateTime Function();

class RealtimeTelemetryEvent {
  RealtimeTelemetryEvent({
    required this.name,
    required num value,
    DateTime? recordedAt,
    this.sessionId,
    Map<String, String>? tags,
  }) : value = value.round(),
       recordedAt = (recordedAt ?? DateTime.now()).toUtc(),
       tags = Map<String, String>.unmodifiable(
         tags ?? const <String, String>{},
       );

  final String name;
  final int value;
  final DateTime recordedAt;
  final String? sessionId;
  final Map<String, String> tags;

  int get rawValue => value;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'value': value,
      'recorded_at_ms': recordedAt.millisecondsSinceEpoch,
      if (sessionId != null && sessionId!.trim().isNotEmpty)
        'session_id': sessionId,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }
}

abstract class SessionRuntimeTelemetry {
  void bindSessionId(String sessionId);

  void setSessionRunning(bool isRunning);

  void recordGatewayReconnect();

  void recordGapRepairPull();
}

abstract class SessionEventGatewayTelemetry {
  void bindSessionId(String sessionId);

  void recordInboundControlFrame();

  void recordControlFrameDecodeError();
}

abstract class ConversationPatchTelemetry {
  void recordConversationPatchApply(Duration duration);
}

abstract class MessageQueryTelemetry {
  void recordSqlitePageQuery(Duration duration, {required String mode});
}

class RealtimeRolloutTelemetry
    implements
        SessionRuntimeTelemetry,
        SessionEventGatewayTelemetry,
        ConversationPatchTelemetry,
        MessageQueryTelemetry {
  RealtimeRolloutTelemetry({
    RealtimeTelemetryTransport? transport,
    this.flushInterval = const Duration(seconds: 30),
    RealtimeTelemetryClock? now,
  }) : _transport = transport ?? _discardTransport,
       _now = now ?? DateTime.now {
    if (flushInterval > Duration.zero) {
      _flushTimer = Timer.periodic(flushInterval, (_) {
        unawaited(flush());
      });
    }
  }

  static const String metricGatewayReconnectCount = 'gateway_reconnect_count';
  static const String metricPullAfterSeqRepairCount =
      'pull_after_seq_repair_count';
  static const String metricActiveRealtimeSessionCount =
      'active_realtime_session_count';
  static const String metricControlFrameDecodeErrorCount =
      'control_frame_decode_error_count';
  static const String metricInboundControlFrameCount =
      'inbound_control_frame_count';
  static const String metricSqlitePageQueryP95Ms = 'sqlite_page_query_p95_ms';
  static const String metricConversationListPatchApplyP95Ms =
      'conversation_list_patch_apply_p95_ms';

  final Duration flushInterval;
  final RealtimeTelemetryTransport _transport;
  final RealtimeTelemetryClock _now;

  Timer? _flushTimer;
  Future<void> _flushQueue = Future<void>.value();
  final List<RealtimeTelemetryEvent> _buffer = <RealtimeTelemetryEvent>[];
  String? _sessionId;
  bool _sessionRunning = false;
  bool _disposed = false;

  @override
  void bindSessionId(String sessionId) {
    if (_disposed) {
      return;
    }
    final normalized = sessionId.trim();
    if (normalized.isEmpty) {
      return;
    }
    _sessionId = normalized;
  }

  @override
  void setSessionRunning(bool isRunning) {
    if (_disposed) {
      return;
    }
    _sessionRunning = isRunning;
  }

  @override
  void recordGatewayReconnect() {
    _recordCount(metricGatewayReconnectCount);
  }

  @override
  void recordGapRepairPull() {
    _recordCount(metricPullAfterSeqRepairCount);
  }

  @override
  void recordInboundControlFrame() {
    _recordCount(metricInboundControlFrameCount);
  }

  @override
  void recordControlFrameDecodeError() {
    _recordCount(metricControlFrameDecodeErrorCount);
  }

  @override
  void recordConversationPatchApply(Duration duration) {
    _recordDuration(metricConversationListPatchApplyP95Ms, duration);
  }

  @override
  void recordSqlitePageQuery(Duration duration, {required String mode}) {
    final normalizedMode = mode.trim();
    final tags = normalizedMode.isEmpty
        ? const <String, String>{}
        : <String, String>{'mode': normalizedMode};
    _recordDuration(metricSqlitePageQueryP95Ms, duration, tags: tags);
  }

  Future<void> flush() {
    _flushQueue = _flushQueue.then((_) async {
      final pending = List<RealtimeTelemetryEvent>.from(
        _buffer,
        growable: true,
      );
      final heartbeat = _buildSessionHeartbeatEvent();
      if (heartbeat != null) {
        pending.add(heartbeat);
      }
      if (pending.isEmpty) {
        return;
      }
      try {
        await _transport(List<RealtimeTelemetryEvent>.unmodifiable(pending));
        _buffer.clear();
      } catch (_) {
        // Keep buffered events for the next flush attempt.
      }
    });
    return _flushQueue;
  }

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void _recordCount(String metricName) {
    _record(metricName, value: 1);
  }

  void _recordDuration(
    String metricName,
    Duration duration, {
    Map<String, String>? tags,
  }) {
    _record(metricName, value: duration.inMilliseconds, tags: tags);
  }

  void _record(
    String metricName, {
    required num value,
    Map<String, String>? tags,
  }) {
    if (_disposed) {
      return;
    }
    _buffer.add(
      RealtimeTelemetryEvent(
        name: metricName,
        value: value,
        recordedAt: _now().toUtc(),
        sessionId: _sessionId,
        tags: tags,
      ),
    );
  }

  RealtimeTelemetryEvent? _buildSessionHeartbeatEvent() {
    if (!_sessionRunning) {
      return null;
    }
    return RealtimeTelemetryEvent(
      name: metricActiveRealtimeSessionCount,
      value: 1,
      recordedAt: _now().toUtc(),
      sessionId: _sessionId,
    );
  }

  static Future<void> _discardTransport(List<RealtimeTelemetryEvent> _) async {}
}
