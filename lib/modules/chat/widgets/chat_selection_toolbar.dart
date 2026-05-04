import 'package:flutter/material.dart';

const String _selectionCountPrefix = '\u5df2\u9009\u62e9';
const String _selectionCountSuffix = '\u6761';
const String _forwardLabel = '\u8f6c\u53d1';

class ChatSelectionToolbar extends StatelessWidget {
  const ChatSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.onCancel,
    required this.onForward,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('chat-selection-toolbar'),
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey<String>('chat-selection-cancel'),
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
            Expanded(
              child: Text(
                '$_selectionCountPrefix $selectedCount $_selectionCountSuffix',
                key: const ValueKey<String>('chat-selection-count'),
              ),
            ),
            TextButton(
              key: const ValueKey<String>('chat-selection-forward'),
              onPressed: onForward,
              child: const Text(_forwardLabel),
            ),
          ],
        ),
      ),
    );
  }
}
