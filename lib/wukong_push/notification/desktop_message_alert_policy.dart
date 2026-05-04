import 'package:flutter/widgets.dart';

import 'message_alert_plan.dart';

class DesktopMessageNotification {
  const DesktopMessageNotification({
    required this.identifier,
    required this.title,
    required this.body,
  });

  final String identifier;
  final String title;
  final String body;
}

class DesktopMessageAlertDecision {
  const DesktopMessageAlertDecision({
    required this.playForegroundSound,
    required this.playMessageSound,
    this.notification,
  });

  const DesktopMessageAlertDecision.none()
    : playForegroundSound = false,
      playMessageSound = false,
      notification = null;

  final bool playForegroundSound;
  final bool playMessageSound;
  final DesktopMessageNotification? notification;
}

class DesktopMessageAlertPolicy {
  DesktopMessageAlertPolicy({
    DateTime Function()? now,
    this.coalesceWindow = const Duration(seconds: 2),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration coalesceWindow;
  final Map<String, _ConversationCoalesceState> _coalesceStates =
      <String, _ConversationCoalesceState>{};

  DesktopMessageAlertDecision resolve({
    required MessageAlertPlan plan,
    required AppLifecycleState lifecycleState,
  }) {
    if (lifecycleState == AppLifecycleState.resumed) {
      return const DesktopMessageAlertDecision(
        playForegroundSound: true,
        playMessageSound: false,
      );
    }

    final notification = _buildNotification(plan);
    return DesktopMessageAlertDecision(
      playForegroundSound: false,
      playMessageSound: true,
      notification: notification,
    );
  }

  DesktopMessageNotification _buildNotification(MessageAlertPlan plan) {
    final timestamp = _now();
    final key = plan.conversationKey;
    final previous = _coalesceStates[key];
    final count =
        previous != null &&
            timestamp.difference(previous.updatedAt) <= coalesceWindow
        ? previous.count + 1
        : 1;

    _coalesceStates[key] = _ConversationCoalesceState(
      count: count,
      updatedAt: timestamp,
    );

    return DesktopMessageNotification(
      identifier: _notificationIdentifier(plan),
      title: plan.title,
      body: count == 1 ? plan.body : '$count new messages',
    );
  }

  String _notificationIdentifier(MessageAlertPlan plan) {
    final normalizedChannelId = plan.channelId.trim().replaceAll(
      RegExp(r'\s+'),
      '-',
    );
    return 'wk-message-${plan.channelType}-$normalizedChannelId';
  }
}

class _ConversationCoalesceState {
  const _ConversationCoalesceState({
    required this.count,
    required this.updatedAt,
  });

  final int count;
  final DateTime updatedAt;
}
