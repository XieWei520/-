import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../wukong_push/models/push_models.dart';
import 'app_route_location.dart';

const int _defaultMaxOpenedEventKeys = 128;
const int _defaultMaxPendingOpenedIntents = 16;

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
    int maxOpenedEventKeys = _defaultMaxOpenedEventKeys,
    int maxPendingOpenedIntents = _defaultMaxPendingOpenedIntents,
  }) : _messageEvents = messageEvents,
       _isLoggedIn = isLoggedIn,
       _isRestoringSession = isRestoringSession,
       _onOpenChat = onOpenChat,
       _maxOpenedEventKeys = maxOpenedEventKeys,
       _maxPendingOpenedIntents = maxPendingOpenedIntents;

  final Stream<PushMessageEvent> _messageEvents;
  final IsLoggedInReader _isLoggedIn;
  final IsRestoringSessionReader _isRestoringSession;
  final OpenChatRoute _onOpenChat;
  final int _maxOpenedEventKeys;
  final int _maxPendingOpenedIntents;

  StreamSubscription<PushMessageEvent>? _subscription;
  final List<_PendingChatRouteIntent> _pendingIntents =
      <_PendingChatRouteIntent>[];
  final Set<String> _pendingOpenedEventKeys = <String>{};
  final Set<String> _openedEventKeys = <String>{};
  final List<String> _openedEventKeyOrder = <String>[];

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
    final eventKey = _openedEventKey(event);
    if (_openedEventKeys.contains(eventKey) ||
        _pendingOpenedEventKeys.contains(eventKey)) {
      return;
    }
    if (_isLoggedIn()) {
      _rememberOpenedEventKey(eventKey);
      _onOpenChat(intent);
      return;
    }
    if (_isRestoringSession()) {
      _pendingOpenedEventKeys.add(eventKey);
      _pendingIntents.add(
        _PendingChatRouteIntent(intent: intent, eventKey: eventKey),
      );
      _trimPendingIntents();
    }
  }

  void flushPending() {
    if (!_isLoggedIn()) {
      if (!_isRestoringSession()) {
        _pendingIntents.clear();
        _pendingOpenedEventKeys.clear();
      }
      return;
    }
    if (_pendingIntents.isEmpty) {
      return;
    }

    final pending = List<_PendingChatRouteIntent>.from(_pendingIntents);
    _pendingIntents.clear();
    _pendingOpenedEventKeys.clear();
    for (final pendingIntent in pending) {
      _rememberOpenedEventKey(pendingIntent.eventKey);
      _onOpenChat(pendingIntent.intent);
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
    _pendingOpenedEventKeys.clear();
    _openedEventKeys.clear();
    _openedEventKeyOrder.clear();
  }

  void _rememberOpenedEventKey(String eventKey) {
    if (_maxOpenedEventKeys <= 0) {
      return;
    }
    if (_openedEventKeys.add(eventKey)) {
      _openedEventKeyOrder.add(eventKey);
    }
    while (_openedEventKeyOrder.length > _maxOpenedEventKeys) {
      final removed = _openedEventKeyOrder.removeAt(0);
      _openedEventKeys.remove(removed);
    }
  }

  void _trimPendingIntents() {
    if (_maxPendingOpenedIntents <= 0) {
      _pendingIntents.clear();
      _pendingOpenedEventKeys.clear();
      return;
    }
    while (_pendingIntents.length > _maxPendingOpenedIntents) {
      final removed = _pendingIntents.removeAt(0);
      _pendingOpenedEventKeys.remove(removed.eventKey);
    }
  }

  String _openedEventKey(PushMessageEvent event) {
    final payload = event.payload;
    final messageId = payload.messageId?.trim();
    if (messageId != null && messageId.isNotEmpty) {
      return 'message:$messageId';
    }

    final channelId = payload.channelId?.trim() ?? '';
    final channelType = payload.channelType ?? 0;
    final title = _firstNonEmpty(event.title, payload.title) ?? '';
    final body = _firstNonEmpty(event.body, payload.body) ?? '';
    return 'conversation:$channelType:$channelId:$title:$body';
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

class _PendingChatRouteIntent {
  const _PendingChatRouteIntent({required this.intent, required this.eventKey});

  final AppChatRouteIntent intent;
  final String eventKey;
}
