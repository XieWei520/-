import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/navigation/app_route_location.dart';
import '../../../../core/config/api_config.dart';
import '../../../../data/providers/runtime_capabilities_provider.dart';
import '../../../conversation/main_page.dart';
import '../../application/auth_providers.dart';
import '../../domain/auth_flow_models.dart';
import '../widgets/auth_page_scaffold.dart';
import '../widgets/auth_status_banner.dart';

class AuthThirdLoginPage extends ConsumerStatefulWidget {
  const AuthThirdLoginPage({super.key});

  @override
  ConsumerState<AuthThirdLoginPage> createState() => _AuthThirdLoginPageState();
}

class _AuthThirdLoginPageState extends ConsumerState<AuthThirdLoginPage> {
  Timer? _pollTimer;
  bool _isLaunching = false;
  bool _isPollingInFlight = false;
  bool _hasPollingTerminalResult = false;
  String? _activePlatform;

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _startThirdLogin(String platform) async {
    if (_isLaunching) {
      return;
    }

    setState(() {
      _isLaunching = true;
      _activePlatform = platform;
    });
    _isPollingInFlight = false;
    _hasPollingTerminalResult = false;

    try {
      final authCode = await ref
          .read(authRepositoryProvider)
          .loadThirdLoginAuthCode();
      final authUri = Uri.parse(
        '${ApiConfig.baseUrl}/v1/user/$platform?authcode=$authCode',
      );
      final opened = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw Exception('无法打开 $platform 授权页面');
      }

      _pollTimer?.cancel();
      _isPollingInFlight = false;
      _hasPollingTerminalResult = false;
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_pollThirdLogin(authCode));
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLaunching = false;
        _activePlatform = null;
      });
      _isPollingInFlight = false;
      _hasPollingTerminalResult = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _pollThirdLogin(String authCode) async {
    if (_hasPollingTerminalResult || _isPollingInFlight) {
      return;
    }
    _isPollingInFlight = true;
    try {
      final status = await ref
          .read(authRepositoryProvider)
          .loadThirdLoginStatus(authCode);
      if (status.isFailed) {
        _pollTimer?.cancel();
        _pollTimer = null;
        _hasPollingTerminalResult = true;
        if (!mounted) {
          return;
        }
        setState(() {
          _isLaunching = false;
          _activePlatform = null;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(status.message ?? '第三方登录失败')));
        return;
      }

      if (!status.isSuccess) {
        return;
      }

      _pollTimer?.cancel();
      _pollTimer = null;
      _hasPollingTerminalResult = true;
      await ref
          .read(authFlowControllerProvider.notifier)
          .loginWithThirdPartyAuthCode(authCode);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLaunching = false;
        _activePlatform = null;
      });

      final flowState = ref.read(authFlowControllerProvider);
      if ((flowState.errorMessage ?? '').trim().isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(flowState.errorMessage!)));
        return;
      }

      if (flowState.stage == AuthStage.authenticatedReady ||
          flowState.stage == AuthStage.awaitingProfileCompletion) {
        final goRouter = GoRouter.maybeOf(context);
        if (goRouter != null) {
          goRouter.go(AppRouteLocation.home);
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage()),
          (route) => false,
        );
      }
    } catch (error) {
      _pollTimer?.cancel();
      _pollTimer = null;
      _hasPollingTerminalResult = true;
      if (!mounted) {
        return;
      }
      setState(() {
        _isLaunching = false;
        _activePlatform = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      _isPollingInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(runtimeCapabilitiesProvider);

    return AuthPageScaffold(
      title: '第三方登录',
      subtitle: '严格对齐 Android 原版的浏览器授权与轮询登录链路',
      body: capabilities.when(
        data: (value) {
          if (!value.thirdLoginEnabled) {
            return AuthStatusBanner(
              key: const ValueKey<String>('auth-status-banner'),
              message: value.thirdLoginStatusMessage,
              tone: AuthStatusBannerTone.warning,
              leadingIcon: Icons.info_outline_rounded,
            );
          }

          return Column(
            key: const ValueKey('auth-third-login-start'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PlatformCard(
                key: const ValueKey('auth-third-login-github'),
                icon: Icons.code_rounded,
                title: 'GitHub',
                subtitle: '使用 GitHub 账号授权登录',
                isLoading: _isLaunching && _activePlatform == 'github',
                onTap: () => _startThirdLogin('github'),
              ),
              const SizedBox(height: 12),
              _PlatformCard(
                key: const ValueKey('auth-third-login-gitee'),
                icon: Icons.account_tree_rounded,
                title: 'Gitee',
                subtitle: '使用 Gitee 账号授权登录',
                isLoading: _isLaunching && _activePlatform == 'gitee',
                onTap: () => _startThirdLogin('gitee'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AuthStatusBanner(
          key: const ValueKey<String>('auth-status-banner'),
          message: error.toString(),
          tone: AuthStatusBannerTone.error,
          leadingIcon: Icons.error_outline_rounded,
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
