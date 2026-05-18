import 'package:feishu_monitor_shell_app/src/feishu_media_extraction_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dedupes repeated feed card placeholders by source and key', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final queue = FeishuMediaExtractionQueue();

    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: 'feed:a',
        sourceConversationName: 'A',
        feedCardKey: 'card-1',
        feedPreviewText: '[图片]',
        enqueuedAt: now,
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );
    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: 'feed:a',
        sourceConversationName: 'A',
        feedCardKey: 'card-1',
        feedPreviewText: '[图片]',
        enqueuedAt: now.add(const Duration(seconds: 5)),
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );

    expect(queue.depth, 1);
    expect(
      queue.diagnostics(
        now.add(const Duration(seconds: 5)),
      )['media_queue_depth'],
      1,
    );
  });

  test('dedupes by stable source id and normalized feed card key', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final queue = FeishuMediaExtractionQueue();

    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: ' feed:a ',
        sourceConversationName: 'Old Name',
        feedCardKey: ' card-1 ',
        feedPreviewText: '[鍥剧墖]',
        enqueuedAt: now,
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );
    queue.enqueue(
      FeishuMediaExtractionQueueItem(
        sourceConversationId: 'feed:a',
        sourceConversationName: 'New Name',
        feedCardKey: 'card-1',
        feedPreviewText: '[鍥剧墖]',
        enqueuedAt: now.add(const Duration(seconds: 5)),
        priority: FeishuMediaExtractionPriority.feedPlaceholder,
      ),
    );

    expect(queue.depth, 1);
    expect(queue.nextReady(now)?.sourceConversationName, 'Old Name');
  });

  test('chooses event-driven placeholder before fallback item', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final queue = FeishuMediaExtractionQueue()
      ..enqueue(
        FeishuMediaExtractionQueueItem(
          sourceConversationId: 'feed:fallback',
          sourceConversationName: 'Fallback',
          feedCardKey: 'fallback',
          feedPreviewText: '',
          enqueuedAt: now,
          priority: FeishuMediaExtractionPriority.fallbackKeepAlive,
        ),
      )
      ..enqueue(
        FeishuMediaExtractionQueueItem(
          sourceConversationId: 'feed:image',
          sourceConversationName: 'Image',
          feedCardKey: 'image-1',
          feedPreviewText: '[图片]',
          enqueuedAt: now,
          priority: FeishuMediaExtractionPriority.feedPlaceholder,
        ),
      );

    expect(queue.nextReady(now)?.sourceConversationId, 'feed:image');
  });

  test('retry item is unavailable until retry time and diagnostics is stable', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final retryAt = now.add(const Duration(seconds: 20));
    final queue = FeishuMediaExtractionQueue()
      ..enqueue(
        FeishuMediaExtractionQueueItem(
          sourceConversationId: 'feed:retry',
          sourceConversationName: 'Retry',
          feedCardKey: 'retry-1',
          feedPreviewText: '[鍥剧墖]',
          enqueuedAt: now,
          priority: FeishuMediaExtractionPriority.retry,
          retryAfter: retryAt,
        ),
      );

    expect(queue.nextReady(now.add(const Duration(seconds: 19))), isNull);
    final diagnostics = queue.diagnostics(now.add(const Duration(seconds: 19)));
    expect(diagnostics['media_queue_depth'], 1);
    expect(diagnostics['media_queue_active_item'], isNull);
    expect(diagnostics['media_queue_estimated_next_delay_seconds'], 1);
    expect(queue.depth, 1);
    expect(queue.nextReady(retryAt)?.sourceConversationId, 'feed:retry');
  });

  test('records failure without producing placeholder forwarding request', () {
    final now = DateTime.utc(2026, 5, 11, 10);
    final queue = FeishuMediaExtractionQueue();
    final item = FeishuMediaExtractionQueueItem(
      sourceConversationId: 'feed:a',
      sourceConversationName: 'A',
      feedCardKey: 'card-1',
      feedPreviewText: '[图片]',
      enqueuedAt: now,
      priority: FeishuMediaExtractionPriority.feedPlaceholder,
    );

    queue.enqueue(item);
    queue.recordFailure(
      item,
      now: now.add(const Duration(seconds: 30)),
      reason: 'image_extraction_timeout',
    );

    final diagnostics = queue.diagnostics(now.add(const Duration(seconds: 30)));
    expect(
      diagnostics['media_queue_last_skip_reason'],
      'image_extraction_timeout',
    );
    expect(diagnostics['media_queue_forward_placeholder'], isFalse);
  });
}
