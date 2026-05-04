import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wukong_im_app/core/utils/storage_utils.dart';
import 'package:wukong_im_app/service/api/conversation_draft_api.dart';
import 'package:wukong_im_app/wukong_base/msg/draft_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageUtils.init();
  });

  setUp(() async {
    final manager = DraftManager();
    manager.resetRemoteStore();
    manager.resetStorage();
    await StorageUtils.setUid('draft_test_user');
    await StorageUtils.clearToken();
    await manager.loadAllDrafts(syncRemote: false);
    await manager.clearAllDrafts();
  });

  tearDown(() {
    final manager = DraftManager();
    manager.resetStorage();
  });

  test('persists and reloads drafts for current user', () async {
    final manager = DraftManager();

    await manager.saveDraft(
      channelId: 'u_alice',
      channelType: 1,
      content: 'unsent draft',
      replyMsgId: 'msg-1',
      replyContent: '[image]',
    );

    await manager.loadAllDrafts();
    final draft = manager.getDraft('u_alice', 1);

    expect(draft, isNotNull);
    expect(draft!.content, 'unsent draft');
    expect(draft.replyMsgId, 'msg-1');
    expect(draft.replyContent, '[image]');

    await manager.removeDraft('u_alice', 1);
    await manager.loadAllDrafts();

    expect(manager.getDraft('u_alice', 1), isNull);
  });

  test('isolates drafts by uid scope', () async {
    final manager = DraftManager();

    await manager.saveDraft(
      channelId: 'u_alice',
      channelType: 1,
      content: 'user-a draft',
    );

    await StorageUtils.setUid('draft_test_user_b');
    await manager.loadAllDrafts();
    expect(manager.getDraft('u_alice', 1), isNull);

    await StorageUtils.setUid('draft_test_user');
    await manager.loadAllDrafts();
    expect(manager.getDraft('u_alice', 1)?.content, 'user-a draft');
  });

  test('merges newer remote drafts into local cache', () async {
    final manager = DraftManager();
    final remoteStore = _FakeRemoteStore()
      ..syncedDrafts.add(
        const RemoteConversationDraft(
          channelId: 'u_alice',
          channelType: 1,
          draft: 'remote draft',
          version: 7,
        ),
      );

    manager.remoteStore = remoteStore;
    await StorageUtils.setToken('remote-token');
    await manager.loadAllDrafts();

    final draft = manager.getDraft('u_alice', 1);
    expect(draft, isNotNull);
    expect(draft!.content, 'remote draft');
    expect(draft.remoteVersion, 7);
  });

  test('pushes draft updates and removals to remote store when logged in',
      () async {
    final manager = DraftManager();
    final remoteStore = _FakeRemoteStore();

    manager.remoteStore = remoteStore;
    await StorageUtils.setToken('remote-token');
    await manager.loadAllDrafts(syncRemote: false);

    await manager.saveDraft(
      channelId: 'u_alice',
      channelType: 1,
      content: 'sync me',
    );
    await Future<void>.delayed(Duration.zero);

    expect(remoteStore.updates, hasLength(1));
    expect(remoteStore.updates.first.channelId, 'u_alice');
    expect(remoteStore.updates.first.channelType, 1);
    expect(remoteStore.updates.first.draft, 'sync me');
    expect(manager.getDraft('u_alice', 1)?.remoteVersion, 100);

    await manager.removeDraft('u_alice', 1);
    await Future<void>.delayed(Duration.zero);

    expect(remoteStore.updates, hasLength(2));
    expect(remoteStore.updates.last.draft, '');
  });

  test('serializes overlapping storage writes so concurrent saves keep both drafts',
      () async {
    final manager = DraftManager();
    final storage = _ControlledDraftStorage();
    manager.storage = storage;
    await manager.loadAllDrafts(syncRemote: false);

    final firstSave = manager.saveDraft(
      channelId: 'u_alice',
      channelType: 1,
      content: 'first draft',
    );
    await storage.waitForWriteCount(1);

    final secondSave = manager.saveDraft(
      channelId: 'u_bob',
      channelType: 1,
      content: 'second draft',
    );
    await Future<void>.delayed(Duration.zero);

    expect(storage.startedWritePayloads, hasLength(1));

    storage.completeNextWrite();
    await storage.waitForWriteCount(2);

    storage.completeNextWrite();
    await Future.wait([firstSave, secondSave]);

    await manager.loadAllDrafts(syncRemote: false);

    expect(manager.getDraft('u_alice', 1)?.content, 'first draft');
    expect(manager.getDraft('u_bob', 1)?.content, 'second draft');

    final storedPayload = storage.readRawList(storage.lastKey!);
    final decodedDrafts = storedPayload
        .map(
          (entry) => MessageDraft.fromJson(
            Map<String, dynamic>.from(jsonDecode(entry) as Map),
          ),
        )
        .toList();
    expect(
      decodedDrafts.map((draft) => draft.channelId),
      containsAll(['u_alice', 'u_bob']),
    );
  });

  test('ignores delayed remote draft acknowledgements after scope switches',
      () async {
    final manager = DraftManager();
    final remoteStore = _ControlledRemoteStore();

    manager.remoteStore = remoteStore;
    await StorageUtils.setUid('draft_test_user');
    await StorageUtils.setToken('remote-token');
    await manager.loadAllDrafts(syncRemote: false);

    await manager.saveDraft(
      channelId: 'u_shared',
      channelType: 1,
      content: 'user-a draft',
    );
    await remoteStore.waitForUpdateCount(1);

    await StorageUtils.setUid('draft_test_user_b');
    await StorageUtils.clearToken();
    await manager.loadAllDrafts(syncRemote: false);
    await manager.saveDraft(
      channelId: 'u_shared',
      channelType: 1,
      content: 'user-b draft',
    );

    expect(manager.getDraft('u_shared', 1)?.content, 'user-b draft');
    expect(manager.getDraft('u_shared', 1)?.remoteVersion, 0);

    remoteStore.completeNextUpdate(version: 101);
    await Future<void>.delayed(Duration.zero);

    expect(manager.getDraft('u_shared', 1)?.content, 'user-b draft');
    expect(manager.getDraft('u_shared', 1)?.remoteVersion, 0);
  });
}

