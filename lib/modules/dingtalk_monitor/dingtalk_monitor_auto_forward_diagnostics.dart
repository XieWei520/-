import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;

import 'dingtalk_monitor_forwarding_service.dart';
import 'dingtalk_monitor_shell_models.dart';

class DingTalkMonitorAutoForwardDiagnosticsSnapshot {
  const DingTalkMonitorAutoForwardDiagnosticsSnapshot({
    required this.updatedAt,
    required this.state,
    required this.settingsEnabled,
    required this.routeCount,
    required this.enabledRouteCount,
    required this.routeSourceHashes,
    required this.hostOnline,
    required this.captureRunning,
    required this.ocrEnabled,
    required this.shellState,
    required this.currentHwnd,
    required this.recentEventCount,
    required this.forwardableTextEventCount,
    required this.matchedRouteCount,
    required this.recentSourceHashes,
    required this.sent,
    required this.skippedDuplicate,
    required this.skippedUnmatched,
    required this.skippedDisabled,
    required this.failed,
    required this.lastErrorType,
    required this.lastErrorMessageLength,
    this.runCount = 0,
    this.primed = false,
    this.startupEventCount = 0,
    this.liveEventCount = 0,
    this.sessionSent = 0,
    this.sessionFailed = 0,
    this.lastSentAt,
    this.lastFailureAt,
  });

  final DateTime updatedAt;
  final String state;
  final bool settingsEnabled;
  final int routeCount;
  final int enabledRouteCount;
  final List<String> routeSourceHashes;
  final bool hostOnline;
  final bool captureRunning;
  final bool ocrEnabled;
  final String shellState;
  final String currentHwnd;
  final int recentEventCount;
  final int forwardableTextEventCount;
  final int matchedRouteCount;
  final List<String> recentSourceHashes;
  final int sent;
  final int skippedDuplicate;
  final int skippedUnmatched;
  final int skippedDisabled;
  final int failed;
  final String lastErrorType;
  final int lastErrorMessageLength;
  final int runCount;
  final bool primed;
  final int startupEventCount;
  final int liveEventCount;
  final int sessionSent;
  final int sessionFailed;
  final DateTime? lastSentAt;
  final DateTime? lastFailureAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'state': state,
      'settings_enabled': settingsEnabled,
      'route_count': routeCount,
      'enabled_route_count': enabledRouteCount,
      'route_source_hashes': routeSourceHashes,
      'host_online': hostOnline,
      'capture_running': captureRunning,
      'ocr_enabled': ocrEnabled,
      'shell_state': shellState,
      'current_hwnd': currentHwnd,
      'recent_event_count': recentEventCount,
      'forwardable_text_event_count': forwardableTextEventCount,
      'matched_route_count': matchedRouteCount,
      'recent_source_hashes': recentSourceHashes,
      'sent': sent,
      'skipped_duplicate': skippedDuplicate,
      'skipped_unmatched': skippedUnmatched,
      'skipped_disabled': skippedDisabled,
      'failed': failed,
      'last_error_type': lastErrorType,
      'last_error_message_length': lastErrorMessageLength,
      'run_count': runCount,
      'primed': primed,
      'startup_event_count': startupEventCount,
      'live_event_count': liveEventCount,
      'session_sent': sessionSent,
      'session_failed': sessionFailed,
      'last_sent_at': lastSentAt?.toUtc().toIso8601String() ?? '',
      'last_failure_at': lastFailureAt?.toUtc().toIso8601String() ?? '',
    };
  }
}

abstract class DingTalkMonitorAutoForwardDiagnosticsStore {
  Future<void> save(DingTalkMonitorAutoForwardDiagnosticsSnapshot snapshot);
}

