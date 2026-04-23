import 'package:flutter/material.dart';

import '../../../../widgets/wk_colors.dart';
import '../../../../widgets/wk_design_tokens.dart';
import 'auth_experience_tokens.dart';

class AuthAgreementLink {
  const AuthAgreementLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class AuthAgreementBlock extends StatelessWidget {
  const AuthAgreementBlock({
    super.key,
    required this.value,
    required this.onChanged,
    required this.prefixText,
    required this.links,
    this.toggleKey,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String prefixText;
  final List<AuthAgreementLink> links;
  final Key? toggleKey;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onChanged != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          key: toggleKey,
          checked: value,
          enabled: isEnabled,
          onTap: isEnabled ? () => onChanged!(!value) : null,
          child: SizedBox(
            width: AuthExperienceTokens.minimumTouchTarget,
            height: AuthExperienceTokens.minimumTouchTarget,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(WKRadius.pill),
                onTap: isEnabled ? () => onChanged!(!value) : null,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: value ? WKColors.brand500 : WKColors.white,
                      borderRadius: BorderRadius.circular(WKRadius.pill),
                      border: Border.all(
                        color: value ? WKColors.brand500 : WKColors.color999,
                      ),
                    ),
                    child: value
                        ? const Icon(
                            Icons.check_rounded,
                            size: 13,
                            color: WKColors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                prefixText,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 13,
                  color: isEnabled ? WKColors.colorDark : WKColors.color999,
                ),
              ),
              for (final link in links)
                TextButton(
                  onPressed: link.onTap,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(
                      AuthExperienceTokens.minimumTouchTarget,
                      AuthExperienceTokens.minimumTouchTarget,
                    ),
                  ),
                  child: Text(
                    link.label,
                    style: const TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 13,
                      color: WKColors.brand500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
