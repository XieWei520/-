import 'package:flutter/material.dart';

import '../../../../widgets/wk_design_tokens.dart';
import 'auth_experience_tokens.dart';
import 'auth_stage_background.dart';

class AuthPageScaffold extends StatelessWidget {
  const AuthPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.leading,
    this.statusBanner,
    this.primaryAction,
    this.secondaryAction,
    this.footer,
    this.backgroundKey = const ValueKey<String>(
      AuthExperienceTokens.stageBackgroundKey,
    ),
    this.panelKey = const ValueKey<String>(AuthExperienceTokens.pagePanelKey),
    this.topPadding = AuthExperienceTokens.pageTopPadding,
    this.bottomPadding = AuthExperienceTokens.pageBottomPadding,
    this.horizontalPadding = AuthExperienceTokens.pageHorizontalPadding,
    this.maxPanelWidth = AuthExperienceTokens.desktopPanelMaxWidth,
    this.pageLabel,
    this.brandEyebrow,
    this.brandTitle,
    this.brandDescription,
    this.brandHighlights = const <String>[],
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? leading;
  final Widget? statusBanner;
  final Widget? primaryAction;
  final Widget? secondaryAction;
  final Widget? footer;
  final Key backgroundKey;
  final Key panelKey;
  final double topPadding;
  final double bottomPadding;
  final double horizontalPadding;
  final double maxPanelWidth;
  final String? pageLabel;
  final String? brandEyebrow;
  final String? brandTitle;
  final String? brandDescription;
  final List<String> brandHighlights;

