import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/utils/storage_utils.dart';
import '../../service/api/conversation_draft_api.dart';

String draftContentSignature({
  required String content,
  String? replyMsgId,
  String? replyContent,
}) {
  return jsonEncode(<String?>[content, replyMsgId, replyContent]);
}

/// Message draft entity
class MessageDraft {
  final String channelId;
  final int channelType;
  final String content;
  final int updateTime;
  final String? replyMsgId;
  final String? replyContent;
  final int remoteVersion;

  MessageDraft({
    required this.channelId,
    required this.channelType,
    required this.content,
    required this.updateTime,
    this.replyMsgId,
    this.replyContent,
    this.remoteVersion = 0,
  });

  MessageDraft copyWith({
    String? channelId,
    int? channelType,
    String? content,
    int? updateTime,
    String? replyMsgId,
    bool clearReplyMsgId = false,
    String? replyContent,
    bool clearReplyContent = false,
    int? remoteVersion,
  }) {
    return MessageDraft(
      channelId: channelId ?? this.channelId,
      channelType: channelType ?? this.channelType,
      content: content ?? this.content,
      updateTime: updateTime ?? this.updateTime,
      replyMsgId: clearReplyMsgId ? null : (replyMsgId ?? this.replyMsgId),
      replyContent: clearReplyContent
          ? null
          : (replyContent ?? this.replyContent),
      remoteVersion: remoteVersion ?? this.remoteVersion,
    );
  }

  factory MessageDraft.fromJson(Map<String, dynamic> json) {
    return MessageDraft(
      channelId: json['channel_id'] ?? '',
      channelType: _readInt(json['channel_type'], fallback: 1),
      content: json['content'] ?? '',
      updateTime: _readInt(json['update_time']),
      replyMsgId: json['reply_msg_id'],
      replyContent: json['reply_content'],
      remoteVersion: _readInt(json['remote_version']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'channel_id': channelId,
      'channel_type': channelType,
      'content': content,
      'update_time': updateTime,
      if (replyMsgId != null) 'reply_msg_id': replyMsgId,
      if (replyContent != null) 'reply_content': replyContent,
      if (remoteVersion > 0) 'remote_version': remoteVersion,
    };
  }

  String get storageKey => '${channelType}_$channelId';

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

extension DraftSignature on MessageDraft {
  String get contentSignature => draftContentSignature(
    content: content,
    replyMsgId: replyMsgId,
    replyContent: replyContent,
  );
}

abstract class DraftStorage {
  List<String>? getStringList(String key);

  Future<void> setStringList(String key, List<String> value);

  Future<void> remove(String key);
}

abstract class DraftStore {
  MessageDraft? getDraft(String channelId, int channelType);

  Future<void> saveDraft({
    required String channelId,
    required int channelType,
    required String content,
    String? replyMsgId,
    String? replyContent,
  });
}

/// Message draft manager
class DraftManager implements DraftStore {
  static final DraftManager _instance = DraftManager._internal();
  factory DraftManager() => _instance;
  DraftManager._internal();

  static const String _storageKeyPrefix = 'wk_message_drafts_v1';

  final Map<String, MessageDraft> _draftCache = {};
  final _draftUpdatesController = StreamController<DraftUpdate>.broadcast();

  ConversationDraftRemoteStore _remoteStore = ConversationDraftApi.instance;
  DraftStorage _storage = const _SharedPreferencesDraftStorage();
  Future<void> _storageWriteChain = Future<void>.value();
  String? _loadedStorageKey;

  Stream<DraftUpdate> get draftUpdates => _draftUpdatesController.stream;

  @visibleForTesting
  set remoteStore(ConversationDraftRemoteStore remoteStore) {
    _remoteStore = remoteStore;
  }

  @visibleForTesting
  void resetRemoteStore() {
    _remoteStore = ConversationDraftApi.instance;
  }

  @visibleForTesting
  set storage(DraftStorage storage) {
    _storage = storage;
  }

  @visibleForTesting
  void resetStorage() {
    _storage = const _SharedPreferencesDraftStorage();
    _storageWriteChain = Future<void>.value();
  }

  @override
  MessageDraft? getDraft(String channelId, int channelType) {
    final key = '${channelType}_$channelId';
    return _draftCache[key];
  }

  @override
  Future<void> saveDraft({
    required String channelId,
    required int channelType,
    required String content,
    String? replyMsgId,
    String? replyContent,
  }) async {
    await _ensureLoadedForCurrentScope();
    final storageKey = _currentStorageKey;

    final normalizedReplyMsgId = _normalizeNullable(replyMsgId);
    final normalizedReplyContent = _normalizeNullable(replyContent);
    if (content.trim().isEmpty && normalizedReplyMsgId == null) {
      await removeDraft(channelId, channelType);
      return;
    }

    final key = '${channelType}_$channelId';
    final previousDraft = _draftCache[key];
    final draft = MessageDraft(
      channelId: channelId,
      channelType: channelType,
      content: content,
      updateTime: _nowSeconds(),
      replyMsgId: normalizedReplyMsgId,
      replyContent: normalizedReplyContent,
      remoteVersion: previousDraft?.remoteVersion ?? 0,
    );

    _draftCache[key] = draft;
    await _persistAllDraftsToStorage(storageKey);
    _notifyUpdate(draft);
    unawaited(_pushRemoteDraft(draft, storageKey: storageKey));
  }

  Future<void> removeDraft(String channelId, int channelType) async {
    await _ensureLoadedForCurrentScope();
    final storageKey = _currentStorageKey;

    final key = '${channelType}_$channelId';
    final removedDraft = _draftCache.remove(key);
    await _persistAllDraftsToStorage(storageKey);
    _notifyRemove(channelId, channelType);

    if (removedDraft != null) {
      unawaited(_pushRemoteDraftRemoval(channelId, channelType));
    }
  }

  Future<void> clearAllDrafts() async {
    await _ensureLoadedForCurrentScope();
    final storageKey = _currentStorageKey;

    _draftCache.clear();
    await _persistAllDraftsToStorage(storageKey);
    _draftUpdatesController.add(DraftUpdate(type: DraftUpdateType.clearAll));
  }

  List<MessageDraft> getAllDrafts() {
    return _draftCache.values.toList()
      ..sort((a, b) => b.updateTime.compareTo(a.updateTime));
  }

  Future<void> loadAllDrafts({bool syncRemote = true}) async {
    await _waitForPendingStorageWrites();
    final storageKey = _currentStorageKey;
    _loadedStorageKey = storageKey;
    _draftCache.clear();

    final rawList = _storage.getStringList(storageKey) ?? const [];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final draft = MessageDraft.fromJson(Map<String, dynamic>.from(decoded));
        if (draft.channelId.trim().isEmpty) {
          continue;
        }
        _draftCache[draft.storageKey] = draft;
      } catch (_) {
        continue;
      }
    }

    if (syncRemote && _canSyncRemoteDrafts) {
      await _mergeRemoteDrafts();
    }
  }

