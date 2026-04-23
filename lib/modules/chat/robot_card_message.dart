import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

class RobotCardViewData {
  const RobotCardViewData({
    required this.robotProvider,
    required this.robotName,
    required this.robotAvatar,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.badge,
    required this.plainText,
    required this.linkUrl,
    required this.linkUri,
  });

  final String robotProvider;
  final String robotName;
  final String robotAvatar;
  final String eyebrow;
  final String title;
  final String body;
  final String badge;
  final String plainText;
  final String linkUrl;
  final Uri? linkUri;

  bool get isClickable => linkUri != null;
}

typedef RobotCardUriLauncher = Future<bool> Function(Uri uri);

RobotCardViewData? resolveRobotCardViewData(
  WKMsg message, {
  Map<String, dynamic>? structuredPayload,
}) {
  final payload = _resolvePayload(
    message,
    structuredPayload: structuredPayload,
  );
  final typedContent = message.messageContent;
  final isTypedRobotCard = typedContent is WKRobotCardContent;
  final payloadType = _readInt(payload, const <String>['type']);
  if (!isTypedRobotCard &&
      message.contentType != MsgContentType.robotCard &&
      payloadType != MsgContentType.robotCard) {
    return null;
  }

  final robot = _asStringDynamicMap(payload?['robot']);
  final card = _asStringDynamicMap(payload?['card']);
  final robotProvider = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.robotProvider,
    _readString(robot, const <String>['provider']),
    _readString(payload, const <String>['platform']),
  ]).toLowerCase();
  final robotName = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.robotName,
    _readString(robot, const <String>['display_name', 'displayName', 'name']),
    _fallbackRobotName(robotProvider),
  ]);
  final robotAvatar = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.robotAvatar,
    _readString(robot, const <String>[
      'display_avatar',
      'displayAvatar',
      'avatar',
    ]),
  ]);
  final title = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.title,
    _readString(card, const <String>['title']),
    _readString(payload, const <String>['title']),
  ]);
  final body = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.body,
    _readString(card, const <String>['body']),
    _readString(payload, const <String>['body']),
  ]);
  final plainText = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.displayText(),
    _readString(payload, const <String>['plain_text', 'plainText']),
    _joinNonEmpty(<String>[title, body]),
  ]);
  final fallbackTitle = title.isNotEmpty
      ? title
      : plainText.isNotEmpty
      ? plainText
      : '[机器人卡片]';
  final fallbackBody = body.isNotEmpty || plainText == fallbackTitle
      ? body
      : plainText;
  final badge = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.badge,
    _readString(card, const <String>['badge']),
    _readString(payload, const <String>['badge']),
  ]).toUpperCase();
  final linkUrl = _firstNonEmpty(<String>[
    if (isTypedRobotCard) typedContent.linkUrl,
    _readString(card, const <String>['link_url', 'linkUrl', 'url']),
    _readString(payload, const <String>['link_url', 'linkUrl', 'url']),
  ]);
  final linkUri = _tryParseLaunchUri(linkUrl);

  return RobotCardViewData(
    robotProvider: robotProvider,
    robotName: robotName,
    robotAvatar: robotAvatar,
    eyebrow: _resolveEyebrow(badge: badge, clickable: linkUri != null),
    title: fallbackTitle,
    body: fallbackBody,
    badge: badge,
    plainText: plainText.isEmpty
        ? _joinNonEmpty(<String>[fallbackTitle, fallbackBody])
        : plainText,
    linkUrl: linkUrl,
    linkUri: linkUri,
  );
}

Uri? resolveRobotCardLaunchUri(
  WKMsg message, {
  Map<String, dynamic>? structuredPayload,
}) {
  return resolveRobotCardViewData(
    message,
    structuredPayload: structuredPayload,
  )?.linkUri;
}

Future<bool> openRobotCardLink(
  WKMsg message, {
  Map<String, dynamic>? structuredPayload,
  RobotCardUriLauncher? launcher,
}) {
  final uri = resolveRobotCardLaunchUri(
    message,
    structuredPayload: structuredPayload,
  );
  if (uri == null) {
    return Future<bool>.value(false);
  }
  final resolvedLauncher =
      launcher ??
      (Uri target) => launchUrl(target, mode: LaunchMode.externalApplication);
  return resolvedLauncher(uri);
}

Map<String, dynamic>? _resolvePayload(
  WKMsg message, {
  Map<String, dynamic>? structuredPayload,
}) {
  if (structuredPayload != null) {
    return structuredPayload;
  }
  final raw = message.content.trim();
  if (raw.isEmpty || (!raw.startsWith('{') && !raw.startsWith('['))) {
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

Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is! Map) {
    return null;
  }
  return Map<String, dynamic>.from(value);
}

int? _readInt(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) {
    return null;
  }
  for (final key in keys) {
    final value = map[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }
  }
  return null;
}

String _readString(Map<String, dynamic>? map, List<String> keys) {
  if (map == null) {
    return '';
  }
  for (final key in keys) {
    final value = map[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

String _firstNonEmpty(List<String> values) {
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '';
}

String _joinNonEmpty(List<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(' ');
}

Uri? _tryParseLaunchUri(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || !uri.hasScheme) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  return uri;
}

String _fallbackRobotName(String provider) {
  switch (provider.trim().toLowerCase()) {
    case 'feishu':
      return '飞书机器人';
    case 'dingtalk':
      return '钉钉机器人';
    default:
      return '机器人';
  }
}

String _resolveEyebrow({required String badge, required bool clickable}) {
  if (badge == 'ALERT') {
    return 'ALERT MESSAGE';
  }
  if (clickable) {
    return 'LINK MESSAGE';
  }
  if (badge == 'NOTICE') {
    return 'MESSAGE NOTICE';
  }
  return 'ROBOT MESSAGE';
}
