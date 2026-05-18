class MediaImageInfo {
  const MediaImageInfo({
    required this.path,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final String path;
  final int width;
  final int height;
  final int bytes;
}

class MediaPreprocessOptions {
  const MediaPreprocessOptions({
    this.maxDimension = 2048,
    this.quality = 82,
    this.outputDirectoryPath,
    this.forceReencode = false,
  });

  final int maxDimension;
  final int quality;
  final String? outputDirectoryPath;
  final bool forceReencode;

  int get normalizedMaxDimension => maxDimension < 1 ? 1 : maxDimension;

  int get normalizedQuality => quality.clamp(1, 100).toInt();
}

class MediaPreprocessResult {
  const MediaPreprocessResult({
    required this.sourcePath,
    required this.outputPath,
    required this.didResize,
    required this.didReencode,
    this.inputInfo,
    this.outputInfo,
  });

  final String sourcePath;
  final String outputPath;
  final bool didResize;
  final bool didReencode;
  final MediaImageInfo? inputInfo;
  final MediaImageInfo? outputInfo;

  bool get changed => sourcePath != outputPath;
}

abstract class MediaPreprocessService {
  Future<MediaImageInfo?> probeImage(String path);

  Future<MediaPreprocessResult> preprocessImage(
    String path, {
    MediaPreprocessOptions options = const MediaPreprocessOptions(),
  });
}
