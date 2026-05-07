import 'package:flutter/foundation.dart';

import 'indexed_db_web_chat_cache_store.dart';
import 'web_chat_cache_store.dart';
import 'web_chat_cache_store_memory.dart';

typedef IndexedDbStoreFactory = IndexedDbWebChatCacheStore Function();

class WebChatCacheStoreFactory {
  const WebChatCacheStoreFactory._();

  static WebChatCacheStore create({
    required bool isWeb,
    IndexedDbStoreFactory? indexedDbStoreFactory,
  }) {
    if (!isWeb) {
      return MemoryWebChatCacheStore();
    }

    try {
      return (indexedDbStoreFactory ?? _defaultIndexedDbStoreFactory)();
    } catch (_) {
      return MemoryWebChatCacheStore();
    }
  }

  static IndexedDbWebChatCacheStore _defaultIndexedDbStoreFactory() {
    return IndexedDbWebChatCacheStore();
  }
}

WebChatCacheStore createWebChatCacheStore({
  IndexedDbStoreFactory? indexedDbStoreFactory,
}) {
  return WebChatCacheStoreFactory.create(
    isWeb: kIsWeb,
    indexedDbStoreFactory: indexedDbStoreFactory,
  );
}
