import 'dart:async';

import '../../service/api/im_sync_api.dart';
import '../telemetry/realtime_rollout_telemetry.dart';
import 'session_event_frame.dart';
import 'session_event_gateway.dart';

typedef SessionFrameHandler = FutureOr<void> Function(SessionEventFrame frame);
typedef DeviceInvalidatedHandler = FutureOr<void> Function();
typedef SessionClock = DateTime Function();
typedef SessionRetryDelay = Duration Function(int attempt);
typedef SessionDelay = Future<void> Function(Duration duration);
typedef SessionDeltaPuller =
    Future<List<SessionEventFrame>> Function({
      required int afterSeq,
      required int limit,
    });

const int _sessionDeltaPullLimit = 200;

class SessionRuntimeSnapshot {
  const SessionRuntimeSnapshot({
    required this.retryAttempt,
    required this.lastAckedSeq,
    required this.lastReceivedSeq,
    required this.gatewayDegradedSince,
  });

  final int retryAttempt;
  final int lastAckedSeq;
  final int lastReceivedSeq;
  final DateTime? gatewayDegradedSince;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is SessionRuntimeSnapshot &&
            other.retryAttempt == retryAttempt &&
            other.lastAckedSeq == lastAckedSeq &&
            other.lastReceivedSeq == lastReceivedSeq &&
            other.gatewayDegradedSince == gatewayDegradedSince;
  }

  @override
  int get hashCode {
    return Object.hash(
      retryAttempt,
      lastAckedSeq,
      lastReceivedSeq,
      gatewayDegradedSince,
    );
  }
}

class SessionRuntime {
  SessionRuntime({
    required this.gateway,
    required this.onDeviceInvalidated,
    this.onFrame,
    SessionRuntimeTelemetry? telemetry,
    SessionDeltaPuller? pullAfterSeq,
    SessionClock? now,
    SessionRetryDelay? retryDelay,
    SessionDelay? delay,
  }) : _now = now ?? DateTime.now,
       _telemetry = telemetry,
       _pullAfterSeq = pullAfterSeq ?? _defaultPullAfterSeq,
       _retryDelay = retryDelay ?? _defaultRetryDelay,
       _delay = delay ?? _defaultDelay;

  final SessionEventGateway gateway;
  final DeviceInvalidatedHandler onDeviceInvalidated;
  final SessionFrameHandler? onFrame;
  final SessionClock _now;
  final SessionRuntimeTelemetry? _telemetry;
  final SessionDeltaPuller _pullAfterSeq;
  final SessionRetryDelay _retryDelay;
  final SessionDelay _delay;

  StreamSubscription<SessionEventFrame>? _subscription;
  DateTime? _gatewayDegradedSince;
  Uri? _resumeUriTemplate;
  Map<String, String>? _resumeHeaders;
  int _retryAttempt = 0;
  int _recoveryGeneration = 0;
  bool _recoveryScheduled = false;
  bool _desiredRunning = false;
  Future<void> _frameProcessing = Future<void>.value();

  bool isRunning = false;

  bool get isGatewayDegraded => _gatewayDegradedSince != null;
  SessionRuntimeSnapshot get snapshot {
    return SessionRuntimeSnapshot(
      retryAttempt: _retryAttempt,
      lastAckedSeq: gateway.lastAckedSeq,
      lastReceivedSeq: gateway.lastReceivedSeq,
      gatewayDegradedSince: _gatewayDegradedSince,
    );
  }

  Future<void> start(Uri uri, {Map<String, String>? headers}) async {
    _bindSessionId(uri);
    _desiredRunning = true;
    _recoveryGeneration += 1;
    _recoveryScheduled = false;
    _retryAttempt = 0;
    _resumeUriTemplate = uri;
    _resumeHeaders = headers == null ? null : Map<String, String>.from(headers);
    await _teardownConnection();
    _gatewayDegradedSince = null;
    await _openConnection();
  }

  Future<void> stop() async {
    _desiredRunning = false;
    _retryAttempt = 0;
    _recoveryGeneration += 1;
    _recoveryScheduled = false;
    _setRunning(false);
    await _teardownConnection();
    await gateway.close();
  }

  Future<void> _openConnection() async {
    final uri = _buildResumeUri();
    final headers = _resumeHeaders;
    final stream = await gateway.open(uri, headers: headers);
    _subscription = stream.listen(
      (frame) {
        _enqueueIncomingFrame(frame);
      },
      onError: (error, stackTrace) {
        _handleGatewayTermination();
      },
      onDone: () {
        if (_desiredRunning) {
          _handleGatewayTermination();
        }
      },
      cancelOnError: false,
    );
    _setRunning(true);
  }

  Future<void> _teardownConnection() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  Future<void> handleFrame(SessionEventFrame frame) async {
    if (_shouldSkipFrame(frame)) {
      return;
    }
    if (!_isInvalidationFrame(frame.kind)) {
      await _repairGapIfNeeded(frame);
    }
    await _processFrame(frame);
  }

