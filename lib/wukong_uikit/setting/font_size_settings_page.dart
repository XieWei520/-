import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'setting_preferences.dart';

class FontSizeSettingsPage extends StatefulWidget {
  const FontSizeSettingsPage({super.key});

  @override
  State<FontSizeSettingsPage> createState() => _FontSizeSettingsPageState();
}

class _FontSizeSettingsPageState extends State<FontSizeSettingsPage> {
  late int _selectedIndex;

  double get _scale => WKSettingPreferences.fontScaleFromIndex(_selectedIndex);

  @override
  void initState() {
    super.initState();
    _selectedIndex = WKSettingPreferences.fontScaleToIndex(
      WKSettingPreferences.getFontScale(),
    );
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text('设置字体大小后，需要重新启动${AppConfig.appName}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('完成'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await WKSettingPreferences.setFontScale(_scale);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '字体大小',
      trailing: WKSubPageAction(text: '完成', onTap: _save),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: _FontSizePreview(scale: _scale),
              ),
            ),
          ),
          _FontSizeSelector(
            selectedIndex: _selectedIndex,
            onChanged: (index) => setState(() => _selectedIndex = index),
          ),
        ],
      ),
    );
  }
}

class _FontSizePreview extends StatelessWidget {
  final double scale;

  const _FontSizePreview({required this.scale});

  @override
  Widget build(BuildContext context) {
    final previewTextSize = 16 * scale;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(50, 0, 10, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _PreviewBubble(
                text: '预览字体大小',
                textSize: previewTextSize,
                isOutgoing: true,
              ),
              const SizedBox(width: 8),
              const WKAvatar(name: '我', size: 38),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(95, 10, 50, 0),
          child: Row(
            children: [
              Expanded(
                child: _PreviewBubble(
                  text: '拖动下面的滑块，可设置字体大小',
                  textSize: previewTextSize,
                  isOutgoing: false,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 3, 50, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const WKAvatar(name: '悟空', size: 38),
              const SizedBox(width: 8),
              Expanded(
                child: _PreviewBubble(
                  text:
                      '设置后，会改变聊天、菜单和朋友圈的字体大小。如果在使用过程中存在问题或意见，可反馈给${AppConfig.appName}团队',
                  textSize: previewTextSize,
                  isOutgoing: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  final String text;
  final double textSize;
  final bool isOutgoing;

  const _PreviewBubble({
    required this.text,
    required this.textSize,
    required this.isOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isOutgoing ? WKColors.chatSendBg : WKColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: textSize,
          color: WKColors.colorDark,
          height: 1.35,
        ),
      ),
    );
  }
}

class _FontSizeSelector extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _FontSizeSelector({
    required this.selectedIndex,
    required this.onChanged,
  });

  void _updateFromPosition(BuildContext context, double dx, double width) {
    if (width <= 0) {
      return;
    }
    final segments = 3;
    final clamped = dx.clamp(0, width);
    final index = (clamped / (width / segments)).round().clamp(0, 3);
    onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WKColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 120,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                _updateFromPosition(
                  context,
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
              },
              onHorizontalDragUpdate: (details) {
                _updateFromPosition(
                  context,
                  details.localPosition.dx,
                  constraints.maxWidth,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 56,
                    child: Container(height: 2, color: WKColors.colorCCC),
                  ),
                  for (var index = 0; index < 4; index++)
                    Positioned(
                      left: ((constraints.maxWidth - 32) / 3) * index,
                      top: 40,
                      child: _FontSizeNode(
                        active: selectedIndex == index,
                        onTap: () => onChanged(index),
                      ),
                    ),
                  const Positioned(
                    left: 0,
                    bottom: 18,
                    child: Text(
                      'A',
                      style: TextStyle(fontSize: 14, color: WKColors.color999),
                    ),
                  ),
                  const Positioned(
                    right: 0,
                    bottom: 14,
                    child: Text(
                      'A',
                      style: TextStyle(fontSize: 22, color: WKColors.color999),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FontSizeNode extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _FontSizeNode({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active ? WKColors.brand500 : WKColors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? WKColors.brand500 : WKColors.colorCCC,
            width: active ? 0 : 2,
          ),
        ),
        child: active
            ? const Center(
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: WKColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
