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
import '../../core/utils/storage_utils.dart';
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
import '../../service/api/message_api.dart';
import '../../wukong_base/msg/draft_manager.dart';

export '../../modules/conversation/conversation_projection.dart'
    show ConversationPatch;

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
    bool attachSdkListeners = true,
    bool loadInitialConversations = true,
  }) : _projectionRepository =
           projectionRepository ??
           ref?.read(conversationProjectionRepositoryProvider) ??
           ConversationProjectionRepository(
             const ConversationProjectionReducer(),
           ),
       _telemetry = telemetry,
       _attachSdkListeners = attachSdkListeners,
       super(const <WKUIConversationMsg>[]) {
    if (_attachSdkListeners) {
      _setupListeners();
    }
    if (loadInitialConversations) {
      unawaited(_loadConversations());
    }
  }

  factory ConversationNotifier.forTest(List<WKUIConversationMsg> seed) {
    final notifier = ConversationNotifier(
      attachSdkListeners: false,
      loadInitialConversations: false,
      projectionRepository: ConversationProjectionRepository(
        const ConversationProjectionReducer(),
      ),
    );
    notifier._replaceState(seed);
    return notifier;
  }

  final ConversationProjectionRepository _projectionRepository;
  final ConversationPatchTelemetry? _telemetry;
  final bool _attachSdkListeners;

  void _setupListeners() {
    WKIM.shared.conversationManager.addOnRefreshMsgListListener('provider', (
      msgs,
    ) {
      _applyRefreshPatches(msgs);
    });
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await WKIM.shared.conversationManager.getAll();
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
    final previousProjectionByKey = <String, ConversationProjection>{
      for (final item in _projectionRepository.snapshot)
        _conversationProjectionKey(item.channelId, item.channelType): item,
    };
    final projectionSeed = conversations
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
    state = _sortConversationsByProjection(conversations);
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
    await WKIM.shared.conversationManager.deleteMsg(channelId, channelType);
    await DraftManager().removeDraft(channelId, channelType);
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
      await WKIM.shared.conversationManager.deleteMsg(
        session.channelId,
        session.channelType,
      );
      await DraftManager().removeDraft(session.channelId, session.channelType);
      nextState.removeWhere(
        (item) =>
            item.channelID == session.channelId &&
            item.channelType == session.channelType,
      );
    }
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
    return clone;
  }
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
        historyGateway: ref.watch(chatHistoryGatewayProvider),
        telemetry: ref.watch(messageQueryTelemetryProvider),
        autoLoad: false,
      ),
    );

final chatHistoryGatewayProvider = Provider<ChatHistoryGateway>(
  (ref) => WkImChatHistoryGateway(),
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
    ChatHistoryGateway? historyGateway,
    MessageQueryTelemetry? telemetry,
    this.autoLoad = true,
  }) : historyGateway = historyGateway ?? WkImChatHistoryGateway(),
       _telemetry = telemetry,
       super([]) {
    if (autoLoad) {
      _ensureListeners();
      unawaited(loadMessages());
    }
  }

  final String channelId;
  final int channelType;
  final ChatHistoryGateway historyGateway;
  final MessageQueryTelemetry? _telemetry;
  final bool autoLoad;
  bool _listenersAttached = false;
  int _replaceRequestVersion = 0;
  Future<void>? _loadMoreInFlight;

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
        query: () => historyGateway.loadLatest(
          channelId: channelId,
          channelType: channelType,
          limit: 50,
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

    final future = () async {
      final oldestOrderSeq = state.last.orderSeq;
      final requestVersion = _replaceRequestVersion;
      try {
        final msgs = await _trackSqlitePageQuery(
          mode: 'older_page',
          query: () => historyGateway.loadMore(
            channelId: channelId,
            channelType: channelType,
            oldestOrderSeq: oldestOrderSeq,
            limit: 50,
          ),
        );
        if (requestVersion != _replaceRequestVersion) {
          return;
        }
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
        mode: 'around_anchor',
        query: () => historyGateway.loadAroundOrderSeq(
          channelId: channelId,
          channelType: channelType,
          limit: 50,
          aroundOrderSeq: aroundOrderSeq,
        ),
      ),
    );
  }

  Future<void> _replaceStateWith(Future<List<WKMsg>> Function() loader) async {
    final version = ++_replaceRequestVersion;
    try {
      final msgs = await loader();
      if (version != _replaceRequestVersion) {
        return;
      }
      state = mergeConversationMessages(msgs.reversed);
    } catch (_) {
      if (version != _replaceRequestVersion) {
        return;
      }
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
  for (final message in messages) {
    if (!shouldDisplayConversationMessage(message)) {
      continue;
    }
    final index = findConversationMessageIndex(merged, message);
    if (index == -1) {
      merged.add(message);
      continue;
    }
    merged[index] = preferConversationMessage(merged[index], message);
  }
  return merged;
}

List<WKMsg> refreshConversationMessages(List<WKMsg> current, WKMsg message) {
  final next = current
      .where(shouldDisplayConversationMessage)
      .toList(growable: true);
  final index = findConversationMessageIndex(next, message);

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
  for (var index = 0; index < messages.length; index++) {
    if (_sameClientSeq(messages[index], target)) {
      return index;
    }
  }

  for (var index = 0; index < messages.length; index++) {
    if (_sameClientMsgNo(messages[index], target)) {
      return index;
    }
  }

  for (var index = 0; index < messages.length; index++) {
    if (_sameMessageId(messages[index], target)) {
      return index;
    }
  }

  for (var index = 0; index < messages.length; index++) {
    if (_sameMessageSeq(messages[index], target)) {
      return index;
    }
  }

  for (var index = 0; index < messages.length; index++) {
    if (_sameOrderSeq(messages[index], target)) {
      return index;
    }
  }

  return -1;
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

bool _sameClientSeq(WKMsg left, WKMsg right) {
  return left.clientSeq > 0 &&
      right.clientSeq > 0 &&
      left.clientSeq == right.clientSeq;
}

bool _sameClientMsgNo(WKMsg left, WKMsg right) {
  final leftClientMsgNo = left.clientMsgNO.trim();
  final rightClientMsgNo = right.clientMsgNO.trim();
  return leftClientMsgNo.isNotEmpty &&
      rightClientMsgNo.isNotEmpty &&
      leftClientMsgNo == rightClientMsgNo;
}

bool _sameMessageId(WKMsg left, WKMsg right) {
  final leftMessageId = left.messageID.trim();
  final rightMessageId = right.messageID.trim();
  return leftMessageId.isNotEmpty &&
      rightMessageId.isNotEmpty &&
      leftMessageId == rightMessageId;
}

bool _sameMessageSeq(WKMsg left, WKMsg right) {
  return _sameConversation(left, right) &&
      left.messageSeq > 0 &&
      right.messageSeq > 0 &&
      left.messageSeq == right.messageSeq;
}

bool _sameOrderSeq(WKMsg left, WKMsg right) {
  return _sameConversation(left, right) &&
      left.orderSeq > 0 &&
      right.orderSeq > 0 &&
      left.orderSeq == right.orderSeq;
}

bool _sameConversation(WKMsg left, WKMsg right) {
  return left.channelType == right.channelType &&
      left.channelID.trim() == right.channelID.trim();
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
