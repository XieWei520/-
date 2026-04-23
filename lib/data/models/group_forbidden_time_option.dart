class GroupForbiddenTimeOption {
  final String text;
  final int key;

  const GroupForbiddenTimeOption({required this.text, required this.key});

  factory GroupForbiddenTimeOption.fromJson(Map<String, dynamic> json) {
    return GroupForbiddenTimeOption(
      text: json['text']?.toString() ?? '',
      key: _parseKey(json['key']),
    );
  }

  static int _parseKey(dynamic rawKey) {
    if (rawKey is num) {
      return rawKey.toInt();
    }
    if (rawKey is String) {
      final normalized = rawKey.trim();
      if (normalized.isEmpty) {
        return 0;
      }
      return int.tryParse(normalized) ??
          double.tryParse(normalized)?.toInt() ??
          0;
    }
    return 0;
  }
}
