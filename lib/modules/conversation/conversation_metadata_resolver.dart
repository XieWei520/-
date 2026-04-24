import '../../data/models/group.dart';
import '../../data/models/user.dart';

typedef ConversationPersonalLoader = Future<UserInfo?> Function(String uid);
typedef ConversationGroupLoader = Future<GroupInfo?> Function(String groupNo);
typedef ConversationMetadataClock = DateTime Function();

class ConversationMetadataResolver {
  ConversationMetadataResolver({
    required ConversationPersonalLoader personalLoader,
    required ConversationGroupLoader groupLoader,
    this.ttl = const Duration(minutes: 10),
    ConversationMetadataClock? now,
  }) : _personalLoader = personalLoader,
       _groupLoader = groupLoader,
       _now = now ?? DateTime.now;

  final ConversationPersonalLoader _personalLoader;
  final ConversationGroupLoader _groupLoader;
  final ConversationMetadataClock _now;
  final Duration ttl;

  final Map<String, Future<UserInfo?>> _personalInFlight =
      <String, Future<UserInfo?>>{};
  final Map<String, _CacheEntry<UserInfo>> _personalCache =
      <String, _CacheEntry<UserInfo>>{};
  final Map<String, Future<GroupInfo?>> _groupInFlight =
      <String, Future<GroupInfo?>>{};
  final Map<String, _CacheEntry<GroupInfo>> _groupCache =
      <String, _CacheEntry<GroupInfo>>{};
  int _generation = 0;

  /// Loads personal metadata, resolving loader failures to null.
  ///
  /// Successful non-null values are cached until [ttl] expires or [clear] is
  /// called.
  Future<UserInfo?> loadPersonal(String uid) {
    final normalized = uid.trim();
    if (normalized.isEmpty) return Future<UserInfo?>.value(null);
    final cached = _readCache(_personalCache, normalized);
    if (cached != null) return Future<UserInfo?>.value(cached);
    final existing = _personalInFlight[normalized];
    if (existing != null) return existing;
    final generation = _generation;
    late final Future<UserInfo?> future;
    future = _personalLoader(normalized)
        .then((value) {
          if (generation == _generation && value != null) {
            _personalCache[normalized] = _CacheEntry<UserInfo>(
              value: value,
              expiresAt: _now().add(ttl),
            );
          }
          return value;
        }, onError: (_, _) => null)
        .whenComplete(() {
          if (generation == _generation &&
              identical(_personalInFlight[normalized], future)) {
            _personalInFlight.remove(normalized);
          }
        });
    _personalInFlight[normalized] = future;
    return future;
  }

  /// Loads group metadata, resolving loader failures to null.
  ///
  /// Successful non-null values are cached until [ttl] expires or [clear] is
  /// called.
  Future<GroupInfo?> loadGroup(String groupNo) {
    final normalized = groupNo.trim();
    if (normalized.isEmpty) return Future<GroupInfo?>.value(null);
    final cached = _readCache(_groupCache, normalized);
    if (cached != null) return Future<GroupInfo?>.value(cached);
    final existing = _groupInFlight[normalized];
    if (existing != null) return existing;
    final generation = _generation;
    late final Future<GroupInfo?> future;
    future = _groupLoader(normalized)
        .then((value) {
          if (generation == _generation && value != null) {
            _groupCache[normalized] = _CacheEntry<GroupInfo>(
              value: value,
              expiresAt: _now().add(ttl),
            );
          }
          return value;
        }, onError: (_, _) => null)
        .whenComplete(() {
          if (generation == _generation &&
              identical(_groupInFlight[normalized], future)) {
            _groupInFlight.remove(normalized);
          }
        });
    _groupInFlight[normalized] = future;
    return future;
  }

  void clear() {
    _generation += 1;
    _personalInFlight.clear();
    _personalCache.clear();
    _groupInFlight.clear();
    _groupCache.clear();
  }

  T? _readCache<T>(Map<String, _CacheEntry<T>> cache, String key) {
    final entry = cache[key];
    if (entry == null) return null;
    if (!_now().isBefore(entry.expiresAt)) {
      cache.remove(key);
      return null;
    }
    return entry.value;
  }
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiresAt});
  final T value;
  final DateTime expiresAt;
}
