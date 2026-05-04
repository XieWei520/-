import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/upload/multipart_upload_models.dart';
import 'package:wukong_im_app/core/upload/resumable_upload_store.dart';
import 'package:wukong_im_app/data/upload/resumable_file_uploader.dart';

void main() {
  test(
    'resumable uploader skips checkpointed parts and completes session',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'resumable_file_uploader_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}hello.bin');
      await file.writeAsBytes(<int>[1, 2, 3, 4, 5, 6, 7]);

      final store = MemoryResumableUploadStore();
      await store.save(
        const ResumableUploadCheckpoint(
          fingerprint: 'fp-existing',
          uploadId: 'upload-existing',
          objectPath: '/chat/c1/hello.bin',
          fileSizeBytes: 7,
          chunkSizeBytes: 3,
          uploadedPartNumbers: <int>{1},
        ),
      );

      final client = _RecordingMultipartClient(
        existingCheckpoint: 'upload-existing',
        completedUrl: 'https://cdn.example.com/chat/c1/hello.bin',
      );
      final uploader = ResumableFileUploader(
        client: client,
        checkpointStore: store,
        chunkSizeBytes: 3,
        fingerprintResolver: (_) async => 'fp-existing',
      );

      final result = await uploader.upload(
        filePath: file.path,
        fileType: 'chat',
        objectPath: '/chat/c1/hello.bin',
      );

      expect(result, 'https://cdn.example.com/chat/c1/hello.bin');
      expect(client.initCallCount, 0);
      expect(client.uploadedPartNumbers, <int>[2, 3]);
      expect(client.uploadedBytes, <List<int>>[
        <int>[4, 5, 6],
        <int>[7],
      ]);
      expect(client.completedUploadId, 'upload-existing');
      expect(await store.read('fp-existing'), isNull);
    },
  );

  test(
    'resumable uploader creates a new session when checkpoint is absent',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'resumable_file_uploader_new_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}new.bin');
      await file.writeAsBytes(<int>[9, 8, 7, 6]);

      final client = _RecordingMultipartClient(
        createdUploadId: 'upload-new',
        completedUrl: 'https://cdn.example.com/new.bin',
      );
      final uploader = ResumableFileUploader(
        client: client,
        checkpointStore: MemoryResumableUploadStore(),
        chunkSizeBytes: 2,
        fingerprintResolver: (_) async => 'fp-new',
      );

      final result = await uploader.upload(
        filePath: file.path,
        fileType: 'chat',
        objectPath: '/chat/c1/new.bin',
      );

      expect(result, 'https://cdn.example.com/new.bin');
      expect(client.initCallCount, 1);
      expect(client.uploadedPartNumbers.toSet(), <int>{1, 2});
      expect(client.uploadedBytes.toSet(), <List<int>>{
        <int>[9, 8],
        <int>[7, 6],
      });
      expect(client.completedUploadId, 'upload-new');
    },
  );

  test(
    'resumable uploader uploads missing parts with at most three concurrent workers',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'resumable_file_uploader_concurrency_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}parallel.bin',
      );
      await file.writeAsBytes(<int>[1, 2, 3, 4, 5]);

      final client = _RecordingMultipartClient(
        createdUploadId: 'upload-parallel',
        completedUrl: 'https://cdn.example.com/parallel.bin',
        uploadDelay: const Duration(milliseconds: 10),
      );
      final uploader = ResumableFileUploader(
        client: client,
        checkpointStore: MemoryResumableUploadStore(),
        chunkSizeBytes: 1,
        fingerprintResolver: (_) async => 'fp-parallel',
      );

      final result = await uploader.upload(
        filePath: file.path,
        fileType: 'chat',
        objectPath: '/chat/c1/parallel.bin',
      );

      expect(result, 'https://cdn.example.com/parallel.bin');
      expect(client.maxConcurrentUploads, 3);
      expect(client.uploadedPartNumbers.toSet(), <int>{1, 2, 3, 4, 5});
      expect(client.completedPartNumbers, <int>[1, 2, 3, 4, 5]);
    },
  );

  test(
    'resumable uploader retries failed parts with exponential backoff and keeps checkpoint progress',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'resumable_file_uploader_retry_test_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}retry.bin');
      await file.writeAsBytes(<int>[1, 2, 3]);

      final delays = <Duration>[];
      final store = MemoryResumableUploadStore();
      final client = _RecordingMultipartClient(
        createdUploadId: 'upload-retry',
        completedUrl: 'https://cdn.example.com/retry.bin',
        failuresBeforeSuccess: <int, int>{2: 2},
      );
      final uploader = ResumableFileUploader(
        client: client,
        checkpointStore: store,
        chunkSizeBytes: 1,
        fingerprintResolver: (_) async => 'fp-retry',
        retryDelay: (delay) async {
          delays.add(delay);
        },
      );

      final result = await uploader.upload(
        filePath: file.path,
        fileType: 'chat',
        objectPath: '/chat/c1/retry.bin',
      );

      expect(result, 'https://cdn.example.com/retry.bin');
      expect(client.attemptsByPart[2], 3);
      expect(delays, <Duration>[
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
      expect(client.completedPartNumbers, <int>[1, 2, 3]);
      expect(await store.read('fp-retry'), isNull);
    },
  );
}

class _RecordingMultipartClient implements MultipartUploadClient {
  _RecordingMultipartClient({
    this.createdUploadId = 'upload-created',
    this.existingCheckpoint,
    required this.completedUrl,
    this.uploadDelay = Duration.zero,
    this.failuresBeforeSuccess = const <int, int>{},
  });

  final String createdUploadId;
  final String? existingCheckpoint;
  final String completedUrl;
  final Duration uploadDelay;
  final Map<int, int> failuresBeforeSuccess;
  int initCallCount = 0;
  int _activeUploads = 0;
  int maxConcurrentUploads = 0;
  final List<int> uploadedPartNumbers = <int>[];
  final List<List<int>> uploadedBytes = <List<int>>[];
  final Map<int, int> attemptsByPart = <int, int>{};
  String? completedUploadId;
  List<int> completedPartNumbers = const <int>[];

  @override
  Future<MultipartUploadSession> initiate(
    MultipartUploadInitRequest request,
  ) async {
    initCallCount++;
    return MultipartUploadSession(
      uploadId: createdUploadId,
      objectPath: request.objectPath,
    );
  }

  @override
  Future<void> uploadPart(MultipartUploadPartRequest request) async {
    _activeUploads += 1;
    if (_activeUploads > maxConcurrentUploads) {
      maxConcurrentUploads = _activeUploads;
    }
    try {
      final partNumber = request.part.partNumber;
      attemptsByPart[partNumber] = (attemptsByPart[partNumber] ?? 0) + 1;
      if (uploadDelay > Duration.zero) {
        await Future<void>.delayed(uploadDelay);
      }
      final failures = failuresBeforeSuccess[partNumber] ?? 0;
      if (attemptsByPart[partNumber]! <= failures) {
        throw StateError('temporary upload failure for part $partNumber');
      }
    } finally {
      _activeUploads -= 1;
    }
    uploadedPartNumbers.add(request.part.partNumber);
    uploadedBytes.add(request.bytes);
  }

  @override
  Future<String> complete(MultipartUploadCompleteRequest request) async {
    completedUploadId = request.uploadId;
    completedPartNumbers = request.partNumbers;
    return completedUrl;
  }
}