  Future<void> _mergeRemoteDrafts() async {
    final storageKey = _loadedStorageKey ?? _currentStorageKey;
    final maxRemoteVersion = _draftCache.values.fold<int>(
      0,
      (current, draft) =>
          draft.remoteVersion > current ? draft.remoteVersion : current,
    );

    try {
      final remoteDrafts = await _remoteStore.syncDrafts(
        version: maxRemoteVersion,
      );
      if (remoteDrafts.isEmpty) {
        return;
      }

      var hasChanged = false;
      for (final remoteDraft in remoteDrafts) {
        final key = '${remoteDraft.channelType}_${remoteDraft.channelId}';
        final existing = _draftCache[key];
        if (existing != null && remoteDraft.version <= existing.remoteVersion) {
          continue;
        }

        if (remoteDraft.draft.trim().isEmpty) {
          if (existing != null) {
            _draftCache.remove(key);
            _notifyRemove(remoteDraft.channelId, remoteDraft.channelType);
            hasChanged = true;
          }
          continue;
        }

        final shouldPreserveReply = existing?.content == remoteDraft.draft;
        final mergedDraft = MessageDraft(
          channelId: remoteDraft.channelId,
          channelType: remoteDraft.channelType,
          content: remoteDraft.draft,
          updateTime: shouldPreserveReply == true
              ? (existing?.updateTime ?? _nowSeconds())
              : _nowSeconds(),
          replyMsgId: shouldPreserveReply == true ? existing?.replyMsgId : null,
          replyContent: shouldPreserveReply == true
              ? existing?.replyContent
              : null,
          remoteVersion: remoteDraft.version,
        );
        _draftCache[key] = mergedDraft;
        _notifyUpdate(mergedDraft);
        hasChanged = true;
      }

      if (hasChanged) {
        await _persistAllDraftsToStorage(storageKey);
      }
    } catch (_) {
      // Keep local drafts available even when remote sync fails.
    }
  }

