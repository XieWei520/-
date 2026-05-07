import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/common/options.dart';
import 'package:wukongimfluttersdk/db/const.dart';
import 'package:wukongimfluttersdk/db/message.dart';
import 'package:wukongimfluttersdk/db/wk_db_helper.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_media_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_video_content.dart';
import 'package:wukongimfluttersdk/model/wk_voice_content.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/config/api_config.dart';
import '../../core/config/im_config.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/chat_session.dart';
import '../../data/providers/user_provider.dart';
import '../../data/providers/conversation_provider.dart';
import '../../data/models/wk_custom_content.dart';
import '../../data/models/wk_robot_card_content.dart';
import '../../modules/conversation/conversation_activity_registry.dart';
import '../../modules/video_call/call_coordinator.dart';
import '../../modules/video_call/video_call_service.dart';
import '../../realtime/session/session_event_frame.dart';
import '../../realtime/session/session_event_gateway.dart';
import '../../realtime/session/session_runtime.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import '../../wukong_base/msg/msg_content_type.dart';
import '../../wukong_base/db/db_helper.dart';
import '../../wukong_push/notification/android_message_alert_manager.dart';
import '../../wukong_push/notification/desktop_message_alert_manager.dart';
import '../../wukong_push/notification/message_alert_plan.dart';
import '../../wukong_push/notification/web_notification_manager.dart';
import '../api/file_api.dart';
import '../api/conversation_draft_api.dart';
import '../api/im_route_info.dart';
import '../api/im_sync_api.dart';
import '../api/message_api.dart';
import '../api/reminder_api.dart';
import 'im_word_sync_models.dart';
import 'local_attachment_file.dart';
import 'coordinators/attachment_pipeline.dart' as attachment_pipeline;
import 'coordinators/command_dispatcher.dart' as command_dispatcher;
import 'coordinators/connection_coordinator.dart' as connection_coordinator;
import 'coordinators/message_sync_coordinator.dart' as message_sync_coordinator;
import 'message_outbox.dart';

export 'coordinators/attachment_pipeline.dart'
    show normalizeFileAttachmentMetadata;
export 'coordinators/command_dispatcher.dart'
    show
        IMCommandSideEffect,
        imSyncRemindersCommand,
        imSyncMessageExtraCommand,
        imSyncConversationExtraCommand,
        imSyncPinnedMessageCommand,
        resolveImCommandSideEffects;

final imServiceProvider = StateNotifierProvider<IMService, IMServiceState>((
  ref,
) {
  return IMService(
    invalidateProvider: ref.invalidate,
    readProvider: ref.read,
    realtimeRolloutTelemetry: ref.read(realtimeRolloutTelemetryProvider),
  );
});

const String _sensitiveWordsCacheKey = 'wk_sensitive_words';
const String _sensitiveWordsVersionKey = 'wk_sensitive_words_version';
const bool _preferProtobufControlProtocol = true;
const String _protobufControlProtocol = 'protobuf';
const String _realtimeControlProtocolHeader = 'X-Realtime-Control-Protocol';

bool shouldReuseInitializedImSession({
  required String? initializedUid,
  required String? initializedToken,
  required String? initializedDeviceSessionId,
  required String uid,
  required String token,
  required String deviceSessionId,
  required int connectionStatus,
  required bool sessionRuntimeRunning,
}) {
  return const connection_coordinator.ConnectionCoordinator()
      .shouldReuseInitializedSession(
        initializedUid: initializedUid,
        initializedToken: initializedToken,
        initializedDeviceSessionId: initializedDeviceSessionId,
        uid: uid,
        token: token,
        deviceSessionId: deviceSessionId,
        connectionStatus: connectionStatus,
        sessionRuntimeRunning: sessionRuntimeRunning,
      );
}

@immutable
class StoredImInitCredentials {
  const StoredImInitCredentials({
    required this.uid,
    required this.apiToken,
    required this.imToken,
    required this.deviceSessionId,
  });

  final String uid;
  final String apiToken;
  final String imToken;
  final String deviceSessionId;
}

StoredImInitCredentials? resolveStoredImInitCredentials({
  String? uid,
  String? apiToken,
  String? imToken,
  String? deviceSessionId,
}) {
  final resolvedUid = uid?.trim() ?? '';
  final resolvedApiToken = apiToken?.trim() ?? '';
  final resolvedImToken = imToken?.trim() ?? '';
  final resolvedDeviceSessionId = deviceSessionId?.trim() ?? '';
  if (resolvedUid.isEmpty ||
      resolvedApiToken.isEmpty ||
      resolvedImToken.isEmpty ||
      resolvedDeviceSessionId.isEmpty) {
    return null;
  }

  return StoredImInitCredentials(
    uid: resolvedUid,
    apiToken: resolvedApiToken,
    imToken: resolvedImToken,
    deviceSessionId: resolvedDeviceSessionId,
  );
}

Uri buildSessionGatewayUri({
  required String baseUrl,
  required String deviceSessionId,
  required int lastAckedSeq,
  String? controlProtocol,
}) {
  return const connection_coordinator.ConnectionCoordinator()
      .buildSessionGatewayUri(
        baseUrl: baseUrl,
        deviceSessionId: deviceSessionId,
        lastAckedSeq: lastAckedSeq,
        controlProtocol: controlProtocol,
      );
}

String selectImConnectAddr(ImRouteInfo route, {required String fallbackAddr}) {
  return const connection_coordinator.ConnectionCoordinator().selectConnectAddr(
    route,
    fallbackAddr: fallbackAddr,
  );
}

@visibleForTesting
bool shouldUseImLocalPersistence({
  required bool isWeb,
  required bool sdkAppMode,
}) {
  return const connection_coordinator.ConnectionCoordinator()
      .shouldUseLocalPersistence(isWeb: isWeb, sdkAppMode: sdkAppMode);
}

@visibleForTesting
bool shouldStartNativeSessionRuntime({required bool isWeb}) {
  return const connection_coordinator.ConnectionCoordinator()
      .shouldStartNativeSessionRuntime(isWeb: isWeb);
}

typedef SessionRuntimeInitStarter = Future<void> Function();
typedef SessionRuntimeInitErrorHandler =
    void Function(Object error, StackTrace stackTrace);

@visibleForTesting
Future<bool> startSessionRuntimeForInit({
  required SessionRuntimeInitStarter start,
  Duration timeout = const Duration(seconds: 5),
  SessionRuntimeInitErrorHandler? onError,
}) async {
  try {
    await start().timeout(timeout);
    return true;
  } catch (error, stackTrace) {
    onError?.call(error, stackTrace);
    return false;
  }
}

@visibleForTesting
bool shouldDisconnectForBackgroundLifecycle({
  required bool isWeb,
  required bool hasActiveCallOrPendingSetup,
  bool keepRealtimeForDesktopNotifications = false,
  bool keepRealtimeForLocalNotifications = false,
}) {
  if (keepRealtimeForLocalNotifications) {
    return false;
  }
  return const connection_coordinator.ConnectionCoordinator()
      .shouldDisconnectForBackgroundLifecycle(
        isWeb: isWeb,
        hasActiveCallOrPendingSetup: hasActiveCallOrPendingSetup,
        keepRealtimeForDesktopNotifications:
            keepRealtimeForDesktopNotifications,
      );
}

