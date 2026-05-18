import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'wk_colors.dart';
import 'wk_design_tokens.dart';
import 'wk_reference_assets.dart';

class WKSubPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? trailing;
  final double trailingWidth;
  final Color backgroundColor;
  final bool resizeToAvoidBottomInset;

  const WKSubPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.trailingWidth = 48,
    this.backgroundColor = WKColors.homeBg,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Column(
        children: [
          ColoredBox(
            color: backgroundColor,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(15, 5, 10, 5),
                        child: WKReferenceAssets.image(
                          WKReferenceAssets.back,
                          width: 11,
                          height: 19,
                          tint: WKColors.colorDark,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: WKFontFamily.title,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: WKColors.colorDark,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: trailingWidth,
                      child: trailing == null
                          ? const SizedBox.shrink()
                          : Align(
                              alignment: Alignment.centerRight,
                              child: trailing,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class WKSubPageAction extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final Color color;

  const WKSubPageAction({
    super.key,
    required this.text,
    this.onTap,
    this.color = WKColors.brand500,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontSize: 15,
              color: onTap == null ? WKColors.color999 : color,
            ),
          ),
        ),
      ),
    );
  }
}

class WKSettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const WKSettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: WKColors.surface,
      child: Column(children: children),
    );
  }
}

class WKSectionGap extends StatelessWidget {
  final double height;

  const WKSectionGap(this.height, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: height, color: WKColors.homeBg);
  }
}

class WKSettingsDescription extends StatelessWidget {
  final String text;

  const WKSettingsDescription({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: WKColors.homeBg,
      padding: const EdgeInsets.fromLTRB(15, 5, 15, 20),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 14,
          color: WKColors.color999,
          height: 1.45,
        ),
      ),
    );
  }
}

class WKSettingsCell extends StatelessWidget {
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showArrow;
  final bool centerTitle;
  final bool enabled;
  final Color? titleColor;
  final EdgeInsetsGeometry padding;

  const WKSettingsCell({
    super.key,
    required this.title,
    this.value,
    this.onTap,
    this.trailing,
    this.showArrow = true,
    this.centerTitle = false,
    this.enabled = true,
    this.titleColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTitleColor = titleColor ?? WKColors.colorDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        highlightColor: WKColors.screenBgSelected,
        splashColor: WKColors.screenBgSelected,
        child: Padding(
          padding: padding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxTrailingWidth = math.min(
                220.0,
                math.max(0.0, constraints.maxWidth * 0.58),
              );
              final resolvedTrailing = centerTitle
                  ? null
                  : _buildTrailing(maxTrailingWidth);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: centerTitle ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: centerTitle
                          ? TextAlign.center
                          : TextAlign.start,
                      style: TextStyle(
                        fontFamily: WKFontFamily.primary,
                        fontSize: 16,
                        color: enabled ? resolvedTitleColor : WKColors.color999,
                      ),
                    ),
                  ),
                  if (resolvedTrailing != null)
                    SizedBox(
                      width: maxTrailingWidth,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: resolvedTrailing,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget? _buildTrailing(double maxTrailingWidth) {
    final customTrailing = trailing;
    if (customTrailing != null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: customTrailing,
      );
    }

    if ((value == null || value!.trim().isEmpty) && !showArrow) {
      return null;
    }

    final valueMaxWidth = math.max(
      0.0,
      maxTrailingWidth - (showArrow ? 24.0 : 0.0),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null && value!.trim().isNotEmpty) ...[
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: valueMaxWidth),
            child: Text(
              value!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: 16,
                color: WKColors.color999,
              ),
            ),
          ),
          if (showArrow) const SizedBox(width: 10),
        ],
        if (showArrow)
          Opacity(
            opacity: enabled ? 1 : 0.4,
            child: WKReferenceAssets.image(
              WKReferenceAssets.arrowRight,
              width: 14,
              height: 14,
            ),
          ),
      ],
    );
  }
}

class WKSettingsSwitchCell extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry padding;

  const WKSettingsSwitchCell({
    super.key,
    required this.title,
    required this.value,
    this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
  });

  @override
  Widget build(BuildContext context) {
    return WKSettingsCell(
      title: title,
      showArrow: false,
      padding: padding,
      trailing: WKAndroidSwitch(value: value, onChanged: onChanged),
    );
  }
}

class WKAndroidSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const WKAndroidSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final trackColor = value ? WKColors.brand300 : WKColors.colorCCC;
    final thumbColor = value ? WKColors.brand500 : WKColors.white;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      toggled: value,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged?.call(!value);
              }
            : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          key: const ValueKey('wk_android_switch'),
          width: 45,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 31,
              height: 20,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: 31,
                      height: 14,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    left: value ? 11 : 0,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: trackColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: thumbColor,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
