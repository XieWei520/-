import 'dart:io';

class ChatRecordingFileProbeResult {
  const ChatRecordingFileProbeResult({
    required this.exists,
    required this.size,
  });

  final bool exists;
  final int size;
}

Future<ChatRecordingFileProbeResult> probeChatRecordingFile(
  String filePath,
) async {
  final normalizedPath = filePath.trim();
  if (normalizedPath.isEmpty) {
    return const ChatRecordingFileProbeResult(exists: false, size: 0);
  }

  try {
    final file = File(normalizedPath);
    final exists = await file.exists();
    if (!exists) {
      return const ChatRecordingFileProbeResult(exists: false, size: 0);
    }
    return ChatRecordingFileProbeResult(
      exists: true,
      size: await file.length(),
    );
  } catch (_) {
    return const ChatRecordingFileProbeResult(exists: false, size: 0);
  }
}
