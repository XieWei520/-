import 'package:flutter/material.dart';

/// Chat toolbar widget
class WKChatToolbar extends StatelessWidget {
  final VoidCallback? onImage;
  final VoidCallback? onCamera;
  final VoidCallback? onFile;
  final VoidCallback? onLocation;
  final VoidCallback? onVideo;
  final VoidCallback? onCard;

  const WKChatToolbar({
    super.key,
    this.onImage,
    this.onCamera,
    this.onFile,
    this.onLocation,
    this.onVideo,
    this.onCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        children: [
          _buildButton(Icons.image, 'ͼƬ', onImage),
          _buildButton(Icons.camera_alt, '拍摄', onCamera),
          _buildButton(Icons.folder, '文件', onFile),
          _buildButton(Icons.location_on, '位置', onLocation),
          _buildButton(Icons.video_call, '视频', onVideo),
          _buildButton(Icons.person, '名片', onCard),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon), const SizedBox(height: 4), Text(label)],
      ),
    );
  }
}
