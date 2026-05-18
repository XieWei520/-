import 'package:flutter/material.dart';

import '../../../core/motion/chat_motion.dart';
import '../../../widgets/liquid_glass_tokens.dart';
import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_reference_assets.dart';
import '../../../widgets/wk_web_ui_tokens.dart';

const double composerActionButtonExtent = 48;
const double composerActionIconExtent = 24;
const double composerToolbarArtworkExtent = 38;
const double composerCallIconExtent = 22;
const double mobileComposerActionButtonExtent = 48;
const double mobileComposerActionIconExtent = 24;
const double mobileComposerSendButtonWidth = 60;

Widget buildComposerSendButtonForTesting({
  required bool enabled,
  bool webStyle = false,
  bool mobileWarmStyle = false,
  VoidCallback? onTap,
}) {
  return ComposerSendButton(
    enabled: enabled,
    liquidStyle: webStyle || mobileWarmStyle,
    onTap: onTap,
  );
}

Widget buildComposerToolbarButtonForTesting({
  Key? key,
  required String asset,
  VoidCallback? onTap,
}) {
  return ComposerToolbarButton(key: key, asset: asset, onTap: onTap);
}

Widget buildComposerCallToolbarButtonForTesting({
  Key? key,
  required VoidCallback onTap,
  String asset = '',
}) {
  return ComposerCallToolbarButton(
    key: key,
    decorationKey: const ValueKey<String>('chat-call-test-decoration'),
    tooltip: 'Call',
    asset: asset,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF36E6B3), Color(0xFF16A76C)],
    ),
    onTap: onTap,
  );
}

Widget buildFunctionItemForTesting({
  required String sid,
  required String asset,
  required String label,
  VoidCallback? onTap,
}) {
  return ComposerFunctionItem(
    sid: sid,
    asset: asset,
    label: label,
    textColor: WKWebColors.textPrimary,
    onTap: onTap,
  );
}

Key chatIconMotionKeyFor(Key? widgetKey, String fallback) {
  if (widgetKey is ValueKey<String>) {
    final value = widgetKey.value;
    return ValueKey<String>(
      value.startsWith('chat-') ? '$value-motion' : 'chat-$value-motion',
    );
  }
  return ValueKey<String>(fallback);
}

class ChatIconInteraction extends StatefulWidget {
  const ChatIconInteraction({
    super.key,
    required this.motionKey,
    required this.child,
    this.enabled = true,
    this.disabledScale = 1.0,
  });

  static const double hoverScale = 1.06;
  static const double pressedScale = 0.92;

  final Key motionKey;
  final Widget child;
  final bool enabled;
  final double disabledScale;

  @override
  State<ChatIconInteraction> createState() => _ChatIconInteractionState();
}

