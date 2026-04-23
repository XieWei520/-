import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/storage_utils.dart';
import 'api_client.dart';

class FileApi {
  FileApi._();

  static final FileApi _instance = FileApi._();
  static FileApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  static const Uuid _uuid = Uuid();

  Future<String> uploadChatFile({
    required String filePath,
    required String channelId,
    required int channelType,
  }) async {
    final extension = _resolveExtension(filePath);
    final uploadPath =
        '/$channelType/$channelId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    return _uploadFile(
      filePath: filePath,
      fileType: 'chat',
      uploadPath: uploadPath,
    );
  }

  Future<String> uploadMomentFile(String filePath, {int? index}) async {
    final extension = _resolveExtension(filePath);
    final uid = StorageUtils.getUid() ?? 'moment';
    final suffix = index == null ? '' : '_$index';
    final uploadPath =
        '/$uid/${DateTime.now().millisecondsSinceEpoch}$suffix.$extension';
    return _uploadFile(
      filePath: filePath,
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
    final uid = StorageUtils.getUid() ?? 'report';
    final extension = _resolveExtension(filePath);
    final uploadPath = '/$uid/${_uuid.v4()}.$extension';
    return _uploadFile(
      filePath: filePath,
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
    final uploadUrl = await _requestUploadUrl(
      fileType: fileType,
      uploadPath: uploadPath,
    );
    if (uploadUrl.isEmpty) {
      throw const FileApiException('获取上传地址失败');
    }

    final response = await _client.uploadFile(
      ApiConfig.resolveUrl(uploadUrl),
      filePath,
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
    final extension = path.extension(filePath).replaceFirst('.', '').trim();
    return extension.isEmpty ? 'dat' : extension;
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
