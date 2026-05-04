import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';

class AvatarCropPage extends StatelessWidget {
  const AvatarCropPage({super.key, required this.sourcePath});

  final String sourcePath;

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '裁剪头像',
      body: ColoredBox(
        color: WKColors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.crop_rounded, color: WKColors.white, size: 48),
                const SizedBox(height: 16),
                const Text(
                  '当前平台不支持本地头像裁剪。',
                  style: TextStyle(color: WKColors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
