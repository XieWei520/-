import 'dart:math';

/// Exponential backoff reconnect policy with jitter.
///
/// Delay = min(baseDelay * 2^retryCount, maxDelay) + random jitter
/// Jitter range: 0 ~ currentDelay / 3
class ReconnectPolicy {
  final int baseDelayMs;
  final int maxDelayMs;
  final int maxRetries;
  final Random _random = Random();
  int _retryCount = 0;

  ReconnectPolicy({
    this.baseDelayMs = 1000,
    this.maxDelayMs = 30000,
    this.maxRetries = 20,
  });

  /// Returns the next delay in milliseconds, or -1 if max retries exceeded.
  int nextDelay() {
    if (_retryCount >= maxRetries) {
      return -1;
    }
    final exponential = baseDelayMs * pow(2, _retryCount).toInt();
    final capped = min(exponential, maxDelayMs);
    final jitter = _random.nextInt((capped ~/ 3) + 1);
    _retryCount++;
    return capped + jitter;
  }

  /// Reset retry count (call after successful connection).
  void reset() {
    _retryCount = 0;
  }

  /// Current retry count.
  int get retryCount => _retryCount;

  /// Whether max retries have been exceeded.
  bool get isExhausted => _retryCount >= maxRetries;
}
