import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wukongimfluttersdk/entity/channel.dart';
import 'package:wukongimfluttersdk/entity/conversation.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../models/chat_session.dart';
import '../../core/repositories/message_repository.dart';
import '../../core/utils/storage_utils.dart';
import '../repositories/repository_providers.dart';
import '../repositories/wk_message_repository.dart';
import 'chat_history_gateway.dart';
import '../../modules/chat/chat_composer_controller.dart';
import '../../modules/chat/chat_message_mapper.dart';
import '../../modules/settings/chat_history_reset_service.dart';
import '../../modules/chat/chat_viewport_controller.dart';
import '../../modules/chat/conversation_read_controller.dart';
import '../../modules/conversation/chat_timeline_controller.dart';
import '../../modules/conversation/conversation_projection.dart';
import '../../modules/conversation/conversation_projection_repository.dart';
import '../../modules/conversation/conversation_projection_reducer.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry.dart';
import '../../realtime/telemetry/realtime_rollout_telemetry_provider.dart';
import '../../service/api/im_sync_api.dart';
import '../../service/api/message_api.dart';
import '../../wukong_base/msg/draft_manager.dart';

export '../../modules/conversation/conversation_projection.dart'
    show ConversationPatch;

typedef ConversationListLoader = Future<List<WKUIConversationMsg>> Function();
typedef ConversationDeleteAction =
    Future<void> Function(String channelId, int channelType);
typedef ConversationDraftDeleteAction =
    Future<void> Function(String channelId, int channelType);

final Expando<WKMsg> _conversationLastMessageCache = Expando<WKMsg>(
  'conversationLastMessageCache',
);
const String _deletedConversationTombstonesStoragePrefix =
    'conversation_deleted_tombstones';

final conversationProjectionRepositoryProvider =
    Provider<ConversationProjectionRepository>((ref) {
      return ConversationProjectionRepository(
        const ConversationProjectionReducer(),
      );
    });

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, List<WKUIConversationMsg>>(
      (ref) => ConversationNotifier(
        ref: ref,
        telemetry: ref.watch(conversationPatchTelemetryProvider),
      ),
    );

class ConversationNotifier extends StateNotifier<List<WKUIConversationMsg>> {
  ConversationNotifier({
    Ref? ref,
    ConversationProjectionRepository? projectionRepository,
    ConversationPatchTelemetry? telemetry,
    ConversationListLoader? conversationLoader,
    ConversationDeleteAction? deleteConversationAction,
    ConversationDraftDeleteAction? removeDraftAction,
    bool attachSdkListeners = true,
    bool loadInitialConversations = true,
  }) : _projectionRepository =
           projectionRepository ??
           ref?.read(conversationProjectionRepositoryProvider) ??
           ConversationProjectionRepository(
             const ConversationProjectionReducer(),
           ),
       _telemetry = telemetry,
       _conversationLoader = conversationLoader ?? loadDefaultConversations,
       _deleteConversationAction =
           deleteConversationAction ?? _deleteConversationFromSdk,
       _removeDraftAction = removeDraftAction ?? _removeDraftFromStore,
       _attachSdkListeners = attachSdkListeners,
       _deletedConversationTombstones =
           _loadPersistedDeletedConversationTombstones(),
       super(const <WKUIConversationMsg>[]) {
    if (_attachSdkListeners) {
      _setupListeners();
    }
    if (loadInitialConversations) {
      unawaited(_loadConversations());
    }
  }

  factory ConversationNotifier.forTest(
    List<WKUIConversationMsg> seed, {
    ConversationListLoader? conversationLoader,
    ConversationDeleteAction? deleteConversationAction,
    ConversationDraftDeleteAction? removeDraftAction,
  }) {
    final notifier = ConversationNotifier(
      attachSdkListeners: false,
      loadInitialConversations: false,
      conversationLoader: conversationLoader,
      deleteConversationAction: deleteConversationAction,
      removeDraftAction: removeDraftAction,
      projectionRepository: ConversationProjectionRepository(
        const ConversationProjectionReducer(),
      ),
    );
    notifier._replaceState(seed);
    return notifier;
  }

  final ConversationProjectionRepository _projectionRepository;
  final ConversationPatchTelemetry? _telemetry;
  final ConversationListLoader _conversationLoader;
  final ConversationDeleteAction _deleteConversationAction;
  final ConversationDraftDeleteAction _removeDraftAction;
  final bool _attachSdkListeners;
  final Map<String, _ConversationDeletionTombstone>
  _deletedConversationTombstones;

  static Future<void> _deleteConversationFromSdk(
    String channelId,
    int channelType,
  ) {
    return WKIM.shared.conversationManager.deleteMsg(channelId, channelType);
  }

  static Future<void> _removeDraftFromStore(String channelId, int channelType) {
    return DraftManager().removeDraft(channelId, channelType);
  }

