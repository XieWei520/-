import 'home_surface_contract.dart';

class HomeTabTransition {
  const HomeTabTransition({
    required this.hiddenSurface,
    required this.visibleSurface,
  });

  final HomeSurfaceId hiddenSurface;
  final HomeSurfaceId visibleSurface;
}

class HomeTabCoordinator {
  HomeTabCoordinator({int initialIndex = 0})
      : _currentIndex =
            _isValidIndex(initialIndex) ? initialIndex : 0;

  int _currentIndex;

  HomeTabTransition setIndex(int nextIndex) {
    final currentSurface = HomeSurfaceId.values[_currentIndex];
    if (!_isValidIndex(nextIndex)) {
      return HomeTabTransition(
        hiddenSurface: currentSurface,
        visibleSurface: currentSurface,
      );
    }

    final previous = currentSurface;
    _currentIndex = nextIndex;
    return HomeTabTransition(
      hiddenSurface: previous,
      visibleSurface: HomeSurfaceId.values[nextIndex],
    );
  }

  static bool _isValidIndex(int index) {
    return index >= 0 && index < HomeSurfaceId.values.length;
  }
}
