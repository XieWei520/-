import 'dart:convert';
import 'dart:io';

const Duration feishuNetworkCaptureRuntimeRetention = Duration(hours: 24);

class FeishuNetworkCaptureRuntimeCleanupResult {
  const FeishuNetworkCaptureRuntimeCleanupResult({
    required this.retainedDiagnosticLines,
    required this.deletedDiagnosticLines,
    required this.deletedImageFiles,
  });

  final int retainedDiagnosticLines;
  final int deletedDiagnosticLines;
  final int deletedImageFiles;
}

Future<FeishuNetworkCaptureRuntimeCleanupResult>
cleanupFeishuNetworkCaptureRuntime({
  required File diagnosticsFile,
  required DateTime now,
  Duration retention = feishuNetworkCaptureRuntimeRetention,
  DateTime? Function(File file)? imageObservedAt,
}) async {
  final cutoff = now.toUtc().subtract(retention);
  var retainedDiagnosticLines = 0;
  var deletedDiagnosticLines = 0;

  if (await diagnosticsFile.exists()) {
    final lines = await diagnosticsFile.readAsLines();
    final retainedLines = <String>[];
    for (final line in lines) {
      final observedAt = _diagnosticLineObservedAt(line);
      if (observedAt != null && observedAt.isBefore(cutoff)) {
        deletedDiagnosticLines += 1;
        continue;
      }
      retainedLines.add(line);
    }
    retainedDiagnosticLines = retainedLines.length;
    if (deletedDiagnosticLines > 0) {
      await diagnosticsFile.writeAsString(
        retainedLines.isEmpty ? '' : '${retainedLines.join('\n')}\n',
        flush: true,
      );
    }
  }

  final imageDirectory = Directory(
    '${diagnosticsFile.parent.path}${Platform.pathSeparator}network_images',
  );
  var deletedImageFiles = 0;
  if (await imageDirectory.exists()) {
    await for (final entity in imageDirectory.list(followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final observedAt = imageObservedAt == null
          ? await entity.lastModified()
          : imageObservedAt(entity);
      if (observedAt == null || !observedAt.toUtc().isBefore(cutoff)) {
        continue;
      }
      try {
        await entity.delete();
        deletedImageFiles += 1;
      } on FileSystemException {
        // Best effort cleanup; a locked image can be retried on the next pass.
      }
    }
  }

  return FeishuNetworkCaptureRuntimeCleanupResult(
    retainedDiagnosticLines: retainedDiagnosticLines,
    deletedDiagnosticLines: deletedDiagnosticLines,
    deletedImageFiles: deletedImageFiles,
  );
}

DateTime? _diagnosticLineObservedAt(String line) {
  try {
    final decoded = jsonDecode(line);
    if (decoded is! Map) {
      return null;
    }
    final observedAt = decoded['observed_at'];
    if (observedAt == null) {
      return null;
    }
    return DateTime.tryParse(observedAt.toString())?.toUtc();
  } catch (_) {
    return null;
  }
}