  static Map<String, _ConversationDeletionTombstone>
  _loadPersistedDeletedConversationTombstones() {
    final storageKey = _deletedConversationTombstonesStorageKey();
    if (storageKey.isEmpty) {
      return <String, _ConversationDeletionTombstone>{};
    }
    final rows = StorageUtils.getStringList(storageKey) ?? const <String>[];
    final tombstones = <String, _ConversationDeletionTombstone>{};
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row);
        if (decoded is! Map) {
          continue;
        }
        final item = Map<String, dynamic>.from(decoded);
        final channelId = (item['channel_id'] ?? '').toString().trim();
        final channelType = _readTombstoneInt(item['channel_type']);
        if (channelId.isEmpty || channelType <= 0) {
          continue;
        }
        tombstones['$channelType:$channelId'] = _ConversationDeletionTombstone(
          lastMsgSeq: _readTombstoneInt(item['last_msg_seq']),
          lastMsgTimestamp: _readTombstoneInt(item['last_msg_timestamp']),
        );
      } catch (_) {
        continue;
      }
    }
    return tombstones;
  }

  static int _readTombstoneInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static String _deletedConversationTombstonesStorageKey() {
    final uid = StorageUtils.getUid()?.trim() ?? '';
    if (uid.isEmpty) {
      return '';
    }
    return '${_deletedConversationTombstonesStoragePrefix}_$uid';
  }

  Future<void> _persistDeletedConversationTombstones() async {
    final storageKey = _deletedConversationTombstonesStorageKey();
    if (storageKey.isEmpty) {
      return;
    }
    if (_deletedConversationTombstones.isEmpty) {
      await StorageUtils.remove(storageKey);
      return;
    }

    final rows = <String>[];
    for (final entry in _deletedConversationTombstones.entries) {
      final separatorIndex = entry.key.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }
      final channelType = int.tryParse(entry.key.substring(0, separatorIndex));
      final channelId = entry.key.substring(separatorIndex + 1).trim();
      if (channelType == null || channelId.isEmpty) {
        continue;
      }
      rows.add(
        jsonEncode(<String, dynamic>{
          'channel_id': channelId,
          'channel_type': channelType,
          'last_msg_seq': entry.value.lastMsgSeq,
          'last_msg_timestamp': entry.value.lastMsgTimestamp,
        }),
      );
    }

    if (rows.isEmpty) {
      await StorageUtils.remove(storageKey);
      return;
    }
    await StorageUtils.setStringList(storageKey, rows);
  }

  void _setupListeners() {
    WKIM.shared.conversationManager.addOnRefreshMsgListListener('provider', (
      msgs,
    ) {
      _applyRefreshPatches(msgs);
    });
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await _conversationLoader();
      if (!mounted) {
        return;
      }
      _replaceState(conversations);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _replaceState(const <WKUIConversationMsg>[]);
    }
  }

  void _replaceState(List<WKUIConversationMsg> conversations) {
    final visibleConversations = _filterDeletedConversations(conversations);
    final previousProjectionByKey = <String, ConversationProjection>{
      for (final item in _projectionRepository.snapshot)
        _conversationProjectionKey(item.channelId, item.channelType): item,
    };
    final projectionSeed = visibleConversations
        .map(
          (item) => _projectionFromConversation(
            item,
            previous:
                previousProjectionByKey[_conversationProjectionKey(
                  item.channelID,
                  item.channelType,
                )],
          ),
        )
        .toList(growable: false);
    _projectionRepository.seed(projectionSeed);
    state = _sortConversationsByProjection(visibleConversations);
  }

  void _applyRefreshPatches(List<WKUIConversationMsg> refreshedConversations) {
    if (!mounted || refreshedConversations.isEmpty) {
      return;
    }

    final next = List<WKUIConversationMsg>.from(state, growable: true);
    for (final refreshed in refreshedConversations) {
      final channelId = refreshed.channelID.trim();
      if (channelId.isEmpty) {
        continue;
      }
      final channelType = refreshed.channelType;
      final index = _findConversationIndex(next, channelId, channelType);
      if (refreshed.isDeleted == 1) {
        if (index != -1) {
          next.removeAt(index);
        }
        continue;
      }
      if (_shouldSuppressConversationUpdate(
        channelId,
        channelType,
        lastMsgSeq: refreshed.lastMsgSeq,
        lastMsgTimestamp: refreshed.lastMsgTimestamp,
      )) {
        if (index != -1) {
          next.removeAt(index);
        }
        continue;
      }

      if (index == -1) {
        next.add(refreshed);
      } else {
        final preserved = _cloneConversation(refreshed);
        final existing = next[index];
        if (preserved.clientMsgNo.trim().isEmpty &&
            existing.clientMsgNo.trim().isNotEmpty) {
          preserved.clientMsgNo = existing.clientMsgNo;
        }
        next[index] = preserved;
      }
    }

    _replaceState(next);
  }

  void refresh() {
    unawaited(refreshNow());
  }

  Future<void> refreshNow() => _loadConversations();

  Future<void> deleteConversation(String channelId, int channelType) async {
    final existing = _findConversation(state, channelId, channelType);
    await _deleteConversationAction(channelId, channelType);
    await _removeDraftAction(channelId, channelType);
    _rememberDeletedConversation(
      channelId,
      channelType,
      conversation: existing,
    );
    await _persistDeletedConversationTombstones();
    _replaceState(
      state
          .where(
            (item) =>
                !(item.channelID == channelId &&
                    item.channelType == channelType),
          )
          .toList(growable: false),
    );
  }

  Future<void> deleteConversations(List<ChatSession> sessions) async {
    final nextState = [...state];
    for (final session in sessions) {
      final existing = _findConversation(
        nextState,
        session.channelId,
        session.channelType,
      );
      await _deleteConversationAction(session.channelId, session.channelType);
      await _removeDraftAction(session.channelId, session.channelType);
      _rememberDeletedConversation(
        session.channelId,
        session.channelType,
        conversation: existing,
      );
      nextState.removeWhere(
        (item) =>
            item.channelID == session.channelId &&
            item.channelType == session.channelType,
      );
    }
    await _persistDeletedConversationTombstones();
    _replaceState(nextState);
  }

  Future<void> clearAllConversations() async {
    final sessions = state
        .map(
          (item) => ChatSession(
            channelId: item.channelID,
            channelType: item.channelType,
          ),
        )
        .toList();
    if (sessions.isEmpty) {
      return;
    }
    await deleteConversations(sessions);
    await DraftManager().clearAllDrafts();
  }

  Future<void> clearAllChatHistory({ChatHistoryResetService? service}) async {
    final resetService =
        service ??
        ChatHistoryResetService(
          loadTargets: () async {
            final conversations = await WKIM.shared.conversationManager
                .getAll();
            return conversations
                .map(
                  (item) => ChatHistoryTarget(
                    channelId: item.channelID,
                    channelType: item.channelType,
                  ),
                )
                .toList();
          },
          clearChannelMessages: (channelId, channelType) async {
            await WKIM.shared.messageManager.clearWithChannel(
              channelId,
              channelType,
            );
          },
          clearAllConversations: () async {
            await WKIM.shared.conversationManager.clearAll();
          },
        );
    await resetService.clearAll();
    await DraftManager().clearAllDrafts();
    _replaceState(const <WKUIConversationMsg>[]);
  }

  Future<void> setMute(String channelId, int channelType, bool mute) async {
    final existingChannel = await WKIM.shared.channelManager.getChannel(
      channelId,
      channelType,
    );
    final channel = existingChannel ?? WKChannel(channelId, channelType);
    channel.mute = mute ? 1 : 0;
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
    applyPatch(
      ConversationPatch(
        channelId: channelId,
        channelType: channelType,
        isMuted: mute,
      ),
    );
  }

  Future<void> setTop(String channelId, int channelType, bool top) async {
    final existingChannel = await WKIM.shared.channelManager.getChannel(
      channelId,
      channelType,
    );
    final channel = existingChannel ?? WKChannel(channelId, channelType);
    channel.top = top ? 1 : 0;
    WKIM.shared.channelManager.addOrUpdateChannel(channel);
    applyPatch(
      ConversationPatch(
        channelId: channelId,
        channelType: channelType,
        isTop: top,
      ),
    );
  }

  Future<void> clearRedDot(String channelId, int channelType) async {
    final unread = _currentUnreadCount(channelId, channelType);
    Object? remoteError;
    StackTrace? remoteStackTrace;

    try {
      await MessageApi.instance.clearUnread(
        channelId: channelId,
        channelType: channelType,
        unread: unread,
      );
    } catch (error, stackTrace) {
      remoteError = error;
      remoteStackTrace = stackTrace;
      debugPrint('Clear unread failed: $error');
      debugPrint('$stackTrace');
    }

    await WKIM.shared.conversationManager.updateRedDot(
      channelId,
      channelType,
      0,
    );
    _applyUnreadPatch(
      channelId: channelId,
      channelType: channelType,
      unread: 0,
    );

    if (remoteError != null) {
      Error.throwWithStackTrace(remoteError, remoteStackTrace!);
    }
  }

  Future<void> markConversationRead(
    String channelId,
    int channelType, {
    required List<String> messageIds,
  }) async {
    final unread = _currentUnreadCount(channelId, channelType);
    Object? remoteError;
    StackTrace? remoteStackTrace;

    try {
      if (unread > 0) {
        await MessageApi.instance.clearUnread(
          channelId: channelId,
          channelType: channelType,
          unread: unread,
        );
      }
      await MessageApi.instance.markAsRead(
        channelId: channelId,
        channelType: channelType,
        messageIds: messageIds,
      );
    } catch (error, stackTrace) {
      remoteError = error;
      remoteStackTrace = stackTrace;
      debugPrint('Mark conversation read failed: $error');
      debugPrint('$stackTrace');
    }

    await WKIM.shared.conversationManager.updateRedDot(
      channelId,
      channelType,
      0,
    );
    _applyUnreadPatch(
      channelId: channelId,
      channelType: channelType,
      unread: 0,
    );

    if (remoteError != null) {
      Error.throwWithStackTrace(remoteError, remoteStackTrace!);
    }
  }

  int _currentUnreadCount(String channelId, int channelType) {
    for (final item in state) {
      if (item.channelID == channelId && item.channelType == channelType) {
        return item.unreadCount;
      }
    }
    return 0;
  }

  void applyRealtimeMessage(WKMsg message, {String? currentUid}) {
    if (!mounted || !shouldDisplayConversationMessage(message)) {
      return;
    }

    final channelId = message.channelID.trim();
    if (channelId.isEmpty) {
      return;
    }
    final timestamp = message.timestamp > 0
        ? message.timestamp
        : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (_shouldSuppressConversationUpdate(
      channelId,
      message.channelType,
      lastMsgSeq: message.messageSeq,
      lastMsgTimestamp: timestamp,
    )) {
      return;
    }

    final next = List<WKUIConversationMsg>.from(state, growable: true);
    final index = _findConversationIndex(next, channelId, message.channelType);
    final existing = index == -1 ? null : next[index];
    final currentUidValue = currentUid?.trim() ?? _resolveActiveUid();
    final isIncoming =
        message.fromUID.trim().isEmpty ||
        message.fromUID.trim() != currentUidValue;
    final shouldIncrementUnread = message.header.redDot && isIncoming;

    final updated = existing == null
        ? WKUIConversationMsg()
        : _cloneConversation(existing);
    updated
      ..channelID = channelId
      ..channelType = message.channelType
      ..clientMsgNo = message.clientMsgNO
      ..lastMsgSeq = message.messageSeq
      ..lastMsgTimestamp = timestamp
      ..unreadCount =
          (existing?.unreadCount ?? 0) + (shouldIncrementUnread ? 1 : 0);
    _cacheConversationLastMessage(updated, message);

    if (index == -1) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    _replaceState(next);
  }

  void applyLocalMessageRefresh(WKMsg message) {
    if (!mounted || !shouldDisplayConversationMessage(message)) {
      return;
    }

    final channelId = message.channelID.trim();
    if (channelId.isEmpty) {
      return;
    }

    final next = List<WKUIConversationMsg>.from(state, growable: true);
    final index = _findConversationIndex(next, channelId, message.channelType);
    if (index == -1) {
      return;
    }

    final current = next[index];
    if (!_conversationReferencesMessage(current, message)) {
      return;
    }

    final updated = _cloneConversation(current);
    final clientMsgNo = message.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty) {
      updated.clientMsgNo = clientMsgNo;
    }
    if (message.messageSeq > 0) {
      updated.lastMsgSeq = message.messageSeq;
    }
    if (message.timestamp > 0) {
      updated.lastMsgTimestamp = message.timestamp;
    }
    _cacheConversationLastMessage(updated, message);
    next[index] = updated;
    _replaceState(next);
  }

  @override
  void dispose() {
    if (_attachSdkListeners) {
      WKIM.shared.conversationManager.removeOnRefreshMsgListListener(
        'provider',
      );
    }
    super.dispose();
  }

  void applyPatch(ConversationPatch patch) {
    final stopwatch = Stopwatch()..start();
    try {
      if (_shouldSuppressConversationPatch(patch)) {
        return;
      }
      _projectionRepository.apply(patch);
      final next = List<WKUIConversationMsg>.from(state, growable: true);
      final index = _findConversationIndex(
        next,
        patch.channelId,
        patch.channelType,
      );
      if (index == -1) {
        if (!patch.canBootstrapProjection) {
          return;
        }
        next.add(
          WKUIConversationMsg()
            ..channelID = patch.channelId
            ..channelType = patch.channelType
            ..unreadCount = patch.unreadCount ?? 0
            ..lastMsgTimestamp = patch.sortTimestamp ?? 0,
        );
        state = _sortConversationsByProjection(next);
        return;
      }

      final current = next[index];
      final updated = _cloneConversation(current)
        ..unreadCount = patch.unreadCount ?? current.unreadCount
        ..lastMsgTimestamp = patch.sortTimestamp ?? current.lastMsgTimestamp;
      next[index] = updated;
      state = _sortConversationsByProjection(next);
    } finally {
      stopwatch.stop();
      _telemetry?.recordConversationPatchApply(stopwatch.elapsed);
    }
  }

  void _applyUnreadPatch({
    required String channelId,
    required int channelType,
    required int unread,
  }) {
    final existing = _findConversation(state, channelId, channelType);
    applyPatch(
      ConversationPatch(
        channelId: channelId,
        channelType: channelType,
        unreadCount: unread,
        sortTimestamp: existing?.lastMsgTimestamp,
        lastMessageDigest: existing == null
            ? null
            : _projectionDigestFromConversation(existing),
      ),
    );
  }

  WKUIConversationMsg? _findConversation(
    List<WKUIConversationMsg> conversations,
    String channelId,
    int channelType,
  ) {
    final index = _findConversationIndex(conversations, channelId, channelType);
    if (index == -1) {
      return null;
    }
    return conversations[index];
  }

  bool _conversationReferencesMessage(
    WKUIConversationMsg conversation,
    WKMsg message,
  ) {
    final clientMsgNo = message.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty && conversation.clientMsgNo == clientMsgNo) {
      return true;
    }

    final cachedMessage = _conversationLastMessageCache[conversation];
    if (cachedMessage != null &&
        ChatMessageMatchIndex(<WKMsg>[cachedMessage]).find(message) == 0) {
      return true;
    }

    return message.messageSeq > 0 &&
        conversation.lastMsgSeq == message.messageSeq;
  }

  List<WKUIConversationMsg> _filterDeletedConversations(
    List<WKUIConversationMsg> conversations,
  ) {
    if (_deletedConversationTombstones.isEmpty) {
      return conversations;
    }
    return conversations
        .where(
          (conversation) => !_shouldSuppressConversationUpdate(
            conversation.channelID,
            conversation.channelType,
            lastMsgSeq: conversation.lastMsgSeq,
            lastMsgTimestamp: conversation.lastMsgTimestamp,
          ),
        )
        .toList(growable: false);
  }

  void _rememberDeletedConversation(
    String channelId,
    int channelType, {
    WKUIConversationMsg? conversation,
  }) {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return;
    }
    _deletedConversationTombstones[_conversationProjectionKey(
      normalizedChannelId,
      channelType,
    )] = _ConversationDeletionTombstone(
      lastMsgSeq: conversation?.lastMsgSeq ?? 0,
      lastMsgTimestamp: conversation?.lastMsgTimestamp ?? 0,
    );
  }

  bool _shouldSuppressConversationPatch(ConversationPatch patch) {
    final key = _conversationProjectionKey(
      patch.channelId.trim(),
      patch.channelType,
    );
    if (!_deletedConversationTombstones.containsKey(key)) {
      return false;
    }
    if (!patch.canBootstrapProjection) {
      return true;
    }
    return _shouldSuppressConversationUpdate(
      patch.channelId,
      patch.channelType,
      lastMsgSeq: 0,
      lastMsgTimestamp: patch.sortTimestamp ?? 0,
    );
  }

  bool _shouldSuppressConversationUpdate(
    String channelId,
    int channelType, {
    required int lastMsgSeq,
    required int lastMsgTimestamp,
  }) {
    final normalizedChannelId = channelId.trim();
    if (normalizedChannelId.isEmpty) {
      return false;
    }
    final key = _conversationProjectionKey(normalizedChannelId, channelType);
    final tombstone = _deletedConversationTombstones[key];
    if (tombstone == null) {
      return false;
    }
    if (_isNewerThanDeletedConversation(
      tombstone,
      lastMsgSeq: lastMsgSeq,
      lastMsgTimestamp: lastMsgTimestamp,
    )) {
      _deletedConversationTombstones.remove(key);
      unawaited(_persistDeletedConversationTombstones());
      return false;
    }
    return true;
  }

  bool _isNewerThanDeletedConversation(
    _ConversationDeletionTombstone tombstone, {
    required int lastMsgSeq,
    required int lastMsgTimestamp,
  }) {
    if (tombstone.lastMsgSeq > 0 && lastMsgSeq > 0) {
      return lastMsgSeq > tombstone.lastMsgSeq;
    }
    if (tombstone.lastMsgTimestamp > 0 && lastMsgTimestamp > 0) {
      return lastMsgTimestamp > tombstone.lastMsgTimestamp;
    }
    return false;
  }

  int _findConversationIndex(
    List<WKUIConversationMsg> conversations,
    String channelId,
    int channelType,
  ) {
    for (var index = 0; index < conversations.length; index++) {
      final item = conversations[index];
      if (item.channelID == channelId && item.channelType == channelType) {
        return index;
      }
    }
    return -1;
  }

  List<WKUIConversationMsg> _sortConversationsByProjection(
    List<WKUIConversationMsg> conversations,
  ) {
    final next = List<WKUIConversationMsg>.from(conversations, growable: true);
    final projectionOrder = <String, int>{};
    final snapshot = _projectionRepository.snapshot;
    for (var index = 0; index < snapshot.length; index++) {
      final item = snapshot[index];
      projectionOrder['${item.channelType}:${item.channelId}'] = index;
    }

    next.sort((left, right) {
      final leftOrder =
          projectionOrder['${left.channelType}:${left.channelID}'] ?? 1 << 30;
      final rightOrder =
          projectionOrder['${right.channelType}:${right.channelID}'] ?? 1 << 30;
      if (leftOrder != rightOrder) {
        return leftOrder.compareTo(rightOrder);
      }
      final timestampCompare = right.lastMsgTimestamp.compareTo(
        left.lastMsgTimestamp,
      );
      if (timestampCompare != 0) {
        return timestampCompare;
      }
      final channelTypeCompare = left.channelType.compareTo(right.channelType);
      if (channelTypeCompare != 0) {
        return channelTypeCompare;
      }
      return left.channelID.compareTo(right.channelID);
    });
    return List<WKUIConversationMsg>.from(next, growable: false);
  }

  ConversationProjection _projectionFromConversation(
    WKUIConversationMsg conversation, {
    ConversationProjection? previous,
  }) {
    return ConversationProjection(
      channelId: conversation.channelID,
      channelType: conversation.channelType,
      unreadCount: conversation.unreadCount,
      sortTimestamp: conversation.lastMsgTimestamp,
      lastMessageDigest: _projectionDigestFromConversation(conversation),
      isTop: previous?.isTop ?? false,
      isMuted: previous?.isMuted ?? false,
    );
  }

  String _projectionDigestFromConversation(WKUIConversationMsg conversation) {
    final digest = conversation.clientMsgNo.trim();
    if (digest.isNotEmpty) {
      return digest;
    }
    return '${conversation.lastMsgSeq}:${conversation.lastMsgTimestamp}';
  }

  String _conversationProjectionKey(String channelId, int channelType) {
    return '$channelType:$channelId';
  }

  @visibleForTesting
  void applyRefreshForTest(List<WKUIConversationMsg> refreshedConversations) {
    _applyRefreshPatches(refreshedConversations);
  }

  @visibleForTesting
  List<String> projectionKeysForTest() {
    return _projectionRepository.snapshot
        .map(
          (item) =>
              _conversationProjectionKey(item.channelId, item.channelType),
        )
        .toList(growable: false);
  }

  WKUIConversationMsg _cloneConversation(WKUIConversationMsg source) {
    final clone = WKUIConversationMsg()
      ..lastMsgSeq = source.lastMsgSeq
      ..clientMsgNo = source.clientMsgNo
      ..channelID = source.channelID
      ..channelType = source.channelType
      ..lastMsgTimestamp = source.lastMsgTimestamp
      ..unreadCount = source.unreadCount
      ..isDeleted = source.isDeleted
      ..localExtraMap = source.localExtraMap
      ..parentChannelID = source.parentChannelID
      ..parentChannelType = source.parentChannelType;
    clone.setRemoteMsgExtra(source.getRemoteMsgExtra());
    final cachedMessage = _conversationLastMessageCache[source];
    if (cachedMessage != null) {
      _cacheConversationLastMessage(clone, cachedMessage);
    }
    return clone;
  }
}

