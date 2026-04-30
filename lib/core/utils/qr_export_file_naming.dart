String safeQrExportFilePrefix(String prefix, {String fallback = 'qrcode'}) {
  final normalized = prefix
      .trim()
      .replaceAll('\\', '/')
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList();
  final candidate = normalized.isNotEmpty ? normalized.last : prefix.trim();
  final withoutQuery = candidate.split('?').first.split('#').first.trim();
  var cleaned = withoutQuery
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[\s._]+|[\s._]+$'), '');

  if (cleaned.toLowerCase().endsWith('.png')) {
    cleaned = cleaned.substring(0, cleaned.length - 4);
  }

  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return fallback;
  }

  return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
}

String qrExportPngFileName({
  required String fileNamePrefix,
  required int timestampMs,
  required String fallbackPrefix,
}) {
  final prefix = safeQrExportFilePrefix(
    fileNamePrefix,
    fallback: fallbackPrefix,
  );
  return '${prefix}_$timestampMs.png';
}
