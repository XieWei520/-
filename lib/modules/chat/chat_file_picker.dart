
import 'package:flutter/foundation.dart';

import '../../core/platform/local_file_picker.dart';

@immutable
class PickedChatFile {
  const PickedChatFile({
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

Future<String?> pickSingleChatImagePath() async {
  return pickSingleLocalImageFilePath();
}

Future<PickedChatFile?> pickSingleChatImageFile() async {
  final file = await pickSingleLocalImageFile();
  if (file == null) {
    return null;
  }
  return PickedChatFile(
    localPath: file.localPath,
    name: file.name,
    size: file.size,
    bytes: file.bytes,
  );
}

Future<PickedChatFile?> pickSingleChatFile() async {
  final file = await pickSingleLocalFile();
  if (file == null) {
    return null;
  }
  return PickedChatFile(
    localPath: file.localPath,
    name: file.name,
    size: file.size,
    bytes: file.bytes,
  );
}