class _ConversationDeletionTombstone {
  const _ConversationDeletionTombstone({
    required this.lastMsgSeq,
    required this.lastMsgTimestamp,
  });

  final int lastMsgSeq;
  final int lastMsgTimestamp;
}

Future<List<WKUIConversationMsg>> loadDefaultConversations() async {
  if (kIsWeb || !WKIM.shared.isApp()) {
    if (!hasAuthenticatedConversationSyncSession(
      uid: StorageUtils.getUid(),
      token: StorageUtils.getToken(),
    )) {
      return const <WKUIConversationMsg>[];
    }
    try {
      final result = await IMSyncApi.instance.syncConversation(
        version: 0,
        lastMsgSeqs: '',
        msgCount: 200,
        deviceUuid: StorageUtils.getDeviceId()?.trim() ?? '',
      );
      return mapSyncConversationsToUiConversations(
        result.conversations ?? const <WKSyncConvMsg>[],
      );
    } catch (_) {
      // Fall back to the SDK cache for native tests or partially initialized
      // sessions. On Web this normally returns an empty list because sqflite is
      // disabled, but the fallback is harmless and keeps startup resilient.
    }
    return const <WKUIConversationMsg>[];
  }
  return WKIM.shared.conversationManager.getAll();
}

@visibleForTesting
bool hasAuthenticatedConversationSyncSession({String? uid, String? token}) {
  return (uid?.trim() ?? '').isNotEmpty && (token?.trim() ?? '').isNotEmpty;
}

