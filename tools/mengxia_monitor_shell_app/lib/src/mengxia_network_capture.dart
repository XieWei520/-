enum MengxiaNetworkEventSource {
  httpRequest,
  httpResponse,
  dataReceived,
  eventSourceMessage,
  webSocketCreated,
  webSocketFrame,
  webSocketFrameSent,
  webSocketClosed,
  imageRequest,
  unknown,
}

class MengxiaNetworkCaptureEvent {
  const MengxiaNetworkCaptureEvent({
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
    this.resourceType = '',
    this.documentUrl = '',
    this.initiatorType = '',
    this.initiatorUrl = '',
    this.initiatorStackUrl = '',
    this.initiatorLineNumber = 0,
    this.initiatorColumnNumber = 0,
    this.frameId = '',
  });

  final String id;
  final DateTime observedAt;
  final MengxiaNetworkEventSource source;
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
  final String resourceType;
  final String documentUrl;
  final String initiatorType;
  final String initiatorUrl;
  final String initiatorStackUrl;
  final int initiatorLineNumber;
  final int initiatorColumnNumber;
  final String frameId;

  Map<String, Object?> toRedactedJson() {
    return <String, Object?>{
      'id': id,
      'observed_at': observedAt.toUtc().toIso8601String(),
      'source': source.name,
      'url': redactMengxiaUrl(url),
      'method': method,
      'status_code': statusCode,
      'mime_type': mimeType,
      'payload_preview': redactMengxiaPayload(payloadPreview),
      'body_local_path': bodyLocalPath.trim().isEmpty
          ? ''
          : '<local-cache-file>',
      'body_sha1': bodySha1,
      'body_size': bodySize,
      'body_mime_type': bodyMimeType,
      'body_base64_encoded': bodyBase64Encoded,
      'body_saved': bodySaved,
      'body_save_error': bodySaveError,
      'resource_type': resourceType,
      'document_url': redactMengxiaUrl(documentUrl),
      'initiator_type': initiatorType,
      'initiator_url': redactMengxiaUrl(initiatorUrl),
      'initiator_stack_url': redactMengxiaUrl(initiatorStackUrl),
      'initiator_line_number': initiatorLineNumber,
      'initiator_column_number': initiatorColumnNumber,
      'frame_id': frameId,
    };
  }
}

String redactMengxiaUrl(String url) {
  final queryStart = url.indexOf('?');
  if (queryStart == -1) {
    return url;
  }
  final fragmentStart = url.indexOf('#', queryStart + 1);
  final queryEnd = fragmentStart == -1 ? url.length : fragmentStart;
  final query = url.substring(queryStart + 1, queryEnd);
  final redacted = query
      .split('&')
      .map((part) {
        final index = part.indexOf('=');
        if (index == -1) {
          return part;
        }
        return '${part.substring(0, index)}=<redacted>';
      })
      .join('&');
  return '${url.substring(0, queryStart + 1)}$redacted${url.substring(queryEnd)}';
}

String redactMengxiaPayload(String payload) {
  var redacted = payload;
  const sensitiveKeyPattern =
      r'(?:access_token|authorization|cookie|credential|jwt|secret|session|sign|signature|ticket|token)';
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
  const maxLength = 2000;
  return redacted.length <= maxLength
      ? redacted
      : '${redacted.substring(0, maxLength)}…';
}
