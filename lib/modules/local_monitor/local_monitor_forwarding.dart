import 'package:wukong_im_app/modules/chat/chat_scene_gateway.dart';
import 'package:wukong_im_app/data/models/wk_custom_content.dart';
import 'package:wukong_im_app/service/api/file_api.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_text_content.dart';

const int localMonitorForwardedMessageExpireSeconds = 6 * 60 * 60;

class LocalMonitorRelayIdentity {
  const LocalMonitorRelayIdentity({
    required this.provider,
    required this.displayName,
    required this.avatar,
  });

  final String provider;
  final String displayName;
  final String avatar;

  bool get isEmpty =>
      provider.trim().isEmpty &&
      displayName.trim().isEmpty &&
      avatar.trim().isEmpty;

  Map<String, dynamic> toRobotJson() {
    return <String, dynamic>{
      if (provider.trim().isNotEmpty) 'provider': provider.trim(),
      if (displayName.trim().isNotEmpty) 'name': displayName.trim(),
      if (avatar.trim().isNotEmpty) 'avatar': avatar.trim(),
    };
  }
}

abstract class LocalMonitorTextSender {
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    LocalMonitorRelayIdentity? relayIdentity,
  });
}

class LocalMonitorForwardableFile {
  const LocalMonitorForwardableFile({
    required this.sourceUrl,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String sourceUrl;
  final String localPath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  bool get hasUsableSource =>
      sourceUrl.trim().isNotEmpty || localPath.trim().isNotEmpty;

  LocalMonitorForwardableFile copyWith({
    String? sourceUrl,
    String? localPath,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
  }) {
    return LocalMonitorForwardableFile(
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
    );
  }
}

class LocalMonitorForwardableImage {
  const LocalMonitorForwardableImage({
    required this.sourceUrl,
    required this.localPath,
    required this.width,
    required this.height,
  });

  final String sourceUrl;
  final String localPath;
  final int width;
  final int height;

  bool get hasUsableSource =>
      sourceUrl.trim().isNotEmpty || localPath.trim().isNotEmpty;
}

typedef LocalMonitorImagePreparer =
    Future<LocalMonitorForwardableImage> Function(
      LocalMonitorForwardableImage image,
    );

typedef LocalMonitorImageUploader =
    Future<String> Function({
      required String filePath,
      required String channelId,
      required int channelType,
    });

typedef LocalMonitorFilePreparer =
    Future<LocalMonitorForwardableFile> Function(
      LocalMonitorForwardableFile file,
    );

typedef LocalMonitorFileUploader =
    Future<String> Function({
      required String filePath,
      required String channelId,
      required int channelType,
      required String fileName,
    });

abstract class LocalMonitorImageSender {
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableImage image,
    LocalMonitorRelayIdentity? relayIdentity,
  });
}

abstract class LocalMonitorFileSender {
  Future<void> sendFile({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableFile file,
    LocalMonitorRelayIdentity? relayIdentity,
  });
}

abstract class LocalMonitorForwardingDedupeStore {
  Future<List<String>> loadSentKeys();
  Future<void> saveSentKeys(List<String> keys);
}

class LocalMonitorFileTooLargeException implements Exception {
  const LocalMonitorFileTooLargeException({
    required this.fileName,
    required this.sizeBytes,
    required this.maxBytes,
  });

  final String fileName;
  final int sizeBytes;
  final int maxBytes;

  @override
  String toString() {
    return 'LocalMonitorFileTooLargeException($fileName, $sizeBytes > $maxBytes)';
  }
}

class WkImLocalMonitorTextSender implements LocalMonitorTextSender {
  WkImLocalMonitorTextSender({ChatSceneGateway? gateway})
    : _gateway = gateway ?? ApiChatSceneGateway();

  final ChatSceneGateway _gateway;

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    LocalMonitorRelayIdentity? relayIdentity,
  }) {
    return _gateway.sendMessageContent(
      LocalMonitorRelayTextContent(text, relayIdentity: relayIdentity),
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      expireSeconds: localMonitorForwardedMessageExpireSeconds,
    );
  }
}

class WkImLocalMonitorImageSender implements LocalMonitorImageSender {
  WkImLocalMonitorImageSender({
    ChatSceneGateway? gateway,
    required LocalMonitorImagePreparer prepareImage,
    required LocalMonitorImageUploader uploadImage,
  }) : _gateway = gateway ?? ApiChatSceneGateway(),
       _prepareImage = prepareImage,
       _uploadImage = uploadImage;

  final ChatSceneGateway _gateway;
  final LocalMonitorImagePreparer _prepareImage;
  final LocalMonitorImageUploader _uploadImage;

  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableImage image,
    LocalMonitorRelayIdentity? relayIdentity,
  }) async {
    final prepared = await _prepareImage(image);
    if (prepared.localPath.trim().isEmpty) {
      throw StateError('Local monitor image was not prepared as a local file.');
    }
    final remoteUrl = await _uploadImage(
      filePath: prepared.localPath.trim(),
      channelId: channelId,
      channelType: channelType,
    );
    if (remoteUrl.trim().isEmpty) {
      throw StateError('Local monitor image upload returned an empty url.');
    }
    final content =
        LocalMonitorRelayImageContent(
            prepared.width,
            prepared.height,
            relayIdentity: relayIdentity,
          )
          ..localPath = prepared.localPath.trim()
          ..url = remoteUrl.trim();
    return _gateway.sendMessageContent(
      content,
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      expireSeconds: localMonitorForwardedMessageExpireSeconds,
    );
  }
}

