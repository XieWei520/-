String downloadFileNameFromUrl(String url, {String fallback = 'download.bin'}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }

  final parsed = Uri.tryParse(trimmed);
  final segments = parsed?.pathSegments
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();
  final rawName = segments?.isNotEmpty == true ? segments!.last : trimmed;
  return safeDownloadFileName(rawName, fallback: fallback);
}

String safeDownloadFileName(
  String fileName, {
  String fallback = 'download.bin',
}) {
  final normalized = fileName
      .trim()
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList();
  final candidate = normalized.isNotEmpty ? normalized.last : fileName.trim();
  final withoutQuery = candidate.split('?').first.split('#').first.trim();
  final cleaned = withoutQuery
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[\s._]+|[\s._]+$'), '');

  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return fallback;
  }

  final reserved = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
    caseSensitive: false,
  );
  if (reserved.hasMatch(cleaned)) {
    return '${cleaned}_file';
  }

  return _clampFileName(cleaned, maxLength: 120, fallback: fallback);
}

String _clampFileName(
  String value, {
  required int maxLength,
  required String fallback,
}) {
  if (value.length <= maxLength) {
    return value;
  }

  final dot = value.lastIndexOf('.');
  if (dot <= 0 || dot == value.length - 1) {
    return value.substring(0, maxLength);
  }

  final extension = value.substring(dot);
  final nameBudget = maxLength - extension.length;
  if (nameBudget <= 0) {
    return fallback;
  }
  return '${value.substring(0, nameBudget)}$extension';
}
