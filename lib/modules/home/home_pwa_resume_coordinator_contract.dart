typedef HomePwaResumeRecovery = Future<void> Function(String reason);

abstract interface class HomePwaResumeCoordinator {
  void start();

  void dispose();
}
