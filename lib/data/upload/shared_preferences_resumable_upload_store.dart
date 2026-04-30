import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/upload/resumable_upload_store.dart';

class SharedPreferencesResumableUploadStore implements ResumableUploadStore {
  SharedPreferencesResumableUploadStore(this._prefs);

  static const String _keyPrefix = 'wk_resumable_upload:';

  final SharedPreferences _prefs;

  @override
  Future<ResumableUploadCheckpoint?> read(String fingerprint) async {
    final raw = _prefs.getString(_keyFor(fingerprint));
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final uploadedParts = decoded['uploaded_part_numbers'];
      return ResumableUploadCheckpoint(
        fingerprint: decoded['fingerprint']?.toString() ?? fingerprint,
        uploadId: decoded['upload_id']?.toString() ?? '',
        objectPath: decoded['object_path']?.toString() ?? '',
        fileSizeBytes: _readInt(decoded['file_size_bytes']),
        chunkSizeBytes: _readInt(decoded['chunk_size_bytes']),
        uploadedPartNumbers: uploadedParts is Iterable
            ? uploadedParts.map(_readInt).where((part) => part > 0).toSet()
            : const <int>{},
      );
    } catch (_) {
      await delete(fingerprint);
      return null;
    }
  }

  @override
  Future<void> save(ResumableUploadCheckpoint checkpoint) async {
    final uploadedParts = checkpoint.uploadedPartNumbers.toList()..sort();
    await _prefs.setString(
      _keyFor(checkpoint.fingerprint),
      jsonEncode(<String, dynamic>{
        'fingerprint': checkpoint.fingerprint,
        'upload_id': checkpoint.uploadId,
        'object_path': checkpoint.objectPath,
        'file_size_bytes': checkpoint.fileSizeBytes,
        'chunk_size_bytes': checkpoint.chunkSizeBytes,
        'uploaded_part_numbers': uploadedParts,
      }),
    );
  }

  @override
  Future<void> delete(String fingerprint) async {
    await _prefs.remove(_keyFor(fingerprint));
  }

  String _keyFor(String fingerprint) {
    return '$_keyPrefix${base64Url.encode(utf8.encode(fingerprint))}';
  }

  int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