@visibleForTesting
List<WKUIConversationMsg> mapSyncConversationsToUiConversations(
  Iterable<WKSyncConvMsg> conversations,
) {
  final uiConversations = <WKUIConversationMsg>[];
  for (final conversation in conversations) {
    final channelId = conversation.channelID.trim();
    if (channelId.isEmpty) {
      continue;
    }
    final recentMessage = _latestRecentMessageForConversation(conversation);
    final fallbackClientMsgNo = recentMessage?.clientMsgNO.trim() ?? '';
    final fallbackMsgSeq = recentMessage?.messageSeq ?? 0;
    final fallbackTimestamp = recentMessage?.timestamp ?? 0;

    final ui = WKUIConversationMsg()
      ..channelID = channelId
      ..channelType = conversation.channelType
      ..clientMsgNo = conversation.lastClientMsgNO.trim().isNotEmpty
          ? conversation.lastClientMsgNO
          : fallbackClientMsgNo
      ..lastMsgSeq = conversation.lastMsgSeq > 0
          ? conversation.lastMsgSeq
          : fallbackMsgSeq
      ..lastMsgTimestamp = conversation.timestamp > 0
          ? conversation.timestamp
          : fallbackTimestamp
      ..unreadCount = conversation.unread;

    if (recentMessage != null) {
      _cacheConversationLastMessage(ui, recentMessage);
    }
    uiConversations.add(ui);
  }
  return uiConversations;
}

