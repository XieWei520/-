import '../../../data/models/wk_custom_content.dart';

class AttachmentPipeline {
  const AttachmentPipeline();

  void normalizeFileMetadata(
    WKFileContent content, {
    required String localPath,
    int? inferredSize,
  }) {
    normalizeFileAttachmentMetadata(
      content,
      localPath: localPath,
      inferredSize: inferredSize,
    );
  }
}

void normalizeFileAttachmentMetadata(
  WKFileContent content, {
  required String localPath,
  int? inferredSize,
}) {
  content.name = _safeAttachmentFileName(content.name, fallbackPath: localPath);
  if (content.size <= 0 && inferredSize != null && inferredSize > 0) {
    content.size = inferredSize;
  } else if (content.size < 0) {
    content.size = 0;
  }
  if (content.suffix.trim().isEmpty) {
    content.suffix = _attachmentFileSuffix(
      name: content.name,
      fallbackPath: localPath,
    );
  }
}

String _safeAttachmentFileName(String name, {required String fallbackPath}) {
  final fromName = _lastSafeAttachmentPathSegment(name);
  if (fromName.isNotEmpty) {
    return fromName;
  }
  final fromPath = _lastSafeAttachmentPathSegment(fallbackPath);
  if (fromPath.isNotEmpty) {
    return fromPath;
  }
  return 'file';
}

String _lastSafeAttachmentPathSegment(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  if (cleaned.isEmpty) {
    return '';
  }
  final segments = cleaned
      .split(RegExp(r'[\\/]+'))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .where((segment) => segment != '.' && segment != '..')
      .toList(growable: false);
  if (segments.isEmpty) {
    return '';
  }
  return segments.last;
}

String _attachmentFileSuffix({
  required String name,
  required String fallbackPath,
}) {
  final safeName = _safeAttachmentFileName(name, fallbackPath: fallbackPath);
  final dotIndex = safeName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == safeName.length - 1) {
    return '';
  }
  return safeName.substring(dotIndex + 1).trim().toLowerCase();
}
