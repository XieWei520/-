import '../../core/repositories/file_repository.dart';
import '../../service/api/file_api.dart';

typedef UploadChatFileDelegate =
    Future<String> Function({
      required String filePath,
      required String channelId,
      required int channelType,
    });

typedef UploadCommonImageDelegate =
    Future<String> Function({
      required String filePath,
      required String uploadPath,
    });

class FileApiRepository implements FileRepository {
  FileApiRepository({
    UploadChatFileDelegate? uploadChatFile,
    UploadCommonImageDelegate? uploadCommonImage,
  }) : _uploadChatFile = uploadChatFile ?? FileApi.instance.uploadChatFile,
       _uploadCommonImage =
           uploadCommonImage ?? FileApi.instance.uploadCommonImage;

  final UploadChatFileDelegate _uploadChatFile;
  final UploadCommonImageDelegate _uploadCommonImage;

  @override
  Future<String> uploadChatFile(ChatFileUploadRequest request) {
    return _uploadChatFile(
      filePath: request.filePath,
      channelId: request.channelId,
      channelType: request.channelType,
    );
  }

  @override
  Future<String> uploadCommonImage(CommonImageUploadRequest request) {
    return _uploadCommonImage(
      filePath: request.filePath,
      uploadPath: request.uploadPath,
    );
  }
}
