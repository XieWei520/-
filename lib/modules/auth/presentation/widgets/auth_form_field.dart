import 'package:flutter/material.dart';

import '../../../../widgets/wk_design_tokens.dart';
import 'auth_experience_tokens.dart';

class AuthFormField extends StatefulWidget {
  const AuthFormField({
    super.key,
    this.fieldKey,
    this.errorKey,
    this.helperKey,
    this.controller,
    this.focusNode,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.leading,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.errorText,
    this.helperText,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 14,
      vertical: 14,
    ),
    this.minHeight = 52,
  });

  final Key? fieldKey;
  final Key? errorKey;
  final Key? helperKey;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final Widget? leading;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final String? helperText;
  final EdgeInsets contentPadding;
  final double minHeight;

  @override
  State<AuthFormField> createState() => _AuthFormFieldState();
}

class _AuthFormFieldState extends State<AuthFormField> {
  FocusNode? _internalFocusNode;

  FocusNode get _focusNode {
    return widget.focusNode ?? _internalFocusNode!;
  }

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode(debugLabel: 'auth-form-field');
    }
  }

  @override
  void didUpdateWidget(covariant AuthFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) {
      return;
    }
    if (oldWidget.focusNode != null && widget.focusNode == null) {
      _internalFocusNode ??= FocusNode(debugLabel: 'auth-form-field');
    } else if (oldWidget.focusNode == null && widget.focusNode != null) {
      _internalFocusNode?.dispose();
      _internalFocusNode = null;
    }
  }

  @override
  void dispose() {
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _handleSurfaceTap() {
    if (!widget.enabled || !_focusNode.canRequestFocus) {
      return;
    }
    _focusNode.requestFocus();
  }

  InputDecoration _buildDecoration() {
    final hasError = (widget.errorText ?? '').trim().isNotEmpty;
    final enabledBorderColor = hasError
        ? AuthExperienceTokens.fieldBorderError
        : AuthExperienceTokens.inputBorder;
    final focusedBorderColor = hasError
        ? AuthExperienceTokens.fieldBorderError
        : AuthExperienceTokens.inputBorderFocus;

    return InputDecoration(
      filled: true,
      fillColor: widget.enabled
          ? AuthExperienceTokens.inputFill
          : AuthExperienceTokens.inputFillDisabled,
      hintStyle: const TextStyle(
        fontFamily: WKFontFamily.primary,
        fontSize: 14,
        color: AuthExperienceTokens.inputHint,
      ),
      errorStyle: const TextStyle(
        fontFamily: WKFontFamily.primary,
        fontSize: 12,
        color: AuthExperienceTokens.errorText,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: enabledBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: focusedBorderColor),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: AuthExperienceTokens.inputBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AuthExperienceTokens.fieldBorderError,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(
          color: AuthExperienceTokens.fieldBorderError,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasError = (widget.errorText ?? '').trim().isNotEmpty;
    final supportingText = hasError ? widget.errorText : widget.helperText;
    final supportingColor = hasError
        ? AuthExperienceTokens.errorText
        : AuthExperienceTokens.helperText;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleSurfaceTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: widget.minHeight),
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              autofillHints: widget.autofillHints,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 14,
                color: AuthExperienceTokens.inputText,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: AuthExperienceTokens.inputText,
              decoration: _buildDecoration().copyWith(
                hintText: widget.hintText,
                isDense: true,
                contentPadding: widget.contentPadding,
                prefixIcon: widget.leading == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(left: 12, right: 6),
                        child: widget.leading,
                      ),
                prefixIconConstraints: widget.leading == null
                    ? null
                    : const BoxConstraints(minWidth: 0, minHeight: 0),
                suffixIcon: widget.trailing == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(left: 6, right: 10),
                        child: widget.trailing,
                      ),
                suffixIconConstraints: widget.trailing == null
                    ? null
                    : const BoxConstraints(minWidth: 0, minHeight: 0),
              ),
            ),
          ),
          if ((supportingText ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                supportingText!,
                key: hasError ? widget.errorKey : widget.helperKey,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 12,
                  color: supportingColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
