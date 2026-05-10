import 'dart:convert';
import 'dart:io';

import 'feishu_network_capture.dart';

class FeishuNetworkCaptureStore {
  FeishuNetworkCaptureStore({
    int maxEvents = 50,
    int maxCandidates = 20,
    int maxAttributions = 20,
    this.diagnosticsFile,
  }) : maxEvents = maxEvents < 0 ? 0 : maxEvents,
       maxCandidates = maxCandidates < 0 ? 0 : maxCandidates,
       maxAttributions = maxAttributions < 0 ? 0 : maxAttributions;

  final int maxEvents;
  final int maxCandidates;
  final int maxAttributions;
  final File? diagnosticsFile;

  final List<FeishuNetworkCaptureEvent> _events =
      <FeishuNetworkCaptureEvent>[];
  final List<FeishuNetworkImageCandidate> _candidates =
      <FeishuNetworkImageCandidate>[];
  final List<FeishuNetworkImageAttribution> _attributions =
      <FeishuNetworkImageAttribution>[];

  String _state = 'running';
  String _lastError = '';
  int _eventCount = 0;
  int _candidateCount = 0;
  int _attributionCount = 0;

  void setUnavailable(String error) {
    _state = 'unavailable';
    _lastError = error;
  }

  void addEvent(FeishuNetworkCaptureEvent event) {
    _eventCount += 1;
    _events.add(event);
    _trim(_events, maxEvents);
    _appendDiagnosticsLine(event.toRedactedJson());
  }

  void addCandidate(FeishuNetworkImageCandidate candidate) {
    _candidateCount += 1;
    _candidates.add(candidate);
    _trim(_candidates, maxCandidates);
  }

  void addAttribution(FeishuNetworkImageAttribution attribution) {
    _attributionCount += 1;
    _attributions.add(attribution);
    _trim(_attributions, maxAttributions);
    _appendDiagnosticsLine(<String, Object?>{
      'diagnostic_type': 'image_attribution',
      ...attribution.toStatusJson(),
    });
  }

  Map<String, Object?> toDiagnosticsJson() {
    return <String, Object?>{
      'network_capture_state': _state,
      'network_event_count': _eventCount,
      'network_recent_events': _events
          .map((event) => event.toRedactedJson())
          .toList(growable: false),
      'network_image_candidate_count': _candidateCount,
      'network_last_image_candidate': _candidates.isEmpty
          ? null
          : _candidates.last.toStatusJson(),
      'network_image_attribution_count': _attributionCount,
      'network_recent_image_attributions': _attributions
          .map((attribution) => attribution.toStatusJson())
          .toList(growable: false),
      'network_last_image_attribution': _attributions.isEmpty
          ? null
          : _attributions.last.toStatusJson(),
      'network_last_attributed_image_candidate':
          _lastAttributedImageCandidate(),
      'network_last_error': _lastError,
    };
  }

  Map<String, Object?>? _lastAttributedImageCandidate() {
    for (final attribution in _attributions.reversed) {
      for (final candidate in _candidates.reversed) {
        if (candidate.resourceUrl == attribution.sourceUrl) {
          return <String, Object?>{
            'candidate': candidate.toStatusJson(),
            'attribution': attribution.toStatusJson(),
            'stable': attribution.isStable,
          };
        }
      }
    }
    return null;
  }

  void _appendDiagnosticsLine(Map<String, Object?> json) {
    final file = diagnosticsFile;
    if (file == null) {
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('${jsonEncode(json)}\n', mode: FileMode.append);
  }
}

void _trim<T>(List<T> items, int maxItems) {
  while (items.length > maxItems) {
    items.removeAt(0);
  }
}
