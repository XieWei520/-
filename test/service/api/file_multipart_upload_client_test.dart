import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/config/api_config.dart';
import 'package:wukong_im_app/core/upload/multipart_upload_models.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/file_multipart_upload_client.dart';

void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  test(
    'multipart upload client maps init, part, and complete endpoints',
    () async {
      final adapter = _RecordingMultipartAdapter();
      ApiClient.instance.dio.httpClientAdapter = adapter;
      final client = FileMultipartUploadClient();

      final session = await client.initiate(
        const MultipartUploadInitRequest(
          fileType: 'chat',
          objectPath: '/chat/c1/big.bin',
          fileSizeBytes: 1024,
          chunkSizeBytes: 256,
        ),
      );
      await client.uploadPart(
        const MultipartUploadPartRequest(
          uploadId: 'upload-1',
          fileType: 'chat',
          objectPath: '/chat/c1/big.bin',
          part: MultipartUploadPart(partNumber: 2, offset: 256, length: 3),
          bytes: <int>[1, 2, 3],
        ),
      );
      final completed = await client.complete(
        const MultipartUploadCompleteRequest(
          uploadId: 'upload-1',
          fileType: 'chat',
          objectPath: '/chat/c1/big.bin',
          fileSizeBytes: 1024,
          partNumbers: <int>[1, 2, 3, 4],
        ),
      );

      expect(session.uploadId, 'upload-1');
      expect(session.objectPath, '/chat/c1/big.bin');
      expect(session.uploadedPartNumbers, <int>{1});
      expect(
        completed,
        ApiConfig.resolveMediaUrl('file/preview/chat/c1/big.bin'),
      );
      expect(adapter.initBody['chunk_size'], 256);
      expect(adapter.partPath, '/v1/file/multipart/parts/2');
      expect(adapter.partQuery['part_number'], '2');
      expect(adapter.partBytes, <int>[1, 2, 3]);
      expect(adapter.completeBody['parts'], <int>[1, 2, 3, 4]);
    },
  );
}

class _RecordingMultipartAdapter implements HttpClientAdapter {
  Map<String, dynamic> initBody = <String, dynamic>{};
  String? partPath;
  Map<String, dynamic> partQuery = <String, dynamic>{};
  List<int> partBytes = <int>[];
  Map<String, dynamic> completeBody = <String, dynamic>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method.toUpperCase() == 'POST' &&
        options.uri.path == ApiConfig.fileMultipartInit) {
      initBody = Map<String, dynamic>.from(options.data as Map);
      return _json(<String, dynamic>{
        'upload_id': 'upload-1',
        'path': initBody['path'],
        'uploaded_parts': <int>[1],
      });
    }

    if (options.method.toUpperCase() == 'PUT' &&
        options.uri.path == '/v1/file/multipart/parts/2') {
      partPath = options.uri.path;
      partQuery = options.queryParameters.map(
        (key, value) => MapEntry<String, dynamic>(key, value.toString()),
      );
      final chunks = await requestStream?.toList() ?? const <Uint8List>[];
      partBytes = chunks.expand((chunk) => chunk).toList(growable: false);
      return _json(<String, dynamic>{'ok': 1});
    }

    if (options.method.toUpperCase() == 'POST' &&
        options.uri.path == ApiConfig.fileMultipartComplete) {
      completeBody = Map<String, dynamic>.from(options.data as Map);
      return _json(<String, dynamic>{'path': 'file/preview/chat/c1/big.bin'});
    }

    return _json(<String, dynamic>{'code': 404}, statusCode: 404);
  }

  ResponseBody _json(Object payload, {int statusCode = 200}) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
