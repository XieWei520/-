import 'dart:convert';

import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';
import 'package:test/test.dart';

void main() {
  group('MessageFileAttachment', () {
    test('parses snake_case and camelCase file attachment records', () {
      final files = MessageFileAttachment.listFromJson(<Map<String, Object?>>[
        <String, Object?>{
          'source_url': 'https://cdn.example.test/guide.pdf',
          'local_path': '',
          'file_name': 'guide.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 2048,
        },
        <String, Object?>{
          'sourceUrl': '',
          'localPath': r'C:\tmp\report.docx',
          'fileName': 'report.docx',
          'mimeType':
              'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          'sizeBytes': '4096',
        },
      ]);

      expect(files, hasLength(2));
      expect(files.first.sourceUrl, 'https://cdn.example.test/guide.pdf');
      expect(files.first.fileName, 'guide.pdf');
      expect(files.first.mimeType, 'application/pdf');
      expect(files.first.sizeBytes, 2048);
      expect(files.last.localPath, r'C:\tmp\report.docx');
      expect(files.last.fileName, 'report.docx');
      expect(files.last.sizeBytes, 4096);
    });

    test('filters records without source url or local path', () {
      final files = MessageFileAttachment.listFromJson(<Map<String, Object?>>[
        <String, Object?>{
          'source_url': '',
          'local_path': '',
          'file_name': 'empty.pdf',
        },
        <String, Object?>{
          'source_url': 'https://cdn.example.test/valid.pdf',
          'file_name': 'valid.pdf',
        },
      ]);

      expect(files, hasLength(1));
      expect(files.single.fileName, 'valid.pdf');
    });
  });

  test('ObservedMessageCandidate preserves file attachments in JSON', () {
    const message = ObservedMessageCandidate(
      id: 'msg-file',
      conversationId: 'course-1',
      conversationName: 'Course A',
      senderName: 'Alice',
      messageType: 'file',
      text: 'course handout',
      observedAt: '2026-05-17T08:00:00Z',
      captureSource: 'xiaoe_dom_probe',
      fileAttachments: <MessageFileAttachment>[
        MessageFileAttachment(
          sourceUrl: 'https://cdn.example.test/handout.pdf',
          localPath: '',
          fileName: 'handout.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
        ),
      ],
    );

    final restored = ObservedMessageCandidate.fromJson(
      jsonDecode(jsonEncode(message.toJson())) as Map<String, dynamic>,
    );

    expect(restored.fileAttachments, hasLength(1));
    expect(restored.fileAttachments.single.fileName, 'handout.pdf');
    expect(
      restored.fileAttachments.single.sourceUrl,
      'https://cdn.example.test/handout.pdf',
    );
  });

  test('NormalizedMessageEvent preserves file attachments in JSON', () {
    const event = NormalizedMessageEvent(
      eventId: 'event-file',
      dedupeKey: 'course-1:file-1',
      accountId: '',
      conversationId: 'course-1',
      conversationName: 'Course A',
      conversationType: 'course',
      messageId: 'file-1',
      senderId: 'user-1',
      senderName: 'Alice',
      messageType: 'file',
      text: 'course handout',
      sentAt: '2026-05-17T07:59:59Z',
      observedAt: '2026-05-17T08:00:00Z',
      captureSource: 'xiaoe_dom_probe',
      fileAttachments: <MessageFileAttachment>[
        MessageFileAttachment(
          sourceUrl: 'https://cdn.example.test/handout.pdf',
          localPath: '',
          fileName: 'handout.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 1024,
        ),
      ],
    );

    final restored = NormalizedMessageEvent.fromJson(
      jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
    );

    expect(restored.fileAttachments, hasLength(1));
    expect(restored.fileAttachments.single.fileName, 'handout.pdf');
    expect(restored.fileAttachments.single.sizeBytes, 1024);
  });
}
