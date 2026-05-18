import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:wukongimfluttersdk/wkim.dart';

import '../../core/utils/storage_utils.dart';
import '../../wukong_base/db/db_helper.dart';
import 'im_connection_service.dart';
import 'im_word_sync_models.dart';

const String _sensitiveWordsCacheKey = 'wk_sensitive_words';
const String _sensitiveWordsVersionKey = 'wk_sensitive_words_version';

abstract interface class ImWordSyncStore {
  bool get usesLocalPersistence;

  SensitiveWordsSnapshot loadSensitiveWordsSnapshot();

  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot);

  Future<void> loadStoredWordCaches();

  Future<int> getMaxProhibitWordVersion();

  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words);

  List<ProhibitWordEntry> resolveProhibitWords();
}

class WkImWordSyncStore implements ImWordSyncStore {
  WkImWordSyncStore({bool Function()? localPersistenceResolver})
    : _localPersistenceResolver =
          localPersistenceResolver ?? _defaultLocalPersistenceResolver;

  final bool Function() _localPersistenceResolver;
  SensitiveWordsSnapshot _sensitiveWordsSnapshot =
      const SensitiveWordsSnapshot();
  List<ProhibitWordEntry>? _cachedProhibitWords;

  @override
  bool get usesLocalPersistence => _localPersistenceResolver();

  @override
  SensitiveWordsSnapshot loadSensitiveWordsSnapshot() {
    if (!_sensitiveWordsSnapshot.isEmpty) {
      return _sensitiveWordsSnapshot;
    }
    final storedVersion = StorageUtils.getInt(_sensitiveWordsVersionKey) ?? 0;
    final raw = StorageUtils.getString(_sensitiveWordsCacheKey)?.trim() ?? '';
    if (raw.isEmpty) {
      if (storedVersion > 0) {
        _sensitiveWordsSnapshot = SensitiveWordsSnapshot(
          version: storedVersion,
        );
      }
      return _sensitiveWordsSnapshot;
    }
    try {
      final decoded = jsonDecode(raw);
      _sensitiveWordsSnapshot = SensitiveWordsSnapshot.fromDynamic(decoded);
      if (_sensitiveWordsSnapshot.version <= 0 && storedVersion > 0) {
        _sensitiveWordsSnapshot = SensitiveWordsSnapshot(
          tips: _sensitiveWordsSnapshot.tips,
          version: storedVersion,
          list: _sensitiveWordsSnapshot.list,
        );
      }
    } catch (_) {
      _sensitiveWordsSnapshot = SensitiveWordsSnapshot(version: storedVersion);
    }
    return _sensitiveWordsSnapshot;
  }

  @override
  Future<void> applySensitiveWordsSync(SensitiveWordsSnapshot snapshot) async {
    await StorageUtils.setInt(_sensitiveWordsVersionKey, snapshot.version);
    if (snapshot.tips.trim().isEmpty) {
      return;
    }
    _sensitiveWordsSnapshot = snapshot;
    await StorageUtils.setString(
      _sensitiveWordsCacheKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  @override
  Future<void> loadStoredWordCaches() async {
    loadSensitiveWordsSnapshot();
    if (!usesLocalPersistence) {
      _cachedProhibitWords = const <ProhibitWordEntry>[];
      return;
    }
    _cachedProhibitWords = await DBHelper.instance.getProhibitWords();
  }

  @override
  Future<int> getMaxProhibitWordVersion() {
    return DBHelper.instance.getMaxProhibitWordVersion();
  }

  @override
  Future<void> applyProhibitWordsSync(List<ProhibitWordEntry> words) async {
    if (!usesLocalPersistence) {
      _cachedProhibitWords = words;
      return;
    }
    await DBHelper.instance.saveProhibitWords(words);
    _cachedProhibitWords = await DBHelper.instance.getProhibitWords();
  }

  @override
  List<ProhibitWordEntry> resolveProhibitWords() {
    return _cachedProhibitWords ?? const <ProhibitWordEntry>[];
  }
}

bool _defaultLocalPersistenceResolver() {
  return ImConnectionService.shouldUseLocalPersistence(
    isWeb: kIsWeb,
    sdkAppMode: WKIM.shared.isApp(),
  );
}
