import 'dart:convert';
import 'dart:io';

import 'feishu_network_capture.dart';
import 'feishu_network_forwardable_image_resolver.dart';

class FeishuNetworkCaptureStore {
  static const int _maxResolverDecisions = 20;

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

  final List<FeishuNetworkCaptureEvent> _events = <FeishuNetworkCaptureEvent>[];
  final List<FeishuNetworkImageCandidate> _candidates =
      <FeishuNetworkImageCandidate>[];
  final List<FeishuNetworkImageAttribution> _attributions =
      <FeishuNetworkImageAttribution>[];
  final List<Map<String, Object?>> _resolverDecisions =
      <Map<String, Object?>>[];

  String _state = 'running';
  String _lastError = '';
  int _eventCount = 0;
  int _candidateCount = 0;
  int _savedImageCount = 0;
  int _attributionCount = 0;
  int _forwardableImageCount = 0;
  String _lastImageSkipReason = '';
  Map<String, Object?>? _lastForwardableImage;

  List<FeishuNetworkImageCandidate> get recentCandidates =>
      List<FeishuNetworkImageCandidate>.unmodifiable(_candidates);

  List<FeishuNetworkImageAttribution> get recentAttributions =>
      List<FeishuNetworkImageAttribution>.unmodifiable(_attributions);

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
    if (candidate.localPath.trim().isNotEmpty) {
      _savedImageCount += 1;
    }
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

  void recordForwardableImageResolution(
    FeishuNetworkForwardableImageResolution resolution,
  ) {
    if (resolution.events.isNotEmpty) {
      _forwardableImageCount += resolution.events.length;
      _lastForwardableImage =
          _deepJsonCopy(resolution.events.last.toJson())
              as Map<String, Object?>;
      _lastImageSkipReason = '';
    } else {
      _lastImageSkipReason = resolution.skipReason;
    }

    final decision = _resolverDecision(resolution);
    _resolverDecisions.add(decision);
    _trim(_resolverDecisions, _maxResolverDecisions);
    _appendDiagnosticsLine(<String, Object?>{
      'diagnostic_type': 'image_resolver',
      ...decision,
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
      'network_saved_image_count': _savedImageCount,
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
      'network_forwardable_image_count': _forwardableImageCount,
      'network_last_forwardable_image': _lastForwardableImage == null
          ? null
          : _deepJsonCopy(_lastForwardableImage),
      'network_last_image_skip_reason': _lastImageSkipReason,
      'network_recent_image_resolver_decisions': _resolverDecisions
          .map((decision) => _deepJsonCopy(decision) as Map<String, Object?>)
          .toList(growable: false),
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

  Map<String, Object?> _resolverDecision(
    FeishuNetworkForwardableImageResolution resolution,
  ) {
    final decision = resolution.decision;
    if (decision != null) {
      return _deepJsonCopy(decision) as Map<String, Object?>;
    }
    return const <String, Object?>{};
  }
}

Object? _deepJsonCopy(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _deepJsonCopy(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_deepJsonCopy).toList(growable: true);
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  return value.toString();
}

void _trim<T>(List<T> items, int maxItems) {
  while (items.length > maxItems) {
    items.removeAt(0);
  }
}
