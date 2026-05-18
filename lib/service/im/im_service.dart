import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wukongimfluttersdk/common/mode.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/cmd.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/config/api_config.dart';
import '../../core/config/im_config.dart';
import '../../core/utils/storage_utils.dart';
import '../../data/models/chat_session.dart';
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
import '../api/conversation_draft_api.dart';
import '../api/file_api.dart';
import '../api/im_route_info.dart';
import '../api/im_sync_api.dart';
import '../api/message_api.dart';
import '../api/reminder_api.dart';
import 'im_word_sync_models.dart';
import 'attachment_upload_pipeline.dart';
import 'im_command_effect_coordinator.dart';
import 'im_connection_service.dart';
import 'im_local_database_service.dart';
import 'im_masked_message_refresh_service.dart';
import 'im_notification_bridge.dart';
import 'im_sensitive_tip_persistence_service.dart';
import 'im_service_providers.dart';
import 'im_sync_orchestrator.dart';
import 'im_word_runtime_filter_service.dart';
import 'im_word_sync_store.dart';
import 'message_delivery_service.dart';

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
    notificationBridge: ref.read(imNotificationBridgeProvider),
    syncOrchestrator: ref.read(imSyncOrchestratorProvider),
    wordSyncStore: ref.read(imWordSyncStoreProvider),
    wordRuntimeFilterService: ref.read(imWordRuntimeFilterServiceProvider),
    localDatabaseService: ref.read(imLocalDatabaseServiceProvider),
    sensitiveTipPersistenceService: ref.read(
      imSensitiveTipPersistenceServiceProvider,
    ),
    attachmentUploadPipeline: ref.read(attachmentUploadPipelineProvider),
    connectionService: ref.read(imConnectionServiceProvider),
    realtimeRolloutTelemetry: ref.read(realtimeRolloutTelemetryProvider),
  );
});

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
  return ImConnectionService.shouldReuseInitializedSession(
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
  final credentials = ImConnectionService.resolveStoredCredentials(
    uid: uid,
    apiToken: apiToken,
    imToken: imToken,
    deviceSessionId: deviceSessionId,
  );
  if (credentials == null) {
    return null;
  }

  return StoredImInitCredentials(
    uid: credentials.uid,
    apiToken: credentials.apiToken,
    imToken: credentials.imToken,
    deviceSessionId: credentials.deviceSessionId,
  );
}

Uri buildSessionGatewayUri({
  required String baseUrl,
  required String deviceSessionId,
  required int lastAckedSeq,
  String? controlProtocol,
}) {
  return ImConnectionService.buildSessionGatewayUri(
    baseUrl: baseUrl,
    deviceSessionId: deviceSessionId,
    lastAckedSeq: lastAckedSeq,
    controlProtocol: controlProtocol,
  );
}

String selectImConnectAddr(ImRouteInfo route, {required String fallbackAddr}) {
  return ImConnectionService.selectConnectAddr(
    route,
    fallbackAddr: fallbackAddr,
  );
}

@visibleForTesting
bool shouldUseImLocalPersistence({
  required bool isWeb,
  required bool sdkAppMode,
}) {
  return ImConnectionService.shouldUseLocalPersistence(
    isWeb: isWeb,
    sdkAppMode: sdkAppMode,
  );
}

