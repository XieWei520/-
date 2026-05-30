enum SyncEndpoint {
  messageSync,
  conversationSync,
  conversationExtraSync,
  conversationSyncAck,
  userIMRoute,
  sensitiveWordsSync,
  prohibitWordsSync,
  reminderSync,
}

class SyncLoadPolicy {
  const SyncLoadPolicy({
    this.visibleMaxDelay = const Duration(seconds: 30),
    this.backgroundMaxDelay = const Duration(minutes: 2),
    this.configurationCoalesceWindow = const Duration(minutes: 5),
  });

  final Duration visibleMaxDelay;
  final Duration backgroundMaxDelay;
  final Duration configurationCoalesceWindow;

  Duration nextDelay({
    required SyncEndpoint endpoint,
    required int consecutiveEmptyResponses,
    required bool appVisible,
    required bool hasPendingLocalMutation,
  }) {
    if (hasPendingLocalMutation ||
        consecutiveEmptyResponses <= 0 ||
        _isAckEndpoint(endpoint)) {
      return Duration.zero;
    }
    final candidate = Duration(seconds: 1 << consecutiveEmptyResponses);
    final cap = appVisible ? visibleMaxDelay : backgroundMaxDelay;
    return candidate > cap ? cap : candidate;
  }

  bool shouldRequest({
    required SyncEndpoint endpoint,
    required DateTime now,
    required DateTime? lastSuccessfulRequestAt,
    required bool hasServerInvalidation,
  }) {
    if (hasServerInvalidation || lastSuccessfulRequestAt == null) {
      return true;
    }
    if (!_isConfigurationEndpoint(endpoint)) {
      return true;
    }
    return now.difference(lastSuccessfulRequestAt) >=
        configurationCoalesceWindow;
  }

  bool _isAckEndpoint(SyncEndpoint endpoint) {
    return endpoint == SyncEndpoint.conversationSyncAck;
  }

  bool _isConfigurationEndpoint(SyncEndpoint endpoint) {
    return endpoint == SyncEndpoint.sensitiveWordsSync ||
        endpoint == SyncEndpoint.prohibitWordsSync;
  }
}
