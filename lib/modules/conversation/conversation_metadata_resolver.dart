import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../data/models/group.dart';
import '../../data/models/user.dart';

typedef PersonalConversationInfoLoader = Future<UserInfo?> Function(String uid);
typedef GroupConversationInfoLoader =
    Future<GroupInfo?> Function(String groupNo);
typedef ConversationPersonalLoader = Future<UserInfo?> Function(String uid);
typedef ConversationGroupLoader = Future<GroupInfo?> Function(String groupNo);
typedef ConversationMetadataClock = DateTime Function();

class ConversationMetadataResolver {
  ConversationMetadataResolver({
    PersonalConversationInfoLoader? personalLoader,
    GroupConversationInfoLoader? groupLoader,
    Duration? cacheTtl,
    Duration? ttl,
    int maxCacheEntries = defaultMaxCacheEntries,
    ConversationMetadataClock? now,
  }) : cacheTtl = cacheTtl ?? ttl ?? const Duration(minutes: 5),
       _defaultPersonalLoader = personalLoader,
       _defaultGroupLoader = groupLoader,
       _maxCacheEntries = maxCacheEntries < 1 ? 1 : maxCacheEntries,
       _now = now ?? DateTime.now;

  static const int defaultMaxCacheEntries = 512;

  final Duration cacheTtl;
  Duration get ttl => cacheTtl;
  final PersonalConversationInfoLoader? _defaultPersonalLoader;
  final GroupConversationInfoLoader? _defaultGroupLoader;
  final int _maxCacheEntries;
  final ConversationMetadataClock _now;
  final Map<String, _InFlight<UserInfo>> _personalInFlight =
      <String, _InFlight<UserInfo>>{};
  final Map<String, _InFlight<GroupInfo>> _groupInFlight =
      <String, _InFlight<GroupInfo>>{};
  final LinkedHashMap<String, _CacheEntry<UserInfo>> _personalCache =
      LinkedHashMap<String, _CacheEntry<UserInfo>>();
  final LinkedHashMap<String, _CacheEntry<GroupInfo>> _groupCache =
      LinkedHashMap<String, _CacheEntry<GroupInfo>>();
  int _generation = 0;

  @visibleForTesting
  int get personalCacheSizeForTesting => _personalCache.length;

  @visibleForTesting
  int get groupCacheSizeForTesting => _groupCache.length;

  Future<UserInfo?> loadPersonal(String uid) {
    final loader = _defaultPersonalLoader;
    if (loader == null) {
      return Future<UserInfo?>.value(null);
    }
    return loadPersonalInfo(uid, loader);
  }

  Future<GroupInfo?> loadGroup(String groupNo) {
    final loader = _defaultGroupLoader;
    if (loader == null) {
      return Future<GroupInfo?>.value(null);
    }
    return loadGroupInfo(groupNo, loader);
  }

  Future<UserInfo?> loadPersonalInfo(
    String uid,
    PersonalConversationInfoLoader loader,
  ) {
    return _loadMetadata<UserInfo>(
      id: uid,
      cache: _personalCache,
      inFlight: _personalInFlight,
      loader: loader,
    );
  }

  Future<GroupInfo?> loadGroupInfo(
    String groupNo,
    GroupConversationInfoLoader loader,
  ) {
    return _loadMetadata<GroupInfo>(
      id: groupNo,
      cache: _groupCache,
      inFlight: _groupInFlight,
      loader: loader,
    );
  }

  void clear() {
    _generation += 1;
    _personalInFlight.clear();
    _groupInFlight.clear();
    _personalCache.clear();
    _groupCache.clear();
  }

  T? _readCache<T>(LinkedHashMap<String, _CacheEntry<T>> cache, String key) {
    final entry = cache.remove(key);
    if (entry == null) {
      return null;
    }
    if (!_now().isBefore(entry.expiresAt)) {
      return null;
    }
    cache[key] = entry;
    return entry.value;
  }

  void _writeCache<T>(
    LinkedHashMap<String, _CacheEntry<T>> cache,
    String key,
    T value,
  ) {
    cache.remove(key);
    while (cache.length >= _maxCacheEntries && cache.isNotEmpty) {
      cache.remove(cache.keys.first);
    }
    cache[key] = _CacheEntry<T>(value: value, expiresAt: _now().add(cacheTtl));
  }

  Future<T?> _loadMetadata<T>({
    required String id,
    required LinkedHashMap<String, _CacheEntry<T>> cache,
    required Map<String, _InFlight<T>> inFlight,
    required Future<T?> Function(String id) loader,
  }) {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return Future<T?>.value(null);
    }
    final cached = _readCache(cache, normalized);
    if (cached != null) {
      return Future<T?>.value(cached);
    }
    final existing = inFlight[normalized];
    if (existing != null) {
      return existing.future;
    }

    final generation = _generation;
    final entry = _InFlight<T>();
    inFlight[normalized] = entry;

    Future<T?>.sync(() => loader(normalized))
        .then<void>(
          (value) {
            if (generation == _generation && value != null) {
              _writeCache(cache, normalized, value);
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
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }
}
