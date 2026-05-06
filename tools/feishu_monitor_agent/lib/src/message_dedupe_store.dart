import 'dart:convert';
import 'dart:io';

class MessageDedupeStore {
  MessageDedupeStore(this.file, {this.maxEntries = 5000});

  final File file;
  final int maxEntries;
  List<String>? _ids;

  Future<bool> markIfNew(String id) async {
    final normalized = id.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final ids = await _load();
    if (ids.contains(normalized)) {
      return false;
    }
    ids.add(normalized);
    _trim(ids);
    await _save(ids);
    return true;
  }

  Future<List<String>> _load() async {
    final cached = _ids;
    if (cached != null) {
      return cached;
    }
    if (!await file.exists()) {
      return _ids = <String>[];
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        final ids = decoded
            .map((item) => item?.toString().trim() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
        _trim(ids);
        return _ids = ids;
      }
    } catch (_) {
      // Corrupted cache should not block forwarding. Start a fresh cache.
    }
    return _ids = <String>[];
  }

  void _trim(List<String> ids) {
    final limit = maxEntries < 1 ? 1 : maxEntries;
    if (ids.length <= limit) {
      return;
    }
    ids.removeRange(0, ids.length - limit);
  }

  Future<void> _save(List<String> ids) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(ids));
  }
}
