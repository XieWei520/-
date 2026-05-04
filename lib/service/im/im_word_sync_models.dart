class SensitiveWordsSnapshot {
  const SensitiveWordsSnapshot({
    this.tips = '',
    this.version = 0,
    this.list = const <String>[],
  });

  final String tips;
  final int version;
  final List<String> list;

  bool get isEmpty => tips.trim().isEmpty || list.isEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tips': tips,
      'version': version,
      'list': list,
    };
  }

  factory SensitiveWordsSnapshot.fromDynamic(dynamic raw) {
    final map = _asMap(raw);
    final words = map['list'] is List
        ? (map['list'] as List<dynamic>)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return SensitiveWordsSnapshot(
      tips: (map['tips'] ?? '').toString(),
      version: _readInt(map['version']),
      list: words,
    );
  }
}

class ProhibitWordEntry {
  const ProhibitWordEntry({
    required this.sid,
    required this.content,
    required this.isDeleted,
    required this.version,
    required this.createdAt,
  });

  final int sid;
  final String content;
  final int isDeleted;
  final int version;
  final String createdAt;

  Map<String, Object?> toDbMap() {
    return <String, Object?>{
      'sid': sid,
      'content': content,
      'is_deleted': isDeleted,
      'version': version,
      'created_at': createdAt,
      'word': content,
    };
  }

  factory ProhibitWordEntry.fromDynamic(dynamic raw) {
    final map = _asMap(raw);
    return ProhibitWordEntry(
      sid: _readInt(map['sid'] ?? map['id']),
      content: (map['content'] ?? map['word'] ?? '').toString(),
      isDeleted: _readInt(map['is_deleted']),
      version: _readInt(map['version']),
      createdAt: (map['created_at'] ?? '').toString(),
    );
  }
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return Map<String, dynamic>.from(raw);
  }
  return <String, dynamic>{};
}

int _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
