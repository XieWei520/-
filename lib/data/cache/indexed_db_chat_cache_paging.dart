class IndexedDbChatCacheAroundPagePlan {
  const IndexedDbChatCacheAroundPagePlan({
    required this.beforeLimit,
    required this.limit,
    required this.includeAnchorInAfter,
  });

  final int beforeLimit;
  final int limit;
  final bool includeAnchorInAfter;

  int afterLimitForBeforeCount(int beforeCount) {
    final normalizedBeforeCount = beforeCount < 0 ? 0 : beforeCount;
    return limit - normalizedBeforeCount;
  }

  int backfillBeforeLimitForAfterCount(int afterCount) {
    final normalizedAfterCount = afterCount < 0 ? 0 : afterCount;
    return limit - normalizedAfterCount;
  }
}

IndexedDbChatCacheAroundPagePlan planIndexedDbAroundPage({required int limit}) {
  final safeLimit = limit <= 0 ? 20 : limit;
  final beforeLimit = safeLimit ~/ 2;
  return IndexedDbChatCacheAroundPagePlan(
    beforeLimit: beforeLimit,
    limit: safeLimit,
    includeAnchorInAfter: true,
  );
}
