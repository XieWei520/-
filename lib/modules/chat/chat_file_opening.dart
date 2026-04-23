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
  final localCandidates = <String>[
    if (messageContent is WKFileContent) messageContent.localPath.trim(),
    _readStructuredString(structuredPayload, const [
      'localPath',
      'local_path',
      'path',
      'file_path',
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
    ]),
  ];
  for (final value in remoteCandidates) {
    final normalized = _normalizeRemoteUrl(value);
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

String _normalizeRemoteUrl(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final lowerValue = normalized.toLowerCase();
  if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
    return normalized;
  }
  if (_looksLikeRemotePath(normalized)) {
    return ApiConfig.resolveMediaUrl(normalized);
  }
  return '';
}

bool _looksLikeRemotePath(String value) {
  final normalized = value.trim();
  return normalized.startsWith('/v1/') ||
      normalized.startsWith('v1/') ||
      normalized.startsWith('/minio/') ||
      normalized.startsWith('minio/');
}
