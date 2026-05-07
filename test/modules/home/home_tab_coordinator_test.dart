import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';
import 'package:wukong_im_app/modules/home/home_surface_invalidation_bus.dart';
import 'package:wukong_im_app/modules/home/home_surface_visibility_controller.dart';
import 'package:wukong_im_app/modules/home/home_tab_coordinator.dart';

void main() {
  test('tab coordinator returns hidden and visible surface ids', () {
    final coordinator = HomeTabCoordinator(initialIndex: 0);

    final transition = coordinator.setIndex(1);

    expect(transition.hiddenSurface, HomeSurfaceId.conversations);
    expect(transition.visibleSurface, HomeSurfaceId.contacts);
  });

  test('tab coordinator ignores out of range indices', () {
    final coordinator = HomeTabCoordinator(initialIndex: -1);

    final transition = coordinator.setIndex(HomeSurfaceId.values.length);

    expect(transition.hiddenSurface, HomeSurfaceId.conversations);
    expect(transition.visibleSurface, HomeSurfaceId.conversations);
  });

  test('visibility controller keeps cold surfaces cold', () {
    final controller = HomeSurfaceVisibilityController(
      HomeSurfaceId.conversations,
    );

    controller.markVisible(HomeSurfaceId.contacts);

    expect(
      controller.stateFor(HomeSurfaceId.user),
      HomeSurfaceVisibilityState.cold,
    );
    expect(
      controller.stateFor(HomeSurfaceId.conversations),
      HomeSurfaceVisibilityState.backgroundAlive,
    );
    expect(
      controller.stateFor(HomeSurfaceId.contacts),
      HomeSurfaceVisibilityState.visible,
    );
  });

  test('invalidation bus closes stream on dispose', () async {
    final bus = HomeSurfaceInvalidationBus();
    final done = expectLater(bus.stream, emitsDone);

    await bus.dispose();

    await done;
    expect(
      () => bus.emit(
        const HomeSurfaceInvalidation(
          surfaceId: HomeSurfaceId.conversations,
          kind: HomeInvalidationKind.structural,
        ),
      ),
      throwsStateError,
    );
  });
}
