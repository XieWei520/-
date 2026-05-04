import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/push_models.dart';
import 'notification_helper.dart';

const int _maxForegroundNotificationTitleLength = 80;
const int _maxForegroundNotificationBodyLength = 240;

class ForegroundNotificationPlan {
  const ForegroundNotificationPlan({
    required this.title,
    required this.body,
    required this.payload,
    required this.channelId,
    required this.channelName,
    required this.importance,
  });

  final String title;
  final String body;
  final String payload;
  final String channelId;
  final String channelName;
  final Importance importance;
}

ForegroundNotificationPlan? buildForegroundNotificationPlan(
  PushMessageEvent event,
) {
  final title = _compactForegroundNotificationText(
    event.title ?? event.payload.title ?? '',
    maxLength: _maxForegroundNotificationTitleLength,
  );
  final body = _compactForegroundNotificationText(
    event.body ?? event.payload.body ?? '',
    maxLength: _maxForegroundNotificationBodyLength,
  );
  if (title.isEmpty && body.isEmpty) {
    return null;
  }
  final displayTitle = title.isEmpty ? 'WuKongIM' : title;

  return ForegroundNotificationPlan(
    title: displayTitle,
    body: body,
    payload: jsonEncode(<String, dynamic>{
      'payload': event.payload.toJson(),
      'title': displayTitle,
      'body': body,
    }),
    channelId: NotificationHelper.messageChannelId,
    channelName: NotificationHelper.messageChannelName,
    importance: Importance.defaultImportance,
  );
}

String _compactForegroundNotificationText(
  String value, {
  required int maxLength,
}) {
  final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.length <= maxLength) {
    return normalized;
  }
  if (maxLength <= 3) {
    return normalized.substring(0, maxLength);
  }
  return '${normalized.substring(0, maxLength - 3)}...';
}
