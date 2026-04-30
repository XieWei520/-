import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/core/upload/multipart_upload_models.dart';

void main() {
  test('planner splits a 1GB file into deterministic chunk ranges', () {
    const oneGb = 1024 * 1024 * 1024;
    const chunkSize = 8 * 1024 * 1024;

    final parts = MultipartUploadPlanner.plan(
      fileSizeBytes: oneGb,
      chunkSizeBytes: chunkSize,
    );

    expect(parts, hasLength(128));
    expect(parts.first.partNumber, 1);
    expect(parts.first.offset, 0);
    expect(parts.first.length, chunkSize);
    expect(parts.last.partNumber, 128);
    expect(parts.last.offset, oneGb - chunkSize);
    expect(parts.last.length, chunkSize);
    expect(parts.last.endExclusive, oneGb);
  });

  test('planner caps invalid chunk sizes to a safe default', () {
    final parts = MultipartUploadPlanner.plan(
      fileSizeBytes: 10,
      chunkSizeBytes: 0,
    );

    expect(parts, hasLength(1));
    expect(parts.single.length, 10);
  });

  test('planner emits a short final part when file size is not aligned', () {
    final parts = MultipartUploadPlanner.plan(
      fileSizeBytes: 10,
      chunkSizeBytes: 4,
    );

    expect(parts.map((part) => part.length), <int>[4, 4, 2]);
    expect(parts.map((part) => part.offset), <int>[0, 4, 8]);
  });
}
