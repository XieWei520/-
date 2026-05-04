import 'package:flutter/material.dart';

import '../modules/chat/robot_card_message.dart';
import 'wk_avatar.dart';
import 'wk_colors.dart';
import 'wk_design_tokens.dart';

class RobotMessageCard extends StatefulWidget {
  const RobotMessageCard({
    super.key,
    required this.data,
    required this.timeText,
    this.onTap,
  });

  final RobotCardViewData data;
  final String timeText;
  final VoidCallback? onTap;

  @override
  State<RobotMessageCard> createState() => _RobotMessageCardState();
}

class _RobotMessageCardState extends State<RobotMessageCard> {
  bool _hovering = false;
  bool _pressed = false;

  bool get _clickable => widget.data.isClickable && widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final footerText = <String>[
      widget.data.robotName,
      widget.timeText.trim(),
    ].where((value) => value.trim().isNotEmpty).join(' · ');
    final surface = BorderRadius.circular(24);
    final lift = _clickable && _hovering && !_pressed ? -2.0 : 0.0;

    return MouseRegion(
      cursor: _clickable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (!_clickable) {
          return;
        }
        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        if (!_clickable) {
          return;
        }
        setState(() {
          _hovering = false;
          _pressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, lift, 0),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: surface,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF162334),
                  Color(0xFF1D2D43),
                  Color(0xFF223851),
                ],
              ),
              border: Border.all(
                color: _clickable
                    ? const Color(0x66F5B971)
                    : const Color(0x33BCD2E8),
              ),
              boxShadow: _resolveShadow(),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -28,
                  right: -12,
                  child: IgnorePointer(
                    child: Container(
                      width: 138,
                      height: 138,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: <Color>[Color(0x40F5B971), Color(0x00F5B971)],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.26),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                InkWell(
                  key: const ValueKey<String>('robot-message-card'),
                  onTap: _clickable ? widget.onTap : null,
                  onHighlightChanged: (value) {
                    if (!_clickable) {
                      return;
                    }
                    setState(() {
                      _pressed = value;
                    });
                  },
                  borderRadius: surface,
                  splashColor: Colors.white.withValues(alpha: 0.08),
                  hoverColor: Colors.white.withValues(alpha: 0.04),
                  highlightColor: Colors.white.withValues(alpha: 0.03),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.data.eyebrow,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFF93A8BC),
                                    fontSize: 10.5,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    fontFamily: WKFontFamily.primary,
                                    fontFamilyFallback:
                                        WKTypography.fontFamilyFallback,
                                  ),
                                ),
                              ),
                              if (widget.data.badge.isNotEmpty)
                                Flexible(
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1AF5B971),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: const Color(0x33F5B971),
                                      ),
                                    ),
                                    child: Text(
                                      widget.data.badge,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFFF6C98F),
                                        fontSize: 11,
                                        height: 1,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        fontFamily: WKFontFamily.primary,
                                        fontFamilyFallback:
                                            WKTypography.fontFamilyFallback,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.data.title,
                            style: TextStyle(
                              color: WKColors.white,
                              fontSize: 20,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              fontFamily: WKFontFamily.primary,
                              fontFamilyFallback:
                                  WKTypography.fontFamilyFallback,
                            ),
                          ),
                          if (widget.data.body.trim().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              widget.data.body,
                              style: TextStyle(
                                color: const Color(0xFFD2DDEA),
                                fontSize: 14.5,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                fontFamily: WKFontFamily.primary,
                                fontFamilyFallback:
                                    WKTypography.fontFamilyFallback,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              WKAvatar(
                                url: widget.data.robotAvatar,
                                name: widget.data.robotName,
                                size: 26,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  footerText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: const Color(0xFFB1C1D4),
                                    fontSize: 12.5,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: WKFontFamily.primary,
                                    fontFamilyFallback:
                                        WKTypography.fontFamilyFallback,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<BoxShadow> _resolveShadow() {
    if (_pressed) {
      return const <BoxShadow>[
        BoxShadow(
          color: Color(0x18081624),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ];
    }
    if (_hovering) {
      return const <BoxShadow>[
        BoxShadow(
          color: Color(0x30081624),
          blurRadius: 32,
          offset: Offset(0, 18),
        ),
      ];
    }
    return const <BoxShadow>[
      BoxShadow(
        color: Color(0x24081624),
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
    ];
  }
}
