import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'feishu_network_capture.dart';

const int feishuBrowserImageBodyMaxBytes = 25 * 1024 * 1024;

class FeishuBrowserImageBody {
  const FeishuBrowserImageBody({
    required this.sourceUrl,
    required this.mimeType,
    required this.bodyBase64,
    required this.bodySize,
    required this.width,
    required this.height,
    required this.conversationId,
    required this.conversationName,
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

  factory FeishuBrowserImageBody.fromJson(Map<String, dynamic> json) {
    return FeishuBrowserImageBody(
      sourceUrl: _stringValue(json['source_url']),
      mimeType: _stringValue(json['mime_type']),
      bodyBase64: _stringValue(json['body_base64']),
      bodySize: _intValue(json['body_size']),
      width: _intValue(json['width']),
      height: _intValue(json['height']),
      conversationId: _stringValue(json['conversation_id']),
      conversationName: _stringValue(json['conversation_name']),
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
  final String mimeType;
  final String bodyBase64;
  final int bodySize;
  final int width;
  final int height;
  final String conversationId;
  final String conversationName;
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
}

class FeishuBrowserImageBodySaveResult {
  const FeishuBrowserImageBodySaveResult({
    this.candidate,
    this.attribution,
    this.error = '',
  });

  final FeishuNetworkImageCandidate? candidate;
  final FeishuNetworkImageAttribution? attribution;
  final String error;
}

Future<FeishuBrowserImageBodySaveResult> saveFeishuBrowserImageBody(
  FeishuBrowserImageBody body, {
  required Directory cacheDirectory,
}) async {
  final sourceUrl = body.sourceUrl.trim();
  final mimeType = _normalizedImageMimeType(body.mimeType);
  if (sourceUrl.isEmpty) {
    return const FeishuBrowserImageBodySaveResult(error: 'missing_source_url');
  }
  if (mimeType.isEmpty) {
    return const FeishuBrowserImageBodySaveResult(error: 'unsupported_mime');
  }
  late final List<int> bytes;
  try {
    bytes = base64Decode(body.bodyBase64.trim());
  } on FormatException {
    return const FeishuBrowserImageBodySaveResult(error: 'decode_failed');
  }
  if (bytes.isEmpty) {
    return const FeishuBrowserImageBodySaveResult(error: 'empty_body');
  }
  if (bytes.length > feishuBrowserImageBodyMaxBytes) {
    return const FeishuBrowserImageBodySaveResult(error: 'body_too_large');
  }
  if (body.bodySize > 0 && body.bodySize != bytes.length) {
    return const FeishuBrowserImageBodySaveResult(error: 'body_size_mismatch');
  }

  await cacheDirectory.create(recursive: true);
  final bodySha1 = sha1.convert(bytes).toString();
  final path =
      '${cacheDirectory.path}${Platform.pathSeparator}$bodySha1.${_extensionForMimeType(mimeType)}';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  final candidate = FeishuNetworkImageCandidate(
    conversationId: body.conversationId,
    conversationName: body.conversationName,
    messageId: 'browser_image:$bodySha1',
    senderName: body.senderName,
    resourceUrl: sourceUrl,
    resourceKey: '',
    width: body.width,
    height: body.height,
    quality: FeishuNetworkImageQuality.original,
    observedAt: body.observedAt,
    localPath: path,
    bodySha1: bodySha1,
    bodySize: bytes.length,
    bodyMimeType: mimeType,
    requestResourceType: 'browser_preview_blob',
    requestDocumentUrl: sourceUrl,
    requestInitiatorType: 'browser_preview_blob',
  );
  final attribution = FeishuNetworkImageAttribution(
    sourceUrl: sourceUrl,
    sourceKind: sourceUrl.startsWith('blob:') ? 'blob' : 'url',
    blobMimeType: mimeType,
    blobSize: bytes.length,
    conversationId: body.conversationId,
    conversationName: body.conversationName,
    messageId: '',
    senderName: body.senderName,
    displayTime: body.displayTime,
    messageText: body.messageText,
    feedCardId: body.feedCardId,
    feedCardText: body.feedCardText,
    confidence: body.confidence,
    confidenceLabel: body.confidenceLabel,
    reason: body.reason,
    observedAt: body.observedAt,
    evidence: body.evidence,
  );
  return FeishuBrowserImageBodySaveResult(
    candidate: candidate,
    attribution: attribution,
  );
}

String _normalizedImageMimeType(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('image/') ? normalized : '';
}

String _extensionForMimeType(String mimeType) {
  final normalized = mimeType.trim().toLowerCase();
  if (normalized.contains('png')) {
    return 'png';
  }
  if (normalized.contains('jpeg') || normalized.contains('jpg')) {
    return 'jpg';
  }
  if (normalized.contains('gif')) {
    return 'gif';
  }
  if (normalized.contains('webp')) {
    return 'webp';
  }
  return 'img';
}

String _stringValue(Object? value) => value == null ? '' : '$value';

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(_stringValue(value)) ?? 0;
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(_stringValue(value)) ?? 0;
}

DateTime _dateTimeValue(Object? value) {
  return DateTime.tryParse(_stringValue(value))?.toUtc() ??
      DateTime.now().toUtc();
}

List<String> _stringListValue(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((item) => '$item'.trim()).where((item) {
    return item.isNotEmpty;
  }).toList(growable: false);
}
