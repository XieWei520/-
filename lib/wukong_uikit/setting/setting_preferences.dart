import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/storage_utils.dart';
import '../../data/models/chat_background_option.dart';
import '../../modules/settings/settings_strings.dart';

enum WKThemeSettingMode { followSystem, light, dark }

enum WKLanguageSetting { followSystem, simplifiedChinese, english }

enum WKChatBackgroundStyle { classic, sunrise, paper }

class WKSettingPreferences {
  WKSettingPreferences._();

  static final ValueNotifier<int> _appearanceRevision = ValueNotifier<int>(0);

  static const String _themeKey = 'wk_setting_theme_mode';
  static const String _languageKey = 'wk_setting_language_mode';
  static const String _fontScaleKey = 'wk_setting_font_scale';
  static const String _chatBackgroundKey = 'wk_setting_chat_background';
  static const String _chatBackgroundSelectionKey =
      'wk_setting_chat_background_selection';
  static const String _chatBackgroundScopedStyleKey =
      'wk_setting_chat_background_scoped_style';
  static const String _chatBackgroundScopedSelectionKey =
      'wk_setting_chat_background_scoped_selection';
  static const String appModuleKey = 'wk_setting_app_modules';
  static const String _workplacePreferencesSnapshotKey =
      'wk_setting_workplace_preferences_snapshot';

  static WKThemeSettingMode getThemeMode() {
    switch (StorageUtils.getString(_themeKey)) {
      case 'light':
        return WKThemeSettingMode.light;
      case 'dark':
        return WKThemeSettingMode.dark;
      default:
        return WKThemeSettingMode.followSystem;
    }
  }

