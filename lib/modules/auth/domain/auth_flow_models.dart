import 'package:flutter/foundation.dart';

import '../../../data/models/user.dart';

enum AuthStage {
  restoringSession,
  unauthenticated,
  submittingCredentials,
  awaitingLoginVerification,
  awaitingRegistrationCode,
  awaitingPasswordResetCode,
  awaitingProfileCompletion,
  bootstrappingAuthenticatedSession,
  authenticatedReady,
}

enum AuthLoginVerificationStep { introduction, codeEntry }

@immutable
class AuthLoginVerificationContext {
  const AuthLoginVerificationContext({
    required this.uid,
    this.phone,
    this.step = AuthLoginVerificationStep.introduction,
    this.prefilledCode,
  });

  final String uid;
  final String? phone;
  final AuthLoginVerificationStep step;
  final String? prefilledCode;

  AuthLoginVerificationContext copyWith({
    String? uid,
    Object? phone = _sentinel,
    AuthLoginVerificationStep? step,
    Object? prefilledCode = _sentinel,
  }) {
    return AuthLoginVerificationContext(
      uid: uid ?? this.uid,
      phone: identical(phone, _sentinel) ? this.phone : phone as String?,
      step: step ?? this.step,
      prefilledCode: identical(prefilledCode, _sentinel)
          ? this.prefilledCode
          : prefilledCode as String?,
    );
  }

  static const Object _sentinel = Object();
}

@immutable
class AuthFlowState {
  const AuthFlowState({
    this.stage = AuthStage.unauthenticated,
    this.zone = '86',
    this.isLoading = false,
    this.errorMessage,
    this.loginVerificationContext,
  });

  final AuthStage stage;
  final String zone;
  final bool isLoading;
  final String? errorMessage;
  final AuthLoginVerificationContext? loginVerificationContext;

  AuthFlowState copyWith({
    AuthStage? stage,
    String? zone,
    bool? isLoading,
    Object? errorMessage = _sentinel,
    Object? loginVerificationContext = _sentinel,
  }) {
    return AuthFlowState(
      stage: stage ?? this.stage,
      zone: zone ?? this.zone,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      loginVerificationContext: identical(loginVerificationContext, _sentinel)
          ? this.loginVerificationContext
          : loginVerificationContext as AuthLoginVerificationContext?,
    );
  }

  static const Object _sentinel = Object();
}

@immutable
class AuthCredentialResult {
  const AuthCredentialResult.success({
    required this.uid,
    required this.token,
    this.imToken = '',
    required this.user,
  }) : success = true,
       requiresLoginVerification = false,
       loginVerificationContext = null,
       message = null;

  const AuthCredentialResult.failure(this.message)
    : success = false,
      requiresLoginVerification = false,
      uid = '',
      token = '',
      imToken = '',
      user = null,
      loginVerificationContext = null;

  AuthCredentialResult.verificationRequired({
    required this.uid,
    String? phone,
    this.message,
  }) : success = false,
       requiresLoginVerification = true,
       token = '',
       imToken = '',
       user = null,
       loginVerificationContext = AuthLoginVerificationContext(
         uid: uid,
         phone: phone,
       );

  final bool success;
  final bool requiresLoginVerification;
  final String uid;
  final String token;
  final String imToken;
  final UserInfo? user;
  final String? message;
  final AuthLoginVerificationContext? loginVerificationContext;
}

@immutable
class AuthBootstrapResult {
  const AuthBootstrapResult({required this.stage, this.user});

  final AuthStage stage;
  final UserInfo? user;

  bool get requiresProfileCompletion =>
      stage == AuthStage.awaitingProfileCompletion;
}
