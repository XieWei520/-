import 'package:flutter/material.dart';

import '../../../core/utils/platform_utils.dart';
import '../../../widgets/wk_colors.dart';
import '../../../widgets/wk_web_ui_tokens.dart';

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

    return RepaintBoundary(
      child: DecoratedBox(
        key: const ValueKey<String>('chat-composer-shell'),
        decoration: BoxDecoration(
          color: webStyle ? WKWebColors.surface : Colors.white,
          border: Border(
            top: BorderSide(
              color: webStyle
                  ? WKWebColors.borderWarm
                  : isMobileWarmStyle
                  ? WKWebColors.borderWarm
                  : WKColors.layoutColorSelected,
              width: 1,
            ),
          ),
          boxShadow: webStyle
              ? const <BoxShadow>[
                  BoxShadow(
                    color: WKWebColors.shadow,
                    blurRadius: 14,
                    offset: Offset(0, -4),
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
              duration: const Duration(milliseconds: 200),
              child: panel,
            ),
          ],
        ),
      ),
    );
  }
}
