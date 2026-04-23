import '../../data/providers/auth_provider.dart';
import '../../modules/auth/domain/auth_flow_models.dart';
import 'app_route_location.dart';

class AppRouteResolver {
  static String? resolve({
    required AuthState authState,
    required AuthFlowState authFlowState,
    required String location,
  }) {
    final path = _normalizePath(location);

    if (authState.isRestoringSession) {
      if (path != AppRouteLocation.boot) {
        return AppRouteLocation.boot;
      }
      return null;
    }

    if (authFlowState.stage == AuthStage.awaitingLoginVerification &&
        authFlowState.loginVerificationContext != null) {
      final targetRoute =
          authFlowState.loginVerificationContext!.step ==
              AuthLoginVerificationStep.codeEntry
          ? AppRouteLocation.loginVerificationCode
          : AppRouteLocation.loginVerification;
      if (path != targetRoute) {
        return targetRoute;
      }
      return null;
    }

    if (authState.isLoggedIn && authState.needsProfileCompletion) {
      if (path != AppRouteLocation.profileCompletion) {
        return AppRouteLocation.profileCompletion;
      }
      return null;
    }

    if (!authState.isLoggedIn) {
      if (_guestRoutes.contains(path)) {
        return null;
      }
      return AppRouteLocation.login;
    }

    if (path == AppRouteLocation.root ||
        path == AppRouteLocation.boot ||
        _guestRoutes.contains(path) ||
        path == AppRouteLocation.loginVerification ||
        path == AppRouteLocation.loginVerificationCode ||
        path == AppRouteLocation.profileCompletion) {
      return AppRouteLocation.home;
    }

    return null;
  }

  static const Set<String> _guestRoutes = <String>{
    AppRouteLocation.login,
    AppRouteLocation.register,
    AppRouteLocation.resetPassword,
    AppRouteLocation.authThirdLogin,
  };

  static String _normalizePath(String location) {
    final path = Uri.parse(location).path.trim();
    if (path.isEmpty) {
      return AppRouteLocation.root;
    }
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }
}
