import 'dart:io';

import '../../core/upload/multipart_upload_models.dart';
import '../../core/upload/resumable_upload_store.dart';

typedef UploadFingerprintResolver = Future<String> Function(File file);
typedef ResumableUploadProgressCallback =
    void Function(ResumableUploadProgress progress);

class ResumableFileUploader {
  ResumableFileUploader({
    required MultipartUploadClient client,
    required ResumableUploadStore checkpointStore,
    UploadFingerprintResolver? fingerprintResolver,
    this.chunkSizeBytes = MultipartUploadPlanner.defaultChunkSizeBytes,
  }) : _client = client,
       _checkpointStore = checkpointStore,
       _fingerprintResolver =
           fingerprintResolver ?? _defaultFingerprintResolver;

  final MultipartUploadClient _client;
  final ResumableUploadStore _checkpointStore;
  final UploadFingerprintResolver _fingerprintResolver;
  final int chunkSizeBytes;

  Future<String> upload({
    required String filePath,
    required String fileType,
    required String objectPath,
    ResumableUploadProgressCallback? onProgress,
  }) async {
    final file = File(filePath.trim());
    if (!await file.exists()) {
      throw ResumableFileUploadException('file does not exist: $filePath');
    }

    final fileSizeBytes = await file.length();
    final safeChunkSize = chunkSizeBytes <= 0
        ? MultipartUploadPlanner.defaultChunkSizeBytes
        : chunkSizeBytes;
    final fingerprint = await _fingerprintResolver(file);
    final existingCheckpoint = await _checkpointStore.read(fingerprint);
    final checkpoint = await _resolveCheckpoint(
      existingCheckpoint: existingCheckpoint,
      fingerprint: fingerprint,
      fileType: fileType,
      objectPath: objectPath,
      fileSizeBytes: fileSizeBytes,
      chunkSizeBytes: safeChunkSize,
    );
    final uploadedPartNumbers = Set<int>.from(checkpoint.uploadedPartNumbers);
    final parts = MultipartUploadPlanner.plan(
      fileSizeBytes: fileSizeBytes,
      chunkSizeBytes: safeChunkSize,
    );

    for (final part in parts) {
      if (uploadedPartNumbers.contains(part.partNumber)) {
        continue;
      }
      final bytes = await _readPart(file, part);
      await _client.uploadPart(
        MultipartUploadPartRequest(
          uploadId: checkpoint.uploadId,
          fileType: fileType,
          objectPath: objectPath,
          part: part,
          bytes: bytes,
        ),
      );
      uploadedPartNumbers.add(part.partNumber);
      await _checkpointStore.save(
        checkpoint.copyWith(
          uploadedPartNumbers: Set<int>.unmodifiable(uploadedPartNumbers),
        ),
      );
      onProgress?.call(
        ResumableUploadProgress(
          uploadedBytes: _uploadedBytes(parts, uploadedPartNumbers),
          totalBytes: fileSizeBytes,
          uploadedPartNumbers: Set<int>.unmodifiable(uploadedPartNumbers),
        ),
      );
    }

    final result = await _client.complete(
      MultipartUploadCompleteRequest(
        uploadId: checkpoint.uploadId,
        fileType: fileType,
        objectPath: objectPath,
        fileSizeBytes: fileSizeBytes,
        partNumbers: parts
            .map((part) => part.partNumber)
            .toList(growable: false),
      ),
    );
    await _checkpointStore.delete(fingerprint);
    return result;
  }

  Future<ResumableUploadCheckpoint> _resolveCheckpoint({
    required ResumableUploadCheckpoint? existingCheckpoint,
    required String fingerprint,
    required String fileType,
    required String objectPath,
    required int fileSizeBytes,
    required int chunkSizeBytes,
  }) async {
    if (existingCheckpoint != null &&
        existingCheckpoint.objectPath == objectPath &&
        existingCheckpoint.fileSizeBytes == fileSizeBytes &&
        existingCheckpoint.chunkSizeBytes == chunkSizeBytes) {
      return existingCheckpoint;
    }

    final session = await _client.initiate(
      MultipartUploadInitRequest(
        fileType: fileType,
        objectPath: objectPath,
        fileSizeBytes: fileSizeBytes,
        chunkSizeBytes: chunkSizeBytes,
      ),
    );
    final checkpoint = ResumableUploadCheckpoint(
      fingerprint: fingerprint,
      uploadId: session.uploadId,
      objectPath: session.objectPath,
      fileSizeBytes: fileSizeBytes,
      chunkSizeBytes: chunkSizeBytes,
      uploadedPartNumbers: Set<int>.unmodifiable(session.uploadedPartNumbers),
    );
    await _checkpointStore.save(checkpoint);
    return checkpoint;
  }

  Future<List<int>> _readPart(File file, MultipartUploadPart part) async {
    final handle = await file.open();
    try {
      await handle.setPosition(part.offset);
      return await handle.read(part.length);
    } finally {
      await handle.close();
    }
  }

  int _uploadedBytes(
    List<MultipartUploadPart> parts,
    Set<int> uploadedPartNumbers,
  ) {
    var uploadedBytes = 0;
    for (final part in parts) {
      if (uploadedPartNumbers.contains(part.partNumber)) {
        uploadedBytes += part.length;
      }
    }
    return uploadedBytes;
  }

  static Future<String> _defaultFingerprintResolver(File file) async {
    final stat = await file.stat();
    return [
      file.absolute.path,
      stat.size,
      stat.modified.microsecondsSinceEpoch,
    ].join(':');
  }
}

class ResumableUploadProgress {
  const ResumableUploadProgress({
    required this.uploadedBytes,
    required this.totalBytes,
    required this.uploadedPartNumbers,
  });

  final int uploadedBytes;
  final int totalBytes;
  final Set<int> uploadedPartNumbers;
}

class ResumableFileUploadException implements Exception {
  const ResumableFileUploadException(this.message);

  final String message;

  @override
  String toString() => message;
}
