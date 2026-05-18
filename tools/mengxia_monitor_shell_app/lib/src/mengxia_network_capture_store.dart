import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

import 'mengxia_network_capture.dart';

class MengxiaNetworkCaptureStore {
  MengxiaNetworkCaptureStore({
    this.maxEvents = 50,
    this.maxNetworkDiagnostics = 20,
  });

  final int maxEvents;
  final int maxNetworkDiagnostics;
  final List<NormalizedMessageEvent> _messageEvents =
      <NormalizedMessageEvent>[];
  final List<MengxiaNetworkCaptureEvent> _networkEvents =
      <MengxiaNetworkCaptureEvent>[];
  int _networkEventCount = 0;
  int _networkMessageEventCount = 0;
  String _state = 'running';
  String _lastError = '';

  List<NormalizedMessageEvent> get recentMessageEvents =>
      List<NormalizedMessageEvent>.unmodifiable(_messageEvents);

  void addNetworkEvent(MengxiaNetworkCaptureEvent event) {
    _networkEventCount += 1;
    _networkEvents.add(event);
    _trim(_networkEvents, maxNetworkDiagnostics);
  }

  void addMessageEvent(NormalizedMessageEvent event) {
    _networkMessageEventCount += 1;
    _messageEvents.add(event);
    _trim(_messageEvents, maxEvents);
  }

  void setUnavailable(String error) {
    _state = 'unavailable';
    _lastError = error.trim();
  }

  Map<String, dynamic> toDiagnosticsJson() {
    return <String, dynamic>{
      'network_capture_state': _state,
      'network_event_count': _networkEventCount,
      'network_message_event_count': _networkMessageEventCount,
      'network_recent_events': _networkEvents
          .map((event) => event.toRedactedJson())
          .toList(growable: false),
      'network_recent_message_events': _messageEvents
          .map((event) => event.toJson())
          .toList(growable: false),
      'network_last_error': _lastError,
    };
  }
}

void _trim<T>(List<T> values, int limit) {
  while (values.length > limit) {
    values.removeAt(0);
  }
}
