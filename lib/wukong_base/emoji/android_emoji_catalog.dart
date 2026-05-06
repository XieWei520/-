import 'dart:collection';

part 'android_emoji_catalog.g.dart';

class AndroidEmojiEntry {
  const AndroidEmojiEntry({
    required this.id,
    required this.groupId,
    required this.tag,
    required this.assetPath,
    this.baseId,
  });

  final String id;
  final String groupId;
  final String tag;
  final String assetPath;
  final String? baseId;

  bool get isColorVariant => id.contains('_color_');
}

class AndroidEmojiCatalog {
  AndroidEmojiCatalog(Iterable<AndroidEmojiEntry> entries)
    : this._(List<AndroidEmojiEntry>.unmodifiable(entries));

  AndroidEmojiCatalog._(this._entries)
    : _entriesById = _buildEntriesById(_entries),
      _entriesByTag = _buildEntriesByTag(_entries),
      _entriesForGroup = _buildEntriesForGroup(_entries),
      _groupIds = _buildGroupIds(_entries),
      _tagsByFirstCodeUnit = _buildTagsByFirstCodeUnit(_entries);

  final List<AndroidEmojiEntry> _entries;
  final Map<String, AndroidEmojiEntry> _entriesById;
  final Map<String, AndroidEmojiEntry> _entriesByTag;
  final Map<String, List<AndroidEmojiEntry>> _entriesForGroup;
  final List<String> _groupIds;
  final Map<int, List<String>> _tagsByFirstCodeUnit;

  List<AndroidEmojiEntry> get entries => _entries;

  List<String> get groupIds => _groupIds;

  AndroidEmojiEntry? lookupById(String id) => _entriesById[id];

  AndroidEmojiEntry? lookupByTag(String tag) => _entriesByTag[tag];

  bool canStartEmojiAt(String text, int start) {
    if (start < 0 || start >= text.length) {
      return false;
    }
    return _tagsByFirstCodeUnit.containsKey(text.codeUnitAt(start));
  }

  AndroidEmojiEntry? longestMatchAt(String text, int start) {
    if (start < 0 || start >= text.length) {
      return null;
    }

    final candidateTags = _tagsByFirstCodeUnit[text.codeUnitAt(start)];
    if (candidateTags == null) {
      return null;
    }

    for (final tag in candidateTags) {
      if (!text.startsWith(tag, start)) {
        continue;
      }
      final entry = _entriesByTag[tag];
      if (entry != null) {
        return entry;
      }
    }

    return null;
  }

  List<AndroidEmojiEntry> entriesForGroup(String groupId) =>
      _entriesForGroup[groupId] ?? const <AndroidEmojiEntry>[];

  static Map<String, AndroidEmojiEntry> _buildEntriesById(
    Iterable<AndroidEmojiEntry> entries,
  ) {
    final map = <String, AndroidEmojiEntry>{};
    for (final entry in entries) {
      final existing = map[entry.id];
      if (existing != null) {
        throw StateError(
          'Duplicate Android emoji id "${entry.id}" for tags '
          '"${existing.tag}" and "${entry.tag}".',
        );
      }
      map[entry.id] = entry;
    }
    return UnmodifiableMapView<String, AndroidEmojiEntry>(map);
  }

  static Map<String, AndroidEmojiEntry> _buildEntriesByTag(
    Iterable<AndroidEmojiEntry> entries,
  ) {
    final map = <String, AndroidEmojiEntry>{};
    for (final entry in entries) {
      final existing = map[entry.tag];
      if (existing != null) {
        throw StateError(
          'Duplicate Android emoji tag "${entry.tag}" for ids '
          '"${existing.id}" and "${entry.id}".',
        );
      }
      map[entry.tag] = entry;
    }
    return UnmodifiableMapView<String, AndroidEmojiEntry>(map);
  }

  static Map<String, List<AndroidEmojiEntry>> _buildEntriesForGroup(
    Iterable<AndroidEmojiEntry> entries,
  ) {
    final map = <String, List<AndroidEmojiEntry>>{};
    for (final entry in entries) {
      if (entry.isColorVariant) {
        continue;
      }
      map.putIfAbsent(entry.groupId, () => <AndroidEmojiEntry>[]).add(entry);
    }
    return UnmodifiableMapView<String, List<AndroidEmojiEntry>>(
      <String, List<AndroidEmojiEntry>>{
        for (final item in map.entries)
          item.key: List<AndroidEmojiEntry>.unmodifiable(item.value),
      },
    );
  }

  static List<String> _buildGroupIds(Iterable<AndroidEmojiEntry> entries) {
    final groups = SplayTreeSet<String>(_compareGroupIds);
    for (final entry in entries) {
      groups.add(entry.groupId);
    }
    return List<String>.unmodifiable(groups);
  }

  static Map<int, List<String>> _buildTagsByFirstCodeUnit(
    Iterable<AndroidEmojiEntry> entries,
  ) {
    final tagsByFirstCodeUnit = <int, List<String>>{};
    for (final entry in entries) {
      final tag = entry.tag;
      if (tag.isEmpty) {
        continue;
      }
      tagsByFirstCodeUnit
          .putIfAbsent(tag.codeUnitAt(0), () => <String>[])
          .add(tag);
    }
    return UnmodifiableMapView<int, List<String>>(<int, List<String>>{
      for (final item in tagsByFirstCodeUnit.entries)
        item.key: _sortTagsByLength(item.value),
    });
  }

  static List<String> _sortTagsByLength(Iterable<String> tags) {
    final sortedTags = tags.toSet().toList();
    sortedTags.sort((a, b) {
      final byLength = b.length.compareTo(a.length);
      if (byLength != 0) {
        return byLength;
      }
      return a.compareTo(b);
    });
    return List<String>.unmodifiable(sortedTags);
  }

  static int _compareGroupIds(String left, String right) {
    final leftInt = int.tryParse(left);
    final rightInt = int.tryParse(right);
    if (leftInt != null && rightInt != null) {
      return leftInt.compareTo(rightInt);
    }
    if (leftInt != null) {
      return -1;
    }
    if (rightInt != null) {
      return 1;
    }
    return left.compareTo(right);
  }
}

final AndroidEmojiCatalog androidEmojiCatalog = AndroidEmojiCatalog(
  androidEmojiEntries,
);
