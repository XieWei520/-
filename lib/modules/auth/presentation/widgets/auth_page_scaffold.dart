import 'dart:ui';

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
    final palette = AuthExperiencePalette.of(context);
    return Scaffold(
      backgroundColor: palette.stageBackgroundBottom,
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
    final radius = BorderRadius.circular(AuthExperienceTokens.stageShellRadius);
    return Builder(
      builder: (context) {
        final palette = AuthExperiencePalette.of(context);
        return ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              key: const ValueKey<String>(AuthExperienceTokens.stageShellKey),
              decoration: BoxDecoration(
                color: palette.stageShellTop.withValues(alpha: 0.78),
                borderRadius: radius,
                border: Border.all(color: palette.stageShellBorder),
                boxShadow: AuthExperienceTokens.stageShellShadow,
              ),
              child: useDesktopSplit
                  ? Row(
                      children: <Widget>[
                        Expanded(
                          flex: 11,
                          child: _buildBrandPanel(compact: false),
                        ),
                        Expanded(
                          flex: 9,
                          child: _buildFormPanel(compact: false),
                        ),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildBrandPanel({required bool compact}) {
    final resolvedEyebrow = (brandEyebrow ?? '').trim();
    final resolvedTitle = (brandTitle ?? '').trim();
    final resolvedDescription = (brandDescription ?? '').trim();
    final visibleHighlights = compact
        ? brandHighlights.take(2).toList(growable: false)
        : brandHighlights;

    return Builder(
      builder: (context) {
        final palette = AuthExperiencePalette.of(context);
        return Container(
          key: const ValueKey<String>(AuthExperienceTokens.brandPanelKey),
          padding: AuthExperienceTokens.brandPanelPadding,
          decoration: BoxDecoration(
            color: palette.brandPanelBackground,
            border: Border(right: BorderSide(color: palette.stageShellBorder)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (resolvedEyebrow.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: palette.brandPanelOverlay,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: palette.brandChipBorder),
                  ),
                  child: Text(
                    resolvedEyebrow,
                    style: TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.35,
                      color: palette.brandAccentStrong,
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
                    color: palette.brandInk,
                  ),
                ),
              if (resolvedDescription.isNotEmpty) ...[
                SizedBox(
                  height: resolvedTitle.isNotEmpty ? (compact ? 14 : 20) : 0,
                ),
                Container(
                  width: compact ? 54 : 72,
                  height: 1.5,
                  color: palette.brandAccent.withValues(alpha: 0.66),
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
                    color: palette.brandInk.withValues(alpha: 0.86),
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
              if (!compact) ...[
                const SizedBox(height: 28),
                const Flexible(
                  fit: FlexFit.loose,
                  child: SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: _AuthNetworkVisual(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileBrandHeader({required bool compact}) {
    final resolvedEyebrow = (brandEyebrow ?? '').trim();
    final resolvedTitle = (brandTitle ?? '').trim();
    final resolvedDescription = (brandDescription ?? '').trim();

    return Builder(
      builder: (context) {
        final palette = AuthExperiencePalette.of(context);
        return Container(
          key: const ValueKey<String>(
            AuthExperienceTokens.mobileBrandHeaderKey,
          ),
          width: double.infinity,
          padding: AuthExperienceTokens.mobileBrandHeaderPadding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.brandPanelBackground,
                palette.stageShellTop,
                palette.stageShellBottom,
              ],
              stops: <double>[0.0, 0.6, 1.0],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: palette.stageShellBorder.withValues(alpha: 0.9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (resolvedEyebrow.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.brandPanelOverlay,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: palette.brandChipBorder),
                  ),
                  child: Text(
                    resolvedEyebrow,
                    style: TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: palette.brandAccentStrong,
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
                    color: palette.brandInk,
                  ),
                ),
              if (resolvedDescription.isNotEmpty) ...[
                SizedBox(
                  height:
                      (resolvedTitle.isNotEmpty || resolvedEyebrow.isNotEmpty)
                      ? (compact ? 7 : 9)
                      : 0,
                ),
                Container(
                  width: compact ? 44 : 56,
                  height: 1.2,
                  color: palette.brandAccent.withValues(alpha: 0.62),
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
                    color: palette.brandInk.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormPanel({required bool compact}) {
    final resolvedPanelPadding = compact
        ? const EdgeInsets.fromLTRB(18, 18, 18, 18)
        : AuthExperienceTokens.panelPadding;
    return Builder(
      builder: (context) {
        final palette = AuthExperiencePalette.of(context);
        return KeyedSubtree(
          key: const ValueKey<String>(AuthExperienceTokens.formPanelKey),
          child: Container(
            key: panelKey,
            width: double.infinity,
            padding: resolvedPanelPadding,
            decoration: BoxDecoration(color: palette.panelBackground),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leading != null)
                  Align(alignment: Alignment.centerLeft, child: leading!),
                if (!compact && (pageLabel ?? '').trim().isNotEmpty) ...[
                  Text(
                    pageLabel!,
                    style: TextStyle(
                      fontFamily: WKFontFamily.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.brandAccentStrong,
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
                    color: palette.panelInk,
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
                      color: palette.panelMuted,
                    ),
                  ),
                ],
                SizedBox(
                  height: compact
                      ? 12
                      : AuthExperienceTokens.titleToBodySpacing,
                ),
                if (statusBanner != null) ...[
                  statusBanner!,
                  const SizedBox(
                    height: AuthExperienceTokens.statusBannerSpacing,
                  ),
                ],
                body,
                if (primaryAction != null) ...[
                  const SizedBox(
                    height: AuthExperienceTokens.primaryActionSpacing,
                  ),
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
      },
    );
  }
}

class _AuthNetworkVisual extends StatelessWidget {
  const _AuthNetworkVisual();

  @override
  Widget build(BuildContext context) {
    final palette = AuthExperiencePalette.of(context);
    return CustomPaint(
      key: const ValueKey<String>('auth-brand-network-visual'),
      painter: _AuthNetworkVisualPainter(palette: palette),
      child: Stack(
        children: const [
          _NetworkNode(
            alignment: Alignment(0.0, -0.28),
            size: 78,
            icon: Icons.hub_outlined,
          ),
          _NetworkNode(
            alignment: Alignment(-0.72, 0.42),
            size: 54,
            icon: Icons.chat_bubble_outline,
          ),
          _NetworkNode(
            alignment: Alignment(0.74, 0.34),
            size: 58,
            icon: Icons.devices_outlined,
          ),
          _NetworkNode(
            alignment: Alignment(-0.42, -0.68),
            size: 42,
            icon: Icons.lock_outline,
          ),
          _NetworkNode(
            alignment: Alignment(0.54, -0.72),
            size: 44,
            icon: Icons.person_outline,
          ),
        ],
      ),
    );
  }
}

class _NetworkNode extends StatelessWidget {
  const _NetworkNode({
    required this.alignment,
    required this.size,
    required this.icon,
  });

  final Alignment alignment;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AuthExperiencePalette.of(context);
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.panelBackground.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(size * 0.34),
          border: Border.all(color: palette.brandChipBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140F172A),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, color: palette.brandAccent, size: size * 0.42),
      ),
    );
  }
}

class _AuthNetworkVisualPainter extends CustomPainter {
  const _AuthNetworkVisualPainter({required this.palette});

  final AuthExperiencePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = palette.brandAccent.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width * 0.5, size.height * 0.36);
    final points = <Offset>[
      Offset(size.width * 0.16, size.height * 0.72),
      Offset(size.width * 0.82, size.height * 0.68),
      Offset(size.width * 0.28, size.height * 0.16),
      Offset(size.width * 0.72, size.height * 0.14),
    ];

    for (final point in points) {
      canvas.drawLine(center, point, paint);
    }

    final haloPaint = Paint()
      ..color = palette.brandAccent.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.12,
          size.height * 0.08,
          size.width * 0.76,
          size.height * 0.76,
        ),
        const Radius.circular(42),
      ),
      haloPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AuthNetworkVisualPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

class _BrandHighlightChip extends StatelessWidget {
  const _BrandHighlightChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AuthExperiencePalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.brandChipBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.brandChipBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: WKFontFamily.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: palette.brandInk,
        ),
      ),
    );
  }
}