@visibleForTesting
bool shouldStartNativeSessionRuntime({required bool isWeb}) {
  return ImConnectionService.shouldStartNativeSessionRuntime(isWeb: isWeb);
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
  return ImConnectionService.shouldDisconnectForBackgroundLifecycle(
    isWeb: isWeb,
    hasActiveCallOrPendingSetup: hasActiveCallOrPendingSetup,
    keepRealtimeForDesktopNotifications: keepRealtimeForDesktopNotifications,
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
    ImConnectionService? connectionService,
    ImNotificationBridge? notificationBridge,
    ImSyncOrchestrator? syncOrchestrator,
    ImWordSyncStore? wordSyncStore,
    ImWordRuntimeFilterService? wordRuntimeFilterService,
    ImMaskedMessageRefreshService? maskedMessageRefreshService,
    ImLocalDatabaseService? localDatabaseService,
    ImSensitiveTipPersistenceService? sensitiveTipPersistenceService,
    ImCommandEffectCoordinator? commandEffectCoordinator,
    AttachmentUploadPipeline? attachmentUploadPipeline,
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
    _connectionService =
        connectionService ??
        ImConnectionService(
          sdk: const WkImSdkConnectionPort(),
          realtimeRuntime: const SkeletonImRealtimeRuntimePort(),
          routeResolver: _resolveConnectAddr,
          listenerKey: _connectionListenerKey,
        );
    _notificationBridge =
        notificationBridge ?? ImNotificationBridge.platformDefaults();
    _wordSyncStore =
        wordSyncStore ?? syncOrchestrator?.wordStore ?? WkImWordSyncStore();
    _wordRuntimeFilterService =
        wordRuntimeFilterService ??
        ImWordRuntimeFilterService(wordStore: _wordSyncStore);
    _localDatabaseService =
        localDatabaseService ??
        ImLocalDatabaseService(
          usesLocalPersistence: () => _usesLocalPersistence,
        );
    _maskedMessageRefreshService =
        maskedMessageRefreshService ??
        ImMaskedMessageRefreshService(
          wordRuntimeFilterService: _wordRuntimeFilterService,
          ensureDatabaseReady: _ensureDatabaseReady,
        );
    _sensitiveTipPersistenceService =
        sensitiveTipPersistenceService ??
        ImSensitiveTipPersistenceService(
          ensureDatabaseReady: _ensureDatabaseReady,
        );
    _syncOrchestrator =
        syncOrchestrator ??
        ImSyncOrchestrator(
          syncApi: IMSyncApi.instance,
          messageApi: MessageApi.instance,
          reminderApi: ReminderApi.instance,
          conversationDraftApi: ConversationDraftApi.instance,
          wordStore: _wordSyncStore,
        );
    _attachmentUploadPipeline =
        attachmentUploadPipeline ??
        AttachmentUploadPipeline(fileApi: FileApi.instance);
    _commandEffectCoordinator =
        commandEffectCoordinator ??
        ImCommandEffectCoordinator(
          invalidateProvider: _invalidateProvider,
          currentUidLoader: () =>
              state.uid ?? StorageUtils.getUid()?.trim() ?? '',
          channelLookup: (channelId, channelType) =>
              WKIM.shared.channelManager.getChannel(channelId, channelType),
          handleConversationActivity:
              ConversationActivityRegistry.instance.handleCommand,
          syncConversationExtras: _syncOrchestrator.syncConversationExtras,
          syncReminders: _syncOrchestrator.syncReminders,
          syncMessageExtras: _syncMessageExtras,
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
  late final RealtimeRolloutTelemetry _realtimeRolloutTelemetry;
  late final SessionRuntime _sessionRuntime;
  late final ImConnectionService _connectionService;
  late final ImNotificationBridge _notificationBridge;
  late final ImSyncOrchestrator _syncOrchestrator;
  late final ImWordSyncStore _wordSyncStore;
  late final ImWordRuntimeFilterService _wordRuntimeFilterService;
  late final ImLocalDatabaseService _localDatabaseService;
  late final ImMaskedMessageRefreshService _maskedMessageRefreshService;
  late final ImSensitiveTipPersistenceService _sensitiveTipPersistenceService;
  final bool _ownsRealtimeRolloutTelemetry;
  final void Function(ProviderOrFamily provider)? _invalidateProvider;
  final T Function<T>(ProviderListenable<T> provider)? _readProvider;
  late final AttachmentUploadPipeline _attachmentUploadPipeline;
  late final ImCommandEffectCoordinator _commandEffectCoordinator;

  void registerVipExpiredHandler({
    required String key,
    required void Function() handler,
  }) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    _commandEffectCoordinator.registerVipExpiredHandler(
      key: normalizedKey,
      handler: handler,
    );
  }

  void unregisterVipExpiredHandler(String key) {
    final normalizedKey = key.trim();
    if (normalizedKey.isEmpty) {
      return;
    }
    _commandEffectCoordinator.unregisterVipExpiredHandler(normalizedKey);
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

      final setupOk = await _connectionService.setupSdk(
        credentials: ImConnectionCredentials(
          uid: credentials.uid,
          apiToken: credentials.apiToken,
          imToken: credentials.imToken,
          deviceSessionId: credentials.deviceSessionId,
        ),
        fallbackAddr: IMConfig.connectAddr,
        protoVersion: IMConfig.protoVersion,
        deviceFlag: IMConfig.currentDeviceFlag,
        debug: kDebugMode,
        onRouteResolveError: (Object error, StackTrace stackTrace) {
          debugPrint('IM route resolve failed: $error');
          debugPrint('$stackTrace');
        },
      );
      if (!setupOk) {
        throw StateError('WKIM.setup returned false.');
      }

      if (_usesLocalPersistence) {
        final dbReady = await _ensureDatabaseReady();
        if (!dbReady) {
          throw StateError('IM database schema is not ready.');
        }
        await _wordRuntimeFilterService.loadStoredWordCaches();
      } else {
        _wordRuntimeFilterService.loadSensitiveWordsSnapshot();
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

      _connectionService.connect();

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
    unawaited(_connectionService.disconnect(isLogout: isLogout));
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

    _connectionService.bindConnectionStatusListener(
      onStatus: _handleConnectionStatus,
    );
    WKIM.shared.cmdManager.removeCmdListener(_cmdListenerKey);
    WKIM.shared.messageManager.removeNewMsgListener(_newMsgListenerKey);

    WKIM.shared.conversationManager.addOnSyncConversationListener((
      lastMsgSeqs,
      msgCount,
      version,
      back,
    ) async {
      try {
        final deviceUuid = await _ensureDeviceUuid();
        final result = await _syncOrchestrator.syncConversation(
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
          _syncOrchestrator.acknowledgeConversationSync(
            cmdVersion: result.cmdVersion,
            deviceUuid: deviceUuid,
          ),
        );
        unawaited(_syncOrchestrator.handleConversationSyncCompleted());
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
        final result = await _syncOrchestrator.syncChannelMessages(
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
          _syncOrchestrator.acknowledgeConversationSync(
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
      _attachmentUploadPipeline
          .uploadMessageAttachments(wkMsg)
          .then(
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

  void _handleConnectionStatus(int status, int? reasonCode, String? _) {
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
      final read = _readProvider;
      if (read != null) {
        unawaited(
          MessageDeliveryReplayCoordinator(
            read(messageDeliveryServiceProvider),
          ).replayForConnectionStatus(status),
        );
      }
      unawaited(
        _syncOrchestrator.handleSyncCompleted(
          refreshMaskedMessagesAfterProhibitWordSync:
              _maskedMessageRefreshService.refreshAfterProhibitWordSync,
        ),
      );
      _completeInit(true);
    } else if (status == WKConnectStatus.kicked) {
      _completeInit(false);
    }
  }

  void _handleCmd(WKCMD cmd) {
    _commandEffectCoordinator.handleCommand(cmd);
  }

  Future<void> _syncMessageExtras({
    required String channelId,
    required int channelType,
    String? reason,
  }) async {
    await _syncOrchestrator.syncMessageExtras(
      channelId: channelId,
      channelType: channelType,
      reason: reason,
      deviceUuidLoader: _ensureDeviceUuid,
      publishRealtimeMessageExtraRefresh: _publishRealtimeMessageExtraRefresh,
    );
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
        unawaited(
          _sensitiveTipPersistenceService.insertSensitiveWordTipMessage(tip),
        );
      }
      _notificationBridge.scheduleMessageAlert(
        message,
        currentUid: currentUid,
        lifecycleState: _appLifecycleState,
      );
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
    return _localDatabaseService.ensureReady();
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

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  String? _resolveConnectionError(int status, int? reasonCode) {
    return ImConnectionService.resolveConnectionError(status, reasonCode);
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
    unawaited(_connectionService.disconnect());
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
    return ImConnectionService.shouldKeepConnectionInBackground(
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
    return _syncOrchestrator.resolveOfflineCommandAckSequence(messages);
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
    _connectionService.unbindConnectionStatusListener();
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
    unawaited(_connectionService.disconnect());
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
    _connectionService.connect();
  }

  @visibleForTesting
  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) async {
    await _syncOrchestrator.applySensitiveWordsSync(snapshot);
  }

  @visibleForTesting
  WKMsg? buildSensitiveWordTipMessageIfNeeded(WKMsg message) {
    return _wordRuntimeFilterService.buildSensitiveWordTipMessageIfNeeded(
      message,
      currentUid: StorageUtils.getUid()?.trim() ?? state.uid ?? '',
    );
  }

  @visibleForTesting
  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) async {
    await _syncOrchestrator.applyProhibitWordsSync(words);
  }

  bool get _usesLocalPersistence => shouldUseImLocalPersistence(
    isWeb: kIsWeb,
    sdkAppMode: WKIM.shared.isApp(),
  );

  @visibleForTesting
  bool applyProhibitWordsToMessage(WKMsg message) {
    return _wordRuntimeFilterService.applyProhibitWordsToMessage(message);
  }
}
