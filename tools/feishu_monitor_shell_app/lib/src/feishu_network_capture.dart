enum FeishuNetworkEventSource {
  httpResponse,
  webSocketFrame,
  imageRequest,
  unknown,
}

enum FeishuNetworkImageQuality { original, preview, thumbnail, unknown }

class FeishuNetworkCaptureEvent {
  const FeishuNetworkCaptureEvent({
    required this.id,
    required this.observedAt,
    required this.source,
    required this.url,
    required this.method,
    required this.statusCode,
    required this.mimeType,
    required this.payloadPreview,
    this.bodyLocalPath = '',
    this.bodySha1 = '',
    this.bodySize = 0,
    this.bodyMimeType = '',
    this.bodyBase64Encoded = false,
    this.bodySaved = false,
    this.bodySaveError = '',
  });

  final String id;
  final DateTime observedAt;
  final FeishuNetworkEventSource source;
  final String url;
  final String method;
  final int statusCode;
  final String mimeType;
  final String payloadPreview;
  final String bodyLocalPath;
  final String bodySha1;
  final int bodySize;
  final String bodyMimeType;
  final bool bodyBase64Encoded;
  final bool bodySaved;
  final String bodySaveError;

  Map<String, Object?> toRedactedJson() {
    return <String, Object?>{
      'id': id,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'source': source.name,
      'url': redactUrl(url),
      'method': method,
      'status_code': statusCode,
      'mime_type': mimeType,
      'payload_preview': redactPayload(payloadPreview),
      'body_local_path': bodyLocalPath.trim().isEmpty
          ? ''
          : '<local-cache-file>',
      'body_sha1': bodySha1,
      'body_size': bodySize,
      'body_mime_type': bodyMimeType,
      'body_base64_encoded': bodyBase64Encoded,
      'body_saved': bodySaved,
      'body_save_error': bodySaveError,
    };
  }
}

class FeishuNetworkImageCandidate {
  const FeishuNetworkImageCandidate({
    required this.conversationId,
    required this.conversationName,
    required this.messageId,
    required this.senderName,
    required this.resourceUrl,
    required this.resourceKey,
    required this.width,
    required this.height,
    required this.quality,
    required this.observedAt,
  });

  final String conversationId;
  final String conversationName;
  final String messageId;
  final String senderName;
  final String resourceUrl;
  final String resourceKey;
  final int width;
  final int height;
  final FeishuNetworkImageQuality quality;
  final DateTime observedAt;

  Map<String, Object?> toStatusJson() {
    return <String, Object?>{
      'conversation_id': conversationId,
      'conversation_name': conversationName,
      'message_id': messageId,
      'sender_name': senderName,
      'resource_url': redactUrl(resourceUrl),
      'resource_key': resourceKey.isEmpty ? resourceKey : '<redacted>',
      'width': width,
      'height': height,
      'quality': quality.name,
      'observed_at': observedAt.toUtc().toIso8601String(),
    };
  }
}

class FeishuNetworkImageAttribution {
  const FeishuNetworkImageAttribution({
    required this.sourceUrl,
    required this.sourceKind,
    required this.blobMimeType,
    required this.blobSize,
    required this.conversationId,
    required this.conversationName,
    required this.messageId,
    required this.senderName,
    required this.displayTime,
    required this.messageText,
    required this.feedCardId,
    required this.feedCardText,
    required this.confidence,
    required this.confidenceLabel,
    required this.reason,
    required this.observedAt,
    required this.evidence,
  });

  factory FeishuNetworkImageAttribution.fromJson(Map<String, dynamic> json) {
    return FeishuNetworkImageAttribution(
      sourceUrl: _stringValue(json['source_url']),
      sourceKind: _stringValue(json['source_kind']),
      blobMimeType: _stringValue(json['blob_mime_type']),
      blobSize: _intValue(json['blob_size']),
      conversationId: _stringValue(json['conversation_id']),
      conversationName: _stringValue(json['conversation_name']),
      messageId: _stringValue(json['message_id']),
      senderName: _stringValue(json['sender_name']),
      displayTime: _stringValue(json['display_time']),
      messageText: _stringValue(json['message_text']),
      feedCardId: _stringValue(json['feed_card_id']),
      feedCardText: _stringValue(json['feed_card_text']),
      confidence: _doubleValue(json['confidence']),
      confidenceLabel: _stringValue(json['confidence_label']),
      reason: _stringValue(json['reason']),
      observedAt: _dateTimeValue(json['observed_at']),
      evidence: _stringListValue(json['evidence']),
    );
  }

