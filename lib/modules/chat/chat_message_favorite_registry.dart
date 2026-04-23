import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../core/utils/storage_utils.dart';

List<String> favoriteMessageKeysOf(WKMsg message) {
  final keys = <String>[];
  final messageId = message.messageID.trim();
  if (messageId.isNotEmpty) {
    keys.add('mid:$messageId');
  }
  final clientMsgNo = message.clientMsgNO.trim();
  if (clientMsgNo.isNotEmpty) {
    keys.add('cid:$clientMsgNo');
  }
  return List<String>.unmodifiable(keys);
}

String favoriteMessageKeyOf(WKMsg message) {
  final keys = favoriteMessageKeysOf(message);
  return keys.isEmpty ? '' : keys.first;
}

abstract class ChatMessageFavoriteRegistry {
  Set<String> snapshot();
  bool contains(String key);
  Future<void> markFavorited(String key);
}

class SharedPrefsChatMessageFavoriteRegistry
    implements ChatMessageFavoriteRegistry {
  SharedPrefsChatMessageFavoriteRegistry({
    String Function()? currentUidProvider,
  }) : _currentUidProvider = currentUidProvider ?? _defaultCurrentUid;

  static const String _storageKeyPrefix = 'chat.favorite.known_message_keys';

  final String Function() _currentUidProvider;

  Set<String>? _cache;
  String? _cacheStorageKey;

  static String _defaultCurrentUid() => StorageUtils.getUid()?.trim() ?? '';

  String? _storageKeyForCurrentUid() {
    final uid = _currentUidProvider().trim();
    if (uid.isEmpty) {
      return null;
    }
    return '$_storageKeyPrefix.$uid';
  }

  Set<String> _snapshotForStorageKey(String storageKey) {
    if (_cache == null || _cacheStorageKey != storageKey) {
      _cacheStorageKey = storageKey;
      _cache = {...?StorageUtils.getStringList(storageKey)};
    }
    return _cache ?? <String>{};
  }

  @override
  Set<String> snapshot() {
    final storageKey = _storageKeyForCurrentUid();
    if (storageKey == null) {
      _cacheStorageKey = null;
      _cache = null;
      return Set<String>.unmodifiable(const <String>{});
    }
    final values = _snapshotForStorageKey(storageKey);
    return Set<String>.unmodifiable(values);
  }

  @override
  bool contains(String key) {
    if (key.isEmpty) {
      return false;
    }
    return snapshot().contains(key);
  }

  @override
  Future<void> markFavorited(String key) async {
    if (key.isEmpty) {
      return;
    }
    final storageKey = _storageKeyForCurrentUid();
    if (storageKey == null) {
      _cacheStorageKey = null;
      _cache = null;
      return;
    }
    final next = {..._snapshotForStorageKey(storageKey), key};
    _cacheStorageKey = storageKey;
    _cache = next;
    await StorageUtils.setStringList(storageKey, next.toList(growable: false));
  }
}
