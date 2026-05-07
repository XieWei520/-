import 'indexed_db_web_chat_cache_store_adapter_base.dart';

IndexedDbChatCacheAdapter createIndexedDbChatCacheAdapter() {
  return const _UnavailableIndexedDbChatCacheAdapter();
}

class _UnavailableIndexedDbChatCacheAdapter
    implements IndexedDbChatCacheAdapter {
  const _UnavailableIndexedDbChatCacheAdapter();

  @override
  Future<List<Map<String, Object?>>> readAll() {
    throw StateError('IndexedDB is unavailable on this platform');
  }

  @override
  Future<void> applyChanges({
    required List<Map<String, Object?>> upserts,
    required Iterable<String> deleteKeys,
  }) {
    throw StateError('IndexedDB is unavailable on this platform');
  }
}
