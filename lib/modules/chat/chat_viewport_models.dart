import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double olderMessageLoadExtentAfterThreshold = 300;

bool shouldTriggerOlderMessageLoad({
  required double extentAfter,
  double threshold = olderMessageLoadExtentAfterThreshold,
}) {
  return extentAfter < threshold;
}

double chatListCacheExtent({
  required double viewportHeight,
  required TargetPlatform platform,
  required bool isWeb,
}) {
  final safeHeight = viewportHeight.isFinite && viewportHeight > 0
      ? viewportHeight
      : 800.0;
  final isDesktop =
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.macOS ||
      platform == TargetPlatform.linux;
  final isMobile = !isWeb && !isDesktop;
  final multiplier = isWeb
      ? 0.9
      : isDesktop
      ? 1.5
      : 0.66;
  final minExtent = isDesktop && !isWeb ? 900.0 : 600.0;
  final maxExtent = isWeb
      ? 1000.0
      : isDesktop
      ? 1600.0
      : isMobile
      ? 900.0
      : 1200.0;
  return (safeHeight * multiplier).clamp(minExtent, maxExtent).toDouble();
}

int? roundFiniteViewportOffset(double value) {
  if (!value.isFinite) {
    return null;
  }
  return value.round();
}

@immutable
class ChatViewportPersistenceSnapshot {
  const ChatViewportPersistenceSnapshot({
    this.keepMessageSeq = 0,
    this.keepOffsetY = 0,
    this.maxVisibleMessageSeq = 0,
  });

  final int keepMessageSeq;
  final int keepOffsetY;
  final int maxVisibleMessageSeq;
}

@immutable
class ChatViewportRestoreResult {
  const ChatViewportRestoreResult({
    required this.keepMessageSeq,
    required this.requestedOffsetY,
    required this.appliedOffsetY,
  });

  final int keepMessageSeq;
  final int requestedOffsetY;
  final int appliedOffsetY;
}
