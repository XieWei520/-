import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/service/im/sync_load_policy.dart';

void main() {
  group('SyncLoadPolicy', () {
    test('keeps immediate sync for the first attempt', () {
      const policy = SyncLoadPolicy();

      final delay = policy.nextDelay(
        endpoint: SyncEndpoint.messageSync,
        consecutiveEmptyResponses: 0,
        appVisible: true,
        hasPendingLocalMutation: false,
      );

      expect(delay, Duration.zero);
    });

    test('backs off repeated empty message sync while visible', () {
      const policy = SyncLoadPolicy();

      expect(
        policy.nextDelay(
          endpoint: SyncEndpoint.messageSync,
          consecutiveEmptyResponses: 1,
          appVisible: true,
          hasPendingLocalMutation: false,
        ),
        const Duration(seconds: 2),
      );
      expect(
        policy.nextDelay(
          endpoint: SyncEndpoint.messageSync,
          consecutiveEmptyResponses: 4,
          appVisible: true,
          hasPendingLocalMutation: false,
        ),
        const Duration(seconds: 16),
      );
      expect(
        policy.nextDelay(
          endpoint: SyncEndpoint.messageSync,
          consecutiveEmptyResponses: 9,
          appVisible: true,
          hasPendingLocalMutation: false,
        ),
        const Duration(seconds: 30),
      );
    });

    test('uses longer cap when app is backgrounded', () {
      const policy = SyncLoadPolicy();

      final delay = policy.nextDelay(
        endpoint: SyncEndpoint.conversationExtraSync,
        consecutiveEmptyResponses: 9,
        appVisible: false,
        hasPendingLocalMutation: false,
      );

      expect(delay, const Duration(minutes: 2));
    });

    test('does not back off when local mutations are pending', () {
      const policy = SyncLoadPolicy();

      final delay = policy.nextDelay(
        endpoint: SyncEndpoint.conversationSync,
        consecutiveEmptyResponses: 8,
        appVisible: true,
        hasPendingLocalMutation: true,
      );

      expect(delay, Duration.zero);
    });

    test('coalesces configuration endpoints for five minutes', () {
      const policy = SyncLoadPolicy();
      final now = DateTime(2026, 5, 28, 12);

      expect(
        policy.shouldRequest(
          endpoint: SyncEndpoint.prohibitWordsSync,
          now: now,
          lastSuccessfulRequestAt: now.subtract(
            const Duration(minutes: 4, seconds: 59),
          ),
          hasServerInvalidation: false,
        ),
        isFalse,
      );
      expect(
        policy.shouldRequest(
          endpoint: SyncEndpoint.prohibitWordsSync,
          now: now,
          lastSuccessfulRequestAt: now.subtract(const Duration(minutes: 5)),
          hasServerInvalidation: false,
        ),
        isTrue,
      );
    });

    test('server invalidation bypasses configuration coalescing', () {
      const policy = SyncLoadPolicy();
      final now = DateTime(2026, 5, 28, 12);

      expect(
        policy.shouldRequest(
          endpoint: SyncEndpoint.sensitiveWordsSync,
          now: now,
          lastSuccessfulRequestAt: now.subtract(const Duration(seconds: 30)),
          hasServerInvalidation: true,
        ),
        isTrue,
      );
    });
  });
}
