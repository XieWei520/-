import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wukong_im_app/core/upload/resumable_upload_store.dart';
import 'package:wukong_im_app/data/upload/shared_preferences_resumable_upload_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'persists, restores, and deletes resumable upload checkpoints',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesResumableUploadStore(prefs);
      const checkpoint = ResumableUploadCheckpoint(
        fingerprint: '/tmp/video.mp4:1048576:123',
        uploadId: 'upload-123',
        objectPath: '/1/channel/video.mp4',
        fileSizeBytes: 1048576,
        chunkSizeBytes: 262144,
        uploadedPartNumbers: <int>{1, 3},
      );

      await store.save(checkpoint);
      final restored = await store.read(checkpoint.fingerprint);

      expect(restored, isNotNull);
      expect(restored!.uploadId, checkpoint.uploadId);
      expect(restored.objectPath, checkpoint.objectPath);
      expect(restored.fileSizeBytes, checkpoint.fileSizeBytes);
      expect(restored.chunkSizeBytes, checkpoint.chunkSizeBytes);
      expect(restored.uploadedPartNumbers, <int>{1, 3});

      await store.delete(checkpoint.fingerprint);
      expect(await store.read(checkpoint.fingerprint), isNull);
    },
  );
}
