enum FeishuMediaExtractionPriority {
  feedPlaceholder,
  retry,
  fallbackKeepAlive;

  int get rank {
    switch (this) {
      case FeishuMediaExtractionPriority.feedPlaceholder:
        return 0;
      case FeishuMediaExtractionPriority.retry:
        return 1;
      case FeishuMediaExtractionPriority.fallbackKeepAlive:
        return 2;
    }
  }
}

class FeishuMediaExtractionQueueItem {
  FeishuMediaExtractionQueueItem({
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.feedCardKey,
    required this.feedPreviewText,
    required this.enqueuedAt,
    required this.priority,
    this.retryAfter,
  });

  final String sourceConversationId;
  final String sourceConversationName;
  final String feedCardKey;
  final String feedPreviewText;
  final DateTime enqueuedAt;
  final FeishuMediaExtractionPriority priority;
  final DateTime? retryAfter;

  String get dedupeKey {
    final conversationId = sourceConversationId.trim();
    final conversationName = sourceConversationName.trim();
    final feedKey = feedCardKey.trim();
    final sourceKey = conversationId.isNotEmpty
        ? 'id:$conversationId'
        : 'name:$conversationName';
    return '$sourceKey\nfeed:$feedKey';
  }

  int get priorityRank => priority.rank;
}

class FeishuMediaExtractionQueue {
  final List<FeishuMediaExtractionQueueItem> _items =
      <FeishuMediaExtractionQueueItem>[];

  String? _lastResult;
  String? _lastSkipReason;

  int get depth => _items.length;

  void enqueue(FeishuMediaExtractionQueueItem item) {
    if (_items.any((queued) => queued.dedupeKey == item.dedupeKey)) {
      return;
    }
    _items.add(item);
  }

  FeishuMediaExtractionQueueItem? nextReady(DateTime now) {
    final readyItems = _items
        .where(
          (item) =>
              item.retryAfter == null || !item.retryAfter!.isAfter(now),
        )
        .toList()
      ..sort(_compareItems);

    if (readyItems.isEmpty) {
      return null;
    }
    return readyItems.first;
  }

  void recordSuccess(
    FeishuMediaExtractionQueueItem item, {
    required DateTime now,
  }) {
    _remove(item);
    _lastResult = 'success';
    _lastSkipReason = null;
  }

  void recordFailure(
    FeishuMediaExtractionQueueItem item, {
    required DateTime now,
    required String reason,
  }) {
    _remove(item);
    _lastResult = 'failed';
    _lastSkipReason = reason;
  }

  Map<String, Object?> diagnostics(DateTime now) {
    return <String, Object?>{
      'media_queue_depth': depth,
      'media_queue_active_item': nextReady(now)?.dedupeKey,
      'media_queue_oldest_wait_seconds': _oldestWaitSeconds(now),
      'media_queue_estimated_next_delay_seconds': _estimatedNextDelaySeconds(
        now,
      ),
      'media_queue_last_result': _lastResult,
      'media_queue_last_skip_reason': _lastSkipReason,
      'media_queue_forward_placeholder': false,
    };
  }

  void _remove(FeishuMediaExtractionQueueItem item) {
    _items.removeWhere((queued) => queued.dedupeKey == item.dedupeKey);
  }

  int _oldestWaitSeconds(DateTime now) {
    if (_items.isEmpty) {
      return 0;
    }

    final oldest = _items
        .map((item) => item.enqueuedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return now.difference(oldest).inSeconds;
  }

  int _estimatedNextDelaySeconds(DateTime now) {
    if (_items.isEmpty || nextReady(now) != null) {
      return 0;
    }

    final nextRetryAfter = _items
        .map((item) => item.retryAfter)
        .whereType<DateTime>()
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final delay = nextRetryAfter.difference(now).inSeconds;
    return delay < 0 ? 0 : delay;
  }
}

int _compareItems(
  FeishuMediaExtractionQueueItem a,
  FeishuMediaExtractionQueueItem b,
) {
  final priority = a.priorityRank.compareTo(b.priorityRank);
  if (priority != 0) {
    return priority;
  }
  return a.enqueuedAt.compareTo(b.enqueuedAt);
}
