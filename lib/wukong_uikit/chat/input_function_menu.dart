import 'package:flutter/material.dart';

/// Function menu panel for chat input (the "+" button menu).
///
/// Shows a grid of function buttons when user taps the "+" icon:
/// - Photo/Video
/// - Camera
/// - File
/// - Location
/// - Voice Call
/// - Video Call
/// - Contact Card
/// - More
/// Legacy placeholder menu retained only for compatibility review.
/// The active chat surface uses ChatPageShell toolbar slots instead.
@Deprecated('Legacy placeholder menu. Do not use for new chat flows.')
class InputFunctionMenu extends StatelessWidget {
  /// Callback when a function is selected.
  final ValueChanged<FunctionMenuItem> onItemSelected;

  const InputFunctionMenu({
    super.key,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = _getDefaultItems();

    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _FunctionGridItem(
            item: item,
            onTap: () => onItemSelected(item),
          );
        },
      ),
    );
  }

  List<FunctionMenuItem> _getDefaultItems() {
    return [
      FunctionMenuItem(
        id: 'photo_video',
        title: '相册',
        icon: Icons.photo_library,
        iconColor: Colors.green,
      ),
      FunctionMenuItem(
        id: 'camera',
        title: '拍摄',
        icon: Icons.camera_alt,
        iconColor: Colors.blue,
      ),
      FunctionMenuItem(
        id: 'file',
        title: '文件',
        icon: Icons.insert_drive_file,
        iconColor: Colors.orange,
      ),
      FunctionMenuItem(
        id: 'location',
        title: '位置',
        icon: Icons.location_on,
        iconColor: Colors.red,
      ),
      FunctionMenuItem(
        id: 'voice_call',
        title: '语音通话',
        icon: Icons.phone,
        iconColor: Colors.green,
      ),
      FunctionMenuItem(
        id: 'video_call',
        title: '视频通话',
        icon: Icons.videocam,
        iconColor: Colors.blue,
      ),
      FunctionMenuItem(
        id: 'contact_card',
        title: '名片',
        icon: Icons.person,
        iconColor: Colors.purple,
      ),
      FunctionMenuItem(
        id: 'more',
        title: '更多',
        icon: Icons.apps,
        iconColor: Colors.grey,
      ),
    ];
  }
}

/// Represents a function menu item.
class FunctionMenuItem {
  final String id;
  final String title;
  final IconData icon;
  final Color iconColor;

  const FunctionMenuItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconColor,
    this.extraData,
  });

  final Map<String, dynamic>? extraData;
}

class _FunctionGridItem extends StatelessWidget {
  final FunctionMenuItem item;
  final VoidCallback onTap;

  const _FunctionGridItem({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: item.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              item.icon,
              color: item.iconColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Popup panel that shows function menu with page indicator.
class FunctionMenuPanel extends StatefulWidget {
  final ValueChanged<FunctionMenuItem> onItemSelected;

  const FunctionMenuPanel({
    super.key,
    required this.onItemSelected,
  });

  @override
  State<FunctionMenuPanel> createState() => _FunctionMenuPanelState();
}

class _FunctionMenuPanelState extends State<FunctionMenuPanel> {
  int _currentPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const itemsPerPage = 8;
    final allItems = <FunctionMenuItem>[
      // Page 1
      const FunctionMenuItem(
        id: 'photo_video',
        title: '相册',
        icon: Icons.photo_library,
        iconColor: Colors.green,
      ),
      const FunctionMenuItem(
        id: 'camera',
        title: '拍摄',
        icon: Icons.camera_alt,
        iconColor: Colors.blue,
      ),
      const FunctionMenuItem(
        id: 'file',
        title: '文件',
        icon: Icons.insert_drive_file,
        iconColor: Colors.orange,
      ),
      const FunctionMenuItem(
        id: 'location',
        title: '位置',
        icon: Icons.location_on,
        iconColor: Colors.red,
      ),
      const FunctionMenuItem(
        id: 'voice_call',
        title: '语音通话',
        icon: Icons.phone,
        iconColor: Colors.green,
      ),
      const FunctionMenuItem(
        id: 'video_call',
        title: '视频通话',
        icon: Icons.videocam,
        iconColor: Colors.blue,
      ),
      const FunctionMenuItem(
        id: 'contact_card',
        title: '名片',
        icon: Icons.person,
        iconColor: Colors.purple,
      ),
      const FunctionMenuItem(
        id: 'sticker',
        title: '表情',
        icon: Icons.sentiment_satisfied,
        iconColor: Colors.amber,
      ),
      // Page 2
      const FunctionMenuItem(
        id: 'favorite',
        title: '收藏',
        icon: Icons.star,
        iconColor: Colors.yellow,
      ),
      const FunctionMenuItem(
        id: 'transfer',
        title: '转账',
        icon: Icons.attach_money,
        iconColor: Colors.green,
      ),
      const FunctionMenuItem(
        id: 'red_packet',
        title: '红包',
        icon: Icons.card_giftcard,
        iconColor: Colors.red,
      ),
      const FunctionMenuItem(
        id: 'screenshot',
        title: '截图',
        icon: Icons.screenshot,
        iconColor: Colors.blue,
      ),
      const FunctionMenuItem(
        id: 'translate',
        title: '翻译',
        icon: Icons.translate,
        iconColor: Colors.purple,
      ),
      const FunctionMenuItem(
        id: 'voice_to_text',
        title: '语音转文字',
        icon: Icons.mic_external_on,
        iconColor: Colors.teal,
      ),
      const FunctionMenuItem(
        id: 'meeting',
        title: '会议',
        icon: Icons.meeting_room,
        iconColor: Colors.indigo,
      ),
      const FunctionMenuItem(
        id: 'more',
        title: '更多',
        icon: Icons.apps,
        iconColor: Colors.grey,
      ),
    ];

    final totalPages = (allItems.length / itemsPerPage).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: totalPages,
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * itemsPerPage;
              final endIndex = (startIndex + itemsPerPage).clamp(0, allItems.length);
              final pageItems = allItems.sublist(startIndex, endIndex);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: pageItems.length,
                  itemBuilder: (context, index) {
                    final item = pageItems[index];
                    return _FunctionGridItem(
                      item: item,
                      onTap: () => widget.onItemSelected(item),
                    );
                  },
                ),
              );
            },
          ),
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? Colors.blue : Colors.grey[300],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
