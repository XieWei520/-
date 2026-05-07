import 'indexed_db_web_chat_cache_store_adapter.dart';

IndexedDbWebChatCacheAdapter createIndexedDbWebChatCacheAdapter() {
  return const _UnimplementedIndexedDbWebChatCacheAdapter();
}

class _UnimplementedIndexedDbWebChatCacheAdapter
    implements IndexedDbWebChatCacheAdapter {
  const _UnimplementedIndexedDbWebChatCacheAdapter();

  @override
  Future<List<Map<String, Object?>>> readAll() {
    return Future.error(
      StateError('IndexedDB is not available on this platform'),
    );
  }

  @override
  Future<void> writeAll(List<Map<String, Object?>> records) {
    return Future.error(
      StateError('IndexedDB is not available on this platform'),
    );
  }
}
