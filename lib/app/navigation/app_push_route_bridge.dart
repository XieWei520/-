import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../wukong_push/models/push_models.dart';
import 'app_route_location.dart';

@immutable
class AppChatRouteIntent {
  const AppChatRouteIntent({
    required this.channelId,
    required this.channelType,
    required this.channelName,
  });

  final String channelId;
  final int channelType;
  final String channelName;

  String get location => AppRouteLocation.chat(
    channelId: channelId,
    channelType: channelType,
    channelName: channelName,
  );
}

typedef IsLoggedInReader = bool Function();
typedef IsRestoringSessionReader = bool Function();
typedef OpenChatRoute = void Function(AppChatRouteIntent intent);
typedef ConsumePendingOpenedEvents = List<PushMessageEvent> Function();

class AppPushRouteBridge {
  AppPushRouteBridge({
    required Stream<PushMessageEvent> messageEvents,
    required IsLoggedInReader isLoggedIn,
    required IsRestoringSessionReader isRestoringSession,
    required OpenChatRoute onOpenChat,
  }) : _messageEvents = messageEvents,
       _isLoggedIn = isLoggedIn,
       _isRestoringSession = isRestoringSession,
       _onOpenChat = onOpenChat;

  final Stream<PushMessageEvent> _messageEvents;
  final IsLoggedInReader _isLoggedIn;
  final IsRestoringSessionReader _isRestoringSession;
  final OpenChatRoute _onOpenChat;

  StreamSubscription<PushMessageEvent>? _subscription;
  final List<AppChatRouteIntent> _pendingIntents = <AppChatRouteIntent>[];

  void start({ConsumePendingOpenedEvents? consumePendingOpenedEvents}) {
    if (_subscription != null) {
      return;
    }
    _subscription = _messageEvents.listen(_handlePushEvent);

    if (consumePendingOpenedEvents == null) {
      return;
    }
    final pendingEvents = consumePendingOpenedEvents();
    for (final event in pendingEvents) {
      _handlePushEvent(event);
    }
  }

  void _handlePushEvent(PushMessageEvent event) {
    final intent = _toChatRouteIntent(event);
    if (intent == null) {
      return;
    }
    if (_isLoggedIn()) {
      _onOpenChat(intent);
      return;
    }
    if (_isRestoringSession()) {
      _pendingIntents.add(intent);
    }
  }

  void flushPending() {
    if (!_isLoggedIn()) {
      if (!_isRestoringSession()) {
        _pendingIntents.clear();
      }
      return;
    }
    if (_pendingIntents.isEmpty) {
      return;
    }

    final pending = List<AppChatRouteIntent>.from(_pendingIntents);
    _pendingIntents.clear();
    for (final intent in pending) {
      _onOpenChat(intent);
    }
  }

  AppChatRouteIntent? _toChatRouteIntent(PushMessageEvent event) {
    if (!event.openedFromNotification) {
      return null;
    }
    final payload = event.payload;
    if (!payload.hasConversationTarget) {
      return null;
    }

    final channelId = payload.channelId?.trim() ?? '';
    final channelType = payload.channelType;
    if (channelId.isEmpty || channelType == null) {
      return null;
    }

    final title = _firstNonEmpty(event.title, payload.title);
    final body = _firstNonEmpty(event.body, payload.body);
    final channelName = title ?? body ?? channelId;

    return AppChatRouteIntent(
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _pendingIntents.clear();
  }

  String? _firstNonEmpty(String? first, String? second) {
    final normalizedFirst = first?.trim();
    if (normalizedFirst != null && normalizedFirst.isNotEmpty) {
      return normalizedFirst;
    }
    final normalizedSecond = second?.trim();
    if (normalizedSecond != null && normalizedSecond.isNotEmpty) {
      return normalizedSecond;
    }
    return null;
  }
}
