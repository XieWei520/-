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
  return const ChatRecordingFileProbeResult(exists: false, size: 0);
}
