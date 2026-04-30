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
      expect(client.uploadedPartNumbers, <int>[1, 2]);
      expect(client.uploadedBytes, <List<int>>[
        <int>[9, 8],
        <int>[7, 6],
      ]);
      expect(client.completedUploadId, 'upload-new');
    },
  );
}

class _RecordingMultipartClient implements MultipartUploadClient {
  _RecordingMultipartClient({
    this.createdUploadId = 'upload-created',
    this.existingCheckpoint,
    required this.completedUrl,
  });

  final String createdUploadId;
  final String? existingCheckpoint;
  final String completedUrl;
  int initCallCount = 0;
  final List<int> uploadedPartNumbers = <int>[];
  final List<List<int>> uploadedBytes = <List<int>>[];
  String? completedUploadId;

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
    uploadedPartNumbers.add(request.part.partNumber);
    uploadedBytes.add(request.bytes);
  }

  @override
  Future<String> complete(MultipartUploadCompleteRequest request) async {
    completedUploadId = request.uploadId;
    return completedUrl;
  }
}
