import 'dart:typed_data';
import 'base_endpoint.dart';

/// Callback for scan result
typedef ScanResultCallback = bool Function(Map<String, dynamic> result);

/// Scan result menu
/// 
/// Used for processing QR code scan results
class ScanResultMenu extends BaseEndpoint {
  /// Callback when scan result is received
  final ScanResultCallback? onResult;

  ScanResultMenu({this.onResult}) : super(sid: 'scan_result');
}

/// Parse QR code menu
/// 
/// Used for parsing QR code from image
class ParseQrCodeMenu {
  /// Whether to jump after parsing
  final bool isJump;

  /// Image data (bytes)
  final Uint8List? imageBytes;

  /// Callback when parsing is complete
  final void Function(String codeContent)? onResult;

  ParseQrCodeMenu({
    this.isJump = true,
    this.imageBytes,
    this.onResult,
  });
}
