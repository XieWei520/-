import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object>? resolveLocalMediaImageProvider(String mediaUrl) {
  final file = _resolveLocalMediaFile(mediaUrl);
  return file == null ? null : FileImage(file);
}

File? _resolveLocalMediaFile(String mediaUrl) {
  final normalized = mediaUrl.trim();
  if (normalized.isEmpty) {
    return null;
  }
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(normalized) ||
      normalized.startsWith(r'\\')) {
    return File(normalized);
  }
  if (normalized.startsWith('file://')) {
    final uri = Uri.tryParse(normalized);
    if (uri != null) {
      return File.fromUri(uri);
    }
    return File(normalized.substring('file://'.length));
  }
  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.scheme == 'file') {
    return File.fromUri(uri);
  }
  if (uri != null && uri.hasScheme) {
    return null;
  }
  return File(normalized);
}
