import 'dart:convert';

import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../core/utils/avatar_utils.dart';

class RobotMessageIdentity {
  final String provider;
  final String displayName;
  final String? displayAvatar;

  const RobotMessageIdentity({
    required this.provider,
    required this.displayName,
    required this.displayAvatar,
  });
}

RobotMessageIdentity? parseRobotMessageIdentity(
  Map<String, dynamic>? structuredPayload,
) {
  if (structuredPayload == null) {
    return null;
  }

  final rawRobot = structuredPayload['robot'];
  final robot = _asStringDynamicMap(rawRobot);
  if (robot == null) {
    return null;
  }
  final provider = _firstNonEmpty([robot['provider'], robot['robot_provider']]);
  final displayName = _firstNonEmpty([
    robot['name'],
    robot['display_name'],
    robot['displayName'],
  ]);
  final displayAvatar = resolveAvatarUrl(
    _firstNonEmpty([
      robot['avatar'],
      robot['display_avatar'],
      robot['displayAvatar'],
    ]),
  );

  if (provider.isEmpty &&
      displayName.isEmpty &&
      (displayAvatar?.trim().isEmpty ?? true)) {
    return null;
  }

  return RobotMessageIdentity(
    provider: provider,
    displayName: displayName,
    displayAvatar: displayAvatar,
  );
}

RobotMessageIdentity? parseRobotMessageIdentityFromRaw(String rawPayload) {
  final normalized = rawPayload.trim();
  if (normalized.isEmpty ||
      (!normalized.startsWith('{') && !normalized.startsWith('['))) {
    return null;
  }

  try {
    final decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      return null;
    }
    return parseRobotMessageIdentity(Map<String, dynamic>.from(decoded));
  } catch (_) {
    return null;
  }
}

RobotMessageIdentity? resolveRobotMessageIdentityFromMessage(
  WKMsg message, {
  Map<String, dynamic>? structuredPayload,
}) {
  final structuredIdentity = parseRobotMessageIdentity(structuredPayload);
  if (structuredIdentity != null) {
    return structuredIdentity;
  }
  return parseRobotMessageIdentityFromRaw(message.content);
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
