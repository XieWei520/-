import 'dart:convert';
import 'dart:typed_data';

import 'feishu_network_capture.dart';

const int _maxProbeSampleLength = 1200;
const int _minReadableRunLength = 4;
const Set<String> _interestingTokens = <String>{
  'chat_id',
  'channel_id',
  'conversation_id',
  'download_url',
  'file_key',
  'from_name',
  'image',
  'image_key',
  'imfile.feishucdn.com',
  'internal-api-lark-file',
  'media',
  'message_id',
  'msg_id',
  'origin',
  'origin_key',
  'origin_url',
  'photo',
  'preview',
  'preview_url',
  'resource_key',
  'sender_name',
  'static-resource',
  'thumbnail',
};

Map<String, Object?>? probeFeishuNetworkCaptureEvent(
  FeishuNetworkCaptureEvent event,
) {
  if (_isRequestWillBeSent(event)) {
    return _probeRequestWillBeSent(event);
  }
  if (_isRealtimeChannelDiagnostic(event)) {
    return _probeRealtimeChannel(event);
  }
  if (!_isFeishuImGatewayProtobuf(event)) {
    return null;
  }

  final payload = _decodePayload(event);
  final readableText = _readableTextFromBytes(payload.bytes);
  final tokens = _matchedTokens(readableText);
  final hasImageHint = tokens.any(_isImageToken);
  final hasMessageHint = tokens.any(_isMessageToken);
  final idLikeSummary = _idLikeSummary(readableText);

  return <String, Object?>{
    'kind': 'im_gateway_protobuf',
    'observed_at': event.observedAt.toUtc().toIso8601String(),
    'source': event.source.name,
    'url': redactUrl(event.url),
    'mime_type': event.mimeType,
    'payload_base64_encoded': event.bodyBase64Encoded,
    'payload_base64_detected': payload.base64Detected,
    'payload_size': event.bodySize,
    'payload_preview_length': event.payloadPreview.length,
    'readable_length': readableText.length,
    'tokens': tokens,
    'id_like_counts': idLikeSummary.counts,
    'id_like_samples': idLikeSummary.samples,
    'has_image_hint': hasImageHint,
    'has_message_hint': hasMessageHint,
    'sample': _redactProbeSample(readableText),
  };
}

bool _isRequestWillBeSent(FeishuNetworkCaptureEvent event) {
  return event.source == FeishuNetworkEventSource.httpRequest;
}

bool _isRealtimeChannelDiagnostic(FeishuNetworkCaptureEvent event) {
  return event.source == FeishuNetworkEventSource.dataReceived ||
      event.source == FeishuNetworkEventSource.eventSourceMessage ||
      event.source == FeishuNetworkEventSource.webSocketCreated ||
      event.source == FeishuNetworkEventSource.webSocketFrame ||
      event.source == FeishuNetworkEventSource.webSocketFrameSent ||
      event.source == FeishuNetworkEventSource.webSocketClosed;
}

Map<String, Object?> _probeRequestWillBeSent(FeishuNetworkCaptureEvent event) {
  final probeText = <String>[
    event.url,
    event.resourceType,
    event.documentUrl,
    event.initiatorType,
    event.initiatorUrl,
    event.initiatorStackUrl,
  ].join(' ');
  final tokens = _matchedTokens(probeText);
  final hasImageHint =
      tokens.any(_isImageToken) || event.resourceType.toLowerCase() == 'image';
  final hasMessageHint = tokens.any(_isMessageToken);

  return <String, Object?>{
    'kind': 'request_will_be_sent',
    'observed_at': event.observedAt.toUtc().toIso8601String(),
    'source': event.source.name,
    'url': redactUrl(event.url),
    'method': event.method,
    'resource_type': event.resourceType,
    'document_url': redactUrl(event.documentUrl),
    'initiator_type': event.initiatorType,
    'initiator_url': redactUrl(event.initiatorUrl),
    'initiator_stack_url': redactUrl(event.initiatorStackUrl),
    'initiator_line_number': event.initiatorLineNumber,
    'initiator_column_number': event.initiatorColumnNumber,
    'frame_id': event.frameId,
    'tokens': tokens,
    'has_image_hint': hasImageHint,
    'has_message_hint': hasMessageHint,
  };
}

Map<String, Object?> _probeRealtimeChannel(FeishuNetworkCaptureEvent event) {
  final payload = _decodePayload(event);
  final readableText = _readableTextFromBytes(payload.bytes);
  final probeText = <String>[
    event.url,
    event.method,
    event.mimeType,
    event.payloadPreview,
    readableText,
  ].join(' ');
  final tokens = _matchedTokens(probeText);
  final hasImageHint = tokens.any(_isImageToken);
  final hasMessageHint = tokens.any(_isMessageToken);
  final idLikeSummary = _idLikeSummary(
    readableText.isEmpty ? probeText : readableText,
  );

  return <String, Object?>{
    'kind': 'realtime_channel',
    'observed_at': event.observedAt.toUtc().toIso8601String(),
    'source': event.source.name,
    'url': redactUrl(event.url),
    'method': event.method,
    'mime_type': event.mimeType,
    'payload_base64_encoded': event.bodyBase64Encoded,
    'payload_base64_detected': payload.base64Detected,
    'payload_preview_length': event.payloadPreview.length,
    'readable_length': readableText.length,
    'tokens': tokens,
    'id_like_counts': idLikeSummary.counts,
    'id_like_samples': idLikeSummary.samples,
    'has_image_hint': hasImageHint,
    'has_message_hint': hasMessageHint,
    'sample': _redactProbeSample(
      readableText.isEmpty ? event.payloadPreview : readableText,
    ),
  };
}