class WkImLocalMonitorFileSender implements LocalMonitorFileSender {
  WkImLocalMonitorFileSender({
    ChatSceneGateway? gateway,
    LocalMonitorFilePreparer? prepareFile,
    LocalMonitorFileUploader? uploadFile,
    int? maxFileBytes,
  }) : _gateway = gateway ?? ApiChatSceneGateway(),
       _prepareFile = prepareFile ?? _identityLocalMonitorFilePreparer,
       _uploadFile = uploadFile ?? _uploadLocalMonitorFileForWk,
       _maxFileBytes = maxFileBytes;

  final ChatSceneGateway _gateway;
  final LocalMonitorFilePreparer _prepareFile;
  final LocalMonitorFileUploader _uploadFile;
  final int? _maxFileBytes;

  @override
  Future<void> sendFile({
    required String channelId,
    required int channelType,
    String? channelName,
    required LocalMonitorForwardableFile file,
    LocalMonitorRelayIdentity? relayIdentity,
  }) async {
    final prepared = await _prepareFile(file);
    final localPath = prepared.localPath.trim();
    if (localPath.isEmpty) {
      throw StateError('Local monitor file was not prepared as a local file.');
    }
    final fileName = _safeLocalMonitorFileName(
      prepared.fileName,
      fallbackPath: localPath,
    );
    final sizeBytes = prepared.sizeBytes < 0 ? 0 : prepared.sizeBytes;
    final maxFileBytes = _maxFileBytes;
    if (maxFileBytes != null && maxFileBytes > 0 && sizeBytes > maxFileBytes) {
      throw LocalMonitorFileTooLargeException(
        fileName: fileName,
        sizeBytes: sizeBytes,
        maxBytes: maxFileBytes,
      );
    }
    final remoteUrl = await _uploadFile(
      filePath: localPath,
      channelId: channelId,
      channelType: channelType,
      fileName: fileName,
    );
    if (remoteUrl.trim().isEmpty) {
      throw StateError('Local monitor file upload returned an empty url.');
    }
    final content = LocalMonitorRelayFileContent(relayIdentity: relayIdentity)
      ..localPath = localPath
      ..name = fileName
      ..size = sizeBytes < 0 ? 0 : sizeBytes
      ..url = remoteUrl.trim()
      ..suffix = _localMonitorFileSuffix(fileName);
    return _gateway.sendMessageContent(
      content,
      channelId: channelId,
      channelType: channelType,
      channelName: channelName,
      expireSeconds: localMonitorForwardedMessageExpireSeconds,
    );
  }
}

class LocalMonitorRelayTextContent extends WKTextContent {
  LocalMonitorRelayTextContent(
    super.content, {
    LocalMonitorRelayIdentity? relayIdentity,
  }) : _relayIdentity = relayIdentity;

  final LocalMonitorRelayIdentity? _relayIdentity;

  @override
  Map<String, dynamic> encodeJson() {
    return withLocalMonitorRelayIdentity(super.encodeJson(), _relayIdentity);
  }
}

class LocalMonitorRelayImageContent extends WKImageContent {
  LocalMonitorRelayImageContent(
    super.width,
    super.height, {
    LocalMonitorRelayIdentity? relayIdentity,
  }) : _relayIdentity = relayIdentity;

  final LocalMonitorRelayIdentity? _relayIdentity;

  @override
  Map<String, dynamic> encodeJson() {
    return withLocalMonitorRelayIdentity(super.encodeJson(), _relayIdentity);
  }
}

class LocalMonitorRelayFileContent extends WKFileContent {
  LocalMonitorRelayFileContent({LocalMonitorRelayIdentity? relayIdentity})
    : _relayIdentity = relayIdentity;

  final LocalMonitorRelayIdentity? _relayIdentity;

  @override
  Map<String, dynamic> encodeJson() {
    return withLocalMonitorRelayIdentity(super.encodeJson(), _relayIdentity);
  }
}

Map<String, dynamic> withLocalMonitorRelayIdentity(
  Map<String, dynamic> json,
  LocalMonitorRelayIdentity? relayIdentity,
) {
  final identity = relayIdentity;
  if (identity == null || identity.isEmpty) {
    return json;
  }
  return <String, dynamic>{...json, 'robot': identity.toRobotJson()};
}

Future<LocalMonitorForwardableFile> _identityLocalMonitorFilePreparer(
  LocalMonitorForwardableFile file,
) async {
  return file;
}

Future<String> _uploadLocalMonitorFileForWk({
  required String filePath,
  required String channelId,
  required int channelType,
  required String fileName,
}) {
  return FileApi.instance.uploadChatFile(
    filePath: filePath,
    channelId: channelId,
    channelType: channelType,
  );
}

String _safeLocalMonitorFileName(
  String fileName, {
  required String fallbackPath,
}) {
  final fromName = _lastLocalMonitorPathSegment(fileName);
  if (fromName.isNotEmpty) {
    return fromName;
  }
  final fromPath = _lastLocalMonitorPathSegment(fallbackPath);
  return fromPath.isEmpty ? 'file' : fromPath;
}

String _lastLocalMonitorPathSegment(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  if (cleaned.isEmpty) {
    return '';
  }
  final segments = cleaned
      .split(RegExp(r'[\\/]+'))
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .where((segment) => segment != '.' && segment != '..')
      .toList(growable: false);
  if (segments.isEmpty) {
    return '';
  }
  return segments.last;
}

String _localMonitorFileSuffix(String fileName) {
  final safeName = _safeLocalMonitorFileName(fileName, fallbackPath: '');
  final dotIndex = safeName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == safeName.length - 1) {
    return '';
  }
  return safeName.substring(dotIndex + 1).trim().toLowerCase();
}