class _FakeRemoteStore implements ConversationDraftRemoteStore {
  final List<RemoteConversationDraft> syncedDrafts = [];
  final List<_RemoteUpdateCall> updates = [];
  int nextVersion = 100;

  @override
  Future<List<RemoteConversationDraft>> syncExtras({required int version}) async {
    return syncDrafts(version: version);
  }

  @override
  Future<List<RemoteConversationDraft>> syncDrafts({required int version}) async {
    return syncedDrafts.where((item) => item.version > version).toList();
  }

  @override
  Future<int?> updateExtra({
    required String channelId,
    required int channelType,
    int? browseTo,
    int? keepMessageSeq,
    int? keepOffsetY,
    String? draft,
  }) async {
    return updateDraft(
      channelId: channelId,
      channelType: channelType,
      draft: draft ?? '',
    );
  }

  @override
  Future<int?> updateDraft({
    required String channelId,
    required int channelType,
    required String draft,
  }) async {
    updates.add(
      _RemoteUpdateCall(
        channelId: channelId,
        channelType: channelType,
        draft: draft,
      ),
    );
    return nextVersion++;
  }
}

class _ControlledRemoteStore implements ConversationDraftRemoteStore {
  final List<_RemoteUpdateCall> updates = <_RemoteUpdateCall>[];
  final Queue<Completer<int?>> _pendingUpdates = Queue<Completer<int?>>();
  final StreamController<void> _updateStartedController =
      StreamController<void>.broadcast();

  @override
  Future<List<RemoteConversationDraft>> syncExtras({required int version}) async {
    return syncDrafts(version: version);
  }

  @override
  Future<List<RemoteConversationDraft>> syncDrafts({required int version}) async {
    return const <RemoteConversationDraft>[];
  }

  @override
  Future<int?> updateExtra({
    required String channelId,
    required int channelType,
    int? browseTo,
    int? keepMessageSeq,
    int? keepOffsetY,
    String? draft,
  }) async {
    return updateDraft(
      channelId: channelId,
      channelType: channelType,
      draft: draft ?? '',
    );
  }

  @override
  Future<int?> updateDraft({
    required String channelId,
    required int channelType,
    required String draft,
  }) async {
    updates.add(
      _RemoteUpdateCall(
        channelId: channelId,
        channelType: channelType,
        draft: draft,
      ),
    );
    _updateStartedController.add(null);
    final completer = Completer<int?>();
    _pendingUpdates.add(completer);
    return completer.future;
  }

  Future<void> waitForUpdateCount(int count) async {
    while (updates.length < count) {
      await _updateStartedController.stream.first;
    }
  }

  void completeNextUpdate({int? version}) {
    _pendingUpdates.removeFirst().complete(version);
  }
}

class _RemoteUpdateCall {
  final String channelId;
  final int channelType;
  final String draft;

  const _RemoteUpdateCall({
    required this.channelId,
    required this.channelType,
    required this.draft,
  });
}

class _ControlledDraftStorage implements DraftStorage {
  final Map<String, List<String>> _data = <String, List<String>>{};
  final Queue<Completer<void>> _pendingWrites = Queue<Completer<void>>();
  final StreamController<void> _writeStartedController =
      StreamController<void>.broadcast();
  final List<List<String>?> startedWritePayloads = <List<String>?>[];
  String? lastKey;

  @override
  List<String>? getStringList(String key) {
    final values = _data[key];
    return values == null ? null : List<String>.from(values);
  }

  @override
  Future<void> remove(String key) async {
    lastKey = key;
    startedWritePayloads.add(null);
    _writeStartedController.add(null);
    final completer = Completer<void>();
    _pendingWrites.add(completer);
    await completer.future;
    _data.remove(key);
  }

  @override
  Future<void> setStringList(String key, List<String> value) async {
    lastKey = key;
    startedWritePayloads.add(List<String>.from(value));
    _writeStartedController.add(null);
    final completer = Completer<void>();
    _pendingWrites.add(completer);
    await completer.future;
    _data[key] = List<String>.from(value);
  }

  Future<void> waitForWriteCount(int count) async {
    while (startedWritePayloads.length < count) {
      await _writeStartedController.stream.first;
    }
  }

  void completeNextWrite() {
    _pendingWrites.removeFirst().complete();
  }

  List<String> readRawList(String key) {
    return List<String>.from(_data[key] ?? const <String>[]);
  }
}