void _cacheConversationLastMessage(
  WKUIConversationMsg conversation,
  WKMsg msg,
) {
  conversation.setWkMsg(msg);
  _conversationLastMessageCache[conversation] = msg;
}

WKMsg? _latestRecentMessageForConversation(WKSyncConvMsg conversation) {
  final recents = conversation.recents ?? const <WKSyncMsg>[];
  WKMsg? latest;
  for (final recent in recents) {
    final message = recent.getWKMsg()
      ..channelID = conversation.channelID
      ..channelType = conversation.channelType;
    if (!shouldDisplayConversationMessage(message)) {
      continue;
    }
    if (latest == null ||
        message.messageSeq > latest.messageSeq ||
        (message.messageSeq == latest.messageSeq &&
            message.timestamp > latest.timestamp)) {
      latest = message;
    }
  }
  return latest;
}

String _resolveActiveUid() {
  final storedUid = StorageUtils.getUid()?.trim() ?? '';
  if (storedUid.isNotEmpty) {
    return storedUid;
  }
  return WKIM.shared.options.uid?.trim() ?? '';
}

final messageListProvider =
    StateNotifierProvider.family<MessageListNotifier, List<WKMsg>, ChatSession>(
      (ref, session) => MessageListNotifier(
        session.channelId,
        session.channelType,
        messageRepository: ref.watch(messageRepositoryProvider),
        telemetry: ref.watch(messageQueryTelemetryProvider),
        autoLoad: false,
      ),
    );

