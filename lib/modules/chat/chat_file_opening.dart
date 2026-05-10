import 'package:url_launcher/url_launcher.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';

import '../../core/config/api_config.dart';
import '../../data/models/wk_custom_content.dart';

enum ChatFileOpenTargetType { localFile, remoteUrl }

class ChatFileOpenTarget {
  const ChatFileOpenTarget({required this.type, required this.value});

  final ChatFileOpenTargetType type;
  final String value;

  Uri toUri() {
    if (type == ChatFileOpenTargetType.remoteUrl) {
      return Uri.parse(value);
    }
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.scheme == 'file') {
      return parsed;
    }
    final isWindows = RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
    return Uri.file(value, windows: isWindows);
  }
}

typedef ChatFileUriLauncher = Future<bool> Function(Uri uri);

ChatFileOpenTarget? resolveChatFileOpenTarget({
  WKMessageContent? messageContent,
  Map<String, dynamic>? structuredPayload,
}) {
  final fileName = _fileNameOf(messageContent, structuredPayload);
  final localCandidates = <String>[
    if (messageContent is WKFileContent) messageContent.localPath.trim(),
    _readStructuredString(structuredPayload, const [
      'localPath',
      'local_path',
      'file_path',
      'filePath',
    ]),
  ];
  for (final value in localCandidates) {
    if (_isLocalPath(value)) {
      return ChatFileOpenTarget(
        type: ChatFileOpenTargetType.localFile,
        value: value,
      );
    }
  }

  final remoteCandidates = <String>[
    if (messageContent is WKFileContent) messageContent.url.trim(),
    _readStructuredString(structuredPayload, const [
      'download_url',
      'downloadUrl',
      'url',
      'file_url',
      'fileUrl',
      'path',
    ]),
  ];
  for (final value in remoteCandidates) {
    final normalized = _normalizeRemoteUrl(value, fileName: fileName);
    if (normalized.isNotEmpty) {
      return ChatFileOpenTarget(
        type: ChatFileOpenTargetType.remoteUrl,
        value: normalized,
      );
    }
  }
  return null;
}

Future<bool> openChatFileTarget(
  ChatFileOpenTarget target, {
  ChatFileUriLauncher? launcher,
}) {
  final resolvedLauncher =
      launcher ??
      (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
  return resolvedLauncher(target.toUri());
}

String _readStructuredString(Map<String, dynamic>? payload, List<String> keys) {
  if (payload == null) {
    return '';
  }
  for (final key in keys) {
    final value = payload[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String _fileNameOf(
  WKMessageContent? messageContent,
  Map<String, dynamic>? payload,
) {
  final candidates = <String>[
    if (messageContent is WKFileContent) messageContent.name.trim(),
    _readStructuredString(payload, const [
      'name',
      'fileName',
      'file_name',
      'filename',
    ]),
  ];
  for (final value in candidates) {
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

bool _isLocalPath(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return false;
  }
  if (_looksLikeRemotePath(normalized)) {
    return false;
  }
  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.scheme == 'file') {
    return true;
  }
  if (normalized.startsWith('/')) {
    return true;
  }
  if (normalized.startsWith(r'\\')) {
    return true;
  }
  return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(normalized);
}

String _normalizeRemoteUrl(String value, {String fileName = ''}) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final lowerValue = normalized.toLowerCase();
  if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.trim().isEmpty) {
      return '';
    }
    return _withAttachmentDisposition(
      ApiConfig.resolveMediaUrl(normalized),
      fileName: fileName,
    );
  }
  if (_looksLikeRemotePath(normalized)) {
    return _withAttachmentDisposition(
      ApiConfig.resolveMediaUrl(_toMinioDownloadPath(normalized)),
      fileName: fileName,
    );
  }
  return '';
}

bool _looksLikeRemotePath(String value) {
  final normalized = value.trim().replaceAll('\\', '/');
  final path = normalized.replaceFirst(RegExp(r'^/+'), '');
  return normalized.startsWith('/v1/') ||
      normalized.startsWith('v1/') ||
      normalized.startsWith('/minio/') ||
      normalized.startsWith('minio/') ||
      _looksLikeFileServicePath(path) ||
      _looksLikeMinioObjectPath(path);
}

bool _looksLikeFileServicePath(String path) {
  return path.startsWith('file/preview/') ||
      path.startsWith('file/download/');
}

bool _looksLikeMinioObjectPath(String path) {
  return path.startsWith('chat/') ||
      path.startsWith('common/') ||
      path.startsWith('avatar/') ||
      path.startsWith('group/') ||
      path.startsWith('moment/') ||
      path.startsWith('report/') ||
      path.startsWith('download/') ||
      path.startsWith('sticker/') ||
      path.startsWith('chatbg/');
}

String _toMinioDownloadPath(String value) {
  final normalized = value.trim().replaceAll('\\', '/');
  final withoutLeadingSlash = normalized.replaceFirst(RegExp(r'^/+'), '');
  for (final prefix in <String>[
    'v1/file/preview/',
    'v1/file/download/',
    'file/preview/',
    'file/download/',
    'minio/',
  ]) {
    if (withoutLeadingSlash.startsWith(prefix)) {
      return 'minio/${withoutLeadingSlash.substring(prefix.length)}';
    }
  }
  if (_looksLikeMinioObjectPath(withoutLeadingSlash)) {
    return 'minio/$withoutLeadingSlash';
  }
  return normalized;
}

String _withAttachmentDisposition(String value, {required String fileName}) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.host.trim().isEmpty) {
    return value;
  }
  final minioUri = _asMinioUri(uri);
  if (minioUri == null) {
    return value;
  }
  final parameters = Map<String, String>.from(minioUri.queryParameters);
  parameters['response-content-disposition'] =
      'attachment; filename="${_safeDispositionFileName(fileName, minioUri)}"';
  return minioUri.replace(queryParameters: parameters).toString();
}

Uri? _asMinioUri(Uri uri) {
  final normalizedPath = uri.path.replaceAll('\\', '/');
  const previewPrefix = '/v1/file/preview/';
  const downloadPrefix = '/v1/file/download/';
  if (normalizedPath.startsWith('/minio/')) {
    return uri;
  }
  if (normalizedPath.startsWith(previewPrefix)) {
    return uri.replace(
      path: '/minio/${normalizedPath.substring(previewPrefix.length)}',
    );
  }
  if (normalizedPath.startsWith(downloadPrefix)) {
    return uri.replace(
      path: '/minio/${normalizedPath.substring(downloadPrefix.length)}',
    );
  }
  return null;
}

String _safeDispositionFileName(String fileName, Uri uri) {
  final fromName = fileName.trim();
  final fromPath = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last.trim();
  final candidate = fromName.isNotEmpty ? fromName : fromPath;
  final cleaned = candidate
      .replaceAll(RegExp(r'[\x00-\x1F\x7F"]+'), '')
      .replaceAll(RegExp(r'[\\/]+'), '_')
      .trim();
  return cleaned.isEmpty ? 'download' : cleaned;
}
