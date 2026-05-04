import 'package:flutter/material.dart';

import '../../data/models/chat_background_option.dart';
import '../../service/api/common_api.dart';
import '../../widgets/chat_background_surface.dart';
import '../../widgets/wk_avatar.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'setting_preferences.dart';

typedef ChatBackgroundsLoader = Future<List<ChatBackgroundOption>> Function();

class ChatBackgroundSettingsPage extends StatefulWidget {
  const ChatBackgroundSettingsPage({
    super.key,
    this.backgroundsLoader,
    this.channelId,
    this.channelType,
  });

  final ChatBackgroundsLoader? backgroundsLoader;
  final String? channelId;
  final int? channelType;

  @override
  State<ChatBackgroundSettingsPage> createState() =>
      _ChatBackgroundSettingsPageState();
}

class _ChatBackgroundSettingsPageState
    extends State<ChatBackgroundSettingsPage> {
  late WKChatBackgroundStyle _selectedStyle;
  ChatBackgroundOption? _selectedOption;
  List<ChatBackgroundOption> _backgrounds = const <ChatBackgroundOption>[];
  bool _isLoadingBackgrounds = true;
  bool _backgroundLoadFailed = false;
  bool _hasScopedOverride = false;
  bool _clearOverrideOnSave = false;

  bool get _isScopedMode {
    final channelId = widget.channelId?.trim() ?? '';
    return channelId.isNotEmpty && widget.channelType != null;
  }

  String get _scopedChannelId => widget.channelId!.trim();
  int get _scopedChannelType => widget.channelType!;

  @override
  void initState() {
    super.initState();
    _selectedStyle = WKSettingPreferences.getChatBackgroundStyle(
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
    _selectedOption = WKSettingPreferences.getSelectedChatBackground(
      channelId: widget.channelId,
      channelType: widget.channelType,
    );
    if (_isScopedMode) {
      _hasScopedOverride = WKSettingPreferences.hasChatBackgroundOverride(
        channelId: _scopedChannelId,
        channelType: _scopedChannelType,
      );
    }
    _loadBackgrounds();
  }

  Future<void> _loadBackgrounds() async {
    final loader =
        widget.backgroundsLoader ?? CommonApi.instance.getChatBackgrounds;
    try {
      final backgrounds = await loader();
      if (!mounted) {
        return;
      }

      ChatBackgroundOption? selectedOption = _selectedOption;
      if (selectedOption != null) {
        final selectedUrl = selectedOption.url;
        for (final candidate in backgrounds) {
          if (candidate.url == selectedUrl) {
            selectedOption = candidate;
            break;
          }
        }
      }

      setState(() {
        _backgrounds = backgrounds;
        _selectedOption = selectedOption;
        _isLoadingBackgrounds = false;
        _backgroundLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backgrounds = const <ChatBackgroundOption>[];
        _isLoadingBackgrounds = false;
        _backgroundLoadFailed = true;
      });
    }
  }

  Future<void> _completeSelection() async {
    if (_isScopedMode && _clearOverrideOnSave) {
      await WKSettingPreferences.clearChatBackgroundOverride(
        channelId: _scopedChannelId,
        channelType: _scopedChannelType,
      );
    } else if (_selectedOption != null) {
      await WKSettingPreferences.setSelectedChatBackground(
        _selectedOption!,
        channelId: _isScopedMode ? _scopedChannelId : null,
        channelType: _isScopedMode ? _scopedChannelType : null,
      );
    } else {
      await WKSettingPreferences.setChatBackgroundStyle(
        _selectedStyle,
        channelId: _isScopedMode ? _scopedChannelId : null,
        channelType: _isScopedMode ? _scopedChannelType : null,
      );
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _markScopedOverrideCleared() {
    final globalStyle = WKSettingPreferences.getChatBackgroundStyle();
    final globalOption = WKSettingPreferences.getSelectedChatBackground();
    setState(() {
      _clearOverrideOnSave = true;
      _hasScopedOverride = false;
      _selectedStyle = globalStyle;
      _selectedOption = globalOption;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '聊天背景',
      trailing: WKSubPageAction(
        key: const ValueKey<String>('chat-background-complete'),
        text: '完成',
        onTap: _completeSelection,
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 20, bottom: 24),
        children: [
          _buildPreviewCard(),
          if (_isScopedMode && (_hasScopedOverride || _clearOverrideOnSave))
            WKSettingsGroup(
              children: [
                WKSettingsCell(
                  key: const ValueKey<String>('chat-background-clear-override'),
                  title: '\u8ddf\u968f\u5168\u5c40\u80cc\u666f',
                  onTap: _markScopedOverrideCleared,
                ),
              ],
            ),
          if (_isLoadingBackgrounds) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(15, 18, 15, 10),
              child: Text(
                '在线背景',
                style: TextStyle(fontSize: 14, color: WKColors.color999),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            ),
          ] else if (_backgrounds.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(15, 18, 15, 10),
              child: Text(
                '在线背景',
                style: TextStyle(fontSize: 14, color: WKColors.color999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var index = 0; index < _backgrounds.length; index++)
                    _RemoteBackgroundCard(
                      key: ValueKey<String>(
                        'chat-background-option-remote-$index',
                      ),
                      option: _backgrounds[index],
                      label: '背景 ${index + 1}',
                      selected: _selectedOption?.url == _backgrounds[index].url,
                      onTap: () {
                        setState(() {
                          _clearOverrideOnSave = false;
                          if (_isScopedMode) {
                            _hasScopedOverride = true;
                          }
                          _selectedOption = _backgrounds[index];
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 20, 15, 5),
            child: Text(
              '本地备选',
              style: TextStyle(fontSize: 14, color: WKColors.color999),
            ),
          ),
          WKSettingsGroup(
            children: [
              _BackgroundOptionCell(
                key: const ValueKey<String>(
                  'chat-background-option-local-classic',
                ),
                title: '默认浅灰',
                subtitle: '保持和当前聊天页一致的轻量背景',
                selected:
                    _selectedOption == null &&
                    _selectedStyle == WKChatBackgroundStyle.classic,
                onTap: () => setState(() {
                  _clearOverrideOnSave = false;
                  if (_isScopedMode) {
                    _hasScopedOverride = true;
                  }
                  _selectedOption = null;
                  _selectedStyle = WKChatBackgroundStyle.classic;
                }),
              ),
              _BackgroundOptionCell(
                key: const ValueKey<String>(
                  'chat-background-option-local-sunrise',
                ),
                title: '暖色渐变',
                subtitle: '保留当前 Flutter 版本已经做好的柔和暖调',
                selected:
                    _selectedOption == null &&
                    _selectedStyle == WKChatBackgroundStyle.sunrise,
                onTap: () => setState(() {
                  _clearOverrideOnSave = false;
                  if (_isScopedMode) {
                    _hasScopedOverride = true;
                  }
                  _selectedOption = null;
                  _selectedStyle = WKChatBackgroundStyle.sunrise;
                }),
              ),
              _BackgroundOptionCell(
                key: const ValueKey<String>(
                  'chat-background-option-local-paper',
                ),
                title: '纯净白底',
                subtitle: '弱化纹理，让气泡和内容层次更突出',
                selected:
                    _selectedOption == null &&
                    _selectedStyle == WKChatBackgroundStyle.paper,
                onTap: () => setState(() {
                  _clearOverrideOnSave = false;
                  if (_isScopedMode) {
                    _hasScopedOverride = true;
                  }
                  _selectedOption = null;
                  _selectedStyle = WKChatBackgroundStyle.paper;
                }),
              ),
            ],
          ),
          WKSettingsDescription(
            text: _backgroundLoadFailed
                ? '在线背景暂时不可用，当前仍可使用本地备选背景。后续将继续沿着 TangSengDaoDao 的 chatbg 路径补齐。'
                : '当前页面会优先读取服务器的聊天背景列表；如果线上背景暂不可用，仍然保留本地样式作为兜底。聊天页真实背景渲染会读取这里保存的选择结果。',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 248,
          child: ChatBackgroundSurface(
            option: _selectedOption,
            fallbackStyle: _selectedStyle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const _PreviewBubble(text: '预览聊天背景', isOutgoing: true),
                      const SizedBox(width: 8),
                      const WKAvatar(name: '我', size: 34),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const WKAvatar(name: '悟空', size: 34),
                      const SizedBox(width: 8),
                      const _PreviewBubble(
                        text: '切换后会先保存你的背景选择',
                        isOutgoing: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(width: 42),
                      _PreviewBubble(
                        text: '聊天页会读取这里的结果做真实渲染',
                        isOutgoing: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoteBackgroundCard extends StatelessWidget {
  const _RemoteBackgroundCard({
    super.key,
    required this.option,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ChatBackgroundOption option;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 104,
                height: 132,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? WKColors.brand500
                        : WKColors.layoutColorSelected,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: ChatBackgroundSurface(option: option),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: WKColors.colorDark,
                      ),
                    ),
                  ),
                  if (selected)
                    WKReferenceAssets.image(
                      WKReferenceAssets.check,
                      width: 16,
                      height: 16,
                      tint: WKColors.brand500,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({required this.text, required this.isOutgoing});

  final String text;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOutgoing ? WKColors.chatSendBg : WKColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          color: WKColors.colorDark,
          height: 1.35,
        ),
      ),
    );
  }
}

class _BackgroundOptionCell extends StatelessWidget {
  const _BackgroundOptionCell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: WKColors.color999,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Opacity(
                opacity: selected ? 1 : 0,
                child: WKReferenceAssets.image(
                  WKReferenceAssets.check,
                  width: 20,
                  height: 20,
                  tint: WKColors.brand500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