class FileDingTalkMonitorAutoForwardDiagnosticsStore
    implements DingTalkMonitorAutoForwardDiagnosticsStore {
  const FileDingTalkMonitorAutoForwardDiagnosticsStore({String? path})
    : _path = path;

  final String? _path;

  @override
  Future<void> save(
    DingTalkMonitorAutoForwardDiagnosticsSnapshot snapshot,
  ) async {
    final file = File(_path ?? _defaultDiagnosticsPath());
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      flush: true,
    );
  }

  static String _defaultDiagnosticsPath() {
    final appData = Platform.environment['APPDATA']?.trim();
    final base = appData == null || appData.isEmpty
        ? Directory.current.path
        : appData;
    return p.join(
      base,
      'InfoEquity',
      'InfoEquity',
      'dingtalk_monitor_diagnostics.json',
    );
  }
}

DingTalkMonitorAutoForwardDiagnosticsSnapshot
buildDingTalkMonitorAutoForwardDiagnosticsSnapshot({
  required DateTime updatedAt,
  required String state,
  required DingTalkMonitorForwardingSettings? settings,
  required DingTalkMonitorShellStatus? status,
  required List<DingTalkMonitorMessageEvent> recentEvents,
  DingTalkMonitorForwardingResult? result,
  Object? error,
  int runCount = 0,
  bool primed = false,
  int startupEventCount = 0,
  int liveEventCount = 0,
  int sessionSent = 0,
  int sessionFailed = 0,
  DateTime? lastSentAt,
  DateTime? lastFailureAt,
}) {
  final effectiveSettings =
      settings ?? const DingTalkMonitorForwardingSettings(enabled: false);
  final enabledRoutes = effectiveSettings.routes
      .where((route) => route.enabled && route.targetGroupId.trim().isNotEmpty)
      .toList(growable: false);
  final forwardableEvents = recentEvents
      .where((event) => event.isForwardableText)
      .toList(growable: false);
  return DingTalkMonitorAutoForwardDiagnosticsSnapshot(
    updatedAt: updatedAt,
    state: state,
    settingsEnabled: effectiveSettings.enabled,
    routeCount: effectiveSettings.routes.length,
    enabledRouteCount: enabledRoutes.length,
    routeSourceHashes: _hashDistinct(
      enabledRoutes.map((route) => route.sourceConversationId),
    ),
    hostOnline: status?.isOnline ?? false,
    captureRunning: status?.isCapturing ?? false,
    ocrEnabled: status?.ocrEnabled ?? false,
    shellState: status?.shellState ?? '',
    currentHwnd: status?.currentHwnd ?? '',
    recentEventCount: recentEvents.length,
    forwardableTextEventCount: forwardableEvents.length,
    matchedRouteCount: forwardableEvents
        .where(
          (event) =>
              findDingTalkMonitorRouteForEvent(
                routes: effectiveSettings.routes,
                event: event,
              ) !=
              null,
        )
        .length,
    recentSourceHashes: _hashDistinct(
      forwardableEvents.map((event) => event.sourceConversationId),
    ),
    sent: result?.sent ?? 0,
    skippedDuplicate: result?.skippedDuplicate ?? 0,
    skippedUnmatched: result?.skippedUnmatched ?? 0,
    skippedDisabled: result?.skippedDisabled ?? 0,
    failed: result?.failed ?? (error == null ? 0 : 1),
    lastErrorType: result?.lastErrorType ?? _errorType(error),
    lastErrorMessageLength:
        result?.lastErrorMessageLength ?? _errorMessageLength(error),
    runCount: runCount,
    primed: primed,
    startupEventCount: startupEventCount,
    liveEventCount: liveEventCount,
    sessionSent: sessionSent,
    sessionFailed: sessionFailed,
    lastSentAt: lastSentAt,
    lastFailureAt: lastFailureAt,
  );
}

List<String> _hashDistinct(Iterable<String> values) {
  final seen = <String>{};
  final hashes = <String>[];
  for (final value in values) {
    final hash = _hash12(value.trim());
    if (hash.isNotEmpty && seen.add(hash)) {
      hashes.add(hash);
    }
  }
  return hashes;
}

String _hash12(String value) {
  if (value.isEmpty) {
    return '';
  }
  return crypto.sha256.convert(utf8.encode(value)).toString().substring(0, 12);
}

String _errorType(Object? error) =>
    error == null ? '' : error.runtimeType.toString();

int _errorMessageLength(Object? error) => error?.toString().length ?? 0;
