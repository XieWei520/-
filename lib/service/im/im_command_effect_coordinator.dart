import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';

import '../../data/providers/user_provider.dart';
import 'coordinators/command_dispatcher.dart';

typedef ImCommandCurrentUidLoader = String Function();
typedef ImCommandChannelLookup =
    Future<WKChannel?> Function(String channelId, int channelType);
typedef ImCommandConversationActivityHandler =
    Future<void> Function(
      WKCMD cmd, {
      required String currentUid,
      required ImCommandChannelLookup? channelLookup,
    });
typedef ImCommandSimpleSyncTask = Future<void> Function({String? reason});
typedef ImCommandMessageExtraSyncTask =
    Future<void> Function({
      required String channelId,
      required int channelType,
      String? reason,
    });
typedef ImCommandEffectErrorReporter =
    void Function(Object error, StackTrace stackTrace);

class ImCommandEffectCoordinator {
  ImCommandEffectCoordinator({
    CommandDispatcher dispatcher = const CommandDispatcher(),
    required ImCommandCurrentUidLoader currentUidLoader,
    required ImCommandChannelLookup channelLookup,
    required ImCommandConversationActivityHandler handleConversationActivity,
    required ImCommandSimpleSyncTask syncConversationExtras,
    required ImCommandSimpleSyncTask syncReminders,
    required ImCommandMessageExtraSyncTask syncMessageExtras,
    void Function(ProviderOrFamily provider)? invalidateProvider,
    ImCommandEffectErrorReporter? onAsyncError,
  }) : _dispatcher = dispatcher,
       _currentUidLoader = currentUidLoader,
       _channelLookup = channelLookup,
       _handleConversationActivity = handleConversationActivity,
       _syncConversationExtras = syncConversationExtras,
       _syncReminders = syncReminders,
       _syncMessageExtras = syncMessageExtras,
       _invalidateProvider = invalidateProvider,
       _onAsyncError = onAsyncError ?? _defaultAsyncErrorReporter;

  final CommandDispatcher _dispatcher;
  final ImCommandCurrentUidLoader _currentUidLoader;
  final ImCommandChannelLookup _channelLookup;
  final ImCommandConversationActivityHandler _handleConversationActivity;
  final ImCommandSimpleSyncTask _syncConversationExtras;
  final ImCommandSimpleSyncTask _syncReminders;
  final ImCommandMessageExtraSyncTask _syncMessageExtras;
  final void Function(ProviderOrFamily provider)? _invalidateProvider;
  final ImCommandEffectErrorReporter _onAsyncError;
  final Map<String, VoidCallback> _vipExpiredHandlers =
      <String, VoidCallback>{};

  void registerVipExpiredHandler({
    required String key,
    required VoidCallback handler,
  }) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    _vipExpiredHandlers[normalizedKey] = handler;
  }

  void unregisterVipExpiredHandler(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    _vipExpiredHandlers.remove(normalizedKey);
  }

  void handleCommand(WKCMD cmd) {
    final plan = _dispatcher.plan(cmd);
    final effects = plan.effects;

    if (plan.shouldNotifyVipExpired) {
      _notifyVipExpiredHandlers();
    }
    _scheduleAsync(
      _handleConversationActivity(
        cmd,
        currentUid: _currentUidLoader(),
        channelLookup: _channelLookup,
      ),
    );
    _invalidateContacts(effects);
    _scheduleSyncEffects(cmd, plan);
  }

  void _notifyVipExpiredHandlers() {
    final handlersSnapshot = List<VoidCallback>.from(
      _vipExpiredHandlers.values,
    );
    for (final handler in handlersSnapshot) {
      handler();
    }
  }

  void _invalidateContacts(Set<IMCommandSideEffect> effects) {
    if (effects.contains(IMCommandSideEffect.refreshFriendList)) {
      _invalidateProvider?.call(friendListProvider);
    }
    if (effects.contains(IMCommandSideEffect.refreshFriendRequests)) {
      _invalidateProvider?.call(friendRequestListProvider);
    }
  }

  void _scheduleSyncEffects(WKCMD cmd, CommandDispatchPlan plan) {
    final effects = plan.effects;
    final reason = 'cmd:${cmd.cmd}';

    if (effects.contains(IMCommandSideEffect.syncConversationExtra)) {
      _scheduleAsync(_syncConversationExtras(reason: reason));
    }
    if (effects.contains(IMCommandSideEffect.syncMessageExtra)) {
      final target = plan.messageExtraTarget;
      if (target != null) {
        _scheduleAsync(
          _syncMessageExtras(
            channelId: target.channelId,
            channelType: target.channelType,
            reason: reason,
          ),
        );
      }
    }
    if (effects.contains(IMCommandSideEffect.syncReminders)) {
      _scheduleAsync(_syncReminders(reason: reason));
    }
  }

  void _scheduleAsync(Future<void> task) {
    unawaited(
      task.catchError((Object error, StackTrace stackTrace) {
        _onAsyncError(error, stackTrace);
      }),
    );
  }
}

void _defaultAsyncErrorReporter(Object error, StackTrace stackTrace) {
  debugPrint('IM command side effect failed: $error');
  debugPrint('$stackTrace');
}
