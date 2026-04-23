import 'package:flutter/material.dart';

import '../../modules/settings/settings_strings.dart';
import '../../widgets/wk_colors.dart';
import '../../widgets/wk_reference_assets.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'setting_preferences.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  late WKLanguageSetting _selectedLanguage;

  SettingsStrings get _strings =>
      resolveSettingsStrings(locale: Localizations.localeOf(context));

  @override
  void initState() {
    super.initState();
    _selectedLanguage = WKSettingPreferences.getLanguageSetting();
  }

  Future<void> _save() async {
    await WKSettingPreferences.setLanguageSetting(_selectedLanguage);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _buildOption({
    required String title,
    required WKLanguageSetting value,
  }) {
    final selected = _selectedLanguage == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedLanguage = value),
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
    final strings = _strings;
    return WKSubPageScaffold(
      title: strings.language,
      trailing: WKSubPageAction(text: strings.save, onTap: _save),
      body: ListView(
        padding: const EdgeInsets.only(top: 20),
        children: [
          WKSettingsGroup(
            children: [
              _buildOption(
                title: strings.followSystem,
                value: WKLanguageSetting.followSystem,
              ),
              _buildOption(
                title: strings.simplifiedChinese,
                value: WKLanguageSetting.simplifiedChinese,
              ),
              _buildOption(
                title: strings.englishDisplay,
                value: WKLanguageSetting.english,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
