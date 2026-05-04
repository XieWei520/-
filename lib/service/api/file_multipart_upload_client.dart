import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/config/api_config.dart';
import '../../core/upload/multipart_upload_models.dart';
import 'api_client.dart';
import 'file_api.dart';

class FileMultipartUploadClient implements MultipartUploadClient {
  FileMultipartUploadClient({ApiClient? apiClient})
    : _client = apiClient ?? ApiClient.instance;

  final ApiClient _client;

  @override
  Future<MultipartUploadSession> initiate(
    MultipartUploadInitRequest request,
  ) async {
    final response = await _client.post(
      ApiConfig.fileMultipartInit,
      data: <String, dynamic>{
        'type': request.fileType,
        'path': request.objectPath,
        'size': request.fileSizeBytes,
        'chunk_size': request.chunkSizeBytes,
      },
    );
    final body = _resolveBody(response.data);
    final uploadId = _readStringField(body, const [
      'upload_id',
      'uploadId',
      'data.upload_id',
      'data.uploadId',
    ]);
    if (uploadId.isEmpty) {
      throw const FileApiException('multipart upload id is empty');
    }
    final resolvedObjectPath = _readStringField(body, const [
      'path',
      'object_path',
      'data.path',
    ]);
    return MultipartUploadSession(
      uploadId: uploadId,
      objectPath: resolvedObjectPath.isEmpty
          ? request.objectPath
          : resolvedObjectPath,
      uploadedPartNumbers: _readIntSet(
        _readNestedValue(body, 'uploaded_parts') ??
            _readNestedValue(body, 'data.uploaded_parts'),
      ),
    );
  }

  @override
  Future<void> uploadPart(MultipartUploadPartRequest request) async {
    final bytes = Uint8List.fromList(request.bytes);
    await _client.dio.put<void>(
      '${ApiConfig.fileMultipartParts}/${request.part.partNumber}',
      queryParameters: <String, dynamic>{
        'upload_id': request.uploadId,
        'type': request.fileType,
        'path': request.objectPath,
        'part_number': request.part.partNumber,
        'offset': request.part.offset,
        'length': request.part.length,
      },
      data: Stream<List<int>>.fromIterable(<List<int>>[bytes]),
      options: Options(
        contentType: 'application/octet-stream',
        headers: <String, Object>{Headers.contentLengthHeader: bytes.length},
      ),
    );
  }

  @override
  Future<String> complete(MultipartUploadCompleteRequest request) async {
    final response = await _client.post(
      ApiConfig.fileMultipartComplete,
      data: <String, dynamic>{
        'upload_id': request.uploadId,
        'type': request.fileType,
        'path': request.objectPath,
        'size': request.fileSizeBytes,
        'parts': request.partNumbers,
      },
    );
    final body = _resolveBody(response.data);
    final path = _readStringField(body, const [
      'path',
      'url',
      'data.path',
      'data.url',
      'data',
    ]);
    if (path.isEmpty) {
      throw const FileApiException('multipart complete path is empty');
    }
    return ApiConfig.resolveMediaUrl(path);
  }

  Map<String, dynamic> _resolveBody(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{'data': raw};
  }

  String _readStringField(Map<String, dynamic> body, List<String> fields) {
    for (final field in fields) {
      final value = _readNestedValue(body, field);
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  dynamic _readNestedValue(Map<String, dynamic> body, String field) {
    final segments = field.split('.');
    dynamic current = body;
    for (final segment in segments) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  Set<int> _readIntSet(dynamic raw) {
    if (raw is! Iterable) {
      return const <int>{};
    }
    return raw
        .map((value) {
          if (value is int) {
            return value;
          }
          if (value is num) {
            return value.toInt();
          }
          return int.tryParse(value.toString());
        })
        .whereType<int>()
        .toSet();
  }
}
