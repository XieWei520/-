import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers/auth_provider.dart';
import '../../modules/auth/application/auth_providers.dart';
import '../../modules/auth/presentation/pages/auth_device_sessions_page.dart';
import '../../modules/auth/login_page.dart';
import '../../modules/auth/presentation/pages/auth_third_login_page.dart';
import '../../modules/auth/presentation/pages/auth_login_verification_page.dart';
import '../../modules/auth/presentation/pages/auth_login_verification_code_page.dart';
import '../../modules/auth/presentation/pages/auth_profile_completion_page.dart';
import '../../modules/auth/presentation/pages/auth_register_page.dart';
import '../../modules/auth/presentation/pages/auth_reset_password_page.dart';
import '../../modules/auth/presentation/pages/auth_web_login_confirm_page.dart';
import '../../modules/chat/chat_page.dart';
import '../../modules/conversation/main_page.dart';
import 'app_route_location.dart';
import 'app_route_resolver.dart';
import 'app_router_refresh_notifier.dart';
import 'auth_route_page.dart';

String? _defaultRouteName(GoRouterState state) => state.name ?? state.path;

Map<String, String> _defaultRouteArguments(GoRouterState state) {
  return <String, String>{
    ...state.pathParameters,
    ...state.uri.queryParameters,
  };
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = AppRouterRefreshNotifier(ref);
  final router = GoRouter(
    initialLocation: AppRouteLocation.boot,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      return AppRouteResolver.resolve(
        authState: ref.read(authProvider),
        authFlowState: ref.read(authFlowControllerProvider),
        location: state.uri.toString(),
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRouteLocation.boot,
        builder: (context, state) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
      GoRoute(
        path: AppRouteLocation.login,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.register,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const AuthRegisterPage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.resetPassword,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const AuthResetPasswordPage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.loginVerification,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const AuthLoginVerificationPage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.loginVerificationCode,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const AuthLoginVerificationCodePage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.profileCompletion,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const AuthProfileCompletionPage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.authThirdLogin,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const AuthThirdLoginPage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.authDeviceSessions,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: const AuthDeviceSessionsPage(),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.authWebLoginConfirm,
        pageBuilder: (context, state) => buildAuthRoutePage<void>(
          key: state.pageKey,
          name: _defaultRouteName(state),
          arguments: _defaultRouteArguments(state),
          restorationId: state.pageKey.value,
          child: AuthWebLoginConfirmPage(
            authCode: state.uri.queryParameters['authCode'] ?? '',
            encrypt: state.uri.queryParameters['encrypt'],
          ),
        ),
      ),
      GoRoute(
        path: AppRouteLocation.home,
        builder: (context, state) => const MainPage(),
      ),
      GoRoute(
        path: AppRouteLocation.chatPath,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId'] ?? '';
          final channelType =
              int.tryParse(state.pathParameters['channelType'] ?? '') ?? 0;
          final channelName = state.uri.queryParameters['name'];
          return ChatPage(
            channelId: channelId,
            channelType: channelType,
            channelName: channelName,
          );
        },
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });

  return router;
});
