import 'dart:convert';

import 'feishu_network_capture.dart';

const _maxTraversalDepth = 32;
const _maxVisitedMaps = 1000;
const _maxVisitedNodes = 5000;
const _specificResourceUrlKeys = <String>[
  'image_url',
  'origin_url',
  'preview_url',
  'download_url',
];
const _imageUrlHints = <String>[
  'image',
  'img',
  'photo',
  'preview',
  'origin',
  'thumb',
  'webp',
  'png',
  'jpg',
  'jpeg',
  'gif',
];

List<FeishuNetworkImageCandidate> parseFeishuNetworkImageCandidates(
  FeishuNetworkCaptureEvent event,
) {
  if (_isDiagnosticOnlySource(event.source)) {
    return const <FeishuNetworkImageCandidate>[];
  }

  final directImage = _candidateFromDirectImageResponse(event);
  final decoded = _tryDecodeJson(event.payloadPreview);
  if (decoded == null) {
    return directImage == null
        ? const <FeishuNetworkImageCandidate>[]
        : <FeishuNetworkImageCandidate>[directImage];
  }

  final maps = <Map<String, Object?>>[];
  _collectMaps(decoded, maps, _TraversalBudget());

  final candidates = maps
      .map((map) => _candidateFromMap(map, event.observedAt))
      .whereType<FeishuNetworkImageCandidate>()
      .toList();
  if (directImage != null) {
    candidates.add(directImage);
  }
  return candidates.toList(growable: false);
}

bool _isDiagnosticOnlySource(FeishuNetworkEventSource source) {
  return source == FeishuNetworkEventSource.httpRequest ||
      source == FeishuNetworkEventSource.dataReceived ||
      source == FeishuNetworkEventSource.eventSourceMessage ||
      source == FeishuNetworkEventSource.webSocketCreated ||
      source == FeishuNetworkEventSource.webSocketFrame ||
      source == FeishuNetworkEventSource.webSocketFrameSent ||
      source == FeishuNetworkEventSource.webSocketClosed;
}

Object? _tryDecodeJson(String payload) {
  try {
    return jsonDecode(payload);
  } catch (_) {
    return null;
  }
}

void _collectMaps(
  Object? value,
  List<Map<String, Object?>> output,
  _TraversalBudget budget, [
  int depth = 0,
]) {
  if (depth > _maxTraversalDepth || !budget.visitNode()) {
    return;
  }

  if (value is Map) {
    if (!budget.visitMap()) {
      return;
    }

    final map = value.map((key, value) => MapEntry('$key', value));
    output.add(map);

    for (final child in map.values) {
      _collectMaps(child, output, budget, depth + 1);
    }
    return;
  }

  if (value is List) {
    for (final child in value) {
      _collectMaps(child, output, budget, depth + 1);
    }
  }
}

FeishuNetworkImageCandidate? _candidateFromMap(
  Map<String, Object?> map,
  DateTime observedAt,
) {
  final resourceKey = _firstString(map, const <String>[
    'image_key',
    'file_key',
    'resource_key',
    'origin_key',
  ]);
  final specificResourceUrl = _firstString(map, _specificResourceUrlKeys);
  final genericResourceUrl = _firstString(map, const <String>['url']);
  final resourceUrl = specificResourceUrl.isNotEmpty
      ? specificResourceUrl
      : genericResourceUrl;

  if (resourceKey.isEmpty &&
      specificResourceUrl.isEmpty &&
      !_hasImageUrlHint(genericResourceUrl)) {
    return null;
  }

  return FeishuNetworkImageCandidate(
    conversationId: _firstString(map, const <String>[
      'conversation_id',
      'chat_id',
      'channel_id',
    ]),
    conversationName: _firstString(map, const <String>[
      'conversation_name',
      'chat_name',
      'title',
    ]),
    messageId: _firstString(map, const <String>['message_id', 'msg_id', 'id']),
    senderName: _firstString(map, const <String>[
      'sender_name',
      'from_name',
      'name',
    ]),
    resourceUrl: resourceUrl,
    resourceKey: resourceKey,
    width: _firstInt(map, const <String>['width', 'w']),
    height: _firstInt(map, const <String>['height', 'h']),
    quality: _qualityForMap(map, resourceUrl),
    observedAt: observedAt,
  );
}

