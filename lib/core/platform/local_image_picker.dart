import 'package:image_picker/image_picker.dart';

import '../utils/platform_utils.dart';
import 'local_file_picker.dart';

enum LocalImagePickSource { gallery, camera }

class LocalImagePicker {
  LocalImagePicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<String?> pickSingleImagePath({
    LocalImagePickSource source = LocalImagePickSource.gallery,
    int imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
    bool useDesktopFilePickerForGallery = true,
  }) async {
    if (source == LocalImagePickSource.gallery &&
        useDesktopFilePickerForGallery &&
        PlatformUtils.isDesktop) {
      return pickSingleLocalImageFilePath();
    }

    final file = await _imagePicker.pickImage(
      source: _toImageSource(source),
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return _normalizedPath(file?.path);
  }

  Future<List<String>> pickMultipleImagePaths({
    int imageQuality = 85,
    double? maxWidth,
    double? maxHeight,
    int? limit,
    bool useDesktopFilePickerForGallery = true,
  }) async {
    if (useDesktopFilePickerForGallery && PlatformUtils.isDesktop) {
      final paths = await pickMultipleLocalImageFilePaths();
      return _limitPaths(paths ?? const <String>[], limit);
    }

    final images = await _imagePicker.pickMultiImage(
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    return _limitPaths(images.map((image) => image.path), limit);
  }

  ImageSource _toImageSource(LocalImagePickSource source) {
    switch (source) {
      case LocalImagePickSource.gallery:
        return ImageSource.gallery;
      case LocalImagePickSource.camera:
        return ImageSource.camera;
    }
  }
}

Future<String?> pickSingleLocalImagePath({
  LocalImagePickSource source = LocalImagePickSource.gallery,
  int imageQuality = 85,
  double? maxWidth,
  double? maxHeight,
  bool useDesktopFilePickerForGallery = true,
}) {
  return LocalImagePicker().pickSingleImagePath(
    source: source,
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    useDesktopFilePickerForGallery: useDesktopFilePickerForGallery,
  );
}

Future<List<String>> pickMultipleLocalImagePaths({
  int imageQuality = 85,
  double? maxWidth,
  double? maxHeight,
  int? limit,
  bool useDesktopFilePickerForGallery = true,
}) {
  return LocalImagePicker().pickMultipleImagePaths(
    imageQuality: imageQuality,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    limit: limit,
    useDesktopFilePickerForGallery: useDesktopFilePickerForGallery,
  );
}

String? _normalizedPath(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

List<String> _limitPaths(Iterable<String> paths, int? limit) {
  final normalized = paths
      .map((path) => path.trim())
      .where((path) => path.isNotEmpty);
  if (limit == null) {
    return normalized.toList(growable: false);
  }
  return normalized.take(limit).toList(growable: false);
}
