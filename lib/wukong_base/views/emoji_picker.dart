import 'package:flutter/material.dart';

/// Emoji picker widget
class WKEmojiPicker extends StatefulWidget {
  final Function(String emoji) onEmojiSelected;
  final VoidCallback? onBackspaceTap;
  final VoidCallback? onStickerTap;
  final List<String>? recentEmojis;

  const WKEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    this.onBackspaceTap,
    this.onStickerTap,
    this.recentEmojis,
  });

  @override
  State<WKEmojiPicker> createState() => _WKEmojiPickerState();
}

class _WKEmojiPickerState extends State<WKEmojiPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Common emoji categories
  static const List<String> _smileys = ['😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥', '😔', '😕', '🙁', '☹️', '😟'];
  static const List<String> _gestures = ['👍', '👎', '👊', '✊', '🤛', '🤜', '🤝', '👏', '🙌', '👐', '🤲', '🙏', '✌️', '🤞', '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤏', '✍️', '🙏', '💪', '🦾', '🦿', '🦵', '🦶', '👂', '🦻', '👃', '🧠', '🫀', '🫁', '🦷', '🦴', '👀', '👁️', '👅', '👄'];
  static const List<String> _objects = ['⌚', '📱', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '🖲️', '💽', '💾', '💿', '📀', '📼', '📷', '📸', '📹', '🎥', '📽️', '🎞️', '📞', '☎️', '📟', '📠', '📺', '📻', '🎙️', '🎚️', '🎛️', '🧭', '⏱️', '⏲️', '⏰', '🕰️', '⌛', '⏳', '📡', '🔋', '🔌', '💡', '🔦', '🕯️', '🧯', '🛢️', '💸', '💵', '💴', '💶', '💷'];
  static const List<String> _symbols = ['❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔', '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️', '✝️', '☪️', '🕉', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐', '⛎', '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️', '☣️'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      color: Colors.grey[100],
      child: Column(
        children: [
          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: const [
              Tab(text: '😀'),
              Tab(text: '👍'),
              Tab(text: '💡'),
              Tab(text: '❤️'),
            ],
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEmojiGrid(_smileys),
                _buildEmojiGrid(_gestures),
                _buildEmojiGrid(_objects),
                _buildEmojiGrid(_symbols),
              ],
            ),
          ),
          
          // Bottom actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: widget.onStickerTap,
                  icon: const Icon(Icons.face),
                  label: const Text('表情包'),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.backspace),
                  onPressed: widget.onBackspaceTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiGrid(List<String> emojis) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () => widget.onEmojiSelected(emojis[index]),
          child: Center(
            child: Text(
              emojis[index],
              style: const TextStyle(fontSize: 24),
            ),
          ),
        );
      },
    );
  }
}
