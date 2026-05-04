import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/home/home_surface_contract.dart';
import 'package:wukong_im_app/modules/home/home_surface_kernel.dart';

void main() {
  test('records focused observability events for bootstrap and visibility', () {
    final sink = <String>[];
    final kernel = HomeSurfaceKernel(logEvent: sink.add);

    kernel.markBootstrapStart();
    kernel.markBootstrapReady();
    kernel.markSurfaceVisible(HomeSurfaceId.conversations);

    expect(sink, <String>[
      'home_bootstrap_start',
      'home_bootstrap_ready',
      'surface_visible:conversations',
    ]);
  });

  test('tracks per-surface reliability transitions', () {
    final sink = <String>[];
    final kernel = HomeSurfaceKernel(logEvent: sink.add);

    kernel.markSurfaceReliability(
      HomeSurfaceId.contacts,
      SurfaceReliabilityState.stale,
    );
    kernel.markSurfaceReliability(
      HomeSurfaceId.contacts,
      SurfaceReliabilityState.healthy,
    );

    expect(
      kernel.reliabilityFor(HomeSurfaceId.contacts),
      SurfaceReliabilityState.healthy,
    );
    expect(sink, <String>[
      'surface_stale:contacts',
      'surface_healthy:contacts',
    ]);
  });
}
