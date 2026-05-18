import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/storage_utils.dart';
import 'api_client.dart';
import 'chat_file_multipart_upload_strategy.dart'
    if (dart.library.io) 'chat_file_multipart_upload_strategy_io.dart';

class FileApi {
  FileApi._();

  static final FileApi _instance = FileApi._();
  static FileApi get instance => _instance;
  static const int defaultMultipartUploadThresholdBytes = 64 * 1024 * 1024;
  static int multipartUploadThresholdBytes =
      defaultMultipartUploadThresholdBytes;

  final ApiClient _client = ApiClient.instance;
  static const Uuid _uuid = Uuid();

  Future<String> uploadChatFile({
    required String filePath,
    required String channelId,
    required int channelType,
  }) async {
    final normalizedFilePath = filePath.trim();
    final extension = _resolveExtension(normalizedFilePath);
    final channelSegment = _safeObjectPathSegment(
      channelId,
      fallback: 'channel',
    );
    final uploadPath =
        '/$channelType/$channelSegment/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final normalizedUploadPath = _normalizeObjectPath(uploadPath);
    final multipartUrl = await tryMultipartChatFileUpload(
      filePath: normalizedFilePath,
      fileType: 'chat',
      objectPath: normalizedUploadPath,
      thresholdBytes: multipartUploadThresholdBytes,
    );
    if (multipartUrl != null && multipartUrl.isNotEmpty) {
      return multipartUrl;
    }
    return _uploadFile(
      filePath: normalizedFilePath,
      fileType: 'chat',
      uploadPath: normalizedUploadPath,
    );
  }

  Future<String> uploadChatFileAtPath({
    required String filePath,
    required String uploadPath,
  }) async {
    final normalizedFilePath = filePath.trim();
    final normalizedUploadPath = _normalizeObjectPath(uploadPath);
    final multipartUrl = await tryMultipartChatFileUpload(
      filePath: normalizedFilePath,
      fileType: 'chat',
      objectPath: normalizedUploadPath,
      thresholdBytes: multipartUploadThresholdBytes,
    );
    if (multipartUrl != null && multipartUrl.isNotEmpty) {
      return multipartUrl;
    }
    return _uploadFile(
      filePath: normalizedFilePath,
      fileType: 'chat',
      uploadPath: normalizedUploadPath,
    );
  }

  Future<String> uploadChatFileBytes({
    required Uint8List bytes,
    required String fileName,
    required String channelId,
    required int channelType,
  }) async {
    if (bytes.isEmpty) {
      throw const FileApiException('file bytes are empty');
    }

    final extension = _resolveExtension(fileName);
    final channelSegment = _safeObjectPathSegment(
      channelId,
      fallback: 'channel',
    );
    final uploadPath =
        '/$channelType/$channelSegment/${DateTime.now().millisecondsSinceEpoch}.$extension';
    return _uploadBytes(
      bytes: bytes,
      fileName: _safeUploadFileName(fileName, extension: extension),
      fileType: 'chat',
      uploadPath: _normalizeObjectPath(uploadPath),
    );
  }

  Future<String> uploadMomentFile(String filePath, {int? index}) async {
    final normalizedFilePath = filePath.trim();
    final extension = _resolveExtension(normalizedFilePath);
    final uid = _safeObjectPathSegment(
      StorageUtils.getUid() ?? '',
      fallback: 'moment',
    );
    final suffix = index == null ? '' : '_$index';
    final uploadPath =
        '/$uid/${DateTime.now().millisecondsSinceEpoch}$suffix.$extension';
    return _uploadFile(
      filePath: normalizedFilePath,
      fileType: 'moment',
      uploadPath: uploadPath,
    );
  }

  Future<List<String>> uploadMomentFiles(List<String> filePaths) async {
    final uploadedUrls = <String>[];
    for (var i = 0; i < filePaths.length; i++) {
      uploadedUrls.add(await uploadMomentFile(filePaths[i], index: i));
    }
    return uploadedUrls;
  }

  Future<String> uploadReportImage(String filePath) async {
    final normalizedFilePath = filePath.trim();
    final uid = _safeObjectPathSegment(
      StorageUtils.getUid() ?? '',
      fallback: 'report',
    );
    final extension = _resolveExtension(normalizedFilePath);
    final uploadPath = '/$uid/${_uuid.v4()}.$extension';
    return _uploadFile(
      filePath: normalizedFilePath,
      fileType: 'report',
      uploadPath: uploadPath,
    );
  }

