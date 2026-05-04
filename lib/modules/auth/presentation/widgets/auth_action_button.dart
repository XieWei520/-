import 'package:flutter/material.dart';

import '../../../../widgets/wk_design_tokens.dart';
import 'auth_experience_tokens.dart';

enum AuthActionButtonVariant { primary, secondary }

class AuthActionButton extends StatelessWidget {
  const AuthActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AuthActionButtonVariant.primary,
    this.isLoading = false,
    this.leading,
    this.height = AuthExperienceTokens.actionButtonHeight,
    this.fullWidth = true,
    this.padding,
    this.labelFontSize = 16,
  });

  const AuthActionButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.leading,
    this.height = AuthExperienceTokens.actionButtonHeight,
    this.fullWidth = true,
    this.padding,
    this.labelFontSize = 16,
  }) : variant = AuthActionButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final AuthActionButtonVariant variant;
  final bool isLoading;
  final Widget? leading;
  final double height;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;
  final double labelFontSize;

  bool get _isPrimary => variant == AuthActionButtonVariant.primary;

  @override
  Widget build(BuildContext context) {
    final onTap = isLoading ? null : onPressed;
    final borderRadius = BorderRadius.circular(
      AuthExperienceTokens.actionButtonRadius,
    );
    final labelStyle = TextStyle(
      fontFamily: WKFontFamily.primary,
      fontSize: labelFontSize,
      fontWeight: FontWeight.w600,
    );
    final content = isLoading
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _isPrimary
                    ? Colors.white
                    : AuthExperienceTokens.brandAccentStrong,
              ),
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: labelStyle,
                ),
              ],
            ),
          );

    final Widget button = _isPrimary
        ? ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: AuthExperienceTokens.brandAccent,
              disabledBackgroundColor: AuthExperienceTokens.brandMuted,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              padding:
                  padding ??
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
            ),
            child: content,
          )
        : OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: AuthExperienceTokens.stageShellTop.withValues(
                alpha: 0.88,
              ),
              foregroundColor: AuthExperienceTokens.brandAccentStrong,
              side: const BorderSide(
                color: AuthExperienceTokens.stageShellBorder,
              ),
              padding:
                  padding ??
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
            ),
            child: content,
          );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: button,
    );
  }
}
