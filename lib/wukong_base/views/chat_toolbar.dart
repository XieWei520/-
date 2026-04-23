import 'package:flutter/material.dart';

/// Chat toolbar item
class ChatToolBarItem {
  final String label;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const ChatToolBarItem({
    required this.label,
    required this.icon,
    this.iconColor,
    required this.onTap,
  });
}

/// Chat toolbar widget
class WKChatToolbar extends StatelessWidget {
  final List<ChatToolBarItem> items;
  final int crossAxisCount;
  final double itemSize;
  final Color? backgroundColor;
  final EdgeInsets? padding;

  const WKChatToolbar({
    super.key,
    required this.items,
    this.crossAxisCount = 4,
    this.itemSize = 60,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Colors.grey[100],
      padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: 1,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildToolbarItem(item);
        },
      ),
    );
  }

  Widget _buildToolbarItem(ChatToolBarItem item) {
    return InkWell(
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              item.icon,
              size: 24,
              color: item.iconColor ?? Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// Default chat toolbar items
class DefaultChatToolbarItems {
  static List<ChatToolBarItem> getDefaultItems({
    required VoidCallback onPhotoTap,
    required VoidCallback onCameraTap,
    required VoidCallback onLocationTap,
    required VoidCallback onFileTap,
  }) {
    return [
      ChatToolBarItem(
        label: '相册',
        icon: Icons.photo_library,
        onTap: onPhotoTap,
      ),
      ChatToolBarItem(
        label: '拍摄',
        icon: Icons.camera_alt,
        onTap: onCameraTap,
      ),
      ChatToolBarItem(
        label: '位置',
        icon: Icons.location_on,
        onTap: onLocationTap,
      ),
      ChatToolBarItem(
        label: '文件',
        icon: Icons.insert_drive_file,
        onTap: onFileTap,
      ),
    ];
  }
}