final chatViewportProvider = StateNotifierProvider.autoDispose
    .family<ChatTimelineController, ChatViewportState, ChatSession>((
      ref,
      session,
    ) {
      final controller = ChatTimelineController(
        mapper: ChatMessageMapper(),
        currentUid: _resolveActiveUid(),
        loadOlderAction: () =>
            ref.read(messageListProvider(session).notifier).loadMore(),
      );
      var previousMessages = const <WKMsg>[];

      void syncViewport(List<WKMsg> nextMessages, {required bool initial}) {
        final decision = decideChatTimelineSync(
          previous: previousMessages,
          next: nextMessages,
          initial: initial,
        );
        switch (decision.mode) {
          case ChatTimelineSyncMode.incoming:
            controller.applyIncoming(decision.incoming);
            break;
          case ChatTimelineSyncMode.olderPage:
            controller.appendOlder(decision.olderPage);
            break;
          case ChatTimelineSyncMode.refresh:
            controller.applyRefresh(decision.refreshed!);
            break;
          case ChatTimelineSyncMode.replaceAll:
            controller.replaceAll(nextMessages);
            break;
        }
        previousMessages = List<WKMsg>.from(nextMessages, growable: false);
      }

      syncViewport(ref.read(messageListProvider(session)), initial: true);
      ref.listen<List<WKMsg>>(messageListProvider(session), (previous, next) {
        syncViewport(next, initial: false);
      });
      return controller;
    });

final chatComposerProvider = StateNotifierProvider.autoDispose
    .family<ChatComposerController, ChatComposerState, ChatSession>((
      ref,
      session,
    ) {
      final controller = ChatComposerController(
        channelId: session.channelId,
        channelType: session.channelType,
      );
      unawaited(controller.initialize());
      return controller;
    });

typedef ChatMarkConversationRead =
    Future<void> Function(ChatSession session, List<String> messageIds);

final chatMarkConversationReadProvider = Provider<ChatMarkConversationRead>((
  ref,
) {
  return (session, messageIds) {
    return ref
        .read(conversationProvider.notifier)
        .markConversationRead(
          session.channelId,
          session.channelType,
          messageIds: messageIds,
        );
  };
});

