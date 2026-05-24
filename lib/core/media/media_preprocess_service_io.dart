import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'media_preprocess_models.dart';

typedef MediaPreprocessOutputDirectoryProvider = Future<Directory> Function();
typedef MediaPreprocessComputeRunner =
    Future<R> Function<M, R>(
      FutureOr<R> Function(M message) callback,
      M message, {
      String? debugLabel,
    });

class DefaultMediaPreprocessService implements MediaPreprocessService {
  DefaultMediaPreprocessService({
    MediaPreprocessOutputDirectoryProvider? outputDirectoryProvider,
    MediaPreprocessComputeRunner? computeRunner,
  }) : _outputDirectoryProvider =
           outputDirectoryProvider ?? _defaultOutputDirectory,
       _computeRunner = computeRunner ?? _defaultMediaPreprocessComputeRunner;

  final MediaPreprocessOutputDirectoryProvider _outputDirectoryProvider;
  final MediaPreprocessComputeRunner _computeRunner;

  @override
  Future<MediaImageInfo?> probeImage(String imagePath) async {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty) {
      return null;
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      return null;
    }

    try {
      final response =
          await _computeRunner<Map<String, Object?>, Map<String, Object?>?>(
            _probeImageInBackground,
            <String, Object?>{'path': normalizedPath},
            debugLabel: 'wukong_probe_image',
          );
      if (response == null) {
        return null;
      }
      return _mediaImageInfoFromPayload(response, normalizedPath);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<MediaPreprocessResult> preprocessImage(
    String imagePath, {
    MediaPreprocessOptions options = const MediaPreprocessOptions(),
  }) async {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty) {
      return _unchanged(normalizedPath);
    }

    final file = File(normalizedPath);
    if (!await file.exists()) {
      return _unchanged(normalizedPath);
    }

    try {
      final response =
          await _computeRunner<Map<String, Object?>, Map<String, Object?>?>(
            _preprocessImageInBackground,
            <String, Object?>{
              'path': normalizedPath,
              'maxDimension': options.normalizedMaxDimension,
              'quality': options.normalizedQuality,
              'forceReencode': options.forceReencode,
            },
            debugLabel: 'wukong_preprocess_image',
          );
      if (response == null) {
        return _unchanged(normalizedPath);
      }

      final inputInfo = MediaImageInfo(
        path: normalizedPath,
        width: response['inputWidth'] as int,
        height: response['inputHeight'] as int,
        bytes: response['inputBytes'] as int,
      );
      final didResize = response['didResize'] as bool;
      final didReencode = response['didReencode'] as bool;
      if (!didReencode) {
        return MediaPreprocessResult(
          sourcePath: normalizedPath,
          outputPath: normalizedPath,
          didResize: didResize,
          didReencode: false,
          inputInfo: inputInfo,
          outputInfo: inputInfo,
        );
      }

      final encodedBytes = response['encodedBytes'] as Uint8List;
      final outputFile = await _createOutputFile(
        sourcePath: normalizedPath,
        extension: response['extension'] as String,
        options: options,
      );
      await outputFile.writeAsBytes(encodedBytes, flush: true);

      final outputInfo = MediaImageInfo(
        path: outputFile.path,
        width: response['outputWidth'] as int,
        height: response['outputHeight'] as int,
        bytes: encodedBytes.length,
      );
      return MediaPreprocessResult(
        sourcePath: normalizedPath,
        outputPath: outputFile.path,
        didResize: didResize,
        didReencode: didReencode,
        inputInfo: inputInfo,
        outputInfo: outputInfo,
      );
    } catch (_) {
      return _unchanged(normalizedPath);
    }
  }

  static Future<Directory> _defaultOutputDirectory() async {
    final baseDir = await getTemporaryDirectory();
    return Directory(path.join(baseDir.path, 'wukong_media_preprocess'));
  }

  MediaPreprocessResult _unchanged(String sourcePath) {
    return MediaPreprocessResult(
      sourcePath: sourcePath,
      outputPath: sourcePath,
      didResize: false,
      didReencode: false,
    );
  }