FeishuNetworkImageCandidate? _candidateFromDirectImageResponse(
  FeishuNetworkCaptureEvent event,
) {
  if (event.source != FeishuNetworkEventSource.httpResponse) {
    return null;
  }
  final bodyLocalPath = event.bodyLocalPath.trim();
  final bodySha1 = event.bodySha1.trim();
  if (!event.bodySaved ||
      bodyLocalPath.isEmpty ||
      bodySha1.isEmpty ||
      event.bodySize <= 0) {
    return null;
  }
  final mimeType = event.mimeType.toLowerCase();
  if (!mimeType.startsWith('image/')) {
    return null;
  }
  final url = event.url.trim();
  if (url.isEmpty) {
    return null;
  }
  if (!_looksLikeMessageImageResponse(url)) {
    return null;
  }
  return FeishuNetworkImageCandidate(
    conversationId: '',
    conversationName: '',
    messageId: event.id,
    senderName: '',
    resourceUrl: url,
    resourceKey: '',
    width: 0,
    height: 0,
    quality: FeishuNetworkImageQuality.unknown,
    observedAt: event.observedAt,
    localPath: bodyLocalPath,
    bodySha1: bodySha1,
    bodySize: event.bodySize,
    bodyMimeType: event.bodyMimeType.trim().isEmpty
        ? event.mimeType
        : event.bodyMimeType.trim(),
    requestResourceType: event.resourceType,
    requestDocumentUrl: event.documentUrl,
    requestInitiatorType: event.initiatorType,
    requestInitiatorUrl: event.initiatorUrl,
    requestInitiatorStackUrl: event.initiatorStackUrl,
    requestInitiatorLineNumber: event.initiatorLineNumber,
    requestInitiatorColumnNumber: event.initiatorColumnNumber,
    requestFrameId: event.frameId,
  );
}

bool _looksLikeMessageImageResponse(String url) {
  final lower = url.toLowerCase();
  if (lower.startsWith('data:')) {
    return false;
  }
  if (lower.startsWith('blob:')) {
    return true;
  }

  final uri = Uri.tryParse(url);
  final host = uri?.host.toLowerCase() ?? '';
  final path = uri?.path.toLowerCase() ?? lower;
  if (host.contains('scmcdn') || path.contains('/feishu-static/')) {
    return false;
  }
  if (path.contains('default-avatar')) {
    return false;
  }
  if (host.contains('internal-api-lark-file')) {
    return true;
  }
  if (host.contains('imfile.feishucdn.com') &&
      path.contains('/static-resource/v1/')) {
    return true;
  }
  return _hasImageUrlHint(url);
}

String _firstString(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    if (value is num) {
      return value.toString();
    }
  }
  return '';
}

int _firstInt(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return 0;
}

bool _hasImageUrlHint(String resourceUrl) {
  if (resourceUrl.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(resourceUrl);
  final pathAndQuery = uri == null
      ? resourceUrl.toLowerCase()
      : '${uri.path}?${uri.query}'.toLowerCase();
  return _imageUrlHints.any(pathAndQuery.contains);
}

FeishuNetworkImageQuality _qualityForMap(
  Map<String, Object?> map,
  String resourceUrl,
) {
  final rawQuality = _firstString(map, const <String>[
    'quality',
    'image_quality',
    'type',
  ]).toLowerCase();
  final url = resourceUrl.toLowerCase();

  if (rawQuality.contains('origin') || url.contains('origin')) {
    return FeishuNetworkImageQuality.original;
  }
  if (rawQuality.contains('thumb') || url.contains('thumb')) {
    return FeishuNetworkImageQuality.thumbnail;
  }
  if (rawQuality.contains('preview') || url.contains('preview')) {
    return FeishuNetworkImageQuality.preview;
  }
  return FeishuNetworkImageQuality.unknown;
}

class _TraversalBudget {
  int _visitedMaps = 0;
  int _visitedNodes = 0;

  bool visitMap() {
    if (_visitedMaps >= _maxVisitedMaps) {
      return false;
    }
    _visitedMaps += 1;
    return true;
  }

  bool visitNode() {
    if (_visitedNodes >= _maxVisitedNodes) {
      return false;
    }
    _visitedNodes += 1;
    return true;
  }
}
