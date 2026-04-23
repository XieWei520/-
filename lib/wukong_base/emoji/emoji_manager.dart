import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/utils/storage_utils.dart';
import 'android_emoji_catalog.dart';

/// Emoji category
class EmojiCategory {
  final String id;
  final String name;
  final IconData icon;
  final List<String> emojis;

  const EmojiCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.emojis,
  });
}

/// Emoji pack
class EmojiPack {
  final String id;
  final String name;
  final String? coverUrl;
  final List<String> emojis;
  final bool isFavorite;
  final bool isBuiltIn;

  const EmojiPack({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.emojis,
    this.isFavorite = false,
    this.isBuiltIn = false,
  });

  EmojiPack copyWith({
    String? id,
    String? name,
    String? coverUrl,
    List<String>? emojis,
    bool? isFavorite,
    bool? isBuiltIn,
  }) {
    return EmojiPack(
      id: id ?? this.id,
      name: name ?? this.name,
      coverUrl: coverUrl ?? this.coverUrl,
      emojis: emojis ?? this.emojis,
      isFavorite: isFavorite ?? this.isFavorite,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'cover_url': coverUrl,
      'emojis': emojis,
      'is_favorite': isFavorite,
      'is_built_in': isBuiltIn,
    };
  }

  factory EmojiPack.fromJson(Map<String, dynamic> json) {
    final emojis = (json['emojis'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    return EmojiPack(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '鏈懡鍚嶈〃鎯呭寘',
      coverUrl: json['cover_url']?.toString(),
      emojis: emojis,
      isFavorite: json['is_favorite'] == true || json['is_favorite'] == 1,
      isBuiltIn: json['is_built_in'] == true || json['is_built_in'] == 1,
    );
  }
}

class _EmojiGroupMeta {
  const _EmojiGroupMeta({
    required this.categoryName,
    required this.packName,
    required this.icon,
  });

  final String categoryName;
  final String packName;
  final IconData icon;
}

/// Emoji manager
class EmojiManager {
  EmojiManager._();
  static final EmojiManager _instance = EmojiManager._();
  static EmojiManager get instance => _instance;

  static const String _packsStorageKey = 'wk_emoji_packs_v2';
  static const String _recentStorageKey = 'wk_emoji_recent_v1';
  static const int _maxRecentEmojis = 30;

  bool _initialized = false;
  List<EmojiCategory> _categories = [];
  final List<EmojiPack> _packs = [];
  List<String> _recentEmojis = [];

  /// Default emoji categories
  static final List<EmojiCategory> defaultCategories =
      _buildDefaultCategories();

  static final List<EmojiPack> defaultPacks = _buildDefaultPacks();

  static List<EmojiCategory> _buildDefaultCategories() {
    final categories = androidEmojiCatalog.groupIds
        .map((groupId) {
          final meta = _groupMetaFor(groupId);
          final tags = androidEmojiCatalog
              .entriesForGroup(groupId)
              .map((entry) => entry.tag)
              .toList(growable: false);
          return EmojiCategory(
            id: groupId,
            name: meta.categoryName,
            icon: meta.icon,
            emojis: tags,
          );
        })
        .toList(growable: false);
    return List<EmojiCategory>.unmodifiable(categories);
  }

  static List<EmojiPack> _buildDefaultPacks() {
    final packs = <EmojiPack>[];
    for (final groupId in androidEmojiCatalog.groupIds) {
      final meta = _groupMetaFor(groupId);
      final entries = androidEmojiCatalog.entriesForGroup(groupId);
      final tags = entries.map((entry) => entry.tag).toList(growable: false);
      if (tags.isEmpty) {
        continue;
      }
      packs.add(
        EmojiPack(
          id: 'builtin_android_$groupId',
          name: meta.packName,
          coverUrl: entries.first.assetPath,
          emojis: tags,
          isBuiltIn: true,
        ),
      );
    }
    return List<EmojiPack>.unmodifiable(packs);
  }

  static _EmojiGroupMeta _groupMetaFor(String groupId) {
    switch (groupId) {
      case '0':
        return const _EmojiGroupMeta(
          categoryName: 'Smileys',
          packName: 'Classic',
          icon: Icons.sentiment_satisfied_alt,
        );
      case '1':
        return const _EmojiGroupMeta(
          categoryName: 'Gestures',
          packName: 'Gestures',
          icon: Icons.thumb_up_alt,
        );
      case '2':
        return const _EmojiGroupMeta(
          categoryName: 'Symbols',
          packName: 'Symbols',
          icon: Icons.favorite,
        );
      default:
        return const _EmojiGroupMeta(
          categoryName: 'Emojis',
          packName: 'Emoji Pack',
          icon: Icons.emoji_emotions,
        );
    }
  }

  /// Get all categories
  List<EmojiCategory> get categories =>
      _categories.isNotEmpty ? _categories : defaultCategories;

  /// Get all packs
  List<EmojiPack> get packs => List<EmojiPack>.unmodifiable(_packs);

  /// Get recent emojis
  List<String> get recentEmojis => List<String>.unmodifiable(_recentEmojis);

  void debugResetForTest() {
    _initialized = false;
    _categories = <EmojiCategory>[];
    _packs.clear();
    _recentEmojis = <String>[];
  }

  /// Initialize the manager
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _categories = List<EmojiCategory>.from(defaultCategories);
    await _loadPacks();
    await _loadRecentEmojis();
    _initialized = true;
  }

  Future<void> _loadPacks() async {
    final storedPacks = _readStoredPacks();
    final reconciledPacks = _reconcileWithBuiltInDefaults(storedPacks);
    _packs
      ..clear()
      ..addAll(reconciledPacks);
    if (!_arePacksEqual(storedPacks, reconciledPacks)) {
      await _persistPacks();
    }
  }

  List<EmojiPack> _reconcileWithBuiltInDefaults(List<EmojiPack> storedPacks) {
    final defaultPackById = <String, EmojiPack>{
      for (final pack in defaultPacks) pack.id: pack,
    };
    final storedById = <String, EmojiPack>{
      for (final pack in storedPacks) pack.id: pack,
    };

    final reconciled = <EmojiPack>[
      for (final pack in storedPacks)
        if (!defaultPackById.containsKey(pack.id)) pack,
    ];
    for (final builtInDefault in defaultPacks) {
      final storedBuiltIn = storedById[builtInDefault.id];
      reconciled.add(
        builtInDefault.copyWith(
          isFavorite: storedBuiltIn?.isFavorite ?? builtInDefault.isFavorite,
        ),
      );
    }
    return reconciled;
  }

  bool _arePacksEqual(List<EmojiPack> left, List<EmojiPack> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (jsonEncode(left[i].toJson()) != jsonEncode(right[i].toJson())) {
        return false;
      }
    }
    return true;
  }

