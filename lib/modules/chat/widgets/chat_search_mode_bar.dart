import 'package:flutter/material.dart';

class ChatSearchModeBar extends StatefulWidget {
  const ChatSearchModeBar({
    super.key,
    required this.initialKeyword,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClose,
  });

  final String initialKeyword;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClose;

  @override
  State<ChatSearchModeBar> createState() => _ChatSearchModeBarState();
}

class _ChatSearchModeBarState extends State<ChatSearchModeBar> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialKeyword,
  );

  @override
  void didUpdateWidget(covariant ChatSearchModeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialKeyword != oldWidget.initialKeyword &&
        widget.initialKeyword != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initialKeyword,
        selection: TextSelection.collapsed(
          offset: widget.initialKeyword.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey<String>('chat-search-mode-field'),
            controller: _controller,
            autofocus: true,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decoration: const InputDecoration(
              hintText: 'Search chat history',
              border: InputBorder.none,
            ),
          ),
        ),
        IconButton(onPressed: widget.onClose, icon: const Icon(Icons.close)),
      ],
    );
  }
}