  Future<File> _createOutputFile({
    required String sourcePath,
    required String extension,
    required MediaPreprocessOptions options,
  }) async {
    final outputDirectoryPath = options.outputDirectoryPath?.trim();
    final outputDirectory =
        outputDirectoryPath == null || outputDirectoryPath.isEmpty
        ? await _outputDirectoryProvider()
        : Directory(outputDirectoryPath);
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }

    final sourceName = path.basenameWithoutExtension(sourcePath);
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return File(
      path.join(outputDirectory.path, '${sourceName}_$timestamp$extension'),
    );
  }
}

Future<R> _defaultMediaPreprocessComputeRunner<M, R>(
  FutureOr<R> Function(M message) callback,
  M message, {
  String? debugLabel,
}) {
  return compute<M, R>(callback, message, debugLabel: debugLabel);
}

Map<String, Object?>? _probeImageInBackground(Map<String, Object?> request) {
  final imagePath = request['path'] as String;
  final bytes = File(imagePath).readAsBytesSync();
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }

  return <String, Object?>{
    'width': decoded.width,
    'height': decoded.height,
    'bytes': bytes.length,
  };
}

Map<String, Object?>? _preprocessImageInBackground(
  Map<String, Object?> request,
) {
  final imagePath = request['path'] as String;
  final maxDimension = request['maxDimension'] as int;
  final quality = request['quality'] as int;
  final forceReencode = request['forceReencode'] as bool;

  final bytes = File(imagePath).readAsBytesSync();
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    return null;
  }

  final target = _resolveTargetSize(
    width: decoded.width,
    height: decoded.height,
    maxDimension: maxDimension,
  );
  final didResize =
      target.width != decoded.width || target.height != decoded.height;
  if (!didResize && !forceReencode && quality >= 100) {
    return <String, Object?>{
      'inputWidth': decoded.width,
      'inputHeight': decoded.height,
      'inputBytes': bytes.length,
      'didResize': false,
      'didReencode': false,
    };
  }

  final outputImage = didResize
      ? image.copyResize(
          decoded,
          width: target.width,
          height: target.height,
          interpolation: image.Interpolation.average,
        )
      : decoded;
  final encoded = _encodeOutput(outputImage, quality: quality);
  return <String, Object?>{
    'inputWidth': decoded.width,
    'inputHeight': decoded.height,
    'inputBytes': bytes.length,
    'didResize': didResize,
    'didReencode': true,
    'outputWidth': outputImage.width,
    'outputHeight': outputImage.height,
    'encodedBytes': encoded.bytes,
    'extension': encoded.extension,
  };
}

MediaImageInfo _mediaImageInfoFromPayload(
  Map<String, Object?> payload,
  String imagePath,
) {
  return MediaImageInfo(
    path: imagePath,
    width: payload['width'] as int,
    height: payload['height'] as int,
    bytes: payload['bytes'] as int,
  );
}

_EncodedMediaImage _encodeOutput(
  image.Image outputImage, {
  required int quality,
}) {
  if (outputImage.hasAlpha) {
    return _EncodedMediaImage(
      bytes: Uint8List.fromList(image.encodePng(outputImage)),
      extension: '.png',
    );
  }

  final jpgReady = outputImage.numChannels == 3
      ? outputImage
      : outputImage.convert(numChannels: 3);
  return _EncodedMediaImage(
    bytes: Uint8List.fromList(image.encodeJpg(jpgReady, quality: quality)),
    extension: '.jpg',
  );
}

_MediaTargetSize _resolveTargetSize({
  required int width,
  required int height,
  required int maxDimension,
}) {
  final longest = math.max(width, height);
  if (longest <= maxDimension) {
    return _MediaTargetSize(width, height);
  }

  final scale = maxDimension / longest;
  return _MediaTargetSize(
    math.max(1, (width * scale).round()),
    math.max(1, (height * scale).round()),
  );
}

class _EncodedMediaImage {
  const _EncodedMediaImage({required this.bytes, required this.extension});

  final Uint8List bytes;
  final String extension;
}

class _MediaTargetSize {
  const _MediaTargetSize(this.width, this.height);

  final int width;
  final int height;
}