  Future<String> uploadCommonImage({
    required String filePath,
    required String uploadPath,
  }) async {
    return _uploadFile(
      filePath: filePath,
      fileType: 'common',
      uploadPath: uploadPath,
    );
  }

  Future<String> _uploadFile({
    required String filePath,
    required String fileType,
    required String uploadPath,
  }) async {
    final normalizedFilePath = filePath.trim();
    if (normalizedFilePath.isEmpty) {
      throw const FileApiException('file path is empty');
    }

    final uploadUrl = await _requestUploadUrl(
      fileType: fileType,
      uploadPath: _normalizeObjectPath(uploadPath),
    );
    if (uploadUrl.isEmpty) {
      throw const FileApiException('获取上传地址失败');
    }

    final response = await _client.uploadFile(
      ApiConfig.resolveUrl(uploadUrl),
      normalizedFilePath,
      name: 'file',
    );

    final uploadedPath = _readStringField(response.data, const [
      'path',
      'data.path',
      'data',
    ]);
    if (uploadedPath.isEmpty) {
      throw const FileApiException('上传文件失败');
    }
    return ApiConfig.resolveMediaUrl(uploadedPath);
  }

  Future<String> _uploadBytes({
    required Uint8List bytes,
    required String fileName,
    required String fileType,
    required String uploadPath,
  }) async {
    if (bytes.isEmpty) {
      throw const FileApiException('file bytes are empty');
    }

    final uploadUrl = await _requestUploadUrl(
      fileType: fileType,
      uploadPath: _normalizeObjectPath(uploadPath),
    );
    if (uploadUrl.isEmpty) {
      throw const FileApiException('鑾峰彇涓婁紶鍦板潃澶辫触');
    }

    final response = await _client.uploadBytes(
      ApiConfig.resolveUrl(uploadUrl),
      bytes,
      filename: fileName,
      name: 'file',
    );

    final uploadedPath = _readStringField(response.data, const [
      'path',
      'data.path',
      'data',
    ]);
    if (uploadedPath.isEmpty) {
      throw const FileApiException('涓婁紶鏂囦欢澶辫触');
    }
    return ApiConfig.resolveMediaUrl(uploadedPath);
  }

  Future<String> _requestUploadUrl({
    required String fileType,
    required String uploadPath,
  }) async {
    final response = await _client.get(
      ApiConfig.fileUpload,
      queryParameters: {'type': fileType, 'path': uploadPath},
    );

    final uploadUrl = _readStringField(response.data, const [
      'url',
      'data.url',
      'public_url',
      'data.public_url',
    ]);
    return ApiConfig.normalizeUploadUrl(uploadUrl);
  }

  String _resolveExtension(String filePath) {
    final extension = path
        .extension(filePath.trim())
        .replaceFirst('.', '')
        .trim()
        .toLowerCase();
    if (!RegExp(r'^[a-z0-9]{1,16}$').hasMatch(extension)) {
      return 'dat';
    }
    return extension.isEmpty ? 'dat' : extension;
  }

  String _safeUploadFileName(String fileName, {required String extension}) {
    final normalized = fileName.trim().replaceAll('\\', '/');
    final basename = path.basename(normalized).trim();
    final cleaned = basename
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]+'), '')
        .replaceAll(RegExp(r'[\\/]+'), '_')
        .trim();
    if (cleaned.isNotEmpty && cleaned != '.' && cleaned != '..') {
      return cleaned;
    }
    return 'file.$extension';
  }

  String _safeObjectPathSegment(String value, {required String fallback}) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[\\/]+'), '_')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceFirst(RegExp(r'^[._-]+'), '')
        .replaceFirst(RegExp(r'[._-]+$'), '');
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  String _normalizeObjectPath(String uploadPath) {
    final segments = uploadPath
        .trim()
        .replaceAll('\\', '/')
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .where((segment) => segment != '.' && segment != '..')
        .map((segment) => _safeObjectPathSegment(segment, fallback: 'file'))
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return '/file';
    }
    return '/${segments.join('/')}';
  }

  String _readStringField(dynamic rawData, List<String> fields) {
    if (rawData is String) {
      final rawValue = rawData.trim();
      if (rawValue.isNotEmpty) {
        return rawValue;
      }
    }

    for (final field in fields) {
      final value = _readNestedValue(rawData, field);
      if (value == null) {
        continue;
      }

      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  dynamic _readNestedValue(dynamic rawData, String field) {
    final segments = field.split('.');
    dynamic current = rawData;
    for (final segment in segments) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }
}

class FileApiException implements Exception {
  final String message;

  const FileApiException(this.message);

  @override
  String toString() => message;
}
