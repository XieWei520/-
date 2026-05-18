import 'package:flutter/material.dart';

import '../../../core/utils/platform_utils.dart';
import '../../../widgets/liquid_glass_tokens.dart';
import '../../../widgets/wk_colors.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    this.header,
    this.robotInlineHeader,
    this.webStyle = false,
    this.showToolbarRow = true,
    required this.inputRow,
    required this.toolbarRow,
    required this.panel,
  });

  final Widget? header;
  final Widget? robotInlineHeader;
  final bool webStyle;
  final bool showToolbarRow;
  final Widget inputRow;
  final Widget toolbarRow;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    final isMobileWarmStyle = PlatformUtils.isMobile && !webStyle;
    final tokens = LiquidGlassTokens.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final restrainedSurface = Theme.of(context).brightness == Brightness.dark
        ? tokens.surface
        : const Color(0xFFF8FAFC);
    final restrainedBorder = Theme.of(context).brightness == Brightness.dark
        ? tokens.border
        : const Color(0xFFE2E8F0);

    return RepaintBoundary(
      child: DecoratedBox(
        key: const ValueKey<String>('chat-composer-shell'),
        decoration: BoxDecoration(
          color: webStyle || isMobileWarmStyle
              ? restrainedSurface
              : Colors.white,
          border: Border(
            top: BorderSide(
              color: webStyle || isMobileWarmStyle
                  ? restrainedBorder
                  : WKColors.layoutColorSelected,
              width: 1,
            ),
          ),
          boxShadow: webStyle || isMobileWarmStyle
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0A111827),
                    blurRadius: 8,
                    offset: Offset(0, -1),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?header,
            ?robotInlineHeader,
            Padding(
              key: const ValueKey<String>('chat-composer-input-row'),
              padding: EdgeInsets.fromLTRB(
                isMobileWarmStyle ? 12 : 10,
                10,
                isMobileWarmStyle ? 12 : 10,
                showToolbarRow ? 4 : 10,
              ),
              child: inputRow,
            ),
            if (showToolbarRow) ...[
              const SizedBox(height: 2),
              Padding(
                key: const ValueKey<String>('chat-composer-toolbar-row'),
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: toolbarRow,
              ),
            ],
            AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: panel,
            ),
          ],
        ),
      ),
    );
  }
}
