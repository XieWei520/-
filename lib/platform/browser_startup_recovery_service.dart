import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_startup_recovery_service_stub.dart'
    if (dart.library.js_interop) 'browser_startup_recovery_service_web.dart';

abstract class BrowserStartupRecoveryService {
  const BrowserStartupRecoveryService();

  /// Returns true when recovery has started a page-level reload/navigation.
  Future<bool> recoverFromStartupFailure();

  /// Returns true after a browser-level reset has already been attempted.
  bool get hasRecoveredStartupFailure;

  /// Clears a broken local browser session and returns the user to login.
  Future<bool> resetDamagedSession();
}

class NoopBrowserStartupRecoveryService
    extends BrowserStartupRecoveryService {
  const NoopBrowserStartupRecoveryService();

  @override
  Future<bool> recoverFromStartupFailure() async => false;

  @override
  bool get hasRecoveredStartupFailure => false;

  @override
  Future<bool> resetDamagedSession() async => false;
}

BrowserStartupRecoveryService createBrowserStartupRecoveryService() =>
    createPlatformBrowserStartupRecoveryService();

final browserStartupRecoveryServiceProvider =
    Provider<BrowserStartupRecoveryService>((ref) {
      return createBrowserStartupRecoveryService();
    });
