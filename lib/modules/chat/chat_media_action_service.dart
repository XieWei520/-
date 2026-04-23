import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:wukongimfluttersdk/model/wk_image_content.dart';
import 'package:wukongimfluttersdk/model/wk_rich_text_content.dart';

import '../../core/utils/platform_utils.dart';
import '../../data/models/wk_custom_content.dart';
import '../location/location_map_page.dart';
import 'chat_contact_picker_dialog.dart';
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
  });

  final String localPath;
  final String name;
  final int size;
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
  }) {
    final content = WKImageContent(width, height);
    content.localPath = localPath;
    return content;
  }

  WKFileContent buildFileContent({
    required String localPath,
    required String name,
    required int size,
  }) {
    final content = WKFileContent()
      ..localPath = localPath
      ..name = name.trim().isEmpty ? path.basename(localPath) : name.trim()
      ..size = size
      ..suffix = _normalizedSuffix(localPath: localPath, name: name);
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

  String _normalizedSuffix({
    required String localPath,
    required String name,
  }) {
    final source = name.trim().isNotEmpty ? name.trim() : localPath.trim();
    final extension = path.extension(source).replaceFirst('.', '').trim();
    return extension.toLowerCase();
  }
}

abstract class ChatMediaActionService {
  Future<WKImageContent?> pickImage(BuildContext context);

  Future<WKFileContent?> pickFile(BuildContext context);

  Future<WKLocationContent?> pickLocation(BuildContext context);

  Future<WKCardContent?> pickCard(BuildContext context);

  Future<WKRichTextContent?> pickRichText(BuildContext context);
}

typedef ChatImagePathPicker = Future<String?> Function();
typedef ChatFilePicker = Future<ChatFileSelection?> Function();
typedef ChatLocationPicker =
    Future<ChatLocationSelection?> Function(BuildContext context);
typedef ChatCardPicker = Future<ChatCardSelection?> Function(BuildContext context);
typedef ChatRichTextComposer =
    Future<ChatRichTextSelection?> Function(BuildContext context);
typedef ChatImageDimensionsLoader =
    Future<ChatImageDimensions> Function(String localPath);

class PlatformChatMediaActionService implements ChatMediaActionService {
  PlatformChatMediaActionService({
    ChatMediaContentFactory? factory,
    ImagePicker? imagePicker,
    ChatImagePathPicker? pickImagePath,
    ChatFilePicker? pickFile,
    ChatLocationPicker? pickLocation,
    ChatCardPicker? pickCard,
    ChatRichTextComposer? pickRichText,
    ChatImageDimensionsLoader? loadImageDimensions,
  }) : _factory = factory ?? ChatMediaContentFactory(),
       _imagePicker = imagePicker ?? ImagePicker(),
       _pickImagePath = pickImagePath,
       _pickFile = pickFile,
       _pickLocation = pickLocation,
       _pickCard = pickCard,
       _pickRichText = pickRichText,
        _loadImageDimensions = loadImageDimensions;

  final ChatMediaContentFactory _factory;
  final ImagePicker _imagePicker;
  final ChatImagePathPicker? _pickImagePath;
  final ChatFilePicker? _pickFile;
  final ChatLocationPicker? _pickLocation;
  final ChatCardPicker? _pickCard;
  final ChatRichTextComposer? _pickRichText;
  final ChatImageDimensionsLoader? _loadImageDimensions;

  @override
  Future<WKCardContent?> pickCard(BuildContext context) async {
    final selection =
        await (_pickCard ?? _defaultPickCardSelection).call(context);
    if (selection == null) {
      return null;
    }
    return _factory.buildCardContent(selection);
  }

  @override
  Future<WKFileContent?> pickFile(BuildContext context) async {
    final selection = await (_pickFile ?? _defaultPickFileSelection).call();
    if (selection == null) {
      return null;
    }
    return _factory.buildFileContent(
      localPath: selection.localPath,
      name: selection.name,
      size: selection.size,
    );
  }

  @override
  Future<WKImageContent?> pickImage(BuildContext context) async {
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
    final selection =
        await (_pickLocation ?? _defaultPickLocationSelection).call(context);
    if (selection == null) {
      return null;
    }
    return _factory.buildLocationContent(selection);
  }

  @override
  Future<WKRichTextContent?> pickRichText(BuildContext context) async {
    final selection =
        await (_pickRichText ?? _defaultComposeRichTextSelection).call(context);
    if (selection == null) {
      return null;
    }
    return _factory.buildRichTextContent(selection);
  }

  Future<String?> _defaultPickImagePath() async {
    if (PlatformUtils.isDesktop) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>[
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'bmp',
        ],
        allowMultiple: false,
        withData: false,
      );
      return result?.files.single.path;
    }

    final file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    return file?.path;
  }

  Future<ChatFileSelection?> _defaultPickFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: false,
    );
    final file = result?.files.single;
    final localPath = file?.path?.trim() ?? '';
    if (file == null || localPath.isEmpty) {
      return null;
    }
    return ChatFileSelection(
      localPath: localPath,
      name: file.name,
      size: file.size,
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
    try {
      final bytes = await File(localPath).readAsBytes();
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
}
