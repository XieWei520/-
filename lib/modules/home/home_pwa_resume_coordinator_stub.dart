import 'home_pwa_resume_coordinator_contract.dart';

HomePwaResumeCoordinator createHomePwaResumeCoordinator({
  required HomePwaResumeRecovery onRecover,
  Duration resumeThrottle = const Duration(seconds: 12),
}) {
  return const NoopHomePwaResumeCoordinator();
}

class NoopHomePwaResumeCoordinator implements HomePwaResumeCoordinator {
  const NoopHomePwaResumeCoordinator();

  @override
  void start() {}

  @override
  void dispose() {}
}
