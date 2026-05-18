Map<String, List<T>> groupByMessageId<T>(
  Iterable<T> items,
  String Function(T item) messageIdOf,
) {
  final grouped = <String, List<T>>{};
  for (final item in items) {
    final messageId = messageIdOf(item).trim();
    if (messageId.isEmpty) {
      continue;
    }
    grouped.putIfAbsent(messageId, () => <T>[]).add(item);
  }
  return grouped;
}

Map<String, T> indexByNonEmptyKey<T>(
  Iterable<T> items,
  String Function(T item) keyOf,
) {
  final indexed = <String, T>{};
  for (final item in items) {
    final key = keyOf(item).trim();
    if (key.isEmpty) {
      continue;
    }
    indexed.putIfAbsent(key, () => item);
  }
  return indexed;
}
