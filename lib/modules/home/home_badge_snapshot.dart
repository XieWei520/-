import 'package:flutter/foundation.dart';

import 'home_surface_contract.dart';

@immutable
class HomeBadgeSnapshot {
  HomeBadgeSnapshot({Map<HomeSurfaceId, int> bySurface = const <HomeSurfaceId, int>{}})
      : bySurface = Map<HomeSurfaceId, int>.unmodifiable(bySurface);

  final Map<HomeSurfaceId, int> bySurface;

  int badgeFor(HomeSurfaceId surfaceId) => bySurface[surfaceId] ?? 0;

  int get totalUnread =>
      bySurface.values.fold<int>(0, (sum, value) => sum + value);
}
