class ChatFileUploadRequest {
  const ChatFileUploadRequest({
    required this.filePath,
    required this.channelId,
    required this.channelType,
  });

  final String filePath;
  final String channelId;
  final int channelType;
}

class CommonImageUploadRequest {
  const CommonImageUploadRequest({
    required this.filePath,
    required this.uploadPath,
  });

  final String filePath;
  final String uploadPath;
}

abstract interface class FileRepository {
  Future<String> uploadChatFile(ChatFileUploadRequest request);

  Future<String> uploadCommonImage(CommonImageUploadRequest request);
}
