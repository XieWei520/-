import 'indexed_db_web_chat_cache_store_adapter_base.dart';
import 'indexed_db_web_chat_cache_store_adapter_io.dart'
    if (dart.library.html) 'indexed_db_web_chat_cache_store_adapter_web.dart'
    as platform;

export 'indexed_db_web_chat_cache_store_adapter_base.dart';

IndexedDbChatCacheAdapter createIndexedDbChatCacheAdapter() {
  return platform.createIndexedDbChatCacheAdapter();
}
