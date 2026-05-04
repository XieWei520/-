import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../wukong_base/endpoint/endpoint_handler.dart';
import '../wukong_base/endpoint/endpoint_manager.dart';
import '../wukong_base/endpoint/entity/scan_result_menu.dart';
import '../wukong_base/endpoint/menu/endpoint_menu.dart';
import 'scan_qr_code_image.dart';
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
       _analyzeImageBytes = analyzeImageBytes ?? defaultAnalyzeScanQrImageBytes,
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
    final imageBytes = await loadScanQrImageBytes(imageSource);
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
        MaterialPageRoute<void>(builder: (_) => ScanResultPage(result: result)),
      ),
    );
    return parsedContent;
  }
}
