import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/auth_provider.dart';
import '../../../wk_foundation/errors/app_failure.dart';
import '../../../wk_foundation/logging/app_logger.dart';
import '../coordinators/auth_bootstrap_coordinator.dart';
import '../domain/auth_flow_models.dart';
import '../domain/auth_repository.dart';

class AuthFlowController extends StateNotifier<AuthFlowState> {
  AuthFlowController({
    required AuthRepository repository,
    required AuthBootstrapCoordinator bootstrapCoordinator,
    required AuthNotifier authNotifier,
  }) : _repository = repository,
       _bootstrapCoordinator = bootstrapCoordinator,
       _authNotifier = authNotifier,
       super(const AuthFlowState());

  static const AppLogger _logger = AppLogger('auth/flow');

  final AuthRepository _repository;
  final AuthBootstrapCoordinator _bootstrapCoordinator;
  final AuthNotifier _authNotifier;

  Future<void> loginWithPhone({
    required String zone,
    required String phone,
    required String password,
  }) async {
    _logger.info(
      'loginWithPhone start zone=$zone phone=${_maskPhone(phone)} passwordLength=${password.length}',
    );
    state = state.copyWith(
      stage: AuthStage.submittingCredentials,
      isLoading: true,
      errorMessage: null,
      zone: zone,
      loginVerificationContext: null,
    );

    final result = await _repository.loginWithPhone(
      zone: zone,
      phone: phone,
      password: password,
    );

    await _consumeCredentialResult(result);
  }

  Future<void> loginWithUsername({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      stage: AuthStage.submittingCredentials,
      isLoading: true,
      errorMessage: null,
      loginVerificationContext: null,
    );
    final result = await _repository.loginWithUsername(
      username: username,
      password: password,
    );
    await _consumeCredentialResult(result);
  }

  Future<void> registerWithPhone({
    required String zone,
    required String phone,
    required String code,
    required String password,
    String? inviteCode,
    String? displayName,
  }) async {
    _logger.info(
      'registerWithPhone start zone=$zone phone=${_maskPhone(phone)} codeLength=${code.length} inviteProvided=${(inviteCode?.trim().isNotEmpty ?? false)} displayNameProvided=${(displayName?.trim().isNotEmpty ?? false)}',
    );
    state = state.copyWith(
      stage: AuthStage.awaitingRegistrationCode,
      isLoading: true,
      errorMessage: null,
      zone: zone,
      loginVerificationContext: null,
    );

    final result = await _repository.registerWithPhone(
      zone: zone,
      phone: phone,
      code: code,
      password: password,
      inviteCode: inviteCode,
      displayName: displayName,
    );

    await _consumeCredentialResult(result);
  }

  Future<void> loginWithThirdPartyAuthCode(String authCode) async {
    state = state.copyWith(
      stage: AuthStage.submittingCredentials,
      isLoading: true,
      errorMessage: null,
      loginVerificationContext: null,
    );
    final result = await _repository.loginWithThirdPartyAuthCode(authCode);
    await _consumeCredentialResult(result);
  }

  Future<void> sendRegisterCode({
    required String zone,
    required String phone,
  }) async {
    _logger.info(
      'sendRegisterCode start zone=$zone phone=${_maskPhone(phone)}',
    );
    state = state.copyWith(
      stage: AuthStage.awaitingRegistrationCode,
      isLoading: true,
      errorMessage: null,
      zone: zone,
    );
    try {
      await _repository.sendRegisterCode(zone: zone, phone: phone);
      _logger.info('sendRegisterCode success phone=${_maskPhone(phone)}');
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      _logger.error(
        'sendRegisterCode failed phone=${_maskPhone(phone)}',
        error,
      );
      state = state.copyWith(
        stage: AuthStage.awaitingRegistrationCode,
        isLoading: false,
        errorMessage: AppFailure.describe(
          error,
          fallbackMessage: 'Failed to send register code.',
        ),
      );
    }
  }

