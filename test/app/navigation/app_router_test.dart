import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/app/navigation/app_route_location.dart';
import 'package:wukong_im_app/app/navigation/app_route_resolver.dart';
import 'package:wukong_im_app/app/navigation/app_router.dart';
import 'package:wukong_im_app/app/navigation/app_router_refresh_notifier.dart';
import 'package:wukong_im_app/data/models/user.dart';
import 'package:wukong_im_app/data/providers/auth_provider.dart';
import 'package:wukong_im_app/modules/auth/domain/auth_flow_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppRouteResolver', () {
    const defaultFlowState = AuthFlowState();

    test('initializing auth redirects non-boot routes to boot', () {
      final redirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: false,
          isRestoringSession: true,
        ),
        authFlowState: defaultFlowState,
        location: AppRouteLocation.login,
      );

      expect(redirect, AppRouteLocation.boot);
    });

    test('logged out users redirect to login', () {
      final redirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: false,
          isRestoringSession: false,
        ),
        authFlowState: defaultFlowState,
        location: AppRouteLocation.home,
      );

      expect(redirect, AppRouteLocation.login);
    });

    test('submit loading does not redirect logged out login route to boot', () {
      final redirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: true,
          isRestoringSession: false,
        ),
        authFlowState: defaultFlowState,
        location: AppRouteLocation.login,
      );

      expect(redirect, isNull);
    });

    test('logged out users can stay on register and reset password routes', () {
      final registerRedirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: false,
          isRestoringSession: false,
        ),
        authFlowState: defaultFlowState,
        location: AppRouteLocation.register,
      );
      final resetRedirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: false,
          isRestoringSession: false,
        ),
        authFlowState: defaultFlowState,
        location: AppRouteLocation.resetPassword,
      );

      expect(registerRedirect, isNull);
      expect(resetRedirect, isNull);
    });

    test('awaiting login verification redirects to verification route', () {
      final redirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: false,
          isRestoringSession: false,
        ),
        authFlowState: AuthFlowState(
          stage: AuthStage.awaitingLoginVerification,
          loginVerificationContext: const AuthLoginVerificationContext(
            uid: 'u-verify',
            phone: '13800138000',
          ),
        ),
        location: AppRouteLocation.login,
      );

      expect(redirect, AppRouteLocation.loginVerification);
    });

    test('verification code step redirects to the code entry route', () {
      final redirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: false,
          isRestoringSession: false,
        ),
        authFlowState: AuthFlowState(
          stage: AuthStage.awaitingLoginVerification,
          loginVerificationContext: const AuthLoginVerificationContext(
            uid: 'u-verify',
            phone: '13800138000',
            step: AuthLoginVerificationStep.codeEntry,
          ),
        ),
        location: AppRouteLocation.loginVerification,
      );

      expect(redirect, AppRouteLocation.loginVerificationCode);
    });

    test(
      'logged in users needing profile completion redirect to profile route',
      () {
        final redirect = AppRouteResolver.resolve(
          authState: AuthState(
            isLoggedIn: true,
            needsProfileCompletion: true,
            isLoading: false,
            isRestoringSession: false,
          ),
          authFlowState: defaultFlowState,
          location: AppRouteLocation.home,
        );

        expect(redirect, AppRouteLocation.profileCompletion);
      },
    );

    test('logged in users redirect away from login to home', () {
      final redirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: true,
          isLoading: false,
          isRestoringSession: false,
        ),
        authFlowState: defaultFlowState,
        location: AppRouteLocation.login,
      );

      expect(redirect, AppRouteLocation.home);
    });

    test('malformed locations do not crash route redirects', () {
      final redirect = AppRouteResolver.resolve(
        authState: AuthState(
          isLoggedIn: false,
          isLoading: false,
          isRestoringSession: false,
        ),
        authFlowState: defaultFlowState,
        location: 'http://[::1',
      );

      expect(redirect, AppRouteLocation.login);
    });
  });

  group('AppRouteLocation', () {
    test('chat route encodes id and query name', () {
      final location = AppRouteLocation.chat(
        channelType: 2,
        channelId: 'team/alpha one',
        channelName: 'Alice & Bob',
      );

      expect(location, '/chat/2/team%2Falpha%20one?name=Alice+%26+Bob');
    });
  });

  test('app router instance stays stable across current user updates', () {
    late _TestAuthNotifier authNotifier;
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) {
          authNotifier = _TestAuthNotifier(
            ref,
            initialState: AuthState(
              isLoggedIn: true,
              isRestoringSession: false,
              userInfo: UserInfo(uid: 'u_self', name: 'Tester'),
            ),
          );
          return authNotifier;
        }),
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    final initialRouter = container.read(appRouterProvider);
    container.read(authProvider.notifier);

    authNotifier.updateCurrentUser(
      UserInfo(uid: 'u_self', name: 'Tester Updated'),
    );

    final nextRouter = container.read(appRouterProvider);

    expect(identical(initialRouter, nextRouter), isTrue);
  });

  test('app router refresh notifier ignores current user profile updates', () {
    late _TestAuthNotifier authNotifier;
    final refreshNotifierProvider = Provider<AppRouterRefreshNotifier>((ref) {
      final notifier = AppRouterRefreshNotifier(ref);
      ref.onDispose(notifier.dispose);
      return notifier;
    });
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith((ref) {
          authNotifier = _TestAuthNotifier(
            ref,
            initialState: AuthState(
              isLoggedIn: true,
              isRestoringSession: false,
              userInfo: UserInfo(uid: 'u_self', name: 'Tester'),
            ),
          );
          return authNotifier;
        }),
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(refreshNotifierProvider);
    container.read(authProvider.notifier);
    var notifications = 0;
    notifier.addListener(() {
      notifications += 1;
    });

    authNotifier.updateCurrentUser(
      UserInfo(uid: 'u_self', name: 'Tester Updated'),
    );

    expect(notifications, 0);
  });
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(super.ref, {required AuthState initialState}) : super() {
    state = initialState;
  }
}