class _ChatIconInteractionState extends State<ChatIconInteraction> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (!widget.enabled || _hovered == value) {
      return;
    }
    setState(() {
      _hovered = value;
      if (!value) {
        _pressed = false;
      }
    });
  }

  void _setPressed(bool value) {
    if (!widget.enabled || _pressed == value) {
      return;
    }
    setState(() {
      _pressed = value;
    });
  }

  @override
  void didUpdateWidget(covariant ChatIconInteraction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && (_hovered || _pressed)) {
      _hovered = false;
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final scale = !widget.enabled
        ? widget.disabledScale
        : _pressed
        ? ChatIconInteraction.pressedScale
        : _hovered
        ? ChatIconInteraction.hoverScale
        : 1.0;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: widget.enabled ? (_) => _setPressed(true) : null,
        onPointerUp: widget.enabled ? (_) => _setPressed(false) : null,
        onPointerCancel: widget.enabled ? (_) => _setPressed(false) : null,
        child: AnimatedScale(
          key: widget.motionKey,
          scale: scale,
          duration: ChatMotionDurations.pressedScale.resolve(
            disableAnimations: reduceMotion,
          ),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class ComposerToolbarButton extends StatelessWidget {
  const ComposerToolbarButton({
    super.key,
    required this.asset,
    this.onTap,
    this.extent = composerActionButtonExtent,
    this.artworkExtent = composerToolbarArtworkExtent,
    this.fit = BoxFit.fill,
    this.warmStyle = false,
  });

  final String asset;
  final VoidCallback? onTap;
  final double extent;
  final double artworkExtent;
  final BoxFit fit;
  final bool warmStyle;

  @override
  Widget build(BuildContext context) {
    final motionKey = chatIconMotionKeyFor(
      key,
      'chat-composer-toolbar-button-motion',
    );
    final icon = IconButton(
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: extent, height: extent),
      onPressed: onTap ?? () {},
      icon: asset.trim().isEmpty
          ? SizedBox(width: artworkExtent, height: artworkExtent)
          : WKReferenceAssets.image(
              asset,
              width: artworkExtent,
              height: artworkExtent,
              fit: fit,
            ),
    );

    if (!warmStyle) {
      return ChatIconInteraction(
        motionKey: motionKey,
        child: SizedBox(width: extent, height: extent, child: icon),
      );
    }

    return ChatIconInteraction(
      motionKey: motionKey,
      child: SizedBox(
        width: extent,
        height: extent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(WKWebRadius.control),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x08111827),
                blurRadius: 5,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Center(child: icon),
        ),
      ),
    );
  }
}

class ComposerCallToolbarButton extends StatelessWidget {
  const ComposerCallToolbarButton({
    super.key,
    required this.decorationKey,
    required this.tooltip,
    required this.asset,
    required this.gradient,
    required this.onTap,
  });

  final Key decorationKey;
  final String tooltip;
  final String asset;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final motionKey = chatIconMotionKeyFor(
      key,
      'chat-composer-call-button-motion',
    );
    return ChatIconInteraction(
      motionKey: motionKey,
      child: SizedBox(
        width: composerActionButtonExtent,
        height: composerActionButtonExtent,
        child: Tooltip(
          message: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: onTap,
              radius: composerActionButtonExtent / 2,
              containedInkWell: true,
              borderRadius: BorderRadius.circular(18),
              child: Center(
                child: DecoratedBox(
                  key: decorationKey,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 38,
                    height: 38,
                    child: Center(
                      child: asset.trim().isEmpty
                          ? const SizedBox(
                              width: composerCallIconExtent,
                              height: composerCallIconExtent,
                            )
                          : WKReferenceAssets.image(
                              asset,
                              width: composerCallIconExtent,
                              height: composerCallIconExtent,
                              tint: Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ComposerSendButton extends StatefulWidget {
  const ComposerSendButton({
    super.key,
    required this.enabled,
    this.onTap,
    this.width = composerActionButtonExtent,
    this.height = composerActionButtonExtent,
    this.iconExtent = composerActionIconExtent,
    this.warmStyle = false,
    this.liquidStyle = false,
  });

  final bool enabled;
  final VoidCallback? onTap;
  final double width;
  final double height;
  final double iconExtent;
  final bool warmStyle;
  final bool liquidStyle;

  @override
  State<ComposerSendButton> createState() => _ComposerSendButtonState();
}

class _ComposerSendButtonState extends State<ComposerSendButton> {
  @override
  Widget build(BuildContext context) {
    final tokens = LiquidGlassTokens.of(context);
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final liquidDisabledIconColor = isDarkTheme
        ? LiquidGlassColors.darkPrimary
        : const Color(0xFF64748B);
    final iconColor = widget.liquidStyle
        ? (widget.enabled ? Colors.white : liquidDisabledIconColor)
        : widget.enabled
        ? WKColors.brand500
        : WKColors.popupText;

    return ChatIconInteraction(
      motionKey: const ValueKey<String>('chat-send-button-motion'),
      enabled: widget.enabled,
      disabledScale: 0.88,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.liquidStyle
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? null
                      : (isDarkTheme ? tokens.surface : Colors.white),
                  gradient: widget.enabled
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF2F80ED), Color(0xFF2563D9)],
                        )
                      : null,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.enabled
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: widget.enabled
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x1A2563D9),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: IconButton(
                  key: const ValueKey<String>('chat-send-button'),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints.tightFor(
                    width: widget.width,
                    height: widget.height,
                  ),
                  onPressed: widget.enabled ? widget.onTap : null,
                  icon: WKReferenceAssets.image(
                    WKReferenceAssets.chatSend,
                    width: widget.iconExtent,
                    height: widget.iconExtent,
                    tint: iconColor,
                  ),
                ),
              )
            : IconButton(
                key: const ValueKey<String>('chat-send-button'),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: widget.width,
                  height: widget.height,
                ),
                onPressed: widget.enabled ? widget.onTap : null,
                icon: WKReferenceAssets.image(
                  WKReferenceAssets.chatSend,
                  width: widget.iconExtent,
                  height: widget.iconExtent,
                  tint: iconColor,
                ),
              ),
      ),
    );
  }
}

class ComposerFunctionItem extends StatelessWidget {
  const ComposerFunctionItem({
    super.key,
    required this.sid,
    required this.asset,
    required this.label,
    required this.textColor,
    this.onTap,
  });

