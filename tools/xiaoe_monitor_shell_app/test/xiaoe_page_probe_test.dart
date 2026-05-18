import 'package:flutter_test/flutter_test.dart';
import 'package:xiaoe_monitor_shell_app/src/xiaoe_page_probe.dart';

void main() {
  test('live comment candidates normalize to one text event per comment', () {
    final probe = XiaoePageProbe.fromScriptResult(<String, Object?>{
      'runtime_url': 'https://study.xiaoe-tech.com/#/live/room/live-1',
      'page_title': '五月直播 - 小鹅通',
      'observed_at': '2026-05-17T08:30:00Z',
      'source': <String, Object?>{
        'id': 'live:live-1',
        'name': '五月直播',
        'type': 'live',
      },
      'comment_candidates': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'comment-1',
          'sender_name': 'Alice',
          'text': '老师这个问题怎么处理？',
          'sent_at': '2026-05-17T08:29:59Z',
        },
        <String, Object?>{
          'id': 'comment-2',
          'sender_name': 'Bob',
          'text': '收到，感谢',
          'sent_at': '2026-05-17T08:30:00Z',
        },
      ],
    });

    final events = normalizeXiaoeProbeEvents(probe);

    expect(probe.pageKind, XiaoePageKind.live);
    expect(events, hasLength(2));
    expect(events.first.eventId, 'xiaoe:live:live-1:comment-1');
    expect(events.first.dedupeKey, 'live:live-1:comment-1');
    expect(events.first.conversationName, '五月直播');
    expect(events.first.conversationType, 'live');
    expect(events.first.messageType, 'text');
    expect(events.first.text, '老师这个问题怎么处理？');
    expect(events.last.text, '收到，感谢');
  });

  test('circle and course candidates preserve image and file attachments', () {
    final probe = XiaoePageProbe.fromScriptResult(<String, Object?>{
      'runtime_url': 'https://study.xiaoe-tech.com/#/circle/topic/alpha',
      'page_title': '训练营圈子',
      'observed_at': '2026-05-17T08:40:00Z',
      'source': <String, Object?>{
        'id': 'circle:alpha',
        'name': '训练营圈子',
        'type': 'circle',
      },
      'comment_candidates': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'post-image-1',
          'sender_name': 'Carol',
          'text': '作业截图',
          'image_attachments': <Map<String, Object?>>[
            <String, Object?>{
              'source_url': 'https://cdn.xiaoe-tech.com/image-1.png',
              'width': 640,
              'height': 480,
            },
          ],
        },
        <String, Object?>{
          'id': 'post-file-1',
          'sender_name': 'Dana',
          'text': '课程资料',
          'file_attachments': <Map<String, Object?>>[
            <String, Object?>{
              'source_url': 'https://cdn.xiaoe-tech.com/handout.pdf',
              'file_name': 'handout.pdf',
              'mime_type': 'application/pdf',
              'size_bytes': 1024,
            },
          ],
        },
      ],
    });

    final events = normalizeXiaoeProbeEvents(probe);

    expect(events, hasLength(2));
    expect(events.first.messageType, 'image');
    expect(events.first.imageAttachments, hasLength(1));
    expect(
      events.first.imageAttachments.single.sourceUrl,
      'https://cdn.xiaoe-tech.com/image-1.png',
    );
    expect(events.last.messageType, 'file');
    expect(events.last.fileAttachments, hasLength(1));
    expect(events.last.fileAttachments.single.fileName, 'handout.pdf');
    expect(events.last.fileAttachments.single.sizeBytes, 1024);
  });

  test('duplicate comments produce stable dedupe keys and one event', () {
    final probe = XiaoePageProbe.fromScriptResult(<String, Object?>{
      'runtime_url': 'https://study.xiaoe-tech.com/#/course/interaction/1',
      'page_title': '课程互动',
      'observed_at': '2026-05-17T08:45:00Z',
      'source': <String, Object?>{
        'id': 'course:lesson-1',
        'name': '课程互动',
        'type': 'course',
      },
      'comment_candidates': <Map<String, Object?>>[
        <String, Object?>{
          'id': 'comment-duplicated',
          'sender_name': 'Eve',
          'text': '同一条评论',
        },
        <String, Object?>{
          'id': 'comment-duplicated',
          'sender_name': 'Eve',
          'text': '同一条评论',
        },
      ],
    });

    final first = normalizeXiaoeProbeEvents(probe);
    final second = normalizeXiaoeProbeEvents(probe);

    expect(first, hasLength(1));
    expect(first.single.dedupeKey, 'course:lesson-1:comment-duplicated');
    expect(second.single.dedupeKey, first.single.dedupeKey);
    expect(second.single.eventId, first.single.eventId);
  });

  test('malformed and noisy UI candidates are ignored with diagnostics', () {
    final probe = XiaoePageProbe.fromScriptResult(<String, Object?>{
      'runtime_url': 'https://study.xiaoe-tech.com/#/muti_index',
      'page_title': '小鹅通',
      'observed_at': '2026-05-17T08:50:00Z',
      'comment_candidates': <Map<String, Object?>>[
        <String, Object?>{'id': 'empty', 'text': ''},
        <String, Object?>{'id': 'nav', 'text': '首页 课程 圈子 订单 设置'},
        <String, Object?>{'text': '缺少来源'},
      ],
    });

    final events = normalizeXiaoeProbeEvents(probe);

    expect(events, isEmpty);
    expect(probe.probeDiagnostics['ignored_candidate_count'], 3);
    expect(probe.probeDiagnostics['comment_candidate_count'], 3);
    expect(probe.pageKind, XiaoePageKind.mutiIndex);
  });
}
