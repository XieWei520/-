abstract interface class IndexedDbChatCacheAdapter {
  Future<List<Map<String, Object?>>> readAll();

  Future<List<Map<String, Object?>>> readMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int limit,
    int beforeOrderSeq = 0,
    int aroundOrderSeq = 0,
  });

  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  });

  Future<void> deleteOldMessages({
    required String uid,
    required String channelId,
    required int channelType,
    required int keepLatest,
  });
}
