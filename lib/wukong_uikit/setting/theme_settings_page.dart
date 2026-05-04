import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'setting_preferences.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late WKThemeSettingMode _selectedMode;

  bool get _followSystem => _selectedMode == WKThemeSettingMode.followSystem;

  @override
  void initState() {
    super.initState();
    _selectedMode = WKSettingPreferences.getThemeMode();
  }

  Future<void> _save() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text('设置深色模式后，需要重新启动${AppConfig.appName}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await WKSettingPreferences.setThemeMode(_selectedMode);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _buildOption({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: WKColors.colorDark,
                  ),
                ),
              ),
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

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '深色模式',
      trailing: WKSubPageAction(text: '确定', onTap: _save),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          WKSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '跟随系统',
                            style: TextStyle(
                              fontSize: 16,
                              color: WKColors.colorDark,
                            ),
                          ),
                        ),
                        Switch(
                          value: _followSystem,
                          onChanged: (value) {
                            setState(() {
                              _selectedMode = value
                                  ? WKThemeSettingMode.followSystem
                                  : WKThemeSettingMode.light;
                            });
                          },
                          activeThumbColor: WKColors.brand500,
                          activeTrackColor: WKColors.brand300,
                          inactiveThumbColor: WKColors.white,
                          inactiveTrackColor: WKColors.colorCCC,
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 5, bottom: 5),
                      child: Text(
                        '开启后，将跟随系统打开或关闭深色模式',
                        style: TextStyle(
                          fontSize: 14,
                          color: WKColors.color999,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_followSystem) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(15, 15, 15, 5),
              child: Text(
                '选择模式',
                style: TextStyle(fontSize: 14, color: WKColors.color999),
              ),
            ),
            WKSettingsGroup(
              children: [
                _buildOption(
                  title: '普通模式',
                  selected: _selectedMode == WKThemeSettingMode.light,
                  onTap: () {
                    setState(() => _selectedMode = WKThemeSettingMode.light);
                  },
                ),
                _buildOption(
                  title: '深色模式',
                  selected: _selectedMode == WKThemeSettingMode.dark,
                  onTap: () {
                    setState(() => _selectedMode = WKThemeSettingMode.dark);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
