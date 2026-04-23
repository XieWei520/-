import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../wukong_base/endpoint/endpoint_handler.dart';
import '../wukong_base/endpoint/endpoint_manager.dart';
import '../wukong_base/endpoint/entity/scan_result_menu.dart';
import '../wukong_base/endpoint/menu/endpoint_menu.dart';
import 'scan_result_page.dart';
import 'scan_service.dart';

typedef ScanQrImageAnalyzer = Future<String?> Function(Uint8List imageBytes);
typedef ScanQrResultProcessor =
    Future<ScanServiceResult> Function(String content);

class ScanQrCodeBridge {
  ScanQrCodeBridge({
    EndpointManager? endpointManager,
    ScanQrImageAnalyzer? analyzeImageBytes,
    ScanQrResultProcessor? processScanResult,
  }) : _endpointManager = endpointManager ?? EndpointManager.getInstance(),
       _analyzeImageBytes =
           analyzeImageBytes ?? _defaultAnalyzeImageBytes,
       _processScanResult =
           processScanResult ?? ScanService.instance.processScanResult;

  static final ScanQrCodeBridge instance = ScanQrCodeBridge();

  final EndpointManager _endpointManager;
  final ScanQrImageAnalyzer _analyzeImageBytes;
  final ScanQrResultProcessor _processScanResult;

  GlobalKey<NavigatorState>? _navigatorKey;
  bool _registered = false;

  bool get isRegistered => _registered;

  void bindNavigator(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  void ensureRegistered() {
    if (_registered || _endpointManager.hasEndpoint(ChatMenuIDs.parseQrCode)) {
      _registered = true;
      return;
    }
    _endpointManager.setMethod(
      ChatMenuIDs.parseQrCode,
      '',
      0,
      AsyncFunctionHandler(_handleParseRequest),
    );
    _registered = true;
  }

  Future<bool> handleImageSource(
    String imageSource, {
    bool isJump = true,
    void Function(String codeContent)? onResult,
  }) async {
    ensureRegistered();
    final imageBytes = await _loadImageBytes(imageSource);
    if (imageBytes == null || imageBytes.isEmpty) {
      onResult?.call('');
      return false;
    }

    final result = await _handleParseRequest(
      ParseQrCodeMenu(
        isJump: isJump,
        imageBytes: imageBytes,
        onResult: onResult,
      ),
    );
    return result is String && result.trim().isNotEmpty;
  }

  Future<dynamic> _handleParseRequest([dynamic param]) async {
    if (param is! ParseQrCodeMenu) {
      return null;
    }
    final imageBytes = param.imageBytes;
    if (imageBytes == null || imageBytes.isEmpty) {
      param.onResult?.call('');
      return null;
    }

    final parsedContent = (await _analyzeImageBytes(imageBytes))?.trim() ?? '';
    if (parsedContent.isEmpty) {
      param.onResult?.call('');
      return null;
    }

    if (!param.isJump) {
      param.onResult?.call(parsedContent);
      return parsedContent;
    }

    final navigatorState = _navigatorKey?.currentState;
    if (navigatorState == null) {
      param.onResult?.call(parsedContent);
      return parsedContent;
    }

    final result = await _processScanResult(parsedContent);
    unawaited(
      navigatorState.push(
        MaterialPageRoute<void>(
          builder: (_) => ScanResultPage(result: result),
        ),
      ),
    );
    return parsedContent;
  }

  Future<Uint8List?> _loadImageBytes(String imageSource) async {
    final normalizedSource = imageSource.trim();
    if (normalizedSource.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalizedSource);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode >= 400) {
          return null;
        }
        return consolidateHttpClientResponseBytes(response);
      } finally {
        client.close(force: true);
      }
    }

    final path = normalizedSource.startsWith('file://')
        ? Uri.parse(normalizedSource).toFilePath()
        : normalizedSource;
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    return file.readAsBytes();
  }

  static Future<String?> _defaultAnalyzeImageBytes(Uint8List imageBytes) async {
    if (kIsWeb || imageBytes.isEmpty) {
      return null;
    }

    final tempFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'wk_qr_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    final controller = MobileScannerController(autoStart: false);
    try {
      await tempFile.writeAsBytes(imageBytes, flush: true);
      final capture = await controller.analyzeImage(tempFile.path);
      if (capture == null) {
        return null;
      }
      for (final barcode in capture.barcodes) {
        final rawValue = barcode.rawValue?.trim() ?? '';
        if (rawValue.isNotEmpty) {
          return rawValue;
        }
        final displayValue = barcode.displayValue?.trim() ?? '';
        if (displayValue.isNotEmpty) {
          return displayValue;
        }
      }
      return null;
    } finally {
      controller.dispose();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
}
