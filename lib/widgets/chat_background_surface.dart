import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/models/chat_background_option.dart';
import '../wukong_uikit/setting/setting_preferences.dart';
import 'wk_colors.dart';

class ChatBackgroundSurface extends StatelessWidget {
  const ChatBackgroundSurface({
    super.key,
    this.option,
    this.fallbackStyle = WKChatBackgroundStyle.classic,
    this.child,
  });

  final ChatBackgroundOption? option;
  final WKChatBackgroundStyle fallbackStyle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _ChatBackgroundFill(
          option: option,
          fallbackStyle: fallbackStyle,
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _ChatBackgroundFill extends StatelessWidget {
  const _ChatBackgroundFill({
    required this.option,
    required this.fallbackStyle,
  });

  final ChatBackgroundOption? option;
  final WKChatBackgroundStyle fallbackStyle;

  @override
  Widget build(BuildContext context) {
    final palette = _resolvePalette(context);
    if (option != null && palette.isNotEmpty) {
      return Container(
        key: const ValueKey<String>('chat-background-gradient'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: const [
            _GlowBlob(
              alignment: Alignment.topLeft,
              size: 260,
              color: Colors.white24,
            ),
            _GlowBlob(
              alignment: Alignment.bottomRight,
              size: 220,
              color: Colors.white12,
            ),
          ],
        ),
      );
    }

    if (option != null && !option!.isSvg && option!.resolvedUrl.isNotEmpty) {
      return Container(
        color: WKColors.homeBg,
        child: Image.network(
          option!.resolvedUrl,
          key: const ValueKey<String>('chat-background-image'),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        ),
      );
    }

    if (option != null && option!.isSvg && option!.resolvedUrl.isNotEmpty) {
      return Container(
        color: WKColors.homeBg,
        child: SvgPicture.network(
          option!.resolvedUrl,
          key: const ValueKey<String>('chat-background-svg'),
          fit: BoxFit.cover,
          placeholderBuilder: (_) => const SizedBox.expand(),
        ),
      );
    }

    return DecoratedBox(decoration: _legacyDecoration(fallbackStyle));
  }

  List<Color> _resolvePalette(BuildContext context) {
    if (option == null) {
      return const <Color>[];
    }
    final brightness = Theme.of(context).brightness;
    final preferred = brightness == Brightness.dark &&
            option!.darkColors.isNotEmpty
        ? option!.darkColors
        : option!.lightColors;
    final colors = preferred
        .map(_parseHexColor)
        .whereType<Color>()
        .toList(growable: false);
    if (colors.length >= 2) {
      return colors;
    }
    return const <Color>[];
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color,
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _legacyDecoration(WKChatBackgroundStyle style) {
  return switch (style) {
    WKChatBackgroundStyle.classic => const BoxDecoration(
      color: WKColors.homeBg,
    ),
    WKChatBackgroundStyle.sunrise => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          WKColors.brand100,
          WKColors.homeBg,
          WKColors.homeBg,
        ],
      ),
    ),
    WKChatBackgroundStyle.paper => const BoxDecoration(
      color: WKColors.white,
    ),
  };
}

Color? _parseHexColor(String rawValue) {
  final normalized = rawValue.trim().replaceAll('#', '');
  if (normalized.isEmpty) {
    return null;
  }
  final hex = switch (normalized.length) {
    6 => 'FF$normalized',
    8 => normalized,
    _ => '',
  };
  if (hex.isEmpty) {
    return null;
  }
  return Color(int.parse(hex, radix: 16));
}
