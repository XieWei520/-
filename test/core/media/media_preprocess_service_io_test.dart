import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:wukong_im_app/core/media/media_preprocess_service.dart';
import 'package:wukong_im_app/utils/wk_image_utils.dart';

void main() {
  group('MediaPreprocessService IO', () {
    late Directory tempDir;
    late DefaultMediaPreprocessService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wk_media_preprocess_');
      service = DefaultMediaPreprocessService(
        outputDirectoryProvider: () async => tempDir,
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('probes image dimensions from a local file', () async {
      final source = await _writeTestImage(
        tempDir,
        fileName: 'source.png',
        width: 120,
        height: 80,
      );

      final info = await service.probeImage(source.path);

      expect(info, isNotNull);
      expect(info!.width, 120);
      expect(info.height, 80);
      expect(info.bytes, greaterThan(0));
    });

    test('probes valid images through the compute runner', () async {
      final computeRunner = _RecordingComputeRunner();
      final service = DefaultMediaPreprocessService(
        outputDirectoryProvider: () async => tempDir,
        computeRunner: computeRunner.call,
      );
      final source = await _writeTestImage(
        tempDir,
        fileName: 'probe_runner.png',
        width: 120,
        height: 80,
      );

      final info = await service.probeImage(source.path);

      expect(info, isNotNull);
      expect(info!.width, 120);
      expect(info.height, 80);
      expect(computeRunner.calls, 1);
    });

    test('resizes oversized images before upload', () async {
      final source = await _writeTestImage(
        tempDir,
        fileName: 'oversized.png',
        width: 120,
        height: 80,
      );

      final result = await service.preprocessImage(
        source.path,
        options: const MediaPreprocessOptions(maxDimension: 60, quality: 75),
      );

      expect(result.outputPath, isNot(source.path));
      expect(result.didResize, isTrue);
      expect(result.outputInfo, isNotNull);
      expect(result.outputInfo!.width, 60);
      expect(result.outputInfo!.height, 40);
      expect(File(result.outputPath).existsSync(), isTrue);
    });

    test('preprocesses valid images through the compute runner', () async {
      final computeRunner = _RecordingComputeRunner();
      final service = DefaultMediaPreprocessService(
        outputDirectoryProvider: () async => tempDir,
        computeRunner: computeRunner.call,
      );
      final source = await _writeTestImage(
        tempDir,
        fileName: 'preprocess_runner.png',
        width: 120,
        height: 80,
      );

      final result = await service.preprocessImage(
        source.path,
        options: const MediaPreprocessOptions(maxDimension: 60, quality: 75),
      );

      expect(result.outputPath, isNot(source.path));
      expect(result.outputInfo, isNotNull);
      expect(result.outputInfo!.width, 60);
      expect(result.outputInfo!.height, 40);
      expect(computeRunner.calls, 1);
    });

    test(
      'WKImageUtils.compressImage delegates to the preprocess pipeline',
      () async {
        final source = await _writeTestImage(
          tempDir,
          fileName: 'legacy.png',
          width: 90,
          height: 60,
        );

        final outputPath = await WKImageUtils.compressImage(
          source.path,
          quality: 75,
          maxDimension: 45,
          outputDirectoryPath: tempDir.path,
        );

        expect(outputPath, isNotNull);
        expect(outputPath, isNot(source.path));
        final outputInfo = await service.probeImage(outputPath!);
        expect(outputInfo!.width, 45);
        expect(outputInfo.height, 30);
      },
    );
  });
}

Future<File> _writeTestImage(
  Directory directory, {
  required String fileName,
  required int width,
  required int height,
}) async {
  final bitmap = image.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bitmap.setPixelRgb(x, y, x % 256, y % 256, (x + y) % 256);
    }
  }
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(image.encodePng(bitmap), flush: true);
  return file;
}

class _RecordingComputeRunner {
  var calls = 0;

  Future<R> call<M, R>(
    FutureOr<R> Function(M message) callback,
    M message, {
    String? debugLabel,
  }) async {
    calls += 1;
    return await callback(message);
  }
}
