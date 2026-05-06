import 'package:flutter/material.dart';

import '../../../../widgets/wk_design_tokens.dart';
import 'auth_experience_tokens.dart';

enum AuthStatusBannerTone { info, success, warning, error }

class AuthStatusBanner extends StatelessWidget {
  const AuthStatusBanner({
    super.key,
    required this.message,
    this.tone = AuthStatusBannerTone.info,
    this.title,
    this.detail,
    this.leadingIcon,
    this.onDismiss,
  });

  final String message;
  final AuthStatusBannerTone tone;
  final String? title;
  final String? detail;
  final IconData? leadingIcon;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(tone);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AuthExperienceTokens.stageShellBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            leadingIcon ?? palette.icon,
            size: 18,
            color: palette.foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((title ?? '').trim().isNotEmpty) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.foreground.withValues(alpha: 0.84),
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: WKFontFamily.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.foreground,
                  ),
                ),
                if ((detail ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 12,
                      color: palette.foreground.withValues(alpha: 0.74),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              key: const ValueKey<String>('auth-status-banner-dismiss'),
              constraints: const BoxConstraints.tightFor(
                width: AuthExperienceTokens.minimumTouchTarget,
                height: AuthExperienceTokens.minimumTouchTarget,
              ),
              padding: EdgeInsets.zero,
              splashRadius: AuthExperienceTokens.minimumTouchTarget / 2,
              onPressed: onDismiss,
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: palette.foreground,
              ),
            ),
        ],
      ),
    );
  }

  _BannerPalette _paletteFor(AuthStatusBannerTone value) {
    switch (value) {
      case AuthStatusBannerTone.info:
        return const _BannerPalette(
          background: AuthExperienceTokens.statusInfoBackground,
          foreground: AuthExperienceTokens.statusInfoForeground,
          icon: Icons.info_outline_rounded,
        );
      case AuthStatusBannerTone.success:
        return const _BannerPalette(
          background: AuthExperienceTokens.statusSuccessBackground,
          foreground: AuthExperienceTokens.statusSuccessForeground,
          icon: Icons.check_circle_outline_rounded,
        );
      case AuthStatusBannerTone.warning:
        return const _BannerPalette(
          background: AuthExperienceTokens.statusWarningBackground,
          foreground: AuthExperienceTokens.statusWarningForeground,
          icon: Icons.warning_amber_rounded,
        );
      case AuthStatusBannerTone.error:
        return const _BannerPalette(
          background: AuthExperienceTokens.statusErrorBackground,
          foreground: AuthExperienceTokens.statusErrorForeground,
          icon: Icons.error_outline_rounded,
        );
    }
  }
}

class _BannerPalette {
  const _BannerPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}