  Future<void> sendLoginVerificationCode({
    required String uid,
    String? prefilledCode,
  }) async {
    _logger.info(
      'sendLoginVerificationCode start uid=$uid prefilled=${(prefilledCode?.trim().isNotEmpty ?? false)}',
    );
    final currentContext = state.loginVerificationContext;
    state = state.copyWith(
      stage: AuthStage.awaitingLoginVerification,
      isLoading: true,
      errorMessage: null,
    );
    final resolvedPrefilledCode = prefilledCode?.trim() ?? '';
    if (resolvedPrefilledCode.isNotEmpty) {
      _logger.info('sendLoginVerificationCode using prefilled code uid=$uid');
      state = state.copyWith(
        stage: AuthStage.awaitingLoginVerification,
        isLoading: false,
        errorMessage: null,
        loginVerificationContext: currentContext?.copyWith(
          step: AuthLoginVerificationStep.codeEntry,
          prefilledCode: resolvedPrefilledCode,
        ),
      );
      return;
    }
    try {
      await _repository.sendLoginVerificationCode(uid);
      _logger.info('sendLoginVerificationCode success uid=$uid');
      state = state.copyWith(
        stage: AuthStage.awaitingLoginVerification,
        isLoading: false,
        errorMessage: null,
        loginVerificationContext: currentContext?.copyWith(
          step: AuthLoginVerificationStep.codeEntry,
          prefilledCode: null,
        ),
      );
    } catch (error) {
      _logger.error('sendLoginVerificationCode failed uid=$uid', error);
      state = state.copyWith(
        stage: AuthStage.awaitingLoginVerification,
        isLoading: false,
        errorMessage: AppFailure.describe(
          error,
          fallbackMessage: 'Failed to send login verification code.',
        ),
      );
    }
  }

  Future<void> verifyLoginCode({
    required String uid,
    required String code,
  }) async {
    _logger.info('verifyLoginCode start uid=$uid codeLength=${code.length}');
    state = state.copyWith(
      stage: AuthStage.awaitingLoginVerification,
      isLoading: true,
      errorMessage: null,
    );
    final result = await _repository.verifyLoginCode(uid: uid, code: code);
    await _consumeVerificationResult(result);
  }

  Future<void> sendResetPasswordCode({
    required String zone,
    required String phone,
  }) async {
    _logger.info(
      'sendResetPasswordCode start zone=$zone phone=${_maskPhone(phone)}',
    );
    state = state.copyWith(
      stage: AuthStage.awaitingPasswordResetCode,
      isLoading: true,
      errorMessage: null,
      zone: zone,
    );
    try {
      await _repository.sendResetPasswordCode(zone: zone, phone: phone);
      _logger.info('sendResetPasswordCode success phone=${_maskPhone(phone)}');
      state = state.copyWith(
        stage: AuthStage.awaitingPasswordResetCode,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      _logger.error(
        'sendResetPasswordCode failed phone=${_maskPhone(phone)}',
        error,
      );
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        isLoading: false,
        errorMessage: AppFailure.describe(
          error,
          fallbackMessage: 'Failed to send reset password code.',
        ),
      );
    }
  }