  final String sid;
  final String asset;
  final String label;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: ChatIconInteraction(
        motionKey: ValueKey<String>('chat-function-$sid-motion'),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _FunctionIcon(sid: sid, asset: asset),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: textColor),
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

class _FunctionIcon extends StatelessWidget {
  const _FunctionIcon({required this.sid, required this.asset});

  final String sid;
  final String asset;

  @override
  Widget build(BuildContext context) {
    final style = _functionIconStyleForSid(sid);
    if (style == null) {
      return asset.trim().isEmpty
          ? const SizedBox(width: 40, height: 40)
          : WKReferenceAssets.image(asset, width: 40, height: 40);
    }

    return DecoratedBox(
      key: ValueKey<String>('chat-function-$sid-icon'),
      decoration: BoxDecoration(
        gradient: style.gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: style.shadowColor.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Stack(
          children: [
            Positioned(
              right: -8,
              top: -10,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 32, height: 32),
              ),
            ),
            Positioned(
              left: -6,
              bottom: -8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 28, height: 28),
              ),
            ),
            Center(child: Icon(style.icon, size: 26, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _FunctionIconStyle {
  const _FunctionIconStyle({
    required this.icon,
    required this.gradient,
    required this.shadowColor,
  });

  final IconData icon;
  final Gradient gradient;
  final Color shadowColor;
}

_FunctionIconStyle? _functionIconStyleForSid(String sid) {
  switch (sid) {
    case 'chooseImg':
      return const _FunctionIconStyle(
        icon: Icons.photo_library_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF41D8FF), Color(0xFF4E6BFF)],
        ),
        shadowColor: Color(0xFF4E6BFF),
      );
    case 'captureImg':
      return const _FunctionIconStyle(
        icon: Icons.photo_camera_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFCB5F), Color(0xFFFF6B8A)],
        ),
        shadowColor: Color(0xFFFF7A45),
      );
    case 'chooseFile':
      return const _FunctionIconStyle(
        icon: Icons.description_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB86B), Color(0xFFFF7A45)],
        ),
        shadowColor: Color(0xFFFF7A45),
      );
    case 'sendLocation':
      return const _FunctionIconStyle(
        icon: Icons.location_on_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF36E6B3), Color(0xFF16A76C)],
        ),
        shadowColor: Color(0xFF16A76C),
      );
    case 'chooseCard':
      return const _FunctionIconStyle(
        icon: Icons.badge_rounded,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB576FF), Color(0xFF7A5CFF)],
        ),
        shadowColor: Color(0xFF7A5CFF),
      );
    default:
      return null;
  }
}
