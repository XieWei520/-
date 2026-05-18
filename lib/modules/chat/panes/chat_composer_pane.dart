import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat_session.dart';
import '../../../data/providers/conversation_provider.dart';
import '../chat_composer_controller.dart';

class ChatComposerPane extends ConsumerStatefulWidget {
  const ChatComposerPane({
    super.key,
    required this.session,
    this.onSubmitText,
    this.onPickImage,
    this.onPickFile,
    this.onStartVoiceInput,
  });

  final ChatSession session;
  final ValueChanged<String>? onSubmitText;
  final VoidCallback? onPickImage;
  final VoidCallback? onPickFile;
  final VoidCallback? onStartVoiceInput;

  @override
  ConsumerState<ChatComposerPane> createState() => _ChatComposerPaneState();
}

class _ChatComposerPaneState extends ConsumerState<ChatComposerPane> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final composerState = ref.watch(chatComposerProvider(widget.session));
    final composerController = ref.read(
      chatComposerProvider(widget.session).notifier,
    );
    if (_controller.text != composerState.text) {
      _controller.value = TextEditingValue(
        text: composerState.text,
        selection: TextSelection.collapsed(offset: composerState.text.length),
      );
    }

    return Material(
      key: const ValueKey<String>('chat-composer-pane'),
      elevation: 2,
      child: SafeArea(
        top: false,
        child: Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.enter):
                const _SendIntent(),
            const SingleActivator(LogicalKeyboardKey.enter, shift: true):
                const _InsertNewlineIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _SendIntent: CallbackAction<_SendIntent>(
                onInvoke: (_) {
                  _submit(composerController);
                  return null;
                },
              ),
              _InsertNewlineIntent: CallbackAction<_InsertNewlineIntent>(
                onInvoke: (_) {
                  final selection = _controller.selection;
                  final text = _controller.text.replaceRange(
                    selection.start,
                    selection.end,
                    '\n',
                  );
                  composerController.updateText(text);
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Row(
                  children: <Widget>[
                    IconButton(
                      key: const ValueKey<String>('chat-composer-voice'),
                      onPressed: widget.onStartVoiceInput,
                      icon: const Icon(Icons.mic_none),
                      tooltip: '语音',
                    ),
                    IconButton(
                      key: const ValueKey<String>('chat-composer-image'),
                      onPressed: widget.onPickImage,
                      icon: const Icon(Icons.image_outlined),
                      tooltip: '图片',
                    ),
                    IconButton(
                      key: const ValueKey<String>('chat-composer-file'),
                      onPressed: widget.onPickFile,
                      icon: const Icon(Icons.attach_file),
                      tooltip: '文件',
                    ),
                    Expanded(
                      child: TextField(
                        key: const ValueKey<String>('chat-composer-input'),
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        onChanged: composerController.updateText,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: '输入消息',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey<String>('chat-composer-send'),
                      onPressed: composerState.text.trim().isEmpty
                          ? null
                          : () => _submit(composerController),
                      child: const Text('发送'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(ChatComposerController composerController) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    widget.onSubmitText?.call(text);
    composerController.updateText('');
  }
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class _InsertNewlineIntent extends Intent {
  const _InsertNewlineIntent();
}