  Future<void> resetPassword({
    required String zone,
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    _logger.info(
      'resetPassword start zone=$zone phone=${_maskPhone(phone)} codeLength=${code.length} passwordLength=${newPassword.length}',
    );
    state = state.copyWith(
      stage: AuthStage.awaitingPasswordResetCode,
      isLoading: true,
      errorMessage: null,
      zone: zone,
    );
    try {
      await _repository.resetPassword(
        zone: zone,
        phone: phone,
        code: code,
        newPassword: newPassword,
      );
      _logger.info('resetPassword success phone=${_maskPhone(phone)}');
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      _logger.error('resetPassword failed phone=${_maskPhone(phone)}', error);
      state = state.copyWith(
        stage: AuthStage.awaitingPasswordResetCode,
        isLoading: false,
        errorMessage: AppFailure.describe(
          error,
          fallbackMessage: 'Failed to reset password.',
        ),
      );
    }
  }

  Future<void> completeProfile({
    required String name,
    int? sex,
    String? avatarFilePath,
  }) async {
    state = state.copyWith(
      stage: AuthStage.awaitingProfileCompletion,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final user = await _repository.completeProfile(
        name: name,
        sex: sex,
        avatarFilePath: avatarFilePath,
      );
      await _authNotifier.completeProfile(user);
      state = state.copyWith(
        stage: AuthStage.authenticatedReady,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        stage: AuthStage.awaitingProfileCompletion,
        isLoading: false,
        errorMessage: AppFailure.describe(
          error,
          fallbackMessage: 'Failed to complete profile.',
        ),
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  void cancelLoginVerification() {
    final currentContext = state.loginVerificationContext;
    if (state.stage != AuthStage.awaitingLoginVerification &&
        currentContext == null) {
      return;
    }
    _logger.info('cancelLoginVerification uid=${currentContext?.uid ?? 'n/a'}');
    state = state.copyWith(
      stage: AuthStage.unauthenticated,
      isLoading: false,
      errorMessage: null,
      loginVerificationContext: null,
    );
  }

  void returnToLoginVerificationIntroduction() {
    final currentContext = state.loginVerificationContext;
    if (state.stage != AuthStage.awaitingLoginVerification ||
        currentContext == null) {
      return;
    }
    _logger.info(
      'returnToLoginVerificationIntroduction uid=${currentContext.uid}',
    );
    state = state.copyWith(
      stage: AuthStage.awaitingLoginVerification,
      isLoading: false,
      errorMessage: null,
      loginVerificationContext: currentContext.copyWith(
        step: AuthLoginVerificationStep.introduction,
        prefilledCode: null,
      ),
    );
  }

  Future<void> _consumeCredentialResult(AuthCredentialResult result) async {
    _logger.info(
      'consumeCredentialResult success=${result.success} requiresVerification=${result.requiresLoginVerification} stage=${state.stage}',
    );
    if (result.requiresLoginVerification &&
        result.loginVerificationContext != null) {
      state = state.copyWith(
        stage: AuthStage.awaitingLoginVerification,
        isLoading: false,
        errorMessage: null,
        loginVerificationContext: result.loginVerificationContext,
      );
      return;
    }

    if (!result.success) {
      _logger.info(
        'consumeCredentialResult failure message=${result.message ?? 'n/a'}',
      );
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        isLoading: false,
        errorMessage: result.message,
        loginVerificationContext: null,
      );
      return;
    }

    await _bootstrapAuthenticatedResult(result);
  }

  Future<void> _consumeVerificationResult(AuthCredentialResult result) async {
    _logger.info(
      'consumeVerificationResult success=${result.success} requiresVerification=${result.requiresLoginVerification} stage=${state.stage}',
    );
    if (result.requiresLoginVerification &&
        result.loginVerificationContext != null) {
      state = state.copyWith(
        stage: AuthStage.awaitingLoginVerification,
        isLoading: false,
        errorMessage: null,
        loginVerificationContext: result.loginVerificationContext,
      );
      return;
    }

    if (!result.success) {
      _logger.info(
        'consumeVerificationResult failure message=${result.message ?? 'n/a'}',
      );
      state = state.copyWith(
        stage: AuthStage.awaitingLoginVerification,
        isLoading: false,
        errorMessage: result.message,
      );
      return;
    }

    await _bootstrapAuthenticatedResult(result);
  }

  Future<void> _bootstrapAuthenticatedResult(
    AuthCredentialResult result,
  ) async {
    _logger.info('bootstrapAuthenticatedResult start uid=${result.uid}');
    state = state.copyWith(
      stage: AuthStage.bootstrappingAuthenticatedSession,
      isLoading: true,
      errorMessage: null,
      loginVerificationContext: null,
    );
    try {
      final bootstrapResult = await _bootstrapCoordinator.bootstrap(result);
      await _authNotifier.commitBootstrapResult(bootstrapResult);
      _logger.info(
        'bootstrapAuthenticatedResult success stage=${bootstrapResult.stage}',
      );
      state = state.copyWith(
        stage: bootstrapResult.stage,
        isLoading: false,
        errorMessage: null,
        loginVerificationContext: null,
      );
    } catch (error) {
      _logger.error(
        'bootstrapAuthenticatedResult failed uid=${result.uid}',
        error,
      );
      state = state.copyWith(
        stage: AuthStage.unauthenticated,
        isLoading: false,
        errorMessage: AppFailure.describe(
          error,
          fallbackMessage: 'Failed to initialize authenticated session.',
        ),
        loginVerificationContext: null,
      );
    }
  }

  static String _maskPhone(String phone) {
    final trimmed = phone.trim();
    if (trimmed.length <= 4) {
      return trimmed;
    }
    final prefix = trimmed.substring(0, 3);
    final suffix = trimmed.substring(trimmed.length - 2);
    return '$prefix***$suffix';
  }
}
