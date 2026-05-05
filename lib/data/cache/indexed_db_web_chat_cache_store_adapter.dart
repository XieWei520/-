import 'indexed_db_web_chat_cache_store_adapter_io.dart'
    if (dart.library.html) 'indexed_db_web_chat_cache_store_adapter_web.dart'
    as platform;

abstract interface class IndexedDbWebChatCacheAdapter {
  Future<List<Map<String, Object?>>> readAll();

  Future<void> writeAll(List<Map<String, Object?>> records);
}

IndexedDbWebChatCacheAdapter createIndexedDbWebChatCacheAdapter() {
  return platform.createIndexedDbWebChatCacheAdapter();
}
