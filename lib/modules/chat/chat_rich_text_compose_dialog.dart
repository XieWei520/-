import 'package:flutter/material.dart';

@immutable
class ChatRichTextSelection {
  const ChatRichTextSelection({required this.title, required this.body});

  final String title;
  final String body;
}

Future<ChatRichTextSelection?> showChatRichTextComposeDialog(
  BuildContext context,
) {
  return showDialog<ChatRichTextSelection>(
    context: context,
    builder: (_) => const _ChatRichTextComposeDialog(),
  );
}

class _ChatRichTextComposeDialog extends StatefulWidget {
  const _ChatRichTextComposeDialog();

  @override
  State<_ChatRichTextComposeDialog> createState() =>
      _ChatRichTextComposeDialogState();
}

class _ChatRichTextComposeDialogState
    extends State<_ChatRichTextComposeDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('\u53d1\u9001\u5bcc\u6587\u672c'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey<String>('chat-rich-text-title'),
              controller: _titleController,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: '\u6807\u9898\uff08\u53ef\u9009\uff09',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey<String>('chat-rich-text-body'),
              controller: _bodyController,
              minLines: 4,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: '\u5185\u5bb9',
                alignLabelWithHint: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('\u53d6\u6d88'),
        ),
        FilledButton(
          key: const ValueKey<String>('chat-rich-text-submit'),
          onPressed: _bodyController.text.trim().isEmpty
              ? null
              : () {
                  Navigator.of(context).pop(
                    ChatRichTextSelection(
                      title: _titleController.text.trim(),
                      body: _bodyController.text.trim(),
                    ),
                  );
                },
          child: const Text('\u53d1\u9001'),
        ),
      ],
    );
  }
}