  bool get _hasExplicitBranding {
    return (brandEyebrow ?? '').trim().isNotEmpty ||
        (brandTitle ?? '').trim().isNotEmpty ||
        (brandDescription ?? '').trim().isNotEmpty ||
        brandHighlights.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthExperienceTokens.stageBackgroundBottom,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AuthStageBackground(backgroundKey: backgroundKey),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final forceStackedForShortViewport =
                    constraints.maxHeight < 700 && statusBanner != null;
                final useDesktopSplit =
                    _hasExplicitBranding &&
                    constraints.maxWidth >= 760 &&
                    !forceStackedForShortViewport;
                final showStackedBranding =
                    _hasExplicitBranding && !useDesktopSplit;
                final isCompactLayout = constraints.maxHeight < 720;
                final useAdaptivePadding =
                    topPadding == AuthExperienceTokens.pageTopPadding &&
                    bottomPadding == AuthExperienceTokens.pageBottomPadding;
                final effectiveTopPadding =
                    (useAdaptivePadding && isCompactLayout)
                    ? topPadding - 10
                    : topPadding;
                final effectiveBottomPadding =
                    (useAdaptivePadding && isCompactLayout)
                    ? bottomPadding - 8
                    : bottomPadding;
                final minContentHeight =
                    (constraints.maxHeight -
                            effectiveTopPadding -
                            effectiveBottomPadding)
                        .clamp(0.0, double.infinity)
                        .toDouble();
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    effectiveTopPadding,
                    horizontalPadding,
                    effectiveBottomPadding,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minContentHeight),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AuthExperienceTokens.desktopStageMaxWidth,
                        ),
                        child: _buildStageShell(
                          useDesktopSplit: useDesktopSplit,
                          showStackedBranding: showStackedBranding,
                          compact: isCompactLayout,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageShell({
    required bool useDesktopSplit,
    required bool showStackedBranding,
    required bool compact,
  }) {
    return Container(
      key: const ValueKey<String>(AuthExperienceTokens.stageShellKey),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AuthExperienceTokens.stageShellTop,
        borderRadius: BorderRadius.circular(
          AuthExperienceTokens.stageShellRadius,
        ),
        border: Border.all(color: AuthExperienceTokens.stageShellBorder),
        boxShadow: AuthExperienceTokens.stageShellShadow,
      ),
      child: useDesktopSplit
          ? Row(
              children: <Widget>[
                Expanded(flex: 11, child: _buildBrandPanel(compact: false)),
                Expanded(flex: 9, child: _buildFormPanel(compact: false)),
              ],
            )
          : showStackedBranding
          ? Column(
              children: <Widget>[
                _buildMobileBrandHeader(compact: compact),
                _buildFormPanel(compact: compact),
              ],
            )
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxPanelWidth),
                child: _buildFormPanel(compact: compact),
              ),
            ),
    );
  }

  Widget _buildBrandPanel({required bool compact}) {
    final resolvedEyebrow = (brandEyebrow ?? '').trim();
    final resolvedTitle = (brandTitle ?? '').trim();
    final resolvedDescription = (brandDescription ?? '').trim();
    final visibleHighlights = compact
        ? brandHighlights.take(2).toList(growable: false)
        : brandHighlights;

    return Container(
      key: const ValueKey<String>(AuthExperienceTokens.brandPanelKey),
      padding: AuthExperienceTokens.brandPanelPadding,
      decoration: BoxDecoration(
        color: AuthExperienceTokens.brandPanelBackground,
        border: Border(
          right: BorderSide(color: AuthExperienceTokens.stageShellBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resolvedEyebrow.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AuthExperienceTokens.brandPanelOverlay,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AuthExperienceTokens.brandChipBorder),
              ),
              child: Text(
                resolvedEyebrow,
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.35,
                  color: AuthExperienceTokens.brandAccentStrong,
                ),
              ),
            ),
            SizedBox(height: compact ? 18 : 26),
          ],
          if (resolvedTitle.isNotEmpty)
            Text(
              resolvedTitle,
              style: TextStyle(
                fontFamily: WKFontFamily.title,
                fontSize: compact ? 34 : 46,
                height: 1.12,
                fontWeight: FontWeight.w800,
                color: AuthExperienceTokens.brandInk,
              ),
            ),
          if (resolvedDescription.isNotEmpty) ...[
            SizedBox(
              height: resolvedTitle.isNotEmpty ? (compact ? 14 : 20) : 0,
            ),
            Container(
              width: compact ? 54 : 72,
              height: 1.5,
              color: AuthExperienceTokens.brandAccent.withValues(alpha: 0.66),
            ),
            SizedBox(height: compact ? 10 : 14),
            Text(
              resolvedDescription,
              maxLines: compact ? 3 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
              style: TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: compact ? 14 : 16,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AuthExperienceTokens.brandInk.withValues(alpha: 0.86),
              ),
            ),
          ],
          if (visibleHighlights.isNotEmpty) ...[
            SizedBox(height: compact ? 20 : 30),
            Wrap(
              spacing: 10,
              runSpacing: AuthExperienceTokens.brandHighlightSpacing,
              children: [
                for (final item in visibleHighlights)
                  _BrandHighlightChip(label: item),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileBrandHeader({required bool compact}) {
    final resolvedEyebrow = (brandEyebrow ?? '').trim();
    final resolvedTitle = (brandTitle ?? '').trim();
    final resolvedDescription = (brandDescription ?? '').trim();

    return Container(
      key: const ValueKey<String>(AuthExperienceTokens.mobileBrandHeaderKey),
      width: double.infinity,
      padding: AuthExperienceTokens.mobileBrandHeaderPadding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AuthExperienceTokens.brandPanelBackground,
            AuthExperienceTokens.stageShellTop,
            AuthExperienceTokens.stageShellBottom,
          ],
          stops: <double>[0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AuthExperienceTokens.stageShellBorder.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (resolvedEyebrow.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AuthExperienceTokens.brandPanelOverlay,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AuthExperienceTokens.brandChipBorder),
              ),
              child: Text(
                resolvedEyebrow,
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AuthExperienceTokens.brandAccentStrong,
                ),
              ),
            ),
          if (resolvedEyebrow.isNotEmpty && resolvedTitle.isNotEmpty)
            const SizedBox(height: 9),
          if (resolvedTitle.isNotEmpty)
            Text(
              resolvedTitle,
              style: TextStyle(
                fontFamily: WKFontFamily.title,
                fontSize: compact ? 23 : 28,
                height: 1.16,
                fontWeight: FontWeight.w800,
                color: AuthExperienceTokens.brandInk,
              ),
            ),
          if (resolvedDescription.isNotEmpty) ...[
            SizedBox(
              height: (resolvedTitle.isNotEmpty || resolvedEyebrow.isNotEmpty)
                  ? (compact ? 7 : 9)
                  : 0,
            ),
            Container(
              width: compact ? 44 : 56,
              height: 1.2,
              color: AuthExperienceTokens.brandAccent.withValues(alpha: 0.62),
            ),
            SizedBox(height: compact ? 7 : 9),
            Text(
              resolvedDescription,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: WKFontFamily.primary,
                fontSize: compact ? 12 : 13,
                height: 1.45,
                color: AuthExperienceTokens.brandInk.withValues(alpha: 0.84),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormPanel({required bool compact}) {
    final resolvedPanelPadding = compact
        ? const EdgeInsets.fromLTRB(18, 18, 18, 18)
        : AuthExperienceTokens.panelPadding;
    return KeyedSubtree(
      key: const ValueKey<String>(AuthExperienceTokens.formPanelKey),
      child: Container(
        key: panelKey,
        width: double.infinity,
        padding: resolvedPanelPadding,
        decoration: const BoxDecoration(
          color: AuthExperienceTokens.panelBackground,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leading != null)
              Align(alignment: Alignment.centerLeft, child: leading!),
            if (!compact && (pageLabel ?? '').trim().isNotEmpty) ...[
              Text(
                pageLabel!,
                style: const TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AuthExperienceTokens.brandAccentStrong,
                ),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              title,
              textAlign: TextAlign.left,
              style: TextStyle(
                fontFamily: WKFontFamily.title,
                fontSize: compact ? 28 : 32,
                fontWeight: FontWeight.w700,
                color: AuthExperienceTokens.panelInk,
              ),
            ),
            if (subtitle != null &&
                subtitle!.trim().isNotEmpty &&
                (!compact || !_hasExplicitBranding)) ...[
              SizedBox(
                height: compact
                    ? AuthExperienceTokens.subtitleSpacing - 2
                    : AuthExperienceTokens.subtitleSpacing,
              ),
              Text(
                subtitle!,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: WKFontFamily.primary,
                  fontSize: compact ? 13 : 14,
                  height: 1.5,
                  color: AuthExperienceTokens.panelMuted,
                ),
              ),
            ],
            SizedBox(
              height: compact ? 12 : AuthExperienceTokens.titleToBodySpacing,
            ),
            if (statusBanner != null) ...[
              statusBanner!,
              const SizedBox(height: AuthExperienceTokens.statusBannerSpacing),
            ],
            body,
            if (primaryAction != null) ...[
              const SizedBox(height: AuthExperienceTokens.primaryActionSpacing),
              primaryAction!,
            ],
            if (secondaryAction != null) ...[
              const SizedBox(
                height: AuthExperienceTokens.secondaryActionSpacing,
              ),
              secondaryAction!,
            ],
            if (footer != null) ...[
              const SizedBox(height: AuthExperienceTokens.footerSpacing),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}

class _BrandHighlightChip extends StatelessWidget {
  const _BrandHighlightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AuthExperienceTokens.brandChipBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuthExperienceTokens.brandChipBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: AuthExperienceTokens.brandInk,
        ),
      ),
    );
  }
}