class _RecoveredCallingKey {
  const _RecoveredCallingKey({
    required this.channelId,
    required this.channelType,
  });

  final String channelId;
  final int channelType;
}

_RecoveredCallingKey? _parseRecoveredCallingKey(String key) {
  final separatorIndex = key.indexOf('_');
  if (separatorIndex <= 0 || separatorIndex >= key.length - 1) {
    return null;
  }

  final channelType = int.tryParse(key.substring(0, separatorIndex));
  final channelId = key.substring(separatorIndex + 1).trim();
  if (channelType == null || channelId.isEmpty) {
    return null;
  }

  return _RecoveredCallingKey(channelId: channelId, channelType: channelType);
}

@immutable
class IMServiceState {
  final bool isInitializing;
  final bool isInitialized;
  final bool isConnected;
  final int connectionStatus;
  final int? reasonCode;
  final String? uid;
  final String? error;

  const IMServiceState({
    this.isInitializing = false,
    this.isInitialized = false,
    this.isConnected = false,
    this.connectionStatus = WKConnectStatus.fail,
    this.reasonCode,
    this.uid,
    this.error,
  });

  IMServiceState copyWith({
    bool? isInitializing,
    bool? isInitialized,
    bool? isConnected,
    int? connectionStatus,
    int? reasonCode,
    bool clearReasonCode = false,
    String? uid,
    String? error,
    bool clearError = false,
  }) {
    return IMServiceState(
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      isConnected: isConnected ?? this.isConnected,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      reasonCode: clearReasonCode ? null : (reasonCode ?? this.reasonCode),
      uid: uid ?? this.uid,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class IMService extends StateNotifier<IMServiceState>
    with WidgetsBindingObserver {
  IMService({
    SessionRuntime? sessionRuntime,
    void Function(ProviderOrFamily provider)? invalidateProvider,
    T Function<T>(ProviderListenable<T> provider)? readProvider,
    RealtimeRolloutTelemetry? realtimeRolloutTelemetry,
  }) : _invalidateProvider = invalidateProvider,
       _readProvider = readProvider,
       _ownsRealtimeRolloutTelemetry = realtimeRolloutTelemetry == null,
       super(const IMServiceState()) {
    _realtimeRolloutTelemetry =
        realtimeRolloutTelemetry ??
        RealtimeRolloutTelemetry(
          transport: IMSyncApi.instance.uploadRealtimeRolloutTelemetry,
        );
    _sessionRuntime =
        sessionRuntime ??
        SessionRuntime(
          gateway: SessionEventGateway(telemetry: _realtimeRolloutTelemetry),
          onDeviceInvalidated: _handleDeviceInvalidated,
          onFrame: _handleSessionFrame,
          telemetry: _realtimeRolloutTelemetry,
        );
    CallCoordinator.instance.setGatewayDegradationReader(
      _sessionRuntime.isGatewayDegradedFor,
    );
    VideoCallService.instance.setGatewayDegradationReader(
      _sessionRuntime.isGatewayDegradedFor,
    );
  }

  static const _connectionListenerKey = 'im_service_connection_listener';
  static const _cmdListenerKey = 'im_service_cmd_listener';
  static const _newMsgListenerKey = 'im_service_new_msg_listener';
  static const _requiredTables = {
    'message',
    'channel',
    'conversation',
    'message_extra',
  };

  Completer<bool>? _initCompleter;
  bool _listenersBound = false;
  bool _lifecycleObserverBound = false;
  bool _lifecycleDisconnected = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  String? _initializedUid;
  String? _initializedApiToken;
  String? _initializedToken;
  String? _initializedDeviceSessionId;
  int _lastConversationCmdVersion = 0;
  bool _isReminderSyncing = false;
  bool _pendingReminderSync = false;
  bool _isSensitiveWordSyncing = false;
  bool _pendingSensitiveWordSync = false;
  bool _isProhibitWordSyncing = false;
  bool _pendingProhibitWordSync = false;
  bool _isConversationExtraSyncing = false;
  bool _pendingConversationExtraSync = false;
  bool _isOfflineCmdSyncing = false;
  bool _pendingOfflineCmdSync = false;
  final Set<String> _activeMessageExtraSyncKeys = <String>{};
  final Set<String> _pendingMessageExtraSyncKeys = <String>{};
  SensitiveWordsSnapshot _sensitiveWordsSnapshot =
      const SensitiveWordsSnapshot();
  List<ProhibitWordEntry>? _cachedProhibitWords;
  late final RealtimeRolloutTelemetry _realtimeRolloutTelemetry;
  late final SessionRuntime _sessionRuntime;
  final bool _ownsRealtimeRolloutTelemetry;
  final void Function(ProviderOrFamily provider)? _invalidateProvider;
  final T Function<T>(ProviderListenable<T> provider)? _readProvider;
  final Map<String, VoidCallback> _vipExpiredHandlers =
      <String, VoidCallback>{};
  final command_dispatcher.CommandDispatcher _commandDispatcher =
      const command_dispatcher.CommandDispatcher();
  final connection_coordinator.ConnectionCoordinator _connectionCoordinator =
      const connection_coordinator.ConnectionCoordinator();
  final message_sync_coordinator.MessageSyncCoordinator
  _messageSyncCoordinator =
      const message_sync_coordinator.MessageSyncCoordinator();
  final attachment_pipeline.AttachmentPipeline _attachmentPipeline =
      const attachment_pipeline.AttachmentPipeline();

  void registerVipExpiredHandler({
    required String key,
    required void Function() handler,
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

  Future<bool> init() async {
    if (kIsWeb) {
      WKIM.shared.runMode = Model.web;
    }

    final credentials = resolveStoredImInitCredentials(
      uid: StorageUtils.getUid(),
      apiToken: StorageUtils.getToken(),
      imToken: StorageUtils.getImToken(),
      deviceSessionId: StorageUtils.getDeviceSessionId(),
    );
    if (credentials == null) {
      state = state.copyWith(
        isInitializing: false,
        isInitialized: false,
        isConnected: false,
        uid: null,
        error: 'IM credentials missing.',
      );
      return false;
    }

    if (_initCompleter != null && !_initCompleter!.isCompleted) {
      return _initCompleter!.future;
    }

    if (shouldReuseInitializedImSession(
          initializedUid: _initializedUid,
          initializedToken: _initializedToken,
          initializedDeviceSessionId: _initializedDeviceSessionId,
          uid: credentials.uid,
          token: credentials.imToken,
          deviceSessionId: credentials.deviceSessionId,
          connectionStatus: state.connectionStatus,
          sessionRuntimeRunning:
              !shouldStartNativeSessionRuntime(isWeb: kIsWeb) ||
              _sessionRuntime.isRunning,
        ) &&
        _initializedApiToken == credentials.apiToken) {
      return true;
    }

    _initCompleter = Completer<bool>();
    await Future<void>.delayed(Duration.zero);
    _ensureLifecycleObserver();
    state = state.copyWith(
      isInitializing: true,
      isInitialized: false,
      isConnected: false,
      uid: credentials.uid,
      clearError: true,
      clearReasonCode: true,
    );

    try {
      await _ensureDeviceUuid();

      final options =
          Options.newDefault(
              credentials.uid,
              credentials.imToken,
              addr: IMConfig.connectAddr,
            )
            ..getAddr = (complete) {
              _resolveConnectAddr(credentials.uid).then(
                complete,
                onError: (Object error, StackTrace stackTrace) {
                  debugPrint('IM route resolve failed: $error');
                  debugPrint('$stackTrace');
                  complete(IMConfig.connectAddr);
                },
              );
            }
            ..protoVersion = IMConfig.protoVersion
            ..deviceFlag = IMConfig.currentDeviceFlag
            ..debug = kDebugMode;

      final setupOk = await WKIM.shared.setup(options);
      if (!setupOk) {
        throw StateError('WKIM.setup returned false.');
      }

      if (_usesLocalPersistence) {
        final dbReady = await _ensureDatabaseReady();
        if (!dbReady) {
          throw StateError('IM database schema is not ready.');
        }
        await _loadStoredWordCaches();
      } else {
        _loadSensitiveWordsSnapshot();
        _cachedProhibitWords = const <ProhibitWordEntry>[];
      }

      _registerMessageContents();
      _bindSdkCallbacks();
      if (shouldStartNativeSessionRuntime(isWeb: kIsWeb)) {
        final sessionRuntimeStarted = await startSessionRuntimeForInit(
          start: () => _startSessionRuntime(
            token: credentials.apiToken,
            deviceSessionId: credentials.deviceSessionId,
          ),
          onError: (Object error, StackTrace stackTrace) {
            debugPrint(
              'Session runtime unavailable during IM init; continuing: $error',
            );
            debugPrint('$stackTrace');
          },
        );
        if (!sessionRuntimeStarted) {
          unawaited(_sessionRuntime.stop());
        }
      }

      WKIM.shared.connectionManager.connect();

      final connected = await _initCompleter!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          _completeInit(false);
          return false;
        },
      );

      if (!connected) {
        state = state.copyWith(
          isInitializing: false,
          isInitialized: false,
          isConnected: false,
          error: 'IM connection timed out.',
        );
        return false;
      }

      _initializedUid = credentials.uid;
      _initializedApiToken = credentials.apiToken;
      _initializedToken = credentials.imToken;
      _initializedDeviceSessionId = credentials.deviceSessionId;
      state = state.copyWith(
        isInitializing: false,
        isInitialized: true,
        isConnected: true,
        uid: credentials.uid,
        clearError: true,
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('IM init failed: $error');
      debugPrint('$stackTrace');
      await _sessionRuntime.stop();
      _completeInit(false);
      state = state.copyWith(
        isInitializing: false,
        isInitialized: false,
        isConnected: false,
        error: error.toString(),
      );
      return false;
    }
  }

  void disconnect({bool isLogout = false}) {
    _completeInit(false);
    unawaited(_sessionRuntime.stop());
    unawaited(_realtimeRolloutTelemetry.flush());
    WKIM.shared.connectionManager.disconnect(isLogout);
    _lifecycleDisconnected = false;
    if (isLogout) {
      _initializedUid = null;
      _initializedApiToken = null;
      _initializedToken = null;
      _initializedDeviceSessionId = null;
      _lastConversationCmdVersion = 0;
      applyRecoveredCallingStates(const <WKChannelState>[]);
    }
    state = IMServiceState(
      connectionStatus: WKConnectStatus.fail,
      uid: isLogout ? null : state.uid,
    );
  }

  void _bindSdkCallbacks() {
    if (_listenersBound) {
      return;
    }

    WKIM.shared.connectionManager.removeOnConnectionStatus(
      _connectionListenerKey,
    );
    WKIM.shared.cmdManager.removeCmdListener(_cmdListenerKey);
    WKIM.shared.messageManager.removeNewMsgListener(_newMsgListenerKey);
    WKIM.shared.connectionManager.addOnConnectionStatus(
      _connectionListenerKey,
      (status, reasonCode, _) {
        final isConnected =
            status == WKConnectStatus.success ||
            status == WKConnectStatus.syncCompleted;
        if (isConnected) {
          _lifecycleDisconnected = false;
        }
        state = state.copyWith(
          connectionStatus: status,
          reasonCode: reasonCode,
          isConnected: isConnected,
          isInitialized:
              state.isInitialized || status == WKConnectStatus.syncCompleted,
          error: _resolveConnectionError(status, reasonCode),
          clearError:
              status == WKConnectStatus.success ||
              status == WKConnectStatus.syncCompleted,
        );

        if (status == WKConnectStatus.syncCompleted) {
          unawaited(_syncReminders(reason: 'sync_completed'));
          unawaited(_syncSensitiveWords(reason: 'sync_completed'));
          unawaited(_syncProhibitWords(reason: 'sync_completed'));
          unawaited(_syncConversationExtras(reason: 'sync_completed'));
          unawaited(_syncOfflineCommandMessages(reason: 'sync_completed'));
          _completeInit(true);
        } else if (status == WKConnectStatus.kicked) {
          _completeInit(false);
        }
      },
    );

    WKIM.shared.conversationManager.addOnSyncConversationListener((
      lastMsgSeqs,
      msgCount,
      version,
      back,
    ) async {
      try {
        final deviceUuid = await _ensureDeviceUuid();
        final result = await IMSyncApi.instance.syncConversation(
          version: version,
          lastMsgSeqs: lastMsgSeqs,
          msgCount: msgCount,
          deviceUuid: deviceUuid,
        );
        _lastConversationCmdVersion = result.cmdVersion;
        applyRecoveredCallingStates(
          result.channelStatus ?? const <WKChannelState>[],
        );
        back(result);
        unawaited(
          _ackConversationSync(
            cmdVersion: result.cmdVersion,
            deviceUuid: deviceUuid,
          ),
        );
        unawaited(_syncConversationExtras(reason: 'conversation_sync'));
        unawaited(_syncOfflineCommandMessages(reason: 'conversation_sync'));
      } catch (error, stackTrace) {
        debugPrint('Conversation sync failed: $error');
        debugPrint('$stackTrace');
        back(WKSyncConversation()..conversations = []);
      }
    });

    WKIM.shared.messageManager.addOnSyncChannelMsgListener((
      channelId,
      channelType,
      startMessageSeq,
      endMessageSeq,
      limit,
      pullMode,
      back,
    ) async {
      try {
        final deviceUuid = await _ensureDeviceUuid();
        final result = await IMSyncApi.instance.syncChannelMessages(
          channelId: channelId,
          channelType: channelType,
          startMessageSeq: startMessageSeq,
          endMessageSeq: endMessageSeq,
          limit: limit,
          pullMode: pullMode,
          deviceUuid: deviceUuid,
        );
        back(result);
        unawaited(
          _ackConversationSync(
            cmdVersion: _lastConversationCmdVersion,
            deviceUuid: deviceUuid,
          ),
        );
      } catch (error, stackTrace) {
        debugPrint('Channel sync failed: $error');
        debugPrint('$stackTrace');
        back(null);
      }
    });

    WKIM.shared.messageManager.addOnUploadAttachmentListener((wkMsg, back) {
      _uploadAttachment(wkMsg).then(
        (success) => back(success, wkMsg),
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Attachment upload failed: $error');
          debugPrint('$stackTrace');
          back(false, wkMsg);
        },
      );
    });

    WKIM.shared.messageManager.addOnMsgInsertedListener((wkMsg) {
      WKIM.shared.messageManager.pushNewMsg([wkMsg]);
    });
    WKIM.shared.messageManager.addOnNewMsgListener(
      _newMsgListenerKey,
      _handleNewMessages,
    );

    WKIM.shared.cmdManager.addOnCmdListener(_cmdListenerKey, _handleCmd);

    _listenersBound = true;
  }

  void _handleCmd(WKCMD cmd) {
    final plan = _commandDispatcher.plan(cmd);
    final effects = plan.effects;
    if (plan.shouldNotifyVipExpired) {
      final vipExpiredHandlersSnapshot = List<VoidCallback>.from(
        _vipExpiredHandlers.values,
      );
      for (final handler in vipExpiredHandlersSnapshot) {
        handler();
      }
    }
    unawaited(
      ConversationActivityRegistry.instance.handleCommand(
        cmd,
        currentUid: state.uid ?? StorageUtils.getUid()?.trim() ?? '',
        channelLookup: (channelId, channelType) =>
            WKIM.shared.channelManager.getChannel(channelId, channelType),
      ),
    );
    if (effects.contains(
      command_dispatcher.IMCommandSideEffect.refreshFriendList,
    )) {
      _invalidateProvider?.call(friendListProvider);
    }
    if (effects.contains(
      command_dispatcher.IMCommandSideEffect.refreshFriendRequests,
    )) {
      _invalidateProvider?.call(friendRequestListProvider);
    }
    if (effects.contains(
      command_dispatcher.IMCommandSideEffect.syncConversationExtra,
    )) {
      unawaited(_syncConversationExtras(reason: 'cmd:${cmd.cmd}'));
    }
    if (effects.contains(
      command_dispatcher.IMCommandSideEffect.syncMessageExtra,
    )) {
      final target = plan.messageExtraTarget;
      if (target != null) {
        unawaited(
          _syncMessageExtras(
            channelId: target.channelId,
            channelType: target.channelType,
            reason: 'cmd:${cmd.cmd}',
          ),
        );
      }
    }
    if (effects.contains(
      command_dispatcher.IMCommandSideEffect.syncReminders,
    )) {
      unawaited(_syncReminders(reason: 'cmd:${cmd.cmd}'));
    }
  }

  Future<void> _syncReminders({String? reason}) async {
    if (_isReminderSyncing) {
      _pendingReminderSync = true;
      return;
    }

    _isReminderSyncing = true;
    try {
      do {
        _pendingReminderSync = false;
        try {
          final version = await WKIM.shared.reminderManager.getMaxVersion();
          final channelIds = await _loadReminderChannelIds();
          final reminders = await ReminderApi.instance.syncReminders(
            version: version,
            channelIds: channelIds,
          );
          if (reminders.isEmpty) {
            continue;
          }
          await WKIM.shared.reminderManager.saveOrUpdateReminders(reminders);
        } catch (error, stackTrace) {
          debugPrint('Reminder sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      } while (_pendingReminderSync);
    } finally {
      _isReminderSyncing = false;
    }
  }

  Future<void> _syncSensitiveWords({String? reason}) async {
    if (_isSensitiveWordSyncing) {
      _pendingSensitiveWordSync = true;
      return;
    }

    _isSensitiveWordSyncing = true;
    try {
      do {
        _pendingSensitiveWordSync = false;
        try {
          final version = _loadSensitiveWordsSnapshot().version;
          final snapshot = await MessageApi.instance.syncSensitiveWords(
            version: version,
          );
          if (snapshot.version <= 0 && snapshot.tips.trim().isEmpty) {
            continue;
          }
          await applySensitiveWordsSync(snapshot);
        } catch (error, stackTrace) {
          debugPrint('Sensitive words sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      } while (_pendingSensitiveWordSync);
    } finally {
      _isSensitiveWordSyncing = false;
    }
  }

  Future<void> _syncProhibitWords({String? reason}) async {
    if (!_usesLocalPersistence) {
      return;
    }

    if (_isProhibitWordSyncing) {
      _pendingProhibitWordSync = true;
      return;
    }

    _isProhibitWordSyncing = true;
    try {
      do {
        _pendingProhibitWordSync = false;
        try {
          final version = await DBHelper.instance.getMaxProhibitWordVersion();
          final words = await MessageApi.instance.syncProhibitWords(
            version: version,
          );
          if (words.isEmpty) {
            continue;
          }
          await applyProhibitWordsSync(words);
          await _refreshMaskedMessagesAfterProhibitWordSync();
        } catch (error, stackTrace) {
          debugPrint('Prohibit words sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      } while (_pendingProhibitWordSync);
    } finally {
      _isProhibitWordSyncing = false;
    }
  }

  Future<void> _syncConversationExtras({String? reason}) async {
    if (_isConversationExtraSyncing) {
      _pendingConversationExtraSync = true;
      return;
    }

    _isConversationExtraSyncing = true;
    try {
      do {
        _pendingConversationExtraSync = false;
        try {
          final version = await WKIM.shared.conversationManager
              .getMsgExtraMaxVersion();
          final extras = await ConversationDraftApi.instance.syncExtras(
            version: version,
          );
          if (extras.isEmpty) {
            continue;
          }
          await WKIM.shared.conversationManager.saveSyncMsgExtras(
            extras.map(_toSyncConversationExtra).toList(growable: false),
          );
        } catch (error, stackTrace) {
          debugPrint('Conversation extra sync failed($reason): $error');
          debugPrint('$stackTrace');
        }
      } while (_pendingConversationExtraSync);
    } finally {
      _isConversationExtraSyncing = false;
    }
  }

  Future<void> _syncMessageExtras({
    required String channelId,
    required int channelType,
    String? reason,
  }) async {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return;
    }

    final syncKey = _messageExtraSyncKey(normalizedChannelId, channelType);
    if (_activeMessageExtraSyncKeys.contains(syncKey)) {
      _pendingMessageExtraSyncKeys.add(syncKey);
      return;
    }

    _activeMessageExtraSyncKeys.add(syncKey);
    try {
      while (true) {
        _pendingMessageExtraSyncKeys.remove(syncKey);
        try {
          final deviceUuid = await _ensureDeviceUuid();
          final extraVersion = await WKIM.shared.messageManager
              .getMaxExtraVersionWithChannel(normalizedChannelId, channelType);
          final extras = await MessageApi.instance.syncMessageExtras(
            channelId: normalizedChannelId,
            channelType: channelType,
            extraVersion: extraVersion,
            deviceUuid: deviceUuid,
            limit: 100,
          );
          if (extras.isEmpty) {
            break;
          }
          final mappedExtras = extras
              .map(
                (item) => WKIM.shared.messageManager.wkSyncExtraMsg2WKMsgExtra(
                  normalizedChannelId,
                  channelType,
                  item,
                ),
              )
              .toList(growable: false);
          await WKIM.shared.messageManager.saveRemoteExtraMsg(mappedExtras);
          if (!_usesLocalPersistence) {
            _publishRealtimeMessageExtraRefresh(
              normalizedChannelId,
              channelType,
              mappedExtras,
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        } catch (error, stackTrace) {
          debugPrint(
            'Message extra sync failed($reason:$normalizedChannelId/$channelType): $error',
          );
          debugPrint('$stackTrace');
          break;
        }
      }
    } finally {
      _activeMessageExtraSyncKeys.remove(syncKey);
      if (_pendingMessageExtraSyncKeys.remove(syncKey)) {
        unawaited(
          _syncMessageExtras(
            channelId: normalizedChannelId,
            channelType: channelType,
            reason: 'pending',
          ),
        );
      }
    }
  }

  Future<void> _syncOfflineCommandMessages({String? reason}) async {
    if (_isOfflineCmdSyncing) {
      _pendingOfflineCmdSync = true;
      return;
    }

    _isOfflineCmdSyncing = true;
    try {
      do {
        _pendingOfflineCmdSync = false;
        await _runOfflineCommandSync(reason: reason);
      } while (_pendingOfflineCmdSync);
    } finally {
      _isOfflineCmdSyncing = false;
    }
  }

  Future<void> _runOfflineCommandSync({String? reason}) async {
    final pendingCommands = <Map<String, dynamic>>[];
    var nextMaxMessageSeq = 0;

    try {
      while (true) {
        final response = await MessageApi.instance.syncCommandMessages(
          maxMessageSeq: nextMaxMessageSeq,
          limit: 500,
        );
        final messages = response.messages ?? const <dynamic>[];
        if (messages.isEmpty) {
          break;
        }

        pendingCommands.addAll(_extractOfflineCommands(messages));
        final ackSequence = resolveOfflineCommandAckSequence(messages);
        if (ackSequence <= 0) {
          break;
        }
        await MessageApi.instance.syncAck(lastMessageSeq: ackSequence);
        nextMaxMessageSeq = ackSequence;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } catch (error, stackTrace) {
      debugPrint('Offline cmd sync failed($reason): $error');
      debugPrint('$stackTrace');
    } finally {
      for (final command in pendingCommands) {
        WKIM.shared.cmdManager.handleCMD(command);
      }
    }
  }

  List<Map<String, dynamic>> _extractOfflineCommands(
    Iterable<dynamic> messages,
  ) {
    final commands = <Map<String, dynamic>>[];
    for (final message in messages) {
      final raw = _asMap(message);
      if (raw.isEmpty) {
        continue;
      }
      final payload = _extractOfflineCommandPayload(raw);
      if (payload == null) {
        continue;
      }
      payload['channel_id'] = payload['channel_id'] ?? raw['channel_id'];
      payload['channel_type'] = payload['channel_type'] ?? raw['channel_type'];
      final command = _readDynamicString(payload['cmd']);
      if (command.isEmpty) {
        continue;
      }
      commands.add(payload);
    }
    return commands;
  }

  Map<String, dynamic>? _extractOfflineCommandPayload(
    Map<String, dynamic> raw,
  ) {
    final payload = raw['payload'];
    if (payload is Map) {
      final payloadMap = Map<String, dynamic>.from(payload);
      final type = _readDynamicInt(payloadMap['type'] ?? raw['type']);
      if (payloadMap.containsKey('cmd') ||
          type == WkMessageContentType.insideMsg) {
        return payloadMap;
      }
    }

    final content = raw['content'];
    if (content is String && content.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          final payloadMap = Map<String, dynamic>.from(decoded);
          final type = _readDynamicInt(payloadMap['type'] ?? raw['type']);
          if (payloadMap.containsKey('cmd') ||
              type == WkMessageContentType.insideMsg) {
            return payloadMap;
          }
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  WKSyncConvMsgExtra _toSyncConversationExtra(RemoteConversationDraft extra) {
    return WKSyncConvMsgExtra()
      ..channelID = extra.channelId
      ..channelType = extra.channelType
      ..browseTo = extra.browseTo
      ..keepMessageSeq = extra.keepMessageSeq
      ..keepOffsetY = extra.keepOffsetY
      ..draft = extra.draft
      ..version = extra.version;
  }

  String _messageExtraSyncKey(String channelId, int channelType) {
    return _messageSyncCoordinator.messageExtraSyncKey(channelId, channelType);
  }

  void _handleNewMessages(List<WKMsg> messages) {
    final currentUid = state.uid ?? StorageUtils.getUid()?.trim() ?? '';
    for (final message in messages) {
      applyProhibitWordsToMessage(message);
      if (!_usesLocalPersistence) {
        _publishRealtimeConversationMessage(message);
      }
      final tip = buildSensitiveWordTipMessageIfNeeded(message);
      if (tip != null) {
        unawaited(_insertSensitiveWordTipMessage(tip));
      }
      if (kIsWeb) {
        _scheduleWebMessageAlert(message, currentUid: currentUid);
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        _scheduleAndroidMessageAlert(message, currentUid: currentUid);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        _scheduleDesktopMessageAlert(message, currentUid: currentUid);
      }
    }
  }

  void _scheduleWebMessageAlert(WKMsg message, {required String currentUid}) {
    try {
      final plan = buildMessageAlertPlan(message, currentUid: currentUid);
      if (plan == null) {
        return;
      }
      unawaited(
        WebNotificationManager.instance.showNewMessageAlert(
          plan: plan,
          lifecycleState: _appLifecycleState,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Web message alert scheduling failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _scheduleAndroidMessageAlert(
    WKMsg message, {
    required String currentUid,
  }) {
    try {
      final plan = buildMessageAlertPlan(message, currentUid: currentUid);
      if (plan == null) {
        return;
      }
      unawaited(
        AndroidMessageAlertManager.instance.showNewMessageAlert(
          plan: plan,
          lifecycleState: _appLifecycleState,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Android message alert scheduling failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _scheduleDesktopMessageAlert(
    WKMsg message, {
    required String currentUid,
  }) {
    try {
      final plan = buildMessageAlertPlan(message, currentUid: currentUid);
      if (plan == null) {
        return;
      }
      unawaited(
        DesktopMessageAlertManager.instance.showNewMessageAlert(
          plan: plan,
          lifecycleState: _appLifecycleState,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Desktop message alert scheduling failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _publishRealtimeConversationMessage(WKMsg message) {
    final read = _readProvider;
    if (read == null) {
      return;
    }
    read(conversationProvider.notifier).applyRealtimeMessage(
      message,
      currentUid: state.uid ?? StorageUtils.getUid()?.trim(),
    );
  }

  void _publishRealtimeMessageExtraRefresh(
    String channelId,
    int channelType,
    Iterable<WKMsgExtra> extras,
  ) {
    final read = _readProvider;
    if (read == null) {
      return;
    }
    final session = ChatSession(channelId: channelId, channelType: channelType);
    final notifier = read(messageListProvider(session).notifier);
    final conversationNotifier = read(conversationProvider.notifier);
    for (final extra in extras) {
      final messageId = extra.messageID.trim();
      if (messageId.isEmpty) {
        continue;
      }
      final refreshMessage = WKMsg()
        ..channelID = channelId
        ..channelType = channelType
        ..messageID = messageId
        ..status = WKSendMsgResult.sendSuccess
        ..wkMsgExtra = extra;
      notifier.applyLocalMessageRefresh(refreshMessage);
      conversationNotifier.applyMessageExtraRefresh(refreshMessage);
    }
  }

  Future<void> _insertSensitiveWordTipMessage(WKMsg tip) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!await _ensureDatabaseReady()) {
      return;
    }

    final orderSeq = await WKIM.shared.messageManager.getMessageOrderSeq(
      0,
      tip.channelID,
      tip.channelType,
    );
    tip.orderSeq = orderSeq + 1;
    final clientSeq = await WKIM.shared.messageManager.saveMsg(tip);
    tip.clientSeq = clientSeq;
    final uiMsg = await WKIM.shared.conversationManager.saveWithLiMMsg(tip, 0);
    WKIM.shared.messageManager.setOnMsgInserted(tip);
    if (uiMsg != null) {
      WKIM.shared.conversationManager.setRefreshUIMsgs(<WKUIConversationMsg>[
        uiMsg,
      ]);
    }
  }

  Future<List<String>> _loadReminderChannelIds() async {
    try {
      final conversations = await WKIM.shared.conversationManager.getAll();
      final ids = <String>{};
      for (final item in conversations) {
        if (item.channelType == WKChannelType.group &&
            item.channelID.trim().isNotEmpty) {
          ids.add(item.channelID.trim());
        }
      }
      return ids.toList();
    } catch (_) {
      return const <String>[];
    }
  }

  void _registerMessageContents() {
    WKIM.shared.messageManager.registerMsgContent(
      WkMessageContentType.location,
      (data) => WKLocationContent().decodeJson(_asMap(data)),
    );
    WKIM.shared.messageManager.registerMsgContent(
      WkMessageContentType.file,
      (data) => WKFileContent().decodeJson(_asMap(data)),
    );
    WKIM.shared.messageManager.registerMsgContent(
      WkMessageContentType.card,
      (data) => WKCardContent('', '').decodeJson(_asMap(data)),
    );
    WKIM.shared.messageManager.registerMsgContent(
      MsgContentType.robotCard,
      (data) => WKRobotCardContent().decodeJson(_asMap(data)),
    );
  }

  Future<bool> _ensureDatabaseReady() async {
    if (!_usesLocalPersistence) {
      return false;
    }

    if (WKDBHelper.shared.getDB() == null) {
      final reopened = await WKDBHelper.shared.init();
      if (!reopened) {
        return false;
      }
    }

    final db = WKDBHelper.shared.getDB();
    if (db == null) {
      return false;
    }

    if (await _hasRequiredTables(db)) {
      return _ensureMessageOutboxSchema(db);
    }

    final migrated = await _applySdkMigrations(db);
    if (!migrated) {
      return false;
    }

    final ready = await _waitForRequiredTables();
    if (!ready) {
      return false;
    }
    final migratedDb = WKDBHelper.shared.getDB();
    if (migratedDb == null) {
      return false;
    }
    return _ensureMessageOutboxSchema(migratedDb);
  }

  Future<bool> _ensureMessageOutboxSchema(Database db) async {
    try {
      await ensureMessageOutboxSchema(db);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Ensuring message outbox schema failed: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  Future<bool> _hasRequiredTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    final names = rows
        .map((row) => row['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toSet();
    return _requiredTables.every(names.contains);
  }

  Future<bool> _applySdkMigrations(Database db) async {
    try {
      return await WKDBHelper.shared.onUpgrade(db);
    } catch (error, stackTrace) {
      debugPrint('Applying SDK migrations failed: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  Future<bool> _waitForRequiredTables() async {
    for (var index = 0; index < 20; index++) {
      final db = WKDBHelper.shared.getDB();
      if (db != null && await _hasRequiredTables(db)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<String> _ensureDeviceUuid() async {
    final cached = StorageUtils.getDeviceId()?.trim() ?? '';
    if (cached.isNotEmpty) {
      return cached;
    }

    final deviceUuid = const Uuid().v4().replaceAll('-', '');
    await StorageUtils.setDeviceId(deviceUuid);
    return deviceUuid;
  }

  Future<bool> _uploadAttachment(WKMsg wkMsg) async {
    final content = wkMsg.messageContent;
    if (content == null) {
      return false;
    }

    if (content is WKVideoContent) {
      final uploadedVideo = await _ensureMediaContentUploaded(content, wkMsg);
      if (!uploadedVideo) {
        return false;
      }
      if (content.cover.trim().isEmpty) {
        final coverLocalPath = content.coverLocalPath.trim();
        if (coverLocalPath.isNotEmpty) {
          if (!await localAttachmentFileExists(coverLocalPath)) {
            return false;
          }
          content.cover = await FileApi.instance.uploadChatFile(
            filePath: coverLocalPath,
            channelId: wkMsg.channelID,
            channelType: wkMsg.channelType,
          );
        }
      }
      wkMsg.messageContent = content;
      return content.url.trim().isNotEmpty;
    }

    if (content is WKImageContent || content is WKVoiceContent) {
      final media = content as WKMediaMessageContent;
      final uploaded = await _ensureMediaContentUploaded(media, wkMsg);
      wkMsg.messageContent = media;
      return uploaded;
    }

    if (content is WKFileContent) {
      final uploaded = await _ensureFileContentUploaded(content, wkMsg);
      wkMsg.messageContent = content;
      return uploaded;
    }

    if (content is WKMediaMessageContent) {
      final uploaded = await _ensureMediaContentUploaded(content, wkMsg);
      wkMsg.messageContent = content;
      return uploaded;
    }

    return true;
  }

  Future<bool> _ensureMediaContentUploaded(
    WKMediaMessageContent content,
    WKMsg wkMsg,
  ) async {
    if (content.url.trim().isNotEmpty) {
      return true;
    }

    final localPath = content.localPath.trim();
    if (localPath.isEmpty) {
      return false;
    }

    if (!await localAttachmentFileExists(localPath)) {
      return false;
    }

    final uploadedUrl = await FileApi.instance.uploadChatFile(
      filePath: localPath,
      channelId: wkMsg.channelID,
      channelType: wkMsg.channelType,
    );
    content.url = uploadedUrl;
    return uploadedUrl.trim().isNotEmpty;
  }

  Future<bool> _ensureFileContentUploaded(
    WKFileContent content,
    WKMsg wkMsg,
  ) async {
    if (content.url.trim().isNotEmpty) {
      return true;
    }

    final localPath = content.localPath.trim();
    if (localPath.isEmpty) {
      return false;
    }

    if (!await localAttachmentFileExists(localPath)) {
      return false;
    }

    final uploadedUrl = await FileApi.instance.uploadChatFile(
      filePath: localPath,
      channelId: wkMsg.channelID,
      channelType: wkMsg.channelType,
    );
    content.url = uploadedUrl;
    _attachmentPipeline.normalizeFileMetadata(
      content,
      localPath: localPath,
      inferredSize: content.size > 0
          ? content.size
          : await localAttachmentFileLength(localPath),
    );
    return uploadedUrl.trim().isNotEmpty;
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  int _readDynamicInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _readDynamicString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  SensitiveWordsSnapshot _loadSensitiveWordsSnapshot() {
    if (!_sensitiveWordsSnapshot.isEmpty) {
      return _sensitiveWordsSnapshot;
    }
    final storedVersion = StorageUtils.getInt(_sensitiveWordsVersionKey) ?? 0;
    final raw = StorageUtils.getString(_sensitiveWordsCacheKey)?.trim() ?? '';
    if (raw.isEmpty) {
      if (storedVersion > 0) {
        _sensitiveWordsSnapshot = SensitiveWordsSnapshot(
          version: storedVersion,
        );
      }
      return _sensitiveWordsSnapshot;
    }
    try {
      final decoded = jsonDecode(raw);
      _sensitiveWordsSnapshot = SensitiveWordsSnapshot.fromDynamic(decoded);
      if (_sensitiveWordsSnapshot.version <= 0 && storedVersion > 0) {
        _sensitiveWordsSnapshot = SensitiveWordsSnapshot(
          tips: _sensitiveWordsSnapshot.tips,
          version: storedVersion,
          list: _sensitiveWordsSnapshot.list,
        );
      }
    } catch (_) {
      _sensitiveWordsSnapshot = SensitiveWordsSnapshot(version: storedVersion);
    }
    return _sensitiveWordsSnapshot;
  }

  Future<void> _loadStoredWordCaches() async {
    _loadSensitiveWordsSnapshot();
    if (!_usesLocalPersistence) {
      _cachedProhibitWords = const <ProhibitWordEntry>[];
      return;
    }
    _cachedProhibitWords = await DBHelper.instance.getProhibitWords();
  }

  List<ProhibitWordEntry> _resolveProhibitWords() {
    return _cachedProhibitWords ?? const <ProhibitWordEntry>[];
  }

  String _maskTextWithProhibitWords(
    String source,
    List<ProhibitWordEntry> words,
  ) {
    var masked = source;
    for (final word in words) {
      final target = word.content.trim();
      if (target.isEmpty || !masked.contains(target)) {
        continue;
      }
      masked = masked.replaceAll(target, '*' * target.length);
    }
    return masked;
  }

  Future<void> _refreshMaskedMessagesAfterProhibitWordSync() async {
    if (!await _ensureDatabaseReady()) {
      return;
    }
    final db = WKDBHelper.shared.getDB();
    if (db == null) {
      return;
    }

    final rows = await db.query(
      WKDBConst.tableMessage,
      columns: const <String>['client_msg_no'],
      where: 'type=? AND is_deleted=0',
      whereArgs: const <Object>[WkMessageContentType.text],
    );
    for (final row in rows) {
      final clientMsgNo = _readDynamicString(row['client_msg_no']);
      if (clientMsgNo.isEmpty) {
        continue;
      }
      final message = await MessageDB.shared.queryWithClientMsgNo(clientMsgNo);
      if (message == null) {
        continue;
      }
      final changed = applyProhibitWordsToMessage(message);
      if (changed) {
        WKIM.shared.messageManager.setRefreshMsg(message);
      }
    }
  }

  String? _resolveConnectionError(int status, int? reasonCode) {
    switch (status) {
      case WKConnectStatus.success:
      case WKConnectStatus.syncCompleted:
      case WKConnectStatus.connecting:
      case WKConnectStatus.syncMsg:
        return null;
      case WKConnectStatus.kicked:
        return 'IM session was kicked out.';
      case WKConnectStatus.noNetwork:
        return 'Network unavailable.';
      case WKConnectStatus.fail:
        if (reasonCode != null && reasonCode != 0) {
          return 'IM connection failed. reason=$reasonCode';
        }
        return null;
      default:
        return null;
    }
  }

  void _completeInit(bool value) {
    final completer = _initCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
    _initCompleter = null;
  }

  Future<void> _startSessionRuntime({
    required String token,
    required String deviceSessionId,
  }) async {
    final controlProtocol = _preferProtobufControlProtocol
        ? _protobufControlProtocol
        : null;

    if (_initializedDeviceSessionId == deviceSessionId &&
        _sessionRuntime.isRunning) {
      return;
    }
    await _sessionRuntime.start(
      _buildSessionGatewayUri(
        deviceSessionId: deviceSessionId,
        lastAckedSeq: _sessionRuntime.gateway.lastAckedSeq,
        controlProtocol: controlProtocol,
      ),
      headers: <String, String>{
        'token': token,
        ...?controlProtocol == null
            ? null
            : <String, String>{_realtimeControlProtocolHeader: controlProtocol},
      },
    );
  }

  Uri _buildSessionGatewayUri({
    required String deviceSessionId,
    required int lastAckedSeq,
    String? controlProtocol,
  }) {
    return buildSessionGatewayUri(
      baseUrl: ApiConfig.baseUrl,
      deviceSessionId: deviceSessionId,
      lastAckedSeq: lastAckedSeq,
      controlProtocol: controlProtocol,
    );
  }

  Future<void> _handleDeviceInvalidated() async {
    _completeInit(false);
    _initializedDeviceSessionId = null;
    _lifecycleDisconnected = false;
    _lastConversationCmdVersion = 0;
    applyRecoveredCallingStates(const <WKChannelState>[]);
    WKIM.shared.connectionManager.disconnect(false);
    state = state.copyWith(
      isInitializing: false,
      isInitialized: false,
      isConnected: false,
      error: 'Device session invalidated.',
    );
  }

  Future<void> _handleSessionFrame(SessionEventFrame frame) async {
    final controlEvent = mapSessionControlEvent(frame);
    if (controlEvent is ConversationUpdatedEvent) {
      _applyConversationUpdatedEvent(controlEvent);
    }
    await CallCoordinator.instance.handleSessionFrame(frame);
  }

  void _applyConversationUpdatedEvent(ConversationUpdatedEvent event) {
    final read = _readProvider;
    if (read == null) {
      return;
    }
    read(conversationProvider.notifier).applyPatch(
      ConversationPatch.unreadAndDigest(
        channelId: event.channelId,
        channelType: event.channelType,
        unreadCount: event.unreadCount,
        lastMessageDigest: event.lastMessageDigest,
        sortTimestamp: event.sortTimestamp,
      ),
    );
  }

  @visibleForTesting
  void handleCmdForTesting(WKCMD cmd) {
    _handleCmd(cmd);
  }

  @visibleForTesting
  bool shouldKeepConnectionInBackground({bool? hasActiveCallOrPendingSetup}) {
    return !_connectionCoordinator.shouldDisconnectForBackgroundLifecycle(
      isWeb: kIsWeb,
      hasActiveCallOrPendingSetup:
          hasActiveCallOrPendingSetup ??
          VideoCallService.instance.hasActiveCallOrPendingSetup,
    );
  }

  @visibleForTesting
  Set<String> applyRecoveredCallingStates(
    Iterable<WKChannelState> channelStates,
  ) {
    final nextKeys = <String>{};
    for (final channelState in channelStates) {
      final channelId = channelState.channelID.trim();
      if (channelId.isEmpty) {
        continue;
      }
      final channelKey = ConversationActivityRegistry.conversationKey(
        channelId,
        channelState.channelType,
      );
      final isCalling = channelState.calling > 0;
      ConversationActivityRegistry.instance.setCallingState(
        channelId,
        channelState.channelType,
        isCalling,
      );
      if (isCalling) {
        nextKeys.add(channelKey);
      }
    }

    final previousCallingKeys = ConversationActivityRegistry.instance
        .getActiveCallingConversationKeys();
    for (final staleKey in previousCallingKeys.difference(nextKeys)) {
      final target = _parseRecoveredCallingKey(staleKey);
      if (target == null) {
        continue;
      }
      ConversationActivityRegistry.instance.setCallingState(
        target.channelId,
        target.channelType,
        false,
      );
    }

    return Set<String>.from(nextKeys);
  }

  @visibleForTesting
  int resolveOfflineCommandAckSequence(Iterable<dynamic> messages) {
    return _messageSyncCoordinator.resolveOfflineCommandAckSequence(messages);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    switch (state) {
      case AppLifecycleState.resumed:
        _resumeAfterLifecycleDisconnect();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(_realtimeRolloutTelemetry.flush());
        _disconnectForBackgroundIfNeeded();
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    if (_lifecycleObserverBound) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverBound = false;
    }
    unawaited(_realtimeRolloutTelemetry.flush());
    if (_ownsRealtimeRolloutTelemetry) {
      _realtimeRolloutTelemetry.dispose();
    }
    WKIM.shared.messageManager.removeNewMsgListener(_newMsgListenerKey);
    WKIM.shared.cmdManager.removeCmdListener(_cmdListenerKey);
    WKIM.shared.connectionManager.removeOnConnectionStatus(
      _connectionListenerKey,
    );
    super.dispose();
  }

  void _ensureLifecycleObserver() {
    if (_lifecycleObserverBound) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverBound = true;
  }

  Future<String> _resolveConnectAddr(String uid) async {
    final route = await IMSyncApi.instance.fetchUserConnectRoute(uid: uid);
    return selectImConnectAddr(route, fallbackAddr: IMConfig.connectAddr);
  }

  Future<void> _ackConversationSync({
    required int cmdVersion,
    required String deviceUuid,
  }) async {
    try {
      await IMSyncApi.instance.ackConversationSync(
        cmdVersion: cmdVersion,
        deviceUuid: deviceUuid,
      );
    } catch (error, stackTrace) {
      debugPrint('Conversation sync ack failed: $error');
      debugPrint('$stackTrace');
    }
  }

  void _disconnectForBackgroundIfNeeded() {
    if (_lifecycleDisconnected) {
      return;
    }
    if (_initializedUid == null ||
        _initializedApiToken == null ||
        _initializedToken == null ||
        _initializedDeviceSessionId == null) {
      return;
    }
    if (!shouldDisconnectForBackgroundLifecycle(
      isWeb: kIsWeb,
      hasActiveCallOrPendingSetup: shouldKeepConnectionInBackground(),
      keepRealtimeForDesktopNotifications:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
      keepRealtimeForLocalNotifications:
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    )) {
      return;
    }
    _lifecycleDisconnected = true;
    WKIM.shared.connectionManager.disconnect(false);
  }

  void _resumeAfterLifecycleDisconnect() {
    if (!_lifecycleDisconnected) {
      return;
    }
    _lifecycleDisconnected = false;

    final uid = _initializedUid?.trim() ?? StorageUtils.getUid()?.trim() ?? '';
    final apiToken =
        _initializedApiToken?.trim() ?? StorageUtils.getToken()?.trim() ?? '';
    final imToken =
        _initializedToken?.trim() ?? StorageUtils.getImToken()?.trim() ?? '';
    final deviceSessionId =
        _initializedDeviceSessionId?.trim() ??
        StorageUtils.getDeviceSessionId()?.trim() ??
        '';
    if (uid.isEmpty ||
        apiToken.isEmpty ||
        imToken.isEmpty ||
        deviceSessionId.isEmpty) {
      return;
    }

    unawaited(
      _startSessionRuntime(token: apiToken, deviceSessionId: deviceSessionId),
    );
    WKIM.shared.connectionManager.connect();
  }

  @visibleForTesting
  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) async {
    await StorageUtils.setInt(_sensitiveWordsVersionKey, snapshot.version);
    if (snapshot.tips.trim().isEmpty) {
      return;
    }
    _sensitiveWordsSnapshot = snapshot;
    await StorageUtils.setString(
      _sensitiveWordsCacheKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  @visibleForTesting
  WKMsg? buildSensitiveWordTipMessageIfNeeded(WKMsg message) {
    if (message.contentType != WkMessageContentType.text) {
      return null;
    }
    final snapshot = _loadSensitiveWordsSnapshot();
    if (snapshot.isEmpty) {
      return null;
    }
    final text = message.messageContent?.displayText().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final containsSensitiveWord = snapshot.list.any(text.contains);
    if (!containsSensitiveWord) {
      return null;
    }

    final tip = WKMsg()
      ..channelID = message.channelID
      ..channelType = message.channelType
      ..fromUID = StorageUtils.getUid()?.trim() ?? state.uid ?? ''
      ..contentType = MsgContentType.sensitiveWord
      ..content = jsonEncode(<String, dynamic>{
        'content': snapshot.tips,
        'type': MsgContentType.sensitiveWord,
      })
      ..status = WKSendMsgResult.sendSuccess
      ..header.redDot = false;
    tip.setChannelInfo(message.getChannelInfo());
    return tip;
  }

  @visibleForTesting
  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) async {
    if (!_usesLocalPersistence) {
      _cachedProhibitWords = words;
      return;
    }
    await DBHelper.instance.saveProhibitWords(words);
    _cachedProhibitWords = await DBHelper.instance.getProhibitWords();
  }

  bool get _usesLocalPersistence => shouldUseImLocalPersistence(
    isWeb: kIsWeb,
    sdkAppMode: WKIM.shared.isApp(),
  );

  @visibleForTesting
  bool applyProhibitWordsToMessage(WKMsg message) {
    if (message.contentType != WkMessageContentType.text) {
      return false;
    }
    final words = _resolveProhibitWords();
    if (words.isEmpty) {
      return false;
    }

    final editedContent = message.wkMsgExtra?.messageContent;
    if (editedContent != null &&
        editedContent.displayText().trim().isNotEmpty) {
      final masked = _maskTextWithProhibitWords(
        editedContent.displayText(),
        words,
      );
      if (masked == editedContent.content) {
        return false;
      }
      editedContent.content = masked;
      return true;
    }

    final baseContent = message.messageContent;
    if (baseContent == null || baseContent.displayText().trim().isEmpty) {
      return false;
    }
    final masked = _maskTextWithProhibitWords(baseContent.displayText(), words);
    if (masked == baseContent.content) {
      return false;
    }
    baseContent.content = masked;
    return true;
  }
}
