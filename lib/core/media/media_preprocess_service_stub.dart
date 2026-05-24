import 'media_preprocess_models.dart';

class DefaultMediaPreprocessService implements MediaPreprocessService {
  const DefaultMediaPreprocessService({
    Object? outputDirectoryProvider,
    Object? computeRunner,
  });

  @override
  Future<MediaImageInfo?> probeImage(String path) async => null;

  @override
  Future<MediaPreprocessResult> preprocessImage(
    String path, {
    MediaPreprocessOptions options = const MediaPreprocessOptions(),
  }) async {
    final normalizedPath = path.trim();
    return MediaPreprocessResult(
      sourcePath: normalizedPath,
      outputPath: normalizedPath,
      didResize: false,
      didReencode: false,
    );
  }
}
