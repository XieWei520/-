import 'indexed_db_web_chat_cache_store.dart';
import 'web_chat_cache_store.dart';
import 'web_chat_cache_store_memory.dart';

class WebChatCacheStoreFactory {
  static WebChatCacheStore create({
    required bool isWeb,
    IndexedDbWebChatCacheStore Function()? indexedDbStoreFactory,
  }) {
    if (!isWeb) {
      return MemoryWebChatCacheStore();
    }
    try {
      return (indexedDbStoreFactory ?? IndexedDbWebChatCacheStore.new)();
    } catch (_) {
      return MemoryWebChatCacheStore();
    }
  }
}
