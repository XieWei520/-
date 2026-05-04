import 'package:flutter/foundation.dart';

enum HomeSurfaceId { conversations, contacts, user }

enum SurfaceReliabilityState { healthy, stale, degraded, failed }

enum HomeSurfaceVisibilityState { cold, warm, visible, backgroundAlive }

@immutable
class HomeSurfacePrefetchHint {
  const HomeSurfacePrefetchHint({
    required this.surfaceId,
    this.critical = false,
    this.adjacent = false,
    this.idle = false,
  });

  final HomeSurfaceId surfaceId;
  final bool critical;
  final bool adjacent;
  final bool idle;
}

@immutable
class HomeSurfaceContract {
  const HomeSurfaceContract({
    required this.surfaceId,
    required this.badgeCount,
    required this.reliabilityState,
    required this.prefetchHint,
  });

  final HomeSurfaceId surfaceId;
  final int badgeCount;
  final SurfaceReliabilityState reliabilityState;
  final HomeSurfacePrefetchHint prefetchHint;
}