  Future<void> _pushRemoteDraft(
    MessageDraft draft, {
    required String storageKey,
  }) async {
    if (!_canSyncRemoteDrafts) {
      return;
    }

    try {
      final remoteVersion = await _remoteStore.updateDraft(
        channelId: draft.channelId,
        channelType: draft.channelType,
        draft: draft.content,
      );
      if (remoteVersion == null) {
        return;
      }

      if (_loadedStorageKey != storageKey || _currentStorageKey != storageKey) {
        return;
      }

      final current = _draftCache[draft.storageKey];
      if (current == null) {
        return;
      }

      _draftCache[draft.storageKey] = current.copyWith(
        remoteVersion: remoteVersion,
      );
      await _persistAllDraftsToStorage(storageKey);
    } catch (_) {
      // Remote save is best-effort. Local draft should remain available.
    }
  }

  Future<void> _pushRemoteDraftRemoval(
    String channelId,
    int channelType,
  ) async {
    if (!_canSyncRemoteDrafts) {
      return;
    }

    try {
      await _remoteStore.updateDraft(
        channelId: channelId,
        channelType: channelType,
        draft: '',
      );
    } catch (_) {
      // Keep local deletion even when remote clear fails.
    }
  }

  Future<void> _persistAllDraftsToStorage(String storageKey) async {
    _storageWriteChain = _storageWriteChain.catchError((_) {}).then((_) async {
      if (_draftCache.isEmpty) {
        await _storage.remove(storageKey);
        return;
      }

      final values = _draftCache.values
          .map((item) => jsonEncode(item.toJson()))
          .toList(growable: false);
      await _storage.setStringList(storageKey, values);
    });
    await _storageWriteChain;
  }

  Future<void> _waitForPendingStorageWrites() async {
    try {
      await _storageWriteChain;
    } catch (_) {
      // A later write should still be allowed to proceed.
    }
  }

  String get _currentStorageKey {
    final uid = StorageUtils.getUid()?.trim();
    final scope = (uid == null || uid.isEmpty) ? 'guest' : uid;
    return '$_storageKeyPrefix:$scope';
  }

  bool get _canSyncRemoteDrafts {
    final uid = StorageUtils.getUid()?.trim() ?? '';
    final token = StorageUtils.getToken()?.trim() ?? '';
    return uid.isNotEmpty && token.isNotEmpty;
  }

  Future<void> _ensureLoadedForCurrentScope() async {
    if (_loadedStorageKey == _currentStorageKey) {
      return;
    }
    await loadAllDrafts();
  }

  void _notifyUpdate(MessageDraft draft) {
    _draftUpdatesController.add(
      DraftUpdate(
        type: DraftUpdateType.update,
        channelId: draft.channelId,
        channelType: draft.channelType,
        draft: draft,
      ),
    );
  }

  void _notifyRemove(String channelId, int channelType) {
    _draftUpdatesController.add(
      DraftUpdate(
        type: DraftUpdateType.remove,
        channelId: channelId,
        channelType: channelType,
      ),
    );
  }

  void dispose() {
    _draftUpdatesController.close();
  }

  static String? _normalizeNullable(String? value) {
    final normalized = value?.trim();
    return (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  static int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;
}

/// Draft update event
class DraftUpdate {
  final DraftUpdateType type;
  final String? channelId;
  final int? channelType;
  final MessageDraft? draft;

  DraftUpdate({
    required this.type,
    this.channelId,
    this.channelType,
    this.draft,
  });
}

/// Draft update type
enum DraftUpdateType { update, remove, clearAll }

class _SharedPreferencesDraftStorage implements DraftStorage {
  const _SharedPreferencesDraftStorage();

  @override
  List<String>? getStringList(String key) {
    return StorageUtils.getStringList(key);
  }

  @override
  Future<void> remove(String key) async {
    await StorageUtils.remove(key);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    await StorageUtils.setStringList(key, value);
  }
}
