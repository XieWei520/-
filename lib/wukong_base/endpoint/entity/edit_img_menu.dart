import 'dart:typed_data';

/// Edit image menu
/// 
/// Used for image editing functionality
class EditImgMenu {
  /// Image path or bytes
  final String? imagePath;

  /// Image bytes (alternative to path)
  final Uint8List? imageBytes;

  /// Request code for result callback
  final int requestCode;

  /// Whether to show save dialog
  final bool isShowSaveDialog;

  /// Callback when editing is complete
  final void Function(Uint8List? imageBytes, String? path)? onResult;

  EditImgMenu({
    this.imagePath,
    this.imageBytes,
    this.requestCode = 0,
    this.isShowSaveDialog = true,
    this.onResult,
  });
}