  final String sourceUrl;
  final String sourceKind;
  final String blobMimeType;
  final int blobSize;
  final String conversationId;
  final String conversationName;
  final String messageId;
  final String senderName;
  final String displayTime;
  final String messageText;
  final String feedCardId;
  final String feedCardText;
  final double confidence;
  final String confidenceLabel;
  final String reason;
  final DateTime observedAt;
  final List<String> evidence;

  bool get isStable =>
      confidence >= 0.8 &&
      confidenceLabel == 'high' &&
      conversationName.trim().isNotEmpty;

  Map<String, Object?> toStatusJson() {
    return <String, Object?>{
      'source_url': redactUrl(sourceUrl),
      'source_kind': sourceKind,
      'blob_mime_type': blobMimeType,
      'blob_size': blobSize,
      'conversation_id': conversationId,
      'conversation_name': conversationName,
      'message_id': messageId,
      'sender_name': senderName,
      'display_time': displayTime,
      'message_text': messageText,
      'feed_card_id': feedCardId,
      'feed_card_text': feedCardText,
      'confidence': confidence,
      'confidence_label': confidenceLabel,
      'reason': reason,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'evidence': evidence.map(_capStatusString).toList(growable: false),
      'stable': isStable,
    };
  }
}

String redactUrl(String url) {
  if (url.toLowerCase().startsWith('data:')) {
    final commaIndex = url.indexOf(',');
    if (commaIndex <= 0) {
      return 'data:<redacted>';
    }
    return '${url.substring(0, commaIndex + 1)}<redacted>';
  }
  final queryStart = url.indexOf('?');
  if (queryStart == -1) {
    return url;
  }

  final fragmentStart = url.indexOf('#', queryStart + 1);
  final queryEnd = fragmentStart == -1 ? url.length : fragmentStart;
  final query = url.substring(queryStart + 1, queryEnd);
  final redactedQuery = query
      .split('&')
      .map((part) {
        final equalsIndex = part.indexOf('=');
        if (equalsIndex == -1) {
          return part;
        }

        return '${part.substring(0, equalsIndex)}=<redacted>';
      })
      .join('&');

  return '${url.substring(0, queryStart + 1)}$redactedQuery${url.substring(queryEnd)}';
}

String _stringValue(Object? value) => value is String ? value : '';

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime _dateTimeValue(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

List<String> _stringListValue(Object? value) {
  if (value is! Iterable<Object?>) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map(_capStatusString)
      .toList(growable: false);
}

String _capStatusString(String value) {
  const maxLength = 240;
  if (value.length <= maxLength) {
    return value;
  }
  return value.substring(0, maxLength);
}

String redactPayload(String payload) {
  var redacted = payload;
  const sensitiveKeyPattern =
      r'(?:access_token|authorization|cookie|credential|csrf|file_key|image_key|jwt|resource_key|secret|session|sign|signature|ticket|token|x-[A-Za-z0-9_-]*token)';
  redacted = redacted.replaceAllMapped(
    RegExp('"($sensitiveKeyPattern)"\\s*:\\s*"[^"]*"', caseSensitive: false),
    (match) => '"${match.group(1)}":"<redacted>"',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(
      r'\b(Authorization|Cookie|Set-Cookie)\s*:\s*[^\r\n]*',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}: <redacted>',
  );
  redacted = redacted.replaceAllMapped(
    RegExp(
      '(^|[\\s&;?])($sensitiveKeyPattern)\\s*[:=]\\s*([^\\s&;\\r\\n]+)',
      caseSensitive: false,
      multiLine: true,
    ),
    (match) {
      final separator = match.group(0)!.contains(':') ? ':' : '=';
      final redactedValue = separator == ':' ? ' <redacted>' : '<redacted>';
      return '${match.group(1)}${match.group(2)}$separator$redactedValue';
    },
  );
  return redacted;
}
