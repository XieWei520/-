import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';

void main() {
  group('LocalMonitorFileAttachment', () {
    test('parses valid file attachment records', () {
      final files = LocalMonitorFileAttachment.listFromJson(<
        Map<String, dynamic>
      >[
        <String, dynamic>{
          'source_url': 'https://cdn.example.test/guide.pdf',
          'local_path': '',
          'file_name': 'guide.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 2048,
        },
        <String, dynamic>{
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
      expect(files.first.localPath, '');
      expect(files.first.fileName, 'guide.pdf');
      expect(files.first.mimeType, 'application/pdf');
      expect(files.first.sizeBytes, 2048);
      expect(files.last.sourceUrl, '');
      expect(files.last.localPath, r'C:\tmp\report.docx');
      expect(files.last.fileName, 'report.docx');
      expect(
        files.last.mimeType,
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
      expect(files.last.sizeBytes, 4096);
    });

    test('filters file attachment records without a usable source', () {
      final files = LocalMonitorFileAttachment.listFromJson(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'source_url': '',
            'local_path': '',
            'file_name': 'empty.pdf',
            'mime_type': 'application/pdf',
            'size_bytes': 100,
          },
          <String, dynamic>{
            'source_url': 'https://cdn.example.test/valid.pdf',
            'file_name': 'valid.pdf',
          },
        ],
      );

      expect(files, hasLength(1));
      expect(files.single.fileName, 'valid.pdf');
    });
  });

  test('LocalMonitorObservedMessage preserves file attachments', () {
    final message = LocalMonitorObservedMessage.fromJson(<String, dynamic>{
      'id': 'msg-file',
      'conversation_id': 'course-1',
      'conversation_name': 'Course A',
      'sender_name': 'Alice',
      'message_type': 'file',
      'text': 'course handout',
      'observed_at': '2026-05-17T08:00:00Z',
      'capture_source': 'xiaoe_dom_probe',
      'file_attachments': <Map<String, dynamic>>[
        <String, dynamic>{
          'source_url': 'https://cdn.example.test/handout.pdf',
          'file_name': 'handout.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 1024,
        },
      ],
    });

    expect(message.fileAttachments, hasLength(1));
    expect(
      message.fileAttachments.single.sourceUrl,
      'https://cdn.example.test/handout.pdf',
    );
    expect(message.fileAttachments.single.fileName, 'handout.pdf');
  });

  test('LocalMonitorMessageEvent preserves file attachments', () {
    final event = LocalMonitorMessageEvent.fromJson(<String, dynamic>{
      'event_id': 'event-file',
      'dedupe_key': 'course-1:file-1',
      'account_id': '',
      'conversation_id': 'course-1',
      'conversation_name': 'Course A',
      'conversation_type': 'course',
      'message_id': 'file-1',
      'sender_id': 'user-1',
      'sender_name': 'Alice',
      'message_type': 'file',
      'text': 'course handout',
      'sent_at': '2026-05-17T07:59:59Z',
      'observed_at': '2026-05-17T08:00:00Z',
      'capture_source': 'xiaoe_dom_probe',
      'file_attachments': <Map<String, dynamic>>[
        <String, dynamic>{
          'source_url': 'https://cdn.example.test/handout.pdf',
          'file_name': 'handout.pdf',
          'mime_type': 'application/pdf',
          'size_bytes': 1024,
        },
      ],
    });

    expect(event.fileAttachments, hasLength(1));
    expect(event.fileAttachments.single.fileName, 'handout.pdf');
    expect(event.fileAttachments.single.sizeBytes, 1024);
  });
}