bool _isFeishuImGatewayProtobuf(FeishuNetworkCaptureEvent event) {
  if (event.source != FeishuNetworkEventSource.httpResponse) {
    return false;
  }
  final uri = Uri.tryParse(event.url.trim());
  final host = uri?.host.toLowerCase() ?? '';
  final path = uri?.path.toLowerCase() ?? '';
  if (!host.endsWith('internal-api-lark-api.feishu.cn') ||
      !path.startsWith('/im/gateway')) {
    return false;
  }
  final mimeType = event.mimeType.toLowerCase();
  return mimeType.contains('protobuf') || event.payloadPreview.isNotEmpty;
}

({Uint8List bytes, bool base64Detected}) _decodePayload(
  FeishuNetworkCaptureEvent event,
) {
  final payload = event.payloadPreview.trim();
  if (payload.isEmpty) {
    return (bytes: Uint8List(0), base64Detected: false);
  }
  if (event.bodyBase64Encoded) {
    return (
      bytes:
          _tryBase64Decode(payload) ?? Uint8List.fromList(utf8.encode(payload)),
      base64Detected: true,
    );
  }
  final detectedBytes = _looksLikeBase64(payload)
      ? _tryBase64Decode(payload)
      : null;
  if (detectedBytes != null) {
    return (bytes: detectedBytes, base64Detected: true);
  }
  return (
    bytes: Uint8List.fromList(utf8.encode(payload)),
    base64Detected: false,
  );
}

String _readableTextFromBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '';
  }
  final runs = <String>[];
  final buffer = StringBuffer();
  for (final byte in bytes) {
    if (_isReadableByte(byte)) {
      buffer.writeCharCode(byte);
      continue;
    }
    _flushReadableRun(buffer, runs);
  }
  _flushReadableRun(buffer, runs);
  if (runs.isNotEmpty) {
    return runs.join(' ');
  }
  return utf8.decode(bytes, allowMalformed: true);
}

bool _looksLikeBase64(String payload) {
  if (payload.length < 16 || payload.length % 4 != 0) {
    return false;
  }
  return RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(payload);
}

Uint8List? _tryBase64Decode(String payload) {
  try {
    return base64Decode(payload);
  } catch (_) {
    return null;
  }
}

bool _isReadableByte(int byte) {
  return byte == 9 || byte == 10 || byte == 13 || (byte >= 32 && byte <= 126);
}

void _flushReadableRun(StringBuffer buffer, List<String> runs) {
  if (buffer.length >= _minReadableRunLength) {
    runs.add(buffer.toString());
  }
  buffer.clear();
}

List<String> _matchedTokens(String readableText) {
  final lower = readableText.toLowerCase();
  final tokens =
      _interestingTokens
          .where((token) => lower.contains(token))
          .toList(growable: false)
        ..sort();
  return tokens;
}

({Map<String, Object?> counts, Map<String, Object?> samples}) _idLikeSummary(
  String readableText,
) {
  final patterns = <String, RegExp>{
    'conversation': RegExp(r'\boc_[A-Za-z0-9_-]{6,}\b'),
    'message': RegExp(r'\bom_[A-Za-z0-9_-]{6,}\b|\b\d{16,}\b'),
    'image_key': RegExp(r'\bimg_v[0-9]_[A-Za-z0-9_-]{6,}\b'),
    'file_key': RegExp(r'\bfile_v[0-9]_[A-Za-z0-9_-]{3,}\b'),
    'chat': RegExp(r'\bch_[A-Za-z0-9_-]{2,}\b'),
    'user': RegExp(r'\buser_[A-Za-z0-9_-]{2,}\b'),
  };

  final counts = <String, Object?>{};
  final samples = <String, Object?>{};
  for (final entry in patterns.entries) {
    final matches = entry.value.allMatches(readableText).toList();
    counts[entry.key] = matches.length;
    if (matches.isEmpty) {
      continue;
    }
    samples[entry.key] = matches
        .take(3)
        .map((match) => _redactedIdLikeSample(match.group(0)!))
        .toList(growable: false);
  }
  return (counts: counts, samples: samples);
}

String _redactedIdLikeSample(String value) {
  final underscore = value.indexOf('_');
  final prefix = underscore > 0 ? value.substring(0, underscore + 1) : '';
  return '<redacted:$prefix${value.length}>';
}

bool _isImageToken(String token) {
  return token.contains('image') ||
      token.contains('file_key') ||
      token.contains('resource_key') ||
      token.contains('origin') ||
      token.contains('preview') ||
      token.contains('thumbnail') ||
      token.contains('photo') ||
      token.contains('media') ||
      token.contains('imfile') ||
      token.contains('static-resource') ||
      token.contains('internal-api-lark-file');
}

bool _isMessageToken(String token) {
  return token.contains('conversation') ||
      token.contains('chat') ||
      token.contains('channel') ||
      token.contains('message') ||
      token.contains('msg') ||
      token.contains('sender') ||
      token.contains('from_name');
}

String _redactProbeSample(String readableText) {
  var sample = readableText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (sample.length > _maxProbeSampleLength) {
    sample = sample.substring(0, _maxProbeSampleLength);
  }
  sample = redactPayload(sample);
  sample = sample.replaceAllMapped(
    RegExp(
      r'\b(chat_id|channel_id|conversation_id|file_key|image_key|'
      r'message_id|msg_id|origin_key|resource_key)\b\s*[:=]?\s*'
      r'([A-Za-z0-9._~/-]+)',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}=<redacted>',
  );
  return sample;
}