  Future<void> _loadRecentEmojis() async {
    _recentEmojis = StorageUtils.getStringList(_recentStorageKey) ?? <String>[];
  }

  Future<void> addPack({
    required String id,
    required String name,
    required List<String> emojis,
    String? coverUrl,
  }) async {
    final filtered = emojis
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (filtered.isEmpty) {
      return;
    }
    _packs.insert(
      0,
      EmojiPack(
        id: id,
        name: name.trim().isEmpty ? '鎴戠殑琛ㄦ儏鍖?' : name.trim(),
        coverUrl: coverUrl?.trim().isNotEmpty == true
            ? coverUrl!.trim()
            : filtered.first,
        emojis: filtered,
      ),
    );
    await _persistPacks();
  }

  Future<void> deletePack(String packId) async {
    _packs.removeWhere((pack) => pack.id == packId && !pack.isBuiltIn);
    await _persistPacks();
  }

  Future<void> togglePackFavorite(String packId) async {
    final index = _packs.indexWhere((item) => item.id == packId);
    if (index == -1) {
      return;
    }
    _packs[index] = _packs[index].copyWith(
      isFavorite: !_packs[index].isFavorite,
    );
    await _persistPacks();
  }

  void addToRecent(String emoji) {
    final value = emoji.trim();
    if (value.isEmpty) {
      return;
    }
    _recentEmojis.remove(value);
    _recentEmojis.insert(0, value);
    if (_recentEmojis.length > _maxRecentEmojis) {
      _recentEmojis = _recentEmojis.sublist(0, _maxRecentEmojis);
    }
    _saveRecentEmojis();
  }

  Future<void> _saveRecentEmojis() async {
    await StorageUtils.setStringList(_recentStorageKey, _recentEmojis);
  }

  List<String> search(String query) {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return <String>[];
    }

    final results = <String>[];
    for (final category in categories) {
      for (final emoji in category.emojis) {
        if (emoji.contains(keyword)) {
          results.add(emoji);
        }
      }
    }
    for (final pack in _packs) {
      for (final emoji in pack.emojis) {
        if (emoji.contains(keyword) && !results.contains(emoji)) {
          results.add(emoji);
        }
      }
    }
    return results;
  }

  List<String> get favoriteEmojis {
    final favorites = <String>[];
    for (final pack in _packs) {
      if (pack.isFavorite) {
        favorites.addAll(pack.emojis);
      }
    }
    return favorites;
  }

  Future<void> _persistPacks() async {
    final rawList = _packs.map((pack) => jsonEncode(pack.toJson())).toList();
    await StorageUtils.setStringList(_packsStorageKey, rawList);
  }

  List<EmojiPack> _readStoredPacks() {
    final rawList = StorageUtils.getStringList(_packsStorageKey) ?? <String>[];
    final parsed = <EmojiPack>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final pack = EmojiPack.fromJson(Map<String, dynamic>.from(decoded));
        if (pack.id.trim().isEmpty || pack.emojis.isEmpty) {
          continue;
        }
        parsed.add(pack);
      } catch (_) {
        continue;
      }
    }
    return parsed;
  }
}
