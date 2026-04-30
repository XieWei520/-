import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../data/models/group.dart';
import '../../data/models/user.dart';

typedef PersonalConversationInfoLoader = Future<UserInfo?> Function(String uid);
typedef GroupConversationInfoLoader =
    Future<GroupInfo?> Function(String groupNo);

class ConversationMetadataResolver {
  ConversationMetadataResolver({
    this.cacheTtl = const Duration(minutes: 5),
    int maxCacheEntries = defaultMaxCacheEntries,
    DateTime Function()? now,
  }) : _maxCacheEntries = maxCacheEntries < 1 ? 1 : maxCacheEntries,
       _now = now ?? DateTime.now;

  static const int defaultMaxCacheEntries = 512;

  final Duration cacheTtl;
  final int _maxCacheEntries;
  final DateTime Function() _now;
  final Map<String, Future<UserInfo?>> _personalInFlight =
      <String, Future<UserInfo?>>{};
  final Map<String, Future<GroupInfo?>> _groupInFlight =
      <String, Future<GroupInfo?>>{};
  final LinkedHashMap<String, _CacheEntry<UserInfo?>> _personalCache =
      LinkedHashMap<String, _CacheEntry<UserInfo?>>();
  final LinkedHashMap<String, _CacheEntry<GroupInfo?>> _groupCache =
      LinkedHashMap<String, _CacheEntry<GroupInfo?>>();

  @visibleForTesting
  int get personalCacheSizeForTesting => _personalCache.length;

  @visibleForTesting
  int get groupCacheSizeForTesting => _groupCache.length;

  Future<UserInfo?> loadPersonalInfo(
    String uid,
    PersonalConversationInfoLoader loader,
  ) {
    final key = uid.trim();
    if (key.isEmpty) {
      return Future<UserInfo?>.value(null);
    }
    final cached = _readCache(_personalCache, key);
    if (cached != null) {
      return Future<UserInfo?>.value(cached.value);
    }
    final inFlight = _personalInFlight[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = loader(key)
        .then<UserInfo?>((value) {
          _writeCache(
            _personalCache,
            key,
            _CacheEntry<UserInfo?>(value, _now().add(cacheTtl)),
          );
          return value;
        })
        .catchError((Object _, StackTrace _) => null);
    _personalInFlight[key] = future;
    future.whenComplete(() {
      if (identical(_personalInFlight[key], future)) {
        _personalInFlight.remove(key);
      }
    });
    return future;
  }

  Future<GroupInfo?> loadGroupInfo(
    String groupNo,
    GroupConversationInfoLoader loader,
  ) {
    final key = groupNo.trim();
    if (key.isEmpty) {
      return Future<GroupInfo?>.value(null);
    }
    final cached = _readCache(_groupCache, key);
    if (cached != null) {
      return Future<GroupInfo?>.value(cached.value);
    }
    final inFlight = _groupInFlight[key];
    if (inFlight != null) {
      return inFlight;
    }

    final future = loader(key)
        .then<GroupInfo?>((value) {
          _writeCache(
            _groupCache,
            key,
            _CacheEntry<GroupInfo?>(value, _now().add(cacheTtl)),
          );
          return value;
        })
        .catchError((Object _, StackTrace _) => null);
    _groupInFlight[key] = future;
    future.whenComplete(() {
      if (identical(_groupInFlight[key], future)) {
        _groupInFlight.remove(key);
      }
    });
    return future;
  }

  void clear() {
    _personalInFlight.clear();
    _groupInFlight.clear();
    _personalCache.clear();
    _groupCache.clear();
  }

  _CacheEntry<T>? _readCache<T>(
    LinkedHashMap<String, _CacheEntry<T>> cache,
    String key,
  ) {
    final entry = cache.remove(key);
    if (entry == null) {
      return null;
    }
    if (!entry.expiresAt.isAfter(_now())) {
      return null;
    }
    cache[key] = entry;
    return entry;
  }

  void _writeCache<T>(
    LinkedHashMap<String, _CacheEntry<T>> cache,
    String key,
    _CacheEntry<T> entry,
  ) {
    cache.remove(key);
    while (cache.length >= _maxCacheEntries && cache.isNotEmpty) {
      cache.remove(cache.keys.first);
    }
    cache[key] = entry;
  }
}

class _CacheEntry<T> {
  const _CacheEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;
}
