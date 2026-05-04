import 'dart:async';

import 'home_surface_contract.dart';

enum HomeInvalidationKind { structural, decorative, viewportTriggered, session }

class HomeSurfaceInvalidation {
  const HomeSurfaceInvalidation({
    required this.surfaceId,
    required this.kind,
    this.key,
  });

  final HomeSurfaceId surfaceId;
  final HomeInvalidationKind kind;
  final String? key;
}

class HomeSurfaceInvalidationBus {
  final StreamController<HomeSurfaceInvalidation> _controller =
      StreamController<HomeSurfaceInvalidation>.broadcast();

  Stream<HomeSurfaceInvalidation> get stream => _controller.stream;

  void emit(HomeSurfaceInvalidation event) => _controller.add(event);

  Future<void> dispose() => _controller.close();
}
