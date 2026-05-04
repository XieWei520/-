import 'package:flutter/foundation.dart';

@immutable
class ResumableUploadCheckpoint {
  const ResumableUploadCheckpoint({
    required this.fingerprint,
    required this.uploadId,
    required this.objectPath,
    required this.fileSizeBytes,
    required this.chunkSizeBytes,
    this.uploadedPartNumbers = const <int>{},
  });

  final String fingerprint;
  final String uploadId;
  final String objectPath;
  final int fileSizeBytes;
  final int chunkSizeBytes;
  final Set<int> uploadedPartNumbers;

  ResumableUploadCheckpoint copyWith({
    String? uploadId,
    Set<int>? uploadedPartNumbers,
  }) {
    return ResumableUploadCheckpoint(
      fingerprint: fingerprint,
      uploadId: uploadId ?? this.uploadId,
      objectPath: objectPath,
      fileSizeBytes: fileSizeBytes,
      chunkSizeBytes: chunkSizeBytes,
      uploadedPartNumbers: uploadedPartNumbers ?? this.uploadedPartNumbers,
    );
  }
}

abstract interface class ResumableUploadStore {
  Future<ResumableUploadCheckpoint?> read(String fingerprint);

  Future<void> save(ResumableUploadCheckpoint checkpoint);

  Future<void> delete(String fingerprint);
}

class MemoryResumableUploadStore implements ResumableUploadStore {
  final Map<String, ResumableUploadCheckpoint> _checkpoints =
      <String, ResumableUploadCheckpoint>{};

  @override
  Future<ResumableUploadCheckpoint?> read(String fingerprint) async {
    return _checkpoints[fingerprint];
  }

  @override
  Future<void> save(ResumableUploadCheckpoint checkpoint) async {
    _checkpoints[checkpoint.fingerprint] = checkpoint;
  }

  @override
  Future<void> delete(String fingerprint) async {
    _checkpoints.remove(fingerprint);
  }
}
