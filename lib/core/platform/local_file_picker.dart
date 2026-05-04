import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

const List<String> localImageFileExtensions = <String>[
  'png',
  'jpg',
  'jpeg',
  'webp',
  'gif',
  'bmp',
];

@immutable
class PickedLocalFile {
  const PickedLocalFile({
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

Future<String?> pickSingleLocalImageFilePath({
  List<String> allowedExtensions = localImageFileExtensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: false,
    withData: kIsWeb,
  );
  if (result == null || kIsWeb) {
    return null;
  }
  return result.files.single.path?.trim();
}

Future<PickedLocalFile?> pickSingleLocalImageFile({
  List<String> allowedExtensions = localImageFileExtensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    allowMultiple: false,
    withData: kIsWeb,
  );
  final file = result?.files.single;
  if (file == null) {
    return null;
  }
  final localPath = kIsWeb ? '' : file.path?.trim() ?? '';
  final bytes = file.bytes;
  if (localPath.isEmpty && (bytes == null || bytes.isEmpty)) {
    return null;
  }
  return PickedLocalFile(
    localPath: localPath,
    name: file.name,
    size: file.size,
    bytes: bytes,
  );
}

Future<List<String>?> pickMultipleLocalImageFilePaths({
  List<String> allowedExtensions = localImageFileExtensions,
}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.custom,
    allowedExtensions: allowedExtensions,
    withData: false,
  );
  if (result == null) {
    return null;
  }
  if (kIsWeb) {
    return const <String>[];
  }
  return result.paths
      .whereType<String>()
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty)
      .toList(growable: false);
}

Future<PickedLocalFile?> pickSingleLocalFile() async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    withData: kIsWeb,
  );
  final file = result?.files.single;
  if (file == null) {
    return null;
  }
  final localPath = kIsWeb ? '' : file.path?.trim() ?? '';
  final bytes = file.bytes;
  if (localPath.isEmpty && (bytes == null || bytes.isEmpty)) {
    return null;
  }
  return PickedLocalFile(
    localPath: localPath,
    name: file.name,
    size: file.size,
    bytes: bytes,
  );
}
