import 'home_surface_contract.dart';

class HomeSurfaceVisibilityController {
  HomeSurfaceVisibilityController(HomeSurfaceId initialSurface)
      : _states = <HomeSurfaceId, HomeSurfaceVisibilityState>{
          for (final surface in HomeSurfaceId.values)
            surface: surface == initialSurface
                ? HomeSurfaceVisibilityState.visible
                : HomeSurfaceVisibilityState.cold,
        };

  final Map<HomeSurfaceId, HomeSurfaceVisibilityState> _states;

  HomeSurfaceVisibilityState stateFor(HomeSurfaceId surfaceId) =>
      _states[surfaceId] ?? HomeSurfaceVisibilityState.cold;

  void markVisible(HomeSurfaceId surfaceId) {
    for (final entry in _states.entries.toList()) {
      if (entry.key == surfaceId) {
        _states[entry.key] = HomeSurfaceVisibilityState.visible;
        continue;
      }

      if (entry.value == HomeSurfaceVisibilityState.cold) {
        _states[entry.key] = HomeSurfaceVisibilityState.cold;
        continue;
      }

      _states[entry.key] = HomeSurfaceVisibilityState.backgroundAlive;
    }
  }
}
