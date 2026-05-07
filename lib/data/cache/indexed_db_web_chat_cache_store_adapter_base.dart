abstract interface class IndexedDbChatCacheAdapter {
  Future<List<Map<String, Object?>>> readAll();

  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  });
}