  bool isGatewayDegradedFor(Duration threshold) {
    final degradedSince = _gatewayDegradedSince;
    if (degradedSince == null) {
      return false;
    }
    return _now().difference(degradedSince) >= threshold;
  }

  Future<void> _handleIncomingFrame(SessionEventFrame frame) async {
    try {
      await handleFrame(frame);
    } catch (_) {
      _handleGatewayTermination();
    }
  }

  void _enqueueIncomingFrame(SessionEventFrame frame) {
    _frameProcessing = _frameProcessing.then(
      (_) => _handleIncomingFrame(frame),
    );
  }

  Future<void> _repairGapIfNeeded(SessionEventFrame incoming) async {
    var cursor = gateway.lastAckedSeq;
    if (incoming.userSeq <= cursor + 1) {
      return;
    }

    while (cursor < incoming.userSeq - 1) {
      _telemetry?.recordGapRepairPull();
      final pulled = await _pullAfterSeq(
        afterSeq: cursor,
        limit: _sessionDeltaPullLimit,
      );
      final replay =
          pulled
              .where(
                (frame) =>
                    frame.userSeq > cursor && frame.userSeq < incoming.userSeq,
              )
              .toList()
            ..sort((a, b) => a.userSeq.compareTo(b.userSeq));

      final batchStart = cursor;
      for (final frame in replay) {
        if (frame.userSeq <= cursor) {
          continue;
        }
        if (frame.userSeq != cursor + 1) {
          throw StateError(
            'Missing session delta event seq ${cursor + 1} before ${incoming.userSeq}.',
          );
        }
        await _processFrame(frame);
        cursor = frame.userSeq;
      }

      if (cursor == incoming.userSeq - 1) {
        return;
      }
      if (cursor == batchStart) {
        break;
      }
    }

    throw StateError(
      'Incomplete session delta replay through ${incoming.userSeq - 1}; got $cursor.',
    );
  }

  Future<void> _processFrame(SessionEventFrame frame) async {
    if (_isInvalidationFrame(frame.kind)) {
      await stop();
      await onDeviceInvalidated();
      return;
    }
    await onFrame?.call(frame);
    await gateway.ack(frame.userSeq);
  }

  bool _isInvalidationFrame(String kind) {
    return kind == 'device.invalidated' || kind == 'session.kicked';
  }

  bool _shouldSkipFrame(SessionEventFrame frame) {
    return !_isInvalidationFrame(frame.kind) &&
        frame.userSeq <= gateway.lastAckedSeq;
  }

  void _markGatewayDegraded() {
    _setRunning(false);
    _gatewayDegradedSince ??= _now();
  }

  void _handleGatewayTermination() {
    if (!_desiredRunning) {
      return;
    }
    _markGatewayDegraded();
    _scheduleRecovery();
  }

  void _scheduleRecovery() {
    if (!_desiredRunning || _resumeUriTemplate == null || _recoveryScheduled) {
      return;
    }

    final generation = _recoveryGeneration;
    final delay = _retryDelay(++_retryAttempt);
    _recoveryScheduled = true;
    _telemetry?.recordGatewayReconnect();

    unawaited(() async {
      try {
        await _delay(delay);
        if (!_desiredRunning || generation != _recoveryGeneration) {
          return;
        }
        await _teardownConnection();
        if (!_desiredRunning || generation != _recoveryGeneration) {
          return;
        }
        await _openConnection();
        _retryAttempt = 0;
        _gatewayDegradedSince = null;
      } catch (_) {
        if (_desiredRunning && generation == _recoveryGeneration) {
          _markGatewayDegraded();
          _recoveryScheduled = false;
          _scheduleRecovery();
          return;
        }
      } finally {
        if (generation == _recoveryGeneration) {
          _recoveryScheduled = false;
        }
      }
    }());
  }

  Uri _buildResumeUri() {
    final template = _resumeUriTemplate;
    if (template == null) {
      throw StateError('Session runtime has no resume URI.');
    }
    final query = <String, String>{
      ...template.queryParameters,
      'last_acked_seq': '${gateway.lastAckedSeq}',
    };
    return template.replace(queryParameters: query);
  }

  void _setRunning(bool running) {
    if (isRunning == running) {
      return;
    }
    isRunning = running;
    _telemetry?.setSessionRunning(running);
  }

  void _bindSessionId(Uri uri) {
    final sessionId = uri.queryParameters['device_session_id']?.trim() ?? '';
    if (sessionId.isEmpty) {
      return;
    }
    _telemetry?.bindSessionId(sessionId);
  }

  static Duration _defaultRetryDelay(int attempt) {
    final clampedAttempt = attempt.clamp(1, 6);
    return Duration(milliseconds: 400 * (1 << (clampedAttempt - 1)));
  }

  static Future<void> _defaultDelay(Duration duration) {
    return Future<void>.delayed(duration);
  }

  static Future<List<SessionEventFrame>> _defaultPullAfterSeq({
    required int afterSeq,
    required int limit,
  }) {
    return IMSyncApi.instance.pullAfterSeq(afterSeq: afterSeq, limit: limit);
  }
}
