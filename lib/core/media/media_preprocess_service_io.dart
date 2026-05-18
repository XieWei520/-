import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'media_preprocess_models.dart';

typedef MediaPreprocessOutputDirectoryProvider = Future<Directory> Function();

class DefaultMediaPreprocessService implements MediaPreprocessService {
  DefaultMediaPreprocessService({
    MediaPreprocessOutputDirectoryProvider? outputDirectoryProvider,
  }) : _outputDirectoryProvider =
           outputDirectoryProvider ?? _defaultOutputDirectory;

  final MediaPreprocessOutputDirectoryProvider _outputDirectoryProvider;

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
      final bytes = await file.readAsBytes();
      final decoded = image.decodeImage(bytes);
      if (decoded == null) {
        return null;
      }
      return MediaImageInfo(
        path: normalizedPath,
        width: decoded.width,
        height: decoded.height,
        bytes: bytes.length,
      );
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
      final bytes = await file.readAsBytes();
      final decoded = image.decodeImage(bytes);
      if (decoded == null) {
        return _unchanged(normalizedPath);
      }

      final inputInfo = MediaImageInfo(
        path: normalizedPath,
        width: decoded.width,
        height: decoded.height,
        bytes: bytes.length,
      );
      final target = _resolveTargetSize(
        width: decoded.width,
        height: decoded.height,
        maxDimension: options.normalizedMaxDimension,
      );
      final didResize =
          target.width != decoded.width || target.height != decoded.height;
      if (!didResize &&
          !options.forceReencode &&
          options.normalizedQuality >= 100) {
        return MediaPreprocessResult(
          sourcePath: normalizedPath,
          outputPath: normalizedPath,
          didResize: false,
          didReencode: false,
          inputInfo: inputInfo,
          outputInfo: inputInfo,
        );
      }

      final outputImage = didResize
          ? image.copyResize(
              decoded,
              width: target.width,
              height: target.height,
              interpolation: image.Interpolation.average,
            )
          : decoded;
      final encoded = _encodeOutput(
        outputImage,
        quality: options.normalizedQuality,
      );
      final outputFile = await _createOutputFile(
        sourcePath: normalizedPath,
        extension: encoded.extension,
        options: options,
      );
      await outputFile.writeAsBytes(encoded.bytes, flush: true);

      final outputInfo = MediaImageInfo(
        path: outputFile.path,
        width: outputImage.width,
        height: outputImage.height,
        bytes: encoded.bytes.length,
      );
      return MediaPreprocessResult(
        sourcePath: normalizedPath,
        outputPath: outputFile.path,
        didResize: didResize,
        didReencode: true,
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
