import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'wk_colors.dart';

class MediaDecodeRequest {
  const MediaDecodeRequest({
    required this.cacheWidth,
    required this.cacheHeight,
  });

  final int? cacheWidth;
  final int? cacheHeight;
}

const double _chatListMediaDecodeLogicalLimit = 200;

MediaDecodeRequest resolveChatListMediaDecodeRequest({
  required double devicePixelRatio,
  required double logicalWidth,
  required double logicalHeight,
  int intrinsicWidth = 0,
  int intrinsicHeight = 0,
}) {
  return resolveMediaDecodeRequest(
    devicePixelRatio: devicePixelRatio,
    logicalWidth: logicalWidth > 0
        ? math.min(logicalWidth, _chatListMediaDecodeLogicalLimit)
        : 0.0,
    logicalHeight: logicalHeight > 0
        ? math.min(logicalHeight, _chatListMediaDecodeLogicalLimit)
        : 0.0,
    intrinsicWidth: intrinsicWidth,
    intrinsicHeight: intrinsicHeight,
  );
}

MediaDecodeRequest resolveMediaDecodeRequest({
  required double devicePixelRatio,
  required double logicalWidth,
  required double logicalHeight,
  int intrinsicWidth = 0,
  int intrinsicHeight = 0,
}) {
  final normalizedRatio = devicePixelRatio > 0 ? devicePixelRatio : 1.0;
  var cacheWidth = logicalWidth > 0
      ? (logicalWidth * normalizedRatio).round()
      : null;
  var cacheHeight = logicalHeight > 0
      ? (logicalHeight * normalizedRatio).round()
      : null;

  if (cacheWidth != null && intrinsicWidth > 0) {
    cacheWidth = math.min(cacheWidth, intrinsicWidth);
  }
  if (cacheHeight != null && intrinsicHeight > 0) {
    cacheHeight = math.min(cacheHeight, intrinsicHeight);
  }

  return MediaDecodeRequest(cacheWidth: cacheWidth, cacheHeight: cacheHeight);
}

Size resolveAdaptiveMediaSize(
  BoxConstraints constraints, {
  required double preferredWidth,
  required double preferredHeight,
}) {
  final maxWidth = constraints.maxWidth.isFinite
      ? constraints.maxWidth
      : preferredWidth;
  final width = math.min(preferredWidth, math.max(0.0, maxWidth));
  if (width <= 0 || preferredWidth <= 0) {
    return Size.zero;
  }
  return Size(width, preferredHeight * (width / preferredWidth));
}

Widget mediaFallback({
  required double width,
  required double height,
  Widget? child,
  IconData icon = Icons.image_not_supported_outlined,
  Color backgroundColor = WKColors.surfaceMuted,
  Color iconColor = WKColors.textTertiary,
}) {
  return Container(
    width: width,
    height: height,
    color: backgroundColor,
    alignment: Alignment.center,
    child: child ?? Icon(icon, size: 44, color: iconColor),
  );
}

bool isBundledAssetPath(String source) {
  final normalized = source.replaceAll('\\', '/');
  return normalized.startsWith('assets/');
}

bool isLocalMediaPath(String mediaUrl) {
  if (mediaUrl.isEmpty) {
    return false;
  }
  if (isRemoteMediaPath(mediaUrl)) {
    return false;
  }
  final uri = Uri.tryParse(mediaUrl);
  if (uri != null && uri.scheme == 'file') {
    return true;
  }
  if (mediaUrl.startsWith('/')) {
    return true;
  }
  if (mediaUrl.startsWith(r'\\')) {
    return true;
  }
  return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(mediaUrl);
}

bool isRemoteMediaPath(String mediaUrl) {
  final value = mediaUrl.trim();
  if (value.isEmpty) {
    return false;
  }
  final lowerValue = value.toLowerCase().replaceAll('\\', '/');
  if (lowerValue.startsWith('http://') || lowerValue.startsWith('https://')) {
    return true;
  }
  final normalized = lowerValue.replaceFirst(RegExp(r'^/+'), '');
  if (normalized.startsWith('v1/file/preview/') ||
      normalized.startsWith('v1/file/download/') ||
      normalized.startsWith('minio/')) {
    return true;
  }
  for (final prefix in <String>[
    'chat/',
    'common/',
    'avatar/',
    'group/',
    'moment/',
    'report/',
    'download/',
    'sticker/',
    'chatbg/',
  ]) {
    if (normalized.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}