final chatReadControllerProvider = Provider.autoDispose
    .family<ConversationReadController, ChatSession>((ref, session) {
      final controller = ConversationReadController(
        channelId: session.channelId,
        channelType: session.channelType,
        currentUid: _resolveActiveUid(),
        markConversationRead: (messageIds) {
          return ref.read(chatMarkConversationReadProvider)(
            session,
            messageIds,
          );
        },
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

class MessageListNotifier extends StateNotifier<List<WKMsg>> {
  MessageListNotifier(
    this.channelId,
    this.channelType, {
    MessageRepository? messageRepository,
    ChatHistoryGateway? historyGateway,
    MessageQueryTelemetry? telemetry,
    this.autoLoad = true,
  }) : messageRepository =
           messageRepository ??
           WkMessageRepository(
             gateway: historyGateway ?? WkImChatHistoryGateway(),
           ),
       _telemetry = telemetry,
       super([]) {
    if (autoLoad) {
      _ensureListeners();
      unawaited(loadMessages());
    }
  }

  final String channelId;
  final int channelType;
  final MessageRepository messageRepository;
  final MessageQueryTelemetry? _telemetry;
  final bool autoLoad;
  bool _listenersAttached = false;
  int _replaceRequestVersion = 0;
  Future<void>? _loadMoreInFlight;
  int? _exhaustedOlderPageOrderSeq;

  String get _listenerKey => 'msg_list_${channelType}_$channelId';

  void _ensureListeners() {
    if (_listenersAttached) {
      return;
    }
    _listenersAttached = true;
    WKIM.shared.messageManager.addOnNewMsgListener(_listenerKey, (msgs) {
      final filteredMsgs = msgs
          .where(
            (item) =>
                item.channelID == channelId &&
                item.channelType == channelType &&
                shouldDisplayConversationMessage(item),
          )
          .toList();
      if (filteredMsgs.isNotEmpty) {
        state = mergeConversationMessages([...filteredMsgs.reversed, ...state]);
      }
    });

    WKIM.shared.messageManager.addOnRefreshMsgListener(_listenerKey, (msg) {
      if (msg.channelID != channelId || msg.channelType != channelType) {
        return;
      }
      state = refreshConversationMessages(state, msg);
    });
  }

  Future<void> loadMessages() async {
    _ensureListeners();
    await _replaceStateWith(
      () => _trackSqlitePageQuery(
        mode: 'latest_page',
        query: () => messageRepository.loadLatest(
          MessagePageQuery(
            channelId: channelId,
            channelType: channelType,
            limit: 50,
          ),
        ),
      ),
    );
  }

  Future<void> loadMore() async {
    _ensureListeners();
    if (state.isEmpty) {
      return;
    }
    final inFlight = _loadMoreInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final oldestOrderSeq = state.last.orderSeq;
    if (_exhaustedOlderPageOrderSeq == oldestOrderSeq) {
      return;
    }

    final future = () async {
      final requestVersion = _replaceRequestVersion;
      try {
        final msgs = await _trackSqlitePageQuery(
          mode: 'older_page',
          query: () => messageRepository.loadOlder(
            MessagePageQuery(
              channelId: channelId,
              channelType: channelType,
              anchorOrderSeq: oldestOrderSeq,
              limit: 50,
            ),
          ),
        );
        if (requestVersion != _replaceRequestVersion) {
          return;
        }
        if (msgs.isEmpty) {
          _exhaustedOlderPageOrderSeq = oldestOrderSeq;
          return;
        }
        _exhaustedOlderPageOrderSeq = null;
        state = mergeConversationMessages([...state, ...msgs.reversed]);
      } catch (_) {}
    }();
    _loadMoreInFlight = future;
    await future;
    if (identical(_loadMoreInFlight, future)) {
      _loadMoreInFlight = null;
    }
  }

  Future<void> loadAroundOrderSeq(int aroundOrderSeq) async {
    _ensureListeners();
    if (aroundOrderSeq <= 0) {
      await loadMessages();
      return;
    }

    await _replaceStateWith(
      () => _trackSqlitePageQuery(
        mode: 'around_page',
        query: () => messageRepository.loadAround(
          MessagePageQuery(
            channelId: channelId,
            channelType: channelType,
            limit: 50,
            anchorOrderSeq: aroundOrderSeq,
          ),
        ),
      ),
    );
  }

  void applyLocalOutgoingMessage(WKMsg message) {
    applyLocalMessageRefresh(message);
  }

  void applyLocalMessageRefresh(WKMsg message) {
    if (!mounted ||
        message.channelID != channelId ||
        message.channelType != channelType) {
      return;
    }
    state = refreshConversationMessages(state, message);
  }

  Future<void> _replaceStateWith(Future<List<WKMsg>> Function() loader) async {
    final version = ++_replaceRequestVersion;
    try {
      final msgs = await loader();
      if (version != _replaceRequestVersion) {
        return;
      }
      _exhaustedOlderPageOrderSeq = null;
      state = mergeConversationMessages(msgs.reversed);
    } catch (_) {
      if (version != _replaceRequestVersion) {
        return;
      }
      _exhaustedOlderPageOrderSeq = null;
      state = [];
    }
  }

  Future<List<WKMsg>> _trackSqlitePageQuery({
    required String mode,
    required Future<List<WKMsg>> Function() query,
  }) async {
    final telemetry = _telemetry;
    if (telemetry == null) {
      return query();
    }
    final stopwatch = Stopwatch()..start();
    try {
      return await query();
    } finally {
      stopwatch.stop();
      telemetry.recordSqlitePageQuery(stopwatch.elapsed, mode: mode);
    }
  }

  @override
  void dispose() {
    if (_listenersAttached) {
      WKIM.shared.messageManager.removeNewMsgListener(_listenerKey);
      WKIM.shared.messageManager.removeOnRefreshMsgListener(_listenerKey);
    }
    super.dispose();
  }
}

final currentChatProvider = StateProvider<ChatSession?>((ref) => null);

List<WKMsg> mergeConversationMessages(Iterable<WKMsg> messages) {
  final merged = <WKMsg>[];
  final matchIndex = ChatMessageMatchIndex(merged);
  for (final message in messages) {
    if (!shouldDisplayConversationMessage(message)) {
      continue;
    }
    final index = matchIndex.find(message);
    if (index == -1) {
      matchIndex.add(merged.length, message);
      merged.add(message);
      continue;
    }
    final preferred = preferConversationMessage(merged[index], message);
    merged[index] = preferred;
    matchIndex.add(index, preferred);
  }
  return merged;
}

List<WKMsg> refreshConversationMessages(List<WKMsg> current, WKMsg message) {
  final next = current
      .where(shouldDisplayConversationMessage)
      .toList(growable: true);
  final index = ChatMessageMatchIndex(next).find(message);

  if (!shouldDisplayConversationMessage(message)) {
    if (index != -1) {
      next.removeAt(index);
    }
    return mergeConversationMessages(next);
  }

  if (index == -1) {
    next.insert(0, message);
    return mergeConversationMessages(next);
  }

  next[index] = preferConversationMessage(next[index], message);
  return mergeConversationMessages(next);
}

bool shouldDisplayConversationMessage(WKMsg message) {
  return message.isDeleted == 0 &&
      message.contentType != WkMessageContentType.insideMsg;
}

int findConversationMessageIndex(List<WKMsg> messages, WKMsg target) {
  return ChatMessageMatchIndex(messages).find(target);
}

class ChatMessageMatchIndex {
  ChatMessageMatchIndex(Iterable<WKMsg> messages) {
    var index = 0;
    for (final message in messages) {
      add(index, message);
      index += 1;
    }
  }

  final Map<int, int> _clientSeq = <int, int>{};
  final Map<String, int> _clientMsgNo = <String, int>{};
  final Map<String, int> _messageId = <String, int>{};
  final Map<String, int> _messageSeq = <String, int>{};
  final Map<String, int> _orderSeq = <String, int>{};

  int find(WKMsg target) {
    final clientSeq = target.clientSeq;
    if (clientSeq > 0) {
      final index = _clientSeq[clientSeq];
      if (index != null) {
        return index;
      }
    }

    final clientMsgNo = target.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty) {
      final index = _clientMsgNo[clientMsgNo];
      if (index != null) {
        return index;
      }
    }

    final messageId = target.messageID.trim();
    if (messageId.isNotEmpty) {
      final index = _messageId[messageId];
      if (index != null) {
        return index;
      }
    }

    final messageSeq = _conversationScopedSeqKey(
      target.channelID,
      target.channelType,
      target.messageSeq,
    );
    if (messageSeq != null) {
      final index = _messageSeq[messageSeq];
      if (index != null) {
        return index;
      }
    }

    final orderSeq = _conversationScopedSeqKey(
      target.channelID,
      target.channelType,
      target.orderSeq,
    );
    if (orderSeq != null) {
      final index = _orderSeq[orderSeq];
      if (index != null) {
        return index;
      }
    }

    return -1;
  }

  void add(int index, WKMsg message) {
    if (message.clientSeq > 0) {
      _clientSeq.putIfAbsent(message.clientSeq, () => index);
    }
    final clientMsgNo = message.clientMsgNO.trim();
    if (clientMsgNo.isNotEmpty) {
      _clientMsgNo.putIfAbsent(clientMsgNo, () => index);
    }
    final messageId = message.messageID.trim();
    if (messageId.isNotEmpty) {
      _messageId.putIfAbsent(messageId, () => index);
    }
    final messageSeq = _conversationScopedSeqKey(
      message.channelID,
      message.channelType,
      message.messageSeq,
    );
    if (messageSeq != null) {
      _messageSeq.putIfAbsent(messageSeq, () => index);
    }
    final orderSeq = _conversationScopedSeqKey(
      message.channelID,
      message.channelType,
      message.orderSeq,
    );
    if (orderSeq != null) {
      _orderSeq.putIfAbsent(orderSeq, () => index);
    }
  }
}

String? _conversationScopedSeqKey(String channelId, int channelType, int seq) {
  final normalizedChannelId = channelId.trim();
  if (normalizedChannelId.isEmpty || seq <= 0) {
    return null;
  }
  return '$channelType:$normalizedChannelId:$seq';
}

WKMsg preferConversationMessage(WKMsg current, WKMsg candidate) {
  if (!shouldDisplayConversationMessage(current)) {
    return candidate;
  }
  if (!shouldDisplayConversationMessage(candidate)) {
    return current;
  }

  final currentScore = _conversationMessageScore(current);
  final candidateScore = _conversationMessageScore(candidate);
  if (candidateScore > currentScore) {
    return candidate;
  }
  if (candidateScore < currentScore) {
    return current;
  }
  final currentExtraVersion = _messageExtraVersionOf(current);
  final candidateExtraVersion = _messageExtraVersionOf(candidate);
  if (candidateExtraVersion > currentExtraVersion) {
    return candidate;
  }
  return current;
}

int _conversationMessageScore(WKMsg message) {
  var score = 0;
  if (message.clientSeq > 0) {
    score += 1;
  }
  if (message.clientMsgNO.trim().isNotEmpty) {
    score += 2;
  }
  if (message.orderSeq > 0) {
    score += 4;
  }
  if (message.status != WKSendMsgResult.sendLoading) {
    score += 8;
  }
  if (message.messageSeq > 0) {
    score += 16;
  }
  if (message.messageID.trim().isNotEmpty) {
    score += 32;
  }
  if ((message.reactionList?.isNotEmpty ?? false) ||
      message.wkMsgExtra != null ||
      _hasNonEmptyLocalExtra(message)) {
    score += 64;
  }
  return score;
}

int _messageExtraVersionOf(WKMsg message) {
  return message.wkMsgExtra?.extraVersion ?? 0;
}

bool _hasNonEmptyLocalExtra(WKMsg message) {
  final localExtra = message.localExtraMap;
  if (localExtra == null) {
    return false;
  }
  if (localExtra is Map) {
    return localExtra.isNotEmpty;
  }
  if (localExtra is List) {
    return localExtra.isNotEmpty;
  }
  if (localExtra is String) {
    return localExtra.trim().isNotEmpty;
  }
  try {
    return jsonEncode(localExtra).trim().isNotEmpty;
  } catch (_) {
    return true;
  }
}
