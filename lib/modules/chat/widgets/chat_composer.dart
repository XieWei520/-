import 'package:flutter/material.dart';

import '../../../widgets/wk_colors.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    this.header,
    this.robotInlineHeader,
    required this.inputRow,
    required this.toolbarRow,
    required this.panel,
  });

  final Widget? header;
  final Widget? robotInlineHeader;
  final Widget inputRow;
  final Widget toolbarRow;
  final Widget panel;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: WKColors.layoutColorSelected, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (header != null) header!,
            if (robotInlineHeader != null) robotInlineHeader!,
            Padding(
              key: const ValueKey<String>('chat-composer-input-row'),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: inputRow,
            ),
            const SizedBox(height: 2),
            Padding(
              key: const ValueKey<String>('chat-composer-toolbar-row'),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: toolbarRow,
            ),
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
