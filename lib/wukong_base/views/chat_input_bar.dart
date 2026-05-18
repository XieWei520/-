import 'package:flutter/material.dart';

/// Chat input bar callback interface
@Deprecated(
  'Use ChatComposer with ChatComposerController instead. Will be removed in v2.0',
)
abstract class ChatInputBarCallback {
  void onTextChanged(String text);
  void onSendText(String text);
  void onVoiceRecordStart();
  void onVoiceRecordEnd();
  void onVoiceRecordCancel();
  void onEmojiTap();
  void onAttachmentTap();
  void onCameraTap();
}

/// Chat input bar widget
@Deprecated(
  'Use ChatComposer with ChatComposerController instead. Will be removed in v2.0',
)
class WKChatInputBar extends StatefulWidget {
  final ChatInputBarCallback? callback;
  final String? hintText;
  final bool showVoiceButton;
  final bool showEmojiButton;
  final bool showAttachmentButton;
  final bool showCameraButton;
  final int? maxLines;
  final TextEditingController? textController;

  const WKChatInputBar({
    super.key,
    this.callback,
    this.hintText = '输入消息...',
    this.showVoiceButton = true,
    this.showEmojiButton = true,
    this.showAttachmentButton = true,
    this.showCameraButton = true,
    this.maxLines,
    this.textController,
  });

  @override
  State<WKChatInputBar> createState() => _WKChatInputBarState();
}

class _WKChatInputBarState extends State<WKChatInputBar> {
  late TextEditingController _textController;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _textController = widget.textController ?? TextEditingController();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.textController == null) {
      _textController.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    widget.callback?.onTextChanged(_textController.text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Voice button
                if (widget.showVoiceButton) _buildVoiceButton(),
                
                const SizedBox(width: 4),
                
                // Text input
                Expanded(
                  child: _buildTextInput(),
                ),
                
                const SizedBox(width: 4),
                
                // Emoji button
                if (widget.showEmojiButton) _buildEmojiButton(),
                
                // Attachment button
                if (widget.showAttachmentButton) _buildAttachmentButton(),
                
                // Camera button
                if (widget.showCameraButton) _buildCameraButton(),
                
                // Send button
                if (_textController.text.isNotEmpty) _buildSendButton(),
              ],
            ),
            
            // Recording indicator
            if (_isRecording) _buildRecordingIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return IconButton(
      icon: Icon(
        _isRecording ? Icons.stop : Icons.mic,
        color: Colors.grey[700],
      ),
      onPressed: () {
        if (_isRecording) {
          _stopRecording();
        } else {
          _startRecording();
        }
      },
    );
  }

  Widget _buildTextInput() {
    return Container(
      constraints: BoxConstraints(
        maxHeight: widget.maxLines != null 
            ? widget.maxLines! * 24.0 + 16 
            : 100,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _textController,
        maxLines: widget.maxLines,
        decoration: InputDecoration(
          hintText: widget.hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          border: InputBorder.none,
        ),
        textInputAction: TextInputAction.send,
        onSubmitted: (value) => _sendMessage(),
      ),
    );
  }

  Widget _buildEmojiButton() {
    return IconButton(
      icon: Icon(
        Icons.emoji_emotions_outlined,
        color: Colors.grey[700],
      ),
      onPressed: widget.callback?.onEmojiTap,
    );
  }

  Widget _buildAttachmentButton() {
    return IconButton(
      icon: Icon(
        Icons.add_circle_outline,
        color: Colors.grey[700],
      ),
      onPressed: widget.callback?.onAttachmentTap,
    );
  }

  Widget _buildCameraButton() {
    return IconButton(
      icon: Icon(
        Icons.camera_alt_outlined,
        color: Colors.grey[700],
      ),
      onPressed: widget.callback?.onCameraTap,
    );
  }

  Widget _buildSendButton() {
    return IconButton(
      icon: const Icon(
        Icons.send,
        color: Colors.blue,
      ),
      onPressed: _sendMessage,
    );
  }

  Widget _buildRecordingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 8),
          const Text('录音中... 上滑取消'),
          const Spacer(),
          GestureDetector(
            onPanEnd: (details) {
              if (details.velocity.pixelsPerSecond.dy < -100) {
                _cancelRecording();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('取消'),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.callback?.onSendText(text);
      _textController.clear();
    }
  }

  void _startRecording() {
    setState(() => _isRecording = true);
    widget.callback?.onVoiceRecordStart();
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
    widget.callback?.onVoiceRecordEnd();
  }

  void _cancelRecording() {
    setState(() => _isRecording = false);
    widget.callback?.onVoiceRecordCancel();
  }
}
