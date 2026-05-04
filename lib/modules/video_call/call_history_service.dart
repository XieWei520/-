import 'dart:async';
import 'dart:convert';

import '../../core/utils/storage_utils.dart';
import '../../data/models/call.dart';

class CallHistoryService {
  CallHistoryService._();

  static final CallHistoryService _instance = CallHistoryService._();
  static CallHistoryService get instance => _instance;

  static const String _storageKey = 'wk_call_history_v1';
  static const int _maxEntries = 100;

  final StreamController<void> _updatesController =
      StreamController<void>.broadcast();

  Stream<void> get updates => _updatesController.stream;

  Future<List<CallHistoryEntry>> getEntries() async {
    final rawList = StorageUtils.getStringList(_storageKey) ?? const <String>[];
    final entries = <CallHistoryEntry>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final entry = CallHistoryEntry.fromJson(
          Map<String, dynamic>.from(decoded),
        );
        if (entry.roomId.trim().isEmpty) {
          continue;
        }
        entries.add(entry);
      } catch (_) {
        continue;
      }
    }
    entries.sort((left, right) => right.startedAt.compareTo(left.startedAt));
    return entries;
  }

  Future<CallHistoryEntry?> getEntry(String roomId) async {
    final normalizedRoomId = roomId.trim();
    if (normalizedRoomId.isEmpty) {
      return null;
    }
    final entries = await getEntries();
    for (final entry in entries) {
      if (entry.roomId == normalizedRoomId) {
        return entry;
      }
    }
    return null;
  }

  Future<void> recordOutgoingStarted({
    required CallRoom room,
    required String channelId,
    required String channelName,
    String? avatar,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getEntry(room.roomId);
    final entry = (existing ??
            CallHistoryEntry(
              roomId: room.roomId,
              channelId: channelId,
              channelName: channelName,
              callType: room.callType,
              direction: CallDirection.outgoing,
              status: CallHistoryStatus.ringing,
              startedAt: now,
              avatar: avatar,
            ))
        .copyWith(
          channelId: channelId,
          channelName: channelName,
          callType: room.callType,
          direction: CallDirection.outgoing,
          status: CallHistoryStatus.ringing,
          avatar: avatar,
          clearEndedAt: true,
        );
    await _upsert(entry);
  }

  Future<void> recordIncomingRinging({
    required CallRoom room,
    required String channelId,
    required String channelName,
    String? avatar,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getEntry(room.roomId);
    final entry = (existing ??
            CallHistoryEntry(
              roomId: room.roomId,
              channelId: channelId,
              channelName: channelName,
              callType: room.callType,
              direction: CallDirection.incoming,
              status: CallHistoryStatus.ringing,
              startedAt: now,
              avatar: avatar,
            ))
        .copyWith(
          channelId: channelId,
          channelName: channelName,
          callType: room.callType,
          direction: CallDirection.incoming,
          status: existing?.status == CallHistoryStatus.connected
              ? CallHistoryStatus.connected
              : CallHistoryStatus.ringing,
          avatar: avatar,
        );
    await _upsert(entry);
  }

  Future<void> markConnected(String roomId) async {
    final existing = await getEntry(roomId);
    if (existing == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _upsert(
      existing.copyWith(
        status: CallHistoryStatus.connected,
        connectedAt: existing.connectedAt ?? now,
        clearEndedAt: true,
      ),
    );
  }

  Future<void> markRejected(String roomId) async {
    await _markFinished(roomId, CallHistoryStatus.rejected);
  }

  Future<void> markMissed(String roomId) async {
    await _markFinished(roomId, CallHistoryStatus.missed);
  }

  Future<void> markCanceled(String roomId) async {
    await _markFinished(roomId, CallHistoryStatus.canceled);
  }

  Future<void> markCompleted(String roomId) async {
    await _markFinished(roomId, CallHistoryStatus.completed);
  }

  Future<void> markRemoteEnded(String roomId) async {
    final existing = await getEntry(roomId);
    if (existing == null) {
      return;
    }
    if (existing.connectedAt != null ||
        existing.status == CallHistoryStatus.connected) {
      await markCompleted(roomId);
      return;
    }
    if (existing.direction == CallDirection.incoming) {
      await markMissed(roomId);
      return;
    }
    await markCanceled(roomId);
  }

  Future<void> deleteEntry(String roomId) async {
    final entries = await getEntries();
    entries.removeWhere((item) => item.roomId == roomId);
    await _save(entries);
  }

  Future<void> clear() async {
    await StorageUtils.remove(_storageKey);
    _updatesController.add(null);
  }

  Future<void> _markFinished(
    String roomId,
    CallHistoryStatus status,
  ) async {
    final existing = await getEntry(roomId);
    if (existing == null) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _upsert(
      existing.copyWith(
        status: status,
        endedAt: now,
      ),
    );
  }

  Future<void> _upsert(CallHistoryEntry entry) async {
    final entries = await getEntries();
    final index = entries.indexWhere((item) => item.roomId == entry.roomId);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    await _save(entries);
  }

  Future<void> _save(List<CallHistoryEntry> entries) async {
    final normalized = [...entries]
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    final payload = normalized
        .take(_maxEntries)
        .map((entry) => jsonEncode(entry.toJson()))
        .toList();
    await StorageUtils.setStringList(_storageKey, payload);
    _updatesController.add(null);
  }
}
