import 'package:wukongimfluttersdk/model/wk_message_content.dart';

import '../../wukong_base/msg/msg_content_type.dart';

class WKRobotCardContent extends WKMessageContent {
  String schema = 'robot_card.v1';
  String platform = '';
  String originType = '';
  String robotProvider = '';
  String robotName = '';
  String robotAvatar = '';
  String style = 'showcase';
  String title = '';
  String body = '';
  String badge = '';
  String linkUrl = '';
  String linkMode = 'whole_card';
  String plainText = '';

  bool? _isClickableOverride;

  WKRobotCardContent() {
    contentType = MsgContentType.robotCard;
  }

  bool get isClickable {
    if (_isClickableOverride != null) {
      return _isClickableOverride!;
    }
    return linkUrl.trim().isNotEmpty;
  }

  @override
  Map<String, dynamic> encodeJson() {
    return <String, dynamic>{
      'schema': schema,
      'platform': platform,
      'origin_type': originType,
      'robot': <String, dynamic>{
        'provider': robotProvider,
        'name': robotName,
        'avatar': robotAvatar,
      },
      'card': <String, dynamic>{
        'style': style,
        'title': title,
        'body': body,
        'badge': badge,
        'link_url': linkUrl,
        'link_mode': linkMode,
      },
      'plain_text': plainText,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    final robot =
        _asStringDynamicMap(json['robot']) ?? const <String, dynamic>{};
    final card = _asStringDynamicMap(json['card']) ?? const <String, dynamic>{};

    schema = _withDefault(_firstNonEmpty([json['schema']]), 'robot_card.v1');
    platform = _firstNonEmpty([json['platform']]);
    originType = _firstNonEmpty([json['origin_type'], json['originType']]);

    robotProvider = _firstNonEmpty([
      robot['provider'],
      robot['robot_provider'],
      json['robot_provider'],
      json['robotProvider'],
    ]);
    robotName = _firstNonEmpty([
      robot['name'],
      robot['display_name'],
      robot['displayName'],
      json['robot_name'],
      json['robotName'],
    ]);
    robotAvatar = _firstNonEmpty([
      robot['avatar'],
      robot['display_avatar'],
      robot['displayAvatar'],
      json['robot_avatar'],
      json['robotAvatar'],
    ]);

    style = _withDefault(
      _firstNonEmpty([card['style'], json['style']]),
      'showcase',
    );
    title = _firstNonEmpty([card['title'], json['title']]);
    body = _firstNonEmpty([card['body'], json['body']]);
    badge = _firstNonEmpty([card['badge'], json['badge']]);
    linkUrl = _firstNonEmpty([
      card['link_url'],
      card['linkUrl'],
      card['url'],
      json['link_url'],
      json['linkUrl'],
      json['url'],
    ]);
    linkMode = _withDefault(
      _firstNonEmpty([
        card['link_mode'],
        card['linkMode'],
        json['link_mode'],
        json['linkMode'],
      ]),
      'whole_card',
    );
    plainText = _firstNonEmpty([json['plain_text'], json['plainText']]);

    _isClickableOverride = _readBool(
      json['is_clickable'] ??
          json['isClickable'] ??
          card['is_clickable'] ??
          card['isClickable'],
    );

    content = displayText();
    return this;
  }

  @override
  String displayText() {
    final normalizedPlainText = plainText.trim();
    if (normalizedPlainText.isNotEmpty) {
      return normalizedPlainText;
    }

    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();
    if (normalizedTitle.isEmpty) {
      return normalizedBody;
    }
    if (normalizedBody.isEmpty) {
      return normalizedTitle;
    }
    return '$normalizedTitle $normalizedBody';
  }

  @override
  String searchableWord() {
    return <String>[
      robotName.trim(),
      title.trim(),
      body.trim(),
      plainText.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
  }

  bool? _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
    return null;
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final normalized = value?.toString().trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _withDefault(String value, String fallback) {
    if (value.trim().isEmpty) {
      return fallback;
    }
    return value;
  }

  Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is! Map) {
      return null;
    }
    final normalized = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        return null;
      }
      normalized[key] = entry.value;
    }
    return normalized;
  }
}
