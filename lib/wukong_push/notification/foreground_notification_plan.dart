import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/push_models.dart';
import 'notification_helper.dart';

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
  final title = (event.title ?? event.payload.title ?? '').trim();
  final body = (event.body ?? event.payload.body ?? '').trim();
  if (title.isEmpty && body.isEmpty) {
    return null;
  }

  return ForegroundNotificationPlan(
    title: title.isEmpty ? 'WuKongIM' : title,
    body: body,
    payload: jsonEncode(<String, dynamic>{
      'payload': event.payload.toJson(),
      'title': title,
      'body': body,
    }),
    channelId: NotificationHelper.messageChannelId,
    channelName: NotificationHelper.messageChannelName,
    importance: Importance.defaultImportance,
  );
}
