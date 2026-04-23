import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_provider.dart';
import '../../modules/auth/application/auth_providers.dart';
import '../../modules/auth/domain/auth_flow_models.dart';

class AppRouterRefreshNotifier extends ChangeNotifier {
  AppRouterRefreshNotifier(this._ref) {
    _authSubscription = _ref.listen<AuthState>(authProvider, (previous, next) {
      if (_sameAuthRoutingSnapshot(previous, next)) {
        return;
      }
      notifyListeners();
    });
    _authFlowSubscription = _ref.listen<AuthFlowState>(
      authFlowControllerProvider,
      (previous, next) {
        if (_sameAuthFlowRoutingSnapshot(previous, next)) {
          return;
        }
        notifyListeners();
      },
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<AuthFlowState> _authFlowSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _authFlowSubscription.close();
    super.dispose();
  }
}

bool _sameAuthRoutingSnapshot(AuthState? previous, AuthState next) {
  if (previous == null) {
    return false;
  }
  return previous.isLoggedIn == next.isLoggedIn &&
      previous.isRestoringSession == next.isRestoringSession &&
      previous.needsProfileCompletion == next.needsProfileCompletion;
}

bool _sameAuthFlowRoutingSnapshot(
  AuthFlowState? previous,
  AuthFlowState next,
) {
  if (previous == null) {
    return false;
  }

  return previous.stage == next.stage &&
      _sameLoginVerificationRoutingContext(
        previous.loginVerificationContext,
        next.loginVerificationContext,
      );
}

bool _sameLoginVerificationRoutingContext(
  AuthLoginVerificationContext? previous,
  AuthLoginVerificationContext? next,
) {
  if (identical(previous, next)) {
    return true;
  }
  if (previous == null || next == null) {
    return false;
  }
  return previous.uid == next.uid &&
      previous.phone == next.phone &&
      previous.step == next.step &&
      previous.prefilledCode == next.prefilledCode;
}
