import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';

@immutable
class ChatBackgroundOption {
  const ChatBackgroundOption({
    required this.cover,
    required this.url,
    required this.isSvg,
    this.lightColors = const <String>[],
    this.darkColors = const <String>[],
  });

  final String cover;
  final String url;
  final bool isSvg;
  final List<String> lightColors;
  final List<String> darkColors;

  factory ChatBackgroundOption.fromJson(Map<String, dynamic> json) {
    return ChatBackgroundOption(
      cover: (json['cover'] ?? '').toString().trim(),
      url: (json['url'] ?? '').toString().trim(),
      isSvg: _readBoolFlag(json['is_svg'] ?? json['isSvg']),
      lightColors: _readStringList(
        json['light_colors'] ?? json['lightColors'],
      ),
      darkColors: _readStringList(json['dark_colors'] ?? json['darkColors']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'cover': cover,
      'url': url,
      'is_svg': isSvg ? 1 : 0,
      'light_colors': lightColors,
      'dark_colors': darkColors,
    };
  }

  String get resolvedCover => ApiConfig.resolveMediaUrl(cover);

  String get resolvedUrl => ApiConfig.resolveMediaUrl(url);

  bool get hasPalette => lightColors.isNotEmpty || darkColors.isNotEmpty;

  static bool _readBoolFlag(dynamic rawValue) {
    if (rawValue is bool) {
      return rawValue;
    }
    if (rawValue is num) {
      return rawValue.toInt() != 0;
    }
    final normalized = rawValue?.toString().trim().toLowerCase() ?? '';
    return normalized == '1' || normalized == 'true';
  }

  static List<String> _readStringList(dynamic rawValue) {
    if (rawValue is! List) {
      return const <String>[];
    }
    return rawValue
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
