import 'package:flutter/material.dart';
import 'wk_colors.dart';

/// 聊天工具栏功能项
class WKChatToolItem {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  WKChatToolItem({required this.icon, required this.title, this.onTap});
}

/// 聊天输入框组件
/// 基于 TangSengDaoDao wk_chat_input_bar 和 toolbar 复刻
class WKChatInputBar extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onVoiceClick;
  final VoidCallback? onEmojiClick;
  final VoidCallback? onPlusClick;
  final bool showVoiceButton;
  final String hintText;

  const WKChatInputBar({
    super.key,
    required this.onSend,
    this.onVoiceClick,
    this.onEmojiClick,
    this.onPlusClick,
    this.showVoiceButton = true,
    this.hintText = '输入消息...',
  });

  @override
  State<WKChatInputBar> createState() => _WKChatInputBarState();
}

class _WKChatInputBarState extends State<WKChatInputBar> {
  final TextEditingController _textController = TextEditingController();
  bool _isRecording = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WKColors.screenBgSelected,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [_buildInputRow()],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        // 语音按钮
        if (widget.showVoiceButton)
          GestureDetector(
            onTapDown: (_) => setState(() => _isRecording = true),
            onTapUp: (_) {
              setState(() => _isRecording = false);
              widget.onVoiceClick?.call();
            },
            onTapCancel: () {
              setState(() => _isRecording = false);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _isRecording ? WKColors.reminderColor : WKColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: WKColors.colorLine, width: 1),
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 20,
                color: _isRecording ? WKColors.white : WKColors.colorDark,
              ),
            ),
          ),
        // 输入框
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: WKColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: WKColors.colorLine, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      hintStyle: const TextStyle(
                        color: WKColors.color999,
                        fontSize: 15,
                      ),
                    ),
                    style: const TextStyle(
                      color: WKColors.colorDark,
                      fontSize: 15,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                // 表情按钮
                IconButton(
                  icon: const Icon(Icons.emoji_emotions_outlined),
                  iconSize: 24,
                  color: WKColors.color999,
                  onPressed: widget.onEmojiClick,
                ),
              ],
            ),
          ),
        ),
        // 更多按钮
        GestureDetector(
          onTap: widget.onPlusClick,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _textController.text.isNotEmpty
                  ? WKColors.primary
                  : WKColors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _textController.text.isNotEmpty
                  ? Icons.send
                  : Icons.add_circle_outline,
              size: 24,
              color: _textController.text.isNotEmpty
                  ? WKColors.white
                  : WKColors.color999,
            ),
          ),
        ),
      ],
    );
  }
}

/// 聊天工具栏面板 (功能菜单)
/// 基于 TangSengDaoDao panel_function_layout 复刻
class WKChatToolbarPanel extends StatelessWidget {
  final List<WKChatToolItem> items;
  final int columns;

  const WKChatToolbarPanel({super.key, required this.items, this.columns = 4});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WKColors.screenBgSelected,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: item.onTap,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: WKColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, size: 28, color: WKColors.colorDark),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  style: const TextStyle(
                    color: WKColors.colorDark,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 语音录制提示组件
/// 基于 TangSengDaoDao frag_recording_voice_layout 复刻
class WKRecordingHint extends StatelessWidget {
  final bool isRecording;

  const WKRecordingHint({super.key, required this.isRecording});

  @override
  Widget build(BuildContext context) {
    if (!isRecording) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: WKColors.tipMessageCellBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, color: WKColors.reminderColor, size: 24),
          const SizedBox(width: 8),
          const Text(
            '正在录音...',
            style: TextStyle(color: WKColors.colorDark, fontSize: 15),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: WKColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text(
              'ֹͣ',
              style: TextStyle(color: WKColors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
