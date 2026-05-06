import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';

import '../../core/platform/local_image_picker.dart';
import '../../data/models/wk_custom_content.dart';
import '../../service/api/file_api.dart';
import '../location/location_map_page.dart';
import 'chat_contact_picker_dialog.dart';
import 'chat_file_picker.dart';
import 'chat_image_bytes_loader.dart';
import 'chat_rich_text_compose_dialog.dart';

@immutable
class ChatImageDimensions {
  const ChatImageDimensions({required this.width, required this.height});

  final int width;
  final int height;
}

@immutable
class ChatLocationSelection {
  const ChatLocationSelection({
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String title;
  final String address;
}

@immutable
class ChatFileSelection {
  const ChatFileSelection({
    required this.localPath,
    required this.name,
    required this.size,
    this.bytes,
  });

  final String localPath;
  final String name;
  final int size;
  final Uint8List? bytes;
}

@immutable
class ChatDroppedFileSelection {
  const ChatDroppedFileSelection({
    required this.localPath,
    required this.name,
    required this.size,
    this.mimeType,
  });

  final String localPath;
  final String name;
  final int size;
  final String? mimeType;
}

@immutable
class ChatCardSelection {
  const ChatCardSelection({required this.uid, required this.name});

  final String uid;
  final String name;
}

class ChatMediaContentFactory {
  WKImageContent buildImageContent({
    required String localPath,
    required int width,
    required int height,
    String remoteUrl = '',
  }) {
    final content = WKImageContent(width, height);
    content.localPath = localPath;
    content.url = remoteUrl.trim();
    return content;
  }

  WKFileContent buildFileContent({
    required String localPath,
    required String name,
    required int size,
    String remoteUrl = '',
  }) {
    final normalizedPath = localPath.trim();
    final safeName = _safeFileName(name, fallbackPath: normalizedPath);
    final content = WKFileContent()
      ..localPath = normalizedPath
      ..name = safeName
      ..size = size < 0 ? 0 : size
      ..url = remoteUrl.trim()
      ..suffix = _normalizedSuffix(localPath: normalizedPath, name: safeName);
    return content;
  }

  WKLocationContent buildLocationContent(ChatLocationSelection selection) {
    return WKLocationContent()
      ..latitude = selection.latitude
      ..longitude = selection.longitude
      ..title = selection.title
      ..address = selection.address;
  }

  WKCardContent buildCardContent(ChatCardSelection selection) {
    return WKCardContent(selection.uid, selection.name);
  }

  WKRichTextContent buildRichTextContent(ChatRichTextSelection selection) {
    return WKRichTextContent(title: selection.title, body: selection.body);
  }

  Future<WKMessageContent?> buildDroppedFileContent(
    ChatDroppedFileSelection selection, {
    ChatImageDimensionsLoader? loadImageDimensions,
  }) async {
    final localPath = selection.localPath.trim();
    if (localPath.isEmpty) {
      return null;
    }

    final name = _safeFileName(selection.name, fallbackPath: localPath);
    if (_isImageLikeDrop(
      localPath: localPath,
      name: name,
      mimeType: selection.mimeType,
    )) {
      final dimensions = await _safeLoadDroppedImageDimensions(
        localPath,
        loadImageDimensions: loadImageDimensions,
      );
      return buildImageContent(
        localPath: localPath,
        width: dimensions.width,
        height: dimensions.height,
      );
    }

    return buildFileContent(
      localPath: localPath,
      name: name,
      size: selection.size,
    );
  }

  String _normalizedSuffix({required String localPath, required String name}) {
    final source = _safeFileName(name, fallbackPath: localPath);
    final dotIndex = source.lastIndexOf('.');
    final extension = dotIndex <= 0 || dotIndex == source.length - 1
        ? ''
        : source.substring(dotIndex + 1).trim();
    return extension.toLowerCase();
  }

  String _safeFileName(String name, {required String fallbackPath}) {
    final fromName = _lastSafePathSegment(name);
    if (fromName.isNotEmpty) {
      return fromName;
    }
    final fromPath = _lastSafePathSegment(fallbackPath);
    if (fromPath.isNotEmpty) {
      return fromPath;
    }
    return 'file';
  }

  String _lastSafePathSegment(String value) {
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

  bool _isImageLikeDrop({
    required String localPath,
    required String name,
    String? mimeType,
  }) {
    final normalizedMime = mimeType?.trim().toLowerCase() ?? '';
    if (normalizedMime.startsWith('image/')) {
      return true;
    }
    final suffix = _normalizedSuffix(localPath: localPath, name: name);
    return const <String>{
      'png',
      'jpg',
      'jpeg',
      'gif',
      'webp',
      'bmp',
      'heic',
      'heif',
    }.contains(suffix);
  }

  Future<ChatImageDimensions> _safeLoadDroppedImageDimensions(
    String localPath, {
    ChatImageDimensionsLoader? loadImageDimensions,
  }) async {
    try {
      return await (loadImageDimensions ?? _loadDroppedImageDimensions)(
        localPath,
      );
    } catch (_) {
      return const ChatImageDimensions(width: 0, height: 0);
    }
  }
}

abstract class ChatMediaActionService {
  Future<WKImageContent?> pickImage(
    BuildContext context, {
    String channelId = '',
    int channelType = 0,
  });

  Future<WKFileContent?> pickFile(
    BuildContext context, {
    String channelId = '',
    int channelType = 0,
  });

  Future<WKMessageContent?> buildDroppedFile(
    ChatDroppedFileSelection selection,
  );

  Future<WKLocationContent?> pickLocation(BuildContext context);

  Future<WKCardContent?> pickCard(BuildContext context);

  Future<WKRichTextContent?> pickRichText(BuildContext context);
}

typedef ChatImagePathPicker = Future<String?> Function();
typedef ChatImageFilePicker = Future<ChatFileSelection?> Function();
typedef ChatFilePicker = Future<ChatFileSelection?> Function();
typedef ChatPickedFileBytesUploader =
    Future<String> Function({
      required Uint8List bytes,
      required String fileName,
      required String channelId,
      required int channelType,
    });
typedef ChatLocationPicker =
    Future<ChatLocationSelection?> Function(BuildContext context);
typedef ChatCardPicker =
    Future<ChatCardSelection?> Function(BuildContext context);
typedef ChatRichTextComposer =
    Future<ChatRichTextSelection?> Function(BuildContext context);
typedef ChatImageDimensionsLoader =
    Future<ChatImageDimensions> Function(String localPath);

class PlatformChatMediaActionService implements ChatMediaActionService {
  PlatformChatMediaActionService({
    ChatMediaContentFactory? factory,
    ChatImagePathPicker? pickImagePath,
    ChatImageFilePicker? pickImageFile,
    ChatFilePicker? pickFile,
    ChatPickedFileBytesUploader? uploadPickedFileBytes,
    ChatLocationPicker? pickLocation,
    ChatCardPicker? pickCard,
    ChatRichTextComposer? pickRichText,
    ChatImageDimensionsLoader? loadImageDimensions,
  }) : _factory = factory ?? ChatMediaContentFactory(),
       _pickImagePath = pickImagePath,
       _pickImageFile = pickImageFile,
       _pickFile = pickFile,
       _uploadPickedFileBytes = uploadPickedFileBytes,
       _pickLocation = pickLocation,
       _pickCard = pickCard,
       _pickRichText = pickRichText,
       _loadImageDimensions = loadImageDimensions;

  final ChatMediaContentFactory _factory;
  final ChatImagePathPicker? _pickImagePath;
  final ChatImageFilePicker? _pickImageFile;
  final ChatFilePicker? _pickFile;
  final ChatPickedFileBytesUploader? _uploadPickedFileBytes;
  final ChatLocationPicker? _pickLocation;
  final ChatCardPicker? _pickCard;
  final ChatRichTextComposer? _pickRichText;
  final ChatImageDimensionsLoader? _loadImageDimensions;

  @override
  Future<WKCardContent?> pickCard(BuildContext context) async {
    final selection = await (_pickCard ?? _defaultPickCardSelection).call(
      context,
    );
    if (selection == null) {
      return null;
    }
    return _factory.buildCardContent(selection);
  }

  @override
  Future<WKFileContent?> pickFile(
    BuildContext context, {
    String channelId = '',
    int channelType = 0,
  }) async {
    final selection = await (_pickFile ?? _defaultPickFileSelection).call();
    if (selection == null) {
      return null;
    }
    final bytes = selection.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final remoteUrl = await _uploadPickedBytes(
        bytes: bytes,
        fileName: selection.name,
        channelId: channelId,
        channelType: channelType,
      );
      return _factory.buildFileContent(
        localPath: '',
        name: selection.name,
        size: selection.size,
        remoteUrl: remoteUrl,
      );
    }
    return _factory.buildFileContent(
      localPath: selection.localPath,
      name: selection.name,
      size: selection.size,
    );
  }

  @override
  Future<WKMessageContent?> buildDroppedFile(
    ChatDroppedFileSelection selection,
  ) {
    return _factory.buildDroppedFileContent(
      selection,
      loadImageDimensions: _loadImageDimensions ?? _defaultLoadImageDimensions,
    );
  }

  @override
  Future<WKImageContent?> pickImage(
    BuildContext context, {
    String channelId = '',
    int channelType = 0,
  }) async {
    final pickImageFile = _pickImageFile;
    if (pickImageFile != null || kIsWeb) {
      final selection = await (pickImageFile ?? _defaultPickImageFileSelection)
          .call();
      return _buildPickedImageContent(
        selection,
        channelId: channelId,
        channelType: channelType,
      );
    }

    final localPath = await (_pickImagePath ?? _defaultPickImagePath).call();
    if (localPath == null || localPath.trim().isEmpty) {
      return null;
    }
    final normalizedPath = localPath.trim();
    final dimensions =
        await (_loadImageDimensions ?? _defaultLoadImageDimensions)(
          normalizedPath,
        );
    return _factory.buildImageContent(
      localPath: normalizedPath,
      width: dimensions.width,
      height: dimensions.height,
    );
  }

  @override
  Future<WKLocationContent?> pickLocation(BuildContext context) async {
    final selection = await (_pickLocation ?? _defaultPickLocationSelection)
        .call(context);
    if (selection == null) {
      return null;
    }
    return _factory.buildLocationContent(selection);
  }

  @override
  Future<WKRichTextContent?> pickRichText(BuildContext context) async {
    final selection = await (_pickRichText ?? _defaultComposeRichTextSelection)
        .call(context);
    if (selection == null) {
      return null;
    }
    return _factory.buildRichTextContent(selection);
  }

  Future<String?> _defaultPickImagePath() async {
    return pickSingleLocalImagePath(
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
  }

  Future<ChatFileSelection?> _defaultPickFileSelection() async {
    final file = await pickSingleChatFile();
    if (file == null) {
      return null;
    }
    return ChatFileSelection(
      localPath: file.localPath,
      name: file.name,
      size: file.size,
      bytes: file.bytes,
    );
  }

  Future<ChatFileSelection?> _defaultPickImageFileSelection() async {
    final file = await pickSingleChatImageFile();
    if (file == null) {
      return null;
    }
    return ChatFileSelection(
      localPath: file.localPath,
      name: file.name,
      size: file.size,
      bytes: file.bytes,
    );
  }

  Future<ChatLocationSelection?> _defaultPickLocationSelection(
    BuildContext context,
  ) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (_) => const LocationMapPage(),
      ),
    );
    if (result == null) {
      return null;
    }

    final latitude = (result['latitude'] as num?)?.toDouble();
    final longitude = (result['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) {
      return null;
    }

    return ChatLocationSelection(
      latitude: latitude,
      longitude: longitude,
      title: result['title']?.toString().trim() ?? '',
      address: result['address']?.toString().trim() ?? '',
    );
  }

  Future<ChatCardSelection?> _defaultPickCardSelection(
    BuildContext context,
  ) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const ContactPickerDialog(),
    );
    final uid = result?['uid']?.trim() ?? '';
    final name = result?['name']?.trim() ?? '';
    if (uid.isEmpty || name.isEmpty) {
      return null;
    }
    return ChatCardSelection(uid: uid, name: name);
  }

  Future<ChatRichTextSelection?> _defaultComposeRichTextSelection(
    BuildContext context,
  ) {
    return showChatRichTextComposeDialog(context);
  }

  Future<ChatImageDimensions> _defaultLoadImageDimensions(
    String localPath,
  ) async {
    return _loadDroppedImageDimensions(localPath);
  }

  Future<WKImageContent?> _buildPickedImageContent(
    ChatFileSelection? selection, {
    required String channelId,
    required int channelType,
  }) async {
    if (selection == null) {
      return null;
    }

    final bytes = selection.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      final remoteUrl = await _uploadPickedBytes(
        bytes: bytes,
        fileName: selection.name,
        channelId: channelId,
        channelType: channelType,
      );
      final dimensions = await _safeDecodeImageDimensions(bytes);
      return _factory.buildImageContent(
        localPath: '',
        width: dimensions.width,
        height: dimensions.height,
        remoteUrl: remoteUrl,
      );
    }

    final localPath = selection.localPath.trim();
    if (localPath.isEmpty) {
      return null;
    }
    final dimensions =
        await (_loadImageDimensions ?? _defaultLoadImageDimensions)(localPath);
    return _factory.buildImageContent(
      localPath: localPath,
      width: dimensions.width,
      height: dimensions.height,
    );
  }

  Future<String> _uploadPickedBytes({
    required Uint8List bytes,
    required String fileName,
    required String channelId,
    required int channelType,
  }) {
    final uploader =
        _uploadPickedFileBytes ?? FileApi.instance.uploadChatFileBytes;
    return uploader(
      bytes: bytes,
      fileName: fileName,
      channelId: channelId,
      channelType: channelType,
    );
  }
}

Future<ChatImageDimensions> _loadDroppedImageDimensions(
  String localPath,
) async {
  try {
    final bytes = await loadChatImageBytes(localPath);
    if (bytes == null || bytes.isEmpty) {
      return const ChatImageDimensions(width: 0, height: 0);
    }
    return _decodeImageDimensions(bytes);
  } catch (_) {
    return const ChatImageDimensions(width: 0, height: 0);
  }
}

Future<ChatImageDimensions> _decodeImageDimensions(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  try {
    return ChatImageDimensions(
      width: descriptor.width,
      height: descriptor.height,
    );
  } finally {
    descriptor.dispose();
    buffer.dispose();
  }
}

Future<ChatImageDimensions> _safeDecodeImageDimensions(Uint8List bytes) async {
  try {
    return await _decodeImageDimensions(bytes);
  } catch (_) {
    return const ChatImageDimensions(width: 0, height: 0);
  }
}
