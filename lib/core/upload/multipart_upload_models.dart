import 'package:flutter/foundation.dart';

@immutable
class MultipartUploadPart {
  const MultipartUploadPart({
    required this.partNumber,
    required this.offset,
    required this.length,
  });

  final int partNumber;
  final int offset;
  final int length;

  int get endExclusive => offset + length;
}

class MultipartUploadPlanner {
  MultipartUploadPlanner._();

  static const int defaultChunkSizeBytes = 8 * 1024 * 1024;
  static const int targetLargeFileBytes = 1024 * 1024 * 1024;

  static List<MultipartUploadPart> plan({
    required int fileSizeBytes,
    int chunkSizeBytes = defaultChunkSizeBytes,
  }) {
    if (fileSizeBytes <= 0) {
      return const <MultipartUploadPart>[];
    }

    final safeChunkSize = chunkSizeBytes <= 0
        ? defaultChunkSizeBytes
        : chunkSizeBytes;
    final parts = <MultipartUploadPart>[];
    var offset = 0;
    var partNumber = 1;
    while (offset < fileSizeBytes) {
      final remaining = fileSizeBytes - offset;
      final length = remaining < safeChunkSize ? remaining : safeChunkSize;
      parts.add(
        MultipartUploadPart(
          partNumber: partNumber,
          offset: offset,
          length: length,
        ),
      );
      offset += length;
      partNumber++;
    }
    return parts;
  }
}

@immutable
class MultipartUploadInitRequest {
  const MultipartUploadInitRequest({
    required this.fileType,
    required this.objectPath,
    required this.fileSizeBytes,
    required this.chunkSizeBytes,
  });

  final String fileType;
  final String objectPath;
  final int fileSizeBytes;
  final int chunkSizeBytes;
}

@immutable
class MultipartUploadSession {
  const MultipartUploadSession({
    required this.uploadId,
    required this.objectPath,
    this.uploadedPartNumbers = const <int>{},
  });

  final String uploadId;
  final String objectPath;
  final Set<int> uploadedPartNumbers;
}

@immutable
class MultipartUploadPartRequest {
  const MultipartUploadPartRequest({
    required this.uploadId,
    required this.fileType,
    required this.objectPath,
    required this.part,
    required this.bytes,
  });

  final String uploadId;
  final String fileType;
  final String objectPath;
  final MultipartUploadPart part;
  final List<int> bytes;
}

@immutable
class MultipartUploadCompleteRequest {
  const MultipartUploadCompleteRequest({
    required this.uploadId,
    required this.fileType,
    required this.objectPath,
    required this.fileSizeBytes,
    required this.partNumbers,
  });

  final String uploadId;
  final String fileType;
  final String objectPath;
  final int fileSizeBytes;
  final List<int> partNumbers;
}

abstract interface class MultipartUploadClient {
  Future<MultipartUploadSession> initiate(MultipartUploadInitRequest request);

  Future<void> uploadPart(MultipartUploadPartRequest request);

  Future<String> complete(MultipartUploadCompleteRequest request);
}
