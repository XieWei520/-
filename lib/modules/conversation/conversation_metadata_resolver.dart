import 'dart:async';

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

  final Map<String, _InFlight<UserInfo>> _personalInFlight =
      <String, _InFlight<UserInfo>>{};
  final Map<String, _CacheEntry<UserInfo>> _personalCache =
      <String, _CacheEntry<UserInfo>>{};
  final Map<String, _InFlight<GroupInfo>> _groupInFlight =
      <String, _InFlight<GroupInfo>>{};
  final Map<String, _CacheEntry<GroupInfo>> _groupCache =
      <String, _CacheEntry<GroupInfo>>{};
  int _generation = 0;

  /// Loads personal metadata, resolving loader failures to null.
  ///
  /// Successful non-null values are cached until [ttl] expires or [clear] is
  /// called.
  Future<UserInfo?> loadPersonal(String uid) {
    return _loadMetadata<UserInfo>(
      id: uid,
      cache: _personalCache,
      inFlight: _personalInFlight,
      loader: _personalLoader,
    );
  }

  /// Loads group metadata, resolving loader failures to null.
  ///
  /// Successful non-null values are cached until [ttl] expires or [clear] is
  /// called.
  Future<GroupInfo?> loadGroup(String groupNo) {
    return _loadMetadata<GroupInfo>(
      id: groupNo,
      cache: _groupCache,
      inFlight: _groupInFlight,
      loader: _groupLoader,
    );
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

  Future<T?> _loadMetadata<T>({
    required String id,
    required Map<String, _CacheEntry<T>> cache,
    required Map<String, _InFlight<T>> inFlight,
    required Future<T?> Function(String id) loader,
  }) {
    final normalized = id.trim();
    if (normalized.isEmpty) return Future<T?>.value(null);
    final cached = _readCache(cache, normalized);
    if (cached != null) return Future<T?>.value(cached);
    final existing = inFlight[normalized];
    if (existing != null) return existing.future;

    final generation = _generation;
    final entry = _InFlight<T>();
    inFlight[normalized] = entry;

    Future<T?>.sync(() => loader(normalized))
        .then<void>(
          (value) {
            if (generation == _generation && value != null) {
              cache[normalized] = _CacheEntry<T>(
                value: value,
                expiresAt: _now().add(ttl),
              );
            }
            entry.complete(value);
          },
          onError: (_, _) {
            entry.complete(null);
          },
        )
        .whenComplete(() {
          if (generation == _generation &&
              identical(inFlight[normalized], entry)) {
            inFlight.remove(normalized);
          }
        });

    return entry.future;
  }
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.expiresAt});
  final T value;
  final DateTime expiresAt;
}

class _InFlight<T> {
  _InFlight() : _completer = Completer<T?>();

  final Completer<T?> _completer;

  Future<T?> get future => _completer.future;

  void complete(T? value) {
    _completer.complete(value);
  }
}
