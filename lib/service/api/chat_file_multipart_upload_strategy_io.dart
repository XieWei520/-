import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/upload/multipart_upload_models.dart';
import '../../data/upload/resumable_file_uploader.dart';
import '../../data/upload/shared_preferences_resumable_upload_store.dart';
import 'file_multipart_upload_client.dart';

Future<String?> tryMultipartChatFileUpload({
  required String filePath,
  required String fileType,
  required String objectPath,
  required int thresholdBytes,
}) async {
  if (thresholdBytes <= 0) {
    return null;
  }

  final file = File(filePath.trim());
  if (!await file.exists()) {
    return null;
  }

  final fileSizeBytes = await file.length();
  if (fileSizeBytes < thresholdBytes) {
    return null;
  }

  final prefs = await SharedPreferences.getInstance();
  final uploader = ResumableFileUploader(
    client: FileMultipartUploadClient(),
    checkpointStore: SharedPreferencesResumableUploadStore(prefs),
    chunkSizeBytes: MultipartUploadPlanner.defaultChunkSizeBytes,
  );
  return uploader.upload(
    filePath: file.path,
    fileType: fileType,
    objectPath: objectPath,
  );
}