  static Future<void> setThemeMode(WKThemeSettingMode mode) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    await StorageUtils.setString(_themeKey, mode.name);
    _notifyAppearanceChanged();
  }

  static bool isDarkModeEnabled() {
    switch (getThemeMode()) {
      case WKThemeSettingMode.dark:
        return true;
      case WKThemeSettingMode.light:
        return false;
      case WKThemeSettingMode.followSystem:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  static String darkModeStatusText([Locale? locale]) {
    final strings = resolveSettingsStrings(
      locale: locale ?? WidgetsBinding.instance.platformDispatcher.locale,
    );
    return strings.darkModeStatus(isDarkModeEnabled());
  }

  static WKLanguageSetting getLanguageSetting() {
    switch (StorageUtils.getString(_languageKey)) {
      case 'simplifiedChinese':
        return WKLanguageSetting.simplifiedChinese;
      case 'english':
        return WKLanguageSetting.english;
      default:
        return WKLanguageSetting.followSystem;
    }
  }

  static Future<void> setLanguageSetting(WKLanguageSetting setting) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    await StorageUtils.setString(_languageKey, setting.name);
    _notifyAppearanceChanged();
  }

  static ValueListenable<int> get appearanceChanges => _appearanceRevision;

  static Locale? resolvePreferredLocale([WKLanguageSetting? setting]) {
    return switch (setting ?? getLanguageSetting()) {
      WKLanguageSetting.english => const Locale('en', 'US'),
      WKLanguageSetting.simplifiedChinese => const Locale('zh', 'CN'),
      WKLanguageSetting.followSystem => null,
    };
  }

  static String languageLabel([Locale? locale]) {
    final strings = resolveSettingsStrings(
      locale: locale ?? WidgetsBinding.instance.platformDispatcher.locale,
    );
    switch (getLanguageSetting()) {
      case WKLanguageSetting.simplifiedChinese:
        return strings.simplifiedChinese;
      case WKLanguageSetting.english:
        return strings.englishDisplay;
      case WKLanguageSetting.followSystem:
        return strings.followSystem;
    }
  }

  static double getFontScale() {
    final saved = StorageUtils.getDouble(_fontScaleKey);
    if (saved == null) {
      return 1.0;
    }
    return saved.clamp(0.875, 1.25).toDouble();
  }

  static Future<void> setFontScale(double scale) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    await StorageUtils.setDouble(
      _fontScaleKey,
      scale.clamp(0.875, 1.25).toDouble(),
    );
    _notifyAppearanceChanged();
  }

  static int fontScaleToIndex(double scale) {
    final normalized = ((scale.clamp(0.875, 1.25) - 0.875) / 0.125).round();
    return normalized.clamp(0, 3);
  }

  static double fontScaleFromIndex(int index) {
    final normalized = index.clamp(0, 3);
    return 0.875 + 0.125 * normalized;
  }

  static String fontScaleLabel(double scale, [Locale? locale]) {
    final isEnglish =
        resolveSettingsStrings(
          locale: locale ?? WidgetsBinding.instance.platformDispatcher.locale,
        ) ==
        enUsSettingsStrings;
    switch (fontScaleToIndex(scale)) {
      case 0:
        return isEnglish ? 'Small' : '小';
      case 2:
        return isEnglish ? 'Large' : '大';
      case 3:
        return isEnglish ? 'Extra Large' : '特大';
      default:
        return isEnglish ? 'Standard' : '标准';
    }
  }

  static WKChatBackgroundStyle getChatBackgroundStyle({
    String? channelId,
    int? channelType,
  }) {
    final scopeKey = _chatBackgroundScopeKey(
      channelId: channelId,
      channelType: channelType,
    );
    if (scopeKey != null) {
      final scopedStyles = _readJsonMap(_chatBackgroundScopedStyleKey);
      final scopedStyle = _parseChatBackgroundStyle(scopedStyles[scopeKey]);
      if (scopedStyle != null) {
        return scopedStyle;
      }
    }
    return _parseChatBackgroundStyle(
          StorageUtils.getString(_chatBackgroundKey),
        ) ??
        WKChatBackgroundStyle.classic;
  }

  static Future<void> setChatBackgroundStyle(
    WKChatBackgroundStyle style, {
    String? channelId,
    int? channelType,
  }) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    final scopeKey = _chatBackgroundScopeKey(
      channelId: channelId,
      channelType: channelType,
    );
    if (scopeKey != null) {
      final scopedStyles = _readJsonMap(_chatBackgroundScopedStyleKey);
      scopedStyles[scopeKey] = style.name;
      await _writeJsonMap(_chatBackgroundScopedStyleKey, scopedStyles);

      final scopedSelections = _readJsonMap(_chatBackgroundScopedSelectionKey);
      if (scopedSelections.remove(scopeKey) != null) {
        await _writeJsonMap(
          _chatBackgroundScopedSelectionKey,
          scopedSelections,
        );
      }
      _notifyAppearanceChanged();
      return;
    }
    await StorageUtils.setString(_chatBackgroundKey, style.name);
    await StorageUtils.remove(_chatBackgroundSelectionKey);
    _notifyAppearanceChanged();
  }

  static ChatBackgroundOption? getSelectedChatBackground({
    String? channelId,
    int? channelType,
  }) {
    final scopeKey = _chatBackgroundScopeKey(
      channelId: channelId,
      channelType: channelType,
    );
    if (scopeKey != null) {
      final scopedSelections = _readJsonMap(_chatBackgroundScopedSelectionKey);
      final scopedSelection = _parseChatBackgroundOption(
        scopedSelections[scopeKey],
      );
      if (scopedSelection != null) {
        return scopedSelection;
      }
      final scopedStyles = _readJsonMap(_chatBackgroundScopedStyleKey);
      if (scopedStyles.containsKey(scopeKey)) {
        return null;
      }
    }
    final raw = StorageUtils.getString(_chatBackgroundSelectionKey);
    return _parseChatBackgroundOption(raw);
  }

  static Future<void> setSelectedChatBackground(
    ChatBackgroundOption option, {
    String? channelId,
    int? channelType,
  }) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    final scopeKey = _chatBackgroundScopeKey(
      channelId: channelId,
      channelType: channelType,
    );
    if (scopeKey != null) {
      final scopedSelections = _readJsonMap(_chatBackgroundScopedSelectionKey);
      scopedSelections[scopeKey] = option.toJson();
      await _writeJsonMap(_chatBackgroundScopedSelectionKey, scopedSelections);
      _notifyAppearanceChanged();
      return;
    }
    await StorageUtils.setString(
      _chatBackgroundSelectionKey,
      jsonEncode(option.toJson()),
    );
    _notifyAppearanceChanged();
  }

  static bool hasChatBackgroundOverride({
    required String channelId,
    required int channelType,
  }) {
    final scopeKey = _chatBackgroundScopeKey(
      channelId: channelId,
      channelType: channelType,
    );
    if (scopeKey == null) {
      return false;
    }
    final scopedSelections = _readJsonMap(_chatBackgroundScopedSelectionKey);
    if (scopedSelections.containsKey(scopeKey)) {
      return true;
    }
    final scopedStyles = _readJsonMap(_chatBackgroundScopedStyleKey);
    return scopedStyles.containsKey(scopeKey);
  }

  static Future<void> clearChatBackgroundOverride({
    required String channelId,
    required int channelType,
  }) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    final scopeKey = _chatBackgroundScopeKey(
      channelId: channelId,
      channelType: channelType,
    );
    if (scopeKey == null) {
      return;
    }

    var changed = false;
    final scopedSelections = _readJsonMap(_chatBackgroundScopedSelectionKey);
    if (scopedSelections.remove(scopeKey) != null) {
      await _writeJsonMap(_chatBackgroundScopedSelectionKey, scopedSelections);
      changed = true;
    }

    final scopedStyles = _readJsonMap(_chatBackgroundScopedStyleKey);
    if (scopedStyles.remove(scopeKey) != null) {
      await _writeJsonMap(_chatBackgroundScopedStyleKey, scopedStyles);
      changed = true;
    }

    if (changed) {
      _notifyAppearanceChanged();
    }
  }

  static String chatBackgroundLabel({
    Locale? locale,
    String? channelId,
    int? channelType,
  }) {
    final isEnglish =
        resolveSettingsStrings(
          locale: locale ?? WidgetsBinding.instance.platformDispatcher.locale,
        ) ==
        enUsSettingsStrings;
    if (getSelectedChatBackground(
          channelId: channelId,
          channelType: channelType,
        ) !=
        null) {
      return isEnglish ? 'Server Background' : '服务器背景';
    }
    switch (getChatBackgroundStyle(
      channelId: channelId,
      channelType: channelType,
    )) {
      case WKChatBackgroundStyle.sunrise:
        return isEnglish ? 'Warm Gradient' : '暖色渐变';
      case WKChatBackgroundStyle.paper:
        return isEnglish ? 'Paper White' : '纯净白底';
      case WKChatBackgroundStyle.classic:
        return isEnglish ? 'Classic Gray' : '默认浅灰';
    }
  }

  static List<String> getLegacyEnabledModuleSids() {
    final stored = StorageUtils.getStringList(appModuleKey) ?? const <String>[];
    return _normalizeStringList(stored);
  }

  static Future<void> setLegacyEnabledModuleSids(
    List<String> moduleSids,
  ) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    await StorageUtils.setStringList(
      appModuleKey,
      _normalizeStringList(moduleSids),
    );
  }

  static Map<String, dynamic>? getWorkplacePreferencesSnapshotCache() {
    final raw = StorageUtils.getString(_workplacePreferencesSnapshotKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> setWorkplacePreferencesSnapshotCache(
    Map<String, dynamic> snapshot,
  ) async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    await StorageUtils.setString(
      _workplacePreferencesSnapshotKey,
      jsonEncode(snapshot),
    );
  }

  static Future<void> clearWorkplacePreferencesSnapshotCache() async {
    if (!StorageUtils.isInitialized) {
      return;
    }
    await StorageUtils.remove(_workplacePreferencesSnapshotKey);
  }

  static List<String> _normalizeStringList(List<String> values) {
    final normalized = <String>[];
    for (final item in values) {
      final value = item.trim();
      if (value.isEmpty || normalized.contains(value)) {
        continue;
      }
      normalized.add(value);
    }
    return normalized;
  }

  static void _notifyAppearanceChanged() {
    _appearanceRevision.value++;
  }

  static String? _chatBackgroundScopeKey({
    String? channelId,
    int? channelType,
  }) {
    final normalizedChannelId = channelId?.trim() ?? '';
    if (normalizedChannelId.isEmpty || channelType == null) {
      return null;
    }
    return '$channelType|$normalizedChannelId';
  }

  static Map<String, dynamic> _readJsonMap(String key) {
    final raw = StorageUtils.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return <String, dynamic>{...decoded};
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  static Future<void> _writeJsonMap(String key, Map<String, dynamic> value) {
    if (value.isEmpty) {
      return StorageUtils.remove(key);
    }
    return StorageUtils.setString(key, jsonEncode(value));
  }

  static WKChatBackgroundStyle? _parseChatBackgroundStyle(dynamic raw) {
    final value = raw?.toString().trim();
    switch (value) {
      case 'sunrise':
        return WKChatBackgroundStyle.sunrise;
      case 'paper':
        return WKChatBackgroundStyle.paper;
      case 'classic':
        return WKChatBackgroundStyle.classic;
      default:
        return null;
    }
  }

  static ChatBackgroundOption? _parseChatBackgroundOption(dynamic raw) {
    if (raw == null) {
      return null;
    }
    if (raw is String) {
      if (raw.trim().isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(raw);
        return _parseChatBackgroundOption(decoded);
      } catch (_) {
        return null;
      }
    }
    if (raw is Map<String, dynamic>) {
      return ChatBackgroundOption.fromJson(raw);
    }
    if (raw is Map) {
      return ChatBackgroundOption.fromJson(Map<String, dynamic>.from(raw));
    }
    return null;
  }
}
