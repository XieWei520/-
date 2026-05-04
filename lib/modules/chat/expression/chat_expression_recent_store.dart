import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'chat_expression_models.dart';

class ChatExpressionRecentStore {
  static const String _storageKey = 'chat_expression_recent_v1';
  static const int _maxItems = 30;

  Future<List<ChatExpressionRecentRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey) ?? const <String>[];
    return rawList
        .map((item) => jsonDecode(item) as Map<String, dynamic>)
        .map(ChatExpressionRecentRecord.fromJson)
        .toList(growable: false);
  }

  Future<void> save(List<ChatExpressionRecentRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey,
      records
          .take(_maxItems)
          .map((item) => jsonEncode(item.toJson()))
          .toList(growable: false),
    );
  }

  Future<void> remember(ChatExpressionRecentRecord nextRecord) async {
    final existing = await load();
    final deduped = <ChatExpressionRecentRecord>[
      nextRecord,
      for (final item in existing)
        if (item.logicalKey != nextRecord.logicalKey) item,
    ];
    await save(deduped);
  }
}
