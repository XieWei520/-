import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_auto_forward_runner.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_forwarding_service.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_client.dart';
import 'package:wukong_im_app/modules/feishu_monitor/feishu_monitor_shell_models.dart';

void main() {
  test(
    'runOnce forwards shell events when routed auto-forwarding is enabled',
    () async {
      final client = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'hello'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = FeishuMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemoryForwardingSettingsStore(
          FeishuMonitorForwardingSettings(
            enabled: true,
            routes: <FeishuMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'feed:alpha',
                targetGroupId: 'wk_alpha',
              ),
            ],
          ),
        ),
      );

      final result = await runner.runOnce();

      expect(client.fetchCount, 1);
      expect(client.lastSyncedSourceIds, <String>['feed:alpha']);
      expect(service.callCount, 1);
      expect(service.lastSettings?.enabled, isTrue);
      expect(service.lastEvents, hasLength(1));
      expect(service.lastEvents.single.text, 'hello');
      expect(result?.sent, 1);
    },
  );

  test(
    'runOnce merges events from all configured workers without duplicate forwarding',
    () async {
      final workerA = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:a', text: 'from A', dedupeKey: 'same'),
          ],
        ),
      );
      final workerB = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:b', text: 'from B', dedupeKey: 'same'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = FeishuMonitorAutoForwardRunner(
        clientGroup: FeishuMonitorShellClientGroup.forTesting(
          <FeishuMonitorShellClient>[workerA, workerB],
        ),
        forwardingService: service,
        forwardingSettingsStore: _MemoryForwardingSettingsStore(
          FeishuMonitorForwardingSettings(
            enabled: true,
            routes: <FeishuMonitorForwardingRoute>[
              _route(sourceConversationId: 'feed:a', targetGroupId: 'wk_a'),
              _route(sourceConversationId: 'feed:b', targetGroupId: 'wk_b'),
            ],
          ),
        ),
      );

      final result = await runner.runOnce();

      expect(workerA.fetchCount, 1);
      expect(workerB.fetchCount, 1);
      expect(service.callCount, 1);
      expect(service.lastEvents, hasLength(1));
      expect(service.lastEvents.single.dedupeKey, 'same');
      expect(result?.sent, 1);
    },
  );

  test(
    'runOnce reports failed worker fetch and forwards healthy worker events',
    () async {
      final errors = <Object>[];
      final failingWorker = _FailingFetchShellClient(
        status: _status(),
        error: StateError('worker fetch failed'),
      );
      final healthyWorker = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:healthy', text: 'from healthy worker'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = FeishuMonitorAutoForwardRunner(
        clientGroup: FeishuMonitorShellClientGroup.forTesting(
          <FeishuMonitorShellClient>[failingWorker, healthyWorker],
        ),
        forwardingService: service,
        forwardingSettingsStore: _MemoryForwardingSettingsStore(
          FeishuMonitorForwardingSettings(
            enabled: true,
            routes: <FeishuMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'feed:healthy',
                targetGroupId: 'wk_healthy',
              ),
            ],
          ),
        ),
        onError: (error, _) => errors.add(error),
      );

      final result = await runner.runOnce();

      expect(failingWorker.fetchCount, 1);
      expect(healthyWorker.fetchCount, 1);
      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect(service.callCount, 1);
      expect(service.lastEvents, hasLength(1));
      expect(service.lastEvents.single.text, 'from healthy worker');
      expect(result?.sent, 1);
    },
  );

  test('runOnce syncs each worker only with its assigned routes', () async {
    final workerA = _FakeShellClient(
      workerId: 'worker-1',
      status: _status(workerId: 'worker-1'),
    );
    final workerB = _FakeShellClient(
      workerId: 'worker-2',
      status: _status(workerId: 'worker-2'),
    );
    final runner = FeishuMonitorAutoForwardRunner(
      clientGroup: FeishuMonitorShellClientGroup.forTesting(
        <FeishuMonitorShellClient>[workerA, workerB],
      ),
      forwardingService: _FakeForwardingService(),
      forwardingSettingsStore: _MemoryForwardingSettingsStore(
        FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'feed:a',
              targetGroupId: 'wk_a',
              workerId: 'worker-1',
            ),
            _route(
              sourceConversationId: 'feed:b',
              targetGroupId: 'wk_b',
              workerId: 'worker-2',
            ),
          ],
        ),
      ),
    );

    await runner.runOnce();

    expect(workerA.lastSyncedSourceIds, <String>['feed:a']);
    expect(workerB.lastSyncedSourceIds, <String>['feed:b']);
  });

  test('runOnce ignores extra workers with no assigned routes', () async {
    final assignedWorker = _FakeShellClient(
      workerId: 'worker-1',
      status: _status(
        workerId: 'worker-1',
        recentEvents: <FeishuMonitorMessageEvent>[
          _event(conversationId: 'feed:a', text: 'assigned worker event'),
        ],
      ),
    );
    final extraWorker = _FakeShellClient(
      workerId: 'worker-2',
      status: _status(workerId: 'worker-2'),
    );
    final service = _FakeForwardingService();
    final runner = FeishuMonitorAutoForwardRunner(
      clientGroup: FeishuMonitorShellClientGroup.forTesting(
        <FeishuMonitorShellClient>[assignedWorker, extraWorker],
      ),
      forwardingService: service,
      forwardingSettingsStore: _MemoryForwardingSettingsStore(
        FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'feed:a',
              targetGroupId: 'wk_a',
              workerId: 'worker-1',
            ),
          ],
        ),
      ),
    );

    final result = await runner.runOnce();

    expect(assignedWorker.syncSourceCount, 1);
    expect(assignedWorker.fetchCount, 1);
    expect(extraWorker.syncSourceCount, 0);
    expect(extraWorker.fetchCount, 0);
    expect(service.callCount, 1);
    expect(service.lastEvents.single.text, 'assigned worker event');
    expect(result?.sent, 1);
  });

  test('runOnce assigns legacy unsharded routes to the first worker', () async {
    final workerA = _FakeShellClient(
      workerId: 'worker-1',
      status: _status(workerId: 'worker-1'),
    );
    final workerB = _FakeShellClient(
      workerId: 'worker-2',
      status: _status(workerId: 'worker-2'),
    );
    final runner = FeishuMonitorAutoForwardRunner(
      clientGroup: FeishuMonitorShellClientGroup.forTesting(
        <FeishuMonitorShellClient>[workerA, workerB],
      ),
      forwardingService: _FakeForwardingService(),
      forwardingSettingsStore: _MemoryForwardingSettingsStore(
        FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(sourceConversationId: 'feed:legacy', targetGroupId: 'wk_a'),
          ],
        ),
      ),
    );

    await runner.runOnce();

    expect(workerA.lastSyncedSourceIds, <String>['feed:legacy']);
    expect(workerB.lastSyncedSourceIds, isEmpty);
  });

  test(
    'runOnce does not fetch shell status when auto-forwarding is disabled',
    () async {
      final client = _FakeShellClient(status: _status());
      final service = _FakeForwardingService();
      final runner = FeishuMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemoryForwardingSettingsStore(
          const FeishuMonitorForwardingSettings(
            enabled: false,
            routes: <FeishuMonitorForwardingRoute>[],
          ),
        ),
      );

      final result = await runner.runOnce();

      expect(result, isNull);
      expect(client.fetchCount, 0);
      expect(client.syncSourceCount, 0);
      expect(service.callCount, 0);
    },
  );

  test('default polling interval is one second for low-latency forwarding', () {
    final client = _FakeShellClient(status: _status());
    final service = _FakeForwardingService();
    final runner = FeishuMonitorAutoForwardRunner(
      client: client,
      forwardingService: service,
      forwardingSettingsStore: _MemoryForwardingSettingsStore(
        FeishuMonitorForwardingSettings(
          enabled: true,
          routes: <FeishuMonitorForwardingRoute>[
            _route(
              sourceConversationId: 'feed:alpha',
              targetGroupId: 'wk_alpha',
            ),
          ],
        ),
      ),
    );

    expect(runner.interval, const Duration(seconds: 1));
  });

  test('start primes current shell events before forwarding updates', () {
    fakeAsync((async) {
      final client = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'existing image'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = _runner(client: client, service: service);

      runner.start();
      async.flushMicrotasks();

      expect(client.fetchCount, 1);
      expect(service.primeCount, 1);
      expect(service.callCount, 0);
      expect(service.lastPrimedEvents, hasLength(1));

      client.addEvent(_snapshotUpdatedEvent());
      async.flushMicrotasks();

      expect(client.fetchCount, 2);
      expect(service.primeCount, 1);
      expect(service.callCount, 1);

      runner.dispose();
    });
  });

  test('start forwards startup network images observed after runner start', () {
    fakeAsync((async) {
      final startAt = DateTime.parse('2026-05-09T13:00:00Z');
      final client = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(
              messageId: 'network_image:live:sha_live',
              dedupeKey: 'feed:alpha:network_image:live:sha_live',
              text: '[Image]',
              captureSource: 'network_original_image',
              observedAt: startAt.add(const Duration(milliseconds: 1)),
            ),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = FeishuMonitorAutoForwardRunner(
        client: client,
        forwardingService: service,
        forwardingSettingsStore: _MemoryForwardingSettingsStore(
          FeishuMonitorForwardingSettings(
            enabled: true,
            routes: <FeishuMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'feed:alpha',
                targetGroupId: 'wk_alpha',
              ),
            ],
          ),
        ),
        clock: () => startAt,
      );

      runner.start();
      async.flushMicrotasks();

      expect(service.primeCount, 0);
      expect(service.callCount, 1);
      expect(service.lastEvents, hasLength(1));
      expect(
        service.lastEvents.single.dedupeKey,
        'feed:alpha:network_image:live:sha_live',
      );

      runner.dispose();
    });
  });

  test(
    'start forwards first non-empty snapshot update after empty startup',
    () {
      fakeAsync((async) {
        final client = _MutableShellClient(status: _status());
        final service = _FakeForwardingService();
        final runner = _runner(client: client, service: service);

        runner.start();
        async.flushMicrotasks();

        expect(client.fetchCount, 1);
        expect(service.primeCount, 0);
        expect(service.callCount, 0);

        client.status = _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(
              conversationId: 'feed:alpha',
              text: 'live after empty startup',
            ),
          ],
        );
        client.addEvent(_snapshotUpdatedEvent());
        async.flushMicrotasks();

        expect(client.fetchCount, 2);
        expect(service.primeCount, 0);
        expect(service.callCount, 1);
        expect(service.lastEvents, hasLength(1));
        expect(service.lastEvents.single.text, 'live after empty startup');

        client.status = _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'new image'),
          ],
        );
        client.addEvent(_snapshotUpdatedEvent());
        async.flushMicrotasks();

        expect(client.fetchCount, 3);
        expect(service.primeCount, 0);
        expect(service.callCount, 2);
        expect(service.lastEvents.single.text, 'new image');

        runner.dispose();
      });
    },
  );

  test(
    'start forwards first live event after initial empty shell snapshot',
    () {
      fakeAsync((async) {
        final client = _MutableShellClient(status: _status());
        final service = _FakeForwardingService();
        final runner = _runner(client: client, service: service);

        runner.start();
        async.flushMicrotasks();

        expect(client.fetchCount, 1);
        expect(service.primeCount, 0);
        expect(service.callCount, 0);

        client.status = _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'live after login'),
          ],
        );
        client.addEvent(_snapshotUpdatedEvent());
        async.flushMicrotasks();

        expect(client.fetchCount, 2);
        expect(service.primeCount, 0);
        expect(service.callCount, 1);
        expect(service.lastEvents.single.text, 'live after login');

        client.status = _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'second live event'),
          ],
        );
        client.addEvent(_snapshotUpdatedEvent());
        async.flushMicrotasks();

        expect(client.fetchCount, 3);
        expect(service.primeCount, 0);
        expect(service.callCount, 2);
        expect(service.lastEvents.single.text, 'second live event');

        runner.dispose();
      });
    },
  );

  test('start forwards immediately when snapshot update event arrives', () {
    fakeAsync((async) {
      final client = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'hello'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = _runner(client: client, service: service);

      runner.start();
      async.flushMicrotasks();
      expect(client.watchCount, 1);
      expect(service.primeCount, 1);
      expect(service.callCount, 0);

      client.addEvent(_snapshotUpdatedEvent());
      async.flushMicrotasks();

      expect(client.fetchCount, 2);
      expect(service.callCount, 1);

      runner.dispose();
    });
  });

  test('start subscribes to events from every worker', () {
    fakeAsync((async) {
      final workerA = _MutableShellClient(
        workerId: 'worker-1',
        status: _status(workerId: 'worker-1'),
      );
      final workerB = _MutableShellClient(
        workerId: 'worker-2',
        status: _status(workerId: 'worker-2'),
      );
      final service = _FakeForwardingService();
      final runner = FeishuMonitorAutoForwardRunner(
        clientGroup: FeishuMonitorShellClientGroup.forTesting(
          <FeishuMonitorShellClient>[workerA, workerB],
        ),
        forwardingService: service,
        forwardingSettingsStore: _MemoryForwardingSettingsStore(
          FeishuMonitorForwardingSettings(
            enabled: true,
            routes: <FeishuMonitorForwardingRoute>[
              _route(
                sourceConversationId: 'feed:a',
                targetGroupId: 'wk_a',
                workerId: 'worker-1',
              ),
              _route(
                sourceConversationId: 'feed:b',
                targetGroupId: 'wk_b',
                workerId: 'worker-2',
              ),
            ],
          ),
        ),
      );

      runner.start();
      async.flushMicrotasks();

      expect(workerA.watchCount, 1);
      expect(workerB.watchCount, 1);

      workerB.status = _status(
        workerId: 'worker-2',
        recentEvents: <FeishuMonitorMessageEvent>[
          _event(
            conversationId: 'feed:b',
            text: 'worker B live',
            dedupeKey: 'feed:b:event_1',
          ),
        ],
      );
      workerB.addEvent(_snapshotUpdatedEvent());
      async.flushMicrotasks();

      expect(service.callCount, 1);
      expect(service.lastEvents, hasLength(1));
      expect(service.lastEvents.single.text, 'worker B live');

      runner.dispose();
    });
  });

  test('start forwards first snapshot update instead of priming it away', () {
    fakeAsync((async) {
      final client = _MutableShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'existing'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = _runner(client: client, service: service);

      runner.start();

      client.status = _status(
        recentEvents: <FeishuMonitorMessageEvent>[
          _event(
            conversationId: 'feed:alpha',
            text: 'live image after startup',
            dedupeKey: 'feed:alpha:live-image-after-startup',
          ),
        ],
      );
      client.addEvent(_snapshotUpdatedEvent());
      async.flushMicrotasks();

      expect(service.primeCount, 0);
      expect(service.callCount, 1);
      expect(service.lastEvents.single.text, 'live image after startup');

      runner.dispose();
    });
  });

  test('start keeps fallback polling when no events arrive', () {
    fakeAsync((async) {
      final client = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'hello'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = _runner(
        client: client,
        service: service,
        interval: const Duration(seconds: 3),
      );

      runner.start();
      async.flushMicrotasks();
      expect(service.primeCount, 1);
      expect(service.callCount, 0);

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      expect(client.fetchCount, 2);
      expect(service.callCount, 1);

      runner.dispose();
    });
  });

  test(
    'fallback polling forwards first event that appears after empty startup',
    () {
      fakeAsync((async) {
        final client = _MutableShellClient(status: _status());
        final service = _FakeForwardingService();
        final runner = _runner(
          client: client,
          service: service,
          interval: const Duration(seconds: 3),
        );

        runner.start();
        async.flushMicrotasks();

        expect(service.primeCount, 0);
        expect(service.callCount, 0);

        client.status = _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(
              conversationId: 'feed:alpha',
              text: '[Image]',
              dedupeKey: 'feed:alpha:network_image:live-after-empty:sha1',
            ),
          ],
        );
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(service.primeCount, 0);
        expect(service.callCount, 1);
        expect(
          service.lastEvents.single.dedupeKey,
          'feed:alpha:network_image:live-after-empty:sha1',
        );

        runner.dispose();
      });
    },
  );

  test(
    'start ignores stale network images already present in shell snapshot',
    () {
      fakeAsync((async) {
        final startAt = DateTime.parse('2026-05-09T13:00:00Z');
        final client = _MutableShellClient(status: _status());
        final service = _FakeForwardingService();
        final runner = FeishuMonitorAutoForwardRunner(
          client: client,
          forwardingService: service,
          forwardingSettingsStore: _MemoryForwardingSettingsStore(
            FeishuMonitorForwardingSettings(
              enabled: true,
              routes: <FeishuMonitorForwardingRoute>[
                _route(
                  sourceConversationId: 'feed:alpha',
                  targetGroupId: 'wk_alpha',
                ),
              ],
            ),
          ),
          clock: () => startAt,
        );

        runner.start();
        async.flushMicrotasks();

        client.status = _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(
              messageId: 'network_image:old:sha_old',
              dedupeKey: 'feed:alpha:network_image:old:sha_old',
              text: '[Image]',
              captureSource: 'network_original_image',
              observedAt: startAt.subtract(const Duration(minutes: 20)),
            ),
            _event(
              messageId: 'network_image:new:sha_new',
              dedupeKey: 'feed:alpha:network_image:new:sha_new',
              text: '[Image]',
              captureSource: 'network_original_image',
              observedAt: startAt.add(const Duration(seconds: 1)),
            ),
          ],
        );
        client.addEvent(_snapshotUpdatedEvent());
        async.flushMicrotasks();

        expect(service.primeCount, 0);
        expect(service.callCount, 1);
        expect(service.lastEvents, hasLength(1));
        expect(
          service.lastEvents.single.dedupeKey,
          'feed:alpha:network_image:new:sha_new',
        );

        runner.dispose();
      });
    },
  );

  test('repeated start does not create duplicate event subscriptions', () {
    fakeAsync((async) {
      final client = _FakeShellClient(
        status: _status(
          recentEvents: <FeishuMonitorMessageEvent>[
            _event(conversationId: 'feed:alpha', text: 'hello'),
          ],
        ),
      );
      final service = _FakeForwardingService();
      final runner = _runner(client: client, service: service);

      runner.start();
      runner.start();
      async.flushMicrotasks();

      expect(client.watchCount, 1);
      expect(service.primeCount, 1);
      expect(service.callCount, 0);

      client.addEvent(_snapshotUpdatedEvent());
      async.flushMicrotasks();

      expect(client.watchCount, 1);
      expect(client.fetchCount, 2);
      expect(service.callCount, 1);

      runner.dispose();
    });
  });

  test(
    'event triggered runOnce errors are reported without uncaught async errors',
    () {
      fakeAsync((async) {
        final errors = <Object>[];
        final client = _FakeShellClient(
          status: _status(
            recentEvents: <FeishuMonitorMessageEvent>[
              _event(conversationId: 'feed:alpha', text: 'hello'),
            ],
          ),
        );
        final service = _FakeForwardingService();
        final runner = _runner(
          client: client,
          service: service,
          onError: (error, _) => errors.add(error),
        );

        runner.start();
        async.flushMicrotasks();
        service.failNextForward = true;

        client.addEvent(_snapshotUpdatedEvent());
        async.flushMicrotasks();

        expect(errors, hasLength(1));
        expect(errors.single, isA<StateError>());

        runner.dispose();
      });
    },
  );

  test(
    'fallback timer runOnce errors are reported without uncaught async errors',
    () {
      fakeAsync((async) {
        final errors = <Object>[];
        final client = _FakeShellClient(
          status: _status(
            recentEvents: <FeishuMonitorMessageEvent>[
              _event(conversationId: 'feed:alpha', text: 'hello'),
            ],
          ),
        );
        final service = _FakeForwardingService();
        final runner = _runner(
          client: client,
          service: service,
          interval: const Duration(seconds: 3),
          onError: (error, _) => errors.add(error),
        );

        runner.start();
        async.flushMicrotasks();
        service.failNextForward = true;

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(errors, hasLength(1));
        expect(errors.single, isA<StateError>());

        runner.dispose();
      });
    },
  );

  test('event stream done reconnects after eventReconnectDelay', () {
    fakeAsync((async) {
      final client = _FakeShellClient(status: _status());
      final service = _FakeForwardingService();
      final runner = _runner(
        client: client,
        service: service,
        eventReconnectDelay: const Duration(seconds: 1),
      );

      runner.start();
      async.flushMicrotasks();
      expect(client.watchCount, 1);

      client.closeLatestEvents();
      async.flushMicrotasks();
      expect(client.watchCount, 1);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(client.watchCount, 2);

      runner.dispose();
    });
  });

  test('event stream error reconnects after eventReconnectDelay', () {
    fakeAsync((async) {
      final client = _FakeShellClient(status: _status());
      final service = _FakeForwardingService();
      final runner = _runner(
        client: client,
        service: service,
        eventReconnectDelay: const Duration(seconds: 1),
      );

      runner.start();
      async.flushMicrotasks();
      expect(client.watchCount, 1);

      client.addEventError(StateError('sse disconnected'));
      async.flushMicrotasks();
      expect(client.watchCount, 1);

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(client.watchCount, 2);

      runner.dispose();
    });
  });

  test('stop before reconnect delay prevents event stream reconnect', () {
    fakeAsync((async) {
      final client = _FakeShellClient(status: _status());
      final service = _FakeForwardingService();
      final runner = _runner(
        client: client,
        service: service,
        eventReconnectDelay: const Duration(seconds: 1),
      );

      runner.start();
      async.flushMicrotasks();
      expect(client.watchCount, 1);

      client.closeLatestEvents();
      async.flushMicrotasks();
      runner.stop();

      async.elapse(const Duration(seconds: 1));
      async.flushMicrotasks();

      expect(client.watchCount, 1);
    });
  });

  test(
    'late data from old event subscription does not trigger runOnce after stop',
    () {
      fakeAsync((async) {
        final client = _RetainedDataShellClient(
          status: _status(
            recentEvents: <FeishuMonitorMessageEvent>[
              _event(conversationId: 'feed:alpha', text: 'hello'),
            ],
          ),
        );
        final service = _FakeForwardingService();
        final runner = _runner(client: client, service: service);

        runner.start();
        async.flushMicrotasks();
        expect(client.fetchCount, 1);
        expect(service.primeCount, 1);
        expect(service.callCount, 0);

        runner.stop();
        client.emitOldEvent(_snapshotUpdatedEvent());
        async.flushMicrotasks();

        expect(client.fetchCount, 1);
        expect(service.callCount, 0);
      });
    },
  );
}

FeishuMonitorAutoForwardRunner _runner({
  required _FakeShellClient client,
  required _FakeForwardingService service,
  Duration interval = const Duration(seconds: 30),
  Duration eventReconnectDelay = const Duration(seconds: 1),
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  return FeishuMonitorAutoForwardRunner(
    client: client,
    forwardingService: service,
    forwardingSettingsStore: _MemoryForwardingSettingsStore(
      FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
        ],
      ),
    ),
    interval: interval,
    eventReconnectDelay: eventReconnectDelay,
    onError: onError,
  );
}

FeishuMonitorShellStatus _status({
  List<FeishuMonitorMessageEvent> recentEvents =
      const <FeishuMonitorMessageEvent>[],
  String workerId = 'worker-1',
}) {
  return FeishuMonitorShellStatus(
    shellState: 'online',
    captureState: 'running',
    loginState: 'logged_in',
    hookState: 'healthy',
    runtimeUrl: 'https://feishu.cn/messenger',
    pageTitle: '消息 - 飞书',
    pageKind: 'messenger',
    webviewAvailable: true,
    shellMode: 'desktop_shell',
    queueDepth: 0,
    messagesToday: 0,
    deliveriesSucceededToday: 0,
    deliveriesFailedToday: 0,
    lastUpdatedAt: null,
    probeObservedAt: DateTime.parse('2026-05-09T13:00:00Z'),
    observedConversations: const <FeishuMonitorObservedConversation>[],
    observedMessages: const <FeishuMonitorObservedMessage>[],
    recentEvents: recentEvents,
    workerId: workerId,
    lastError: '',
  );
}

FeishuMonitorMessageEvent _event({
  String conversationId = 'feed:alpha',
  String text = 'hello',
  String dedupeKey = 'feed:alpha:event_1',
  String messageId = 'message_1',
  String captureSource = 'feed_card_probe',
  DateTime? observedAt,
}) {
  return FeishuMonitorMessageEvent(
    eventId: 'event_$messageId',
    dedupeKey: dedupeKey,
    accountId: '',
    conversationId: conversationId,
    conversationName: 'Alpha',
    conversationType: 'unknown',
    messageId: messageId,
    senderId: '',
    senderName: 'Alice',
    messageType: 'text',
    text: text,
    sentAt: null,
    observedAt: observedAt ?? DateTime.parse('2026-05-09T13:00:00Z'),
    captureSource: captureSource,
  );
}

FeishuMonitorShellEvent _snapshotUpdatedEvent() {
  return FeishuMonitorShellEvent(
    type: 'snapshot_updated',
    reason: 'message_observed',
    updatedAt: DateTime.parse('2026-05-09T13:00:00Z'),
    recentEvents: 1,
    observedConversations: 1,
    error: '',
  );
}

FeishuMonitorForwardingRoute _route({
  String sourceConversationId = 'feed:alpha',
  String targetGroupId = 'wk_alpha',
  String workerId = '',
}) {
  return FeishuMonitorForwardingRoute(
    id: 'route_1',
    enabled: true,
    sourceConversationId: sourceConversationId,
    sourceConversationName: 'Alpha',
    sourceConversationType: 'unknown',
    targetGroupId: targetGroupId,
    targetGroupName: 'Target',
    workerId: workerId,
    createdAt: DateTime.parse('2026-05-09T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-09T01:00:00Z'),
  );
}

class _FakeShellClient extends FeishuMonitorShellClient {
  _FakeShellClient({required this.status, super.workerId});

  FeishuMonitorShellStatus status;
  final List<StreamController<FeishuMonitorShellEvent>> events =
      <StreamController<FeishuMonitorShellEvent>>[];
  int fetchCount = 0;
  int watchCount = 0;
  int syncSourceCount = 0;
  List<String> lastSyncedSourceIds = const <String>[];
  List<String> lastSyncedSourceNames = const <String>[];

  @override
  Future<FeishuMonitorShellStatus> fetchStatus() async {
    fetchCount += 1;
    return status;
  }

  @override
  Stream<FeishuMonitorShellEvent> watchEvents() {
    watchCount += 1;
    final controller = StreamController<FeishuMonitorShellEvent>();
    events.add(controller);
    return controller.stream;
  }

  @override
  Future<void> syncConfiguredMediaSources(
    List<FeishuMonitorForwardingRoute> routes,
  ) async {
    syncSourceCount += 1;
    lastSyncedSourceIds = routes
        .map((route) => route.sourceConversationId)
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
    lastSyncedSourceNames = routes
        .map((route) => route.sourceConversationName)
        .where((value) => value.trim().isNotEmpty)
        .toList(growable: false);
  }

  void addEvent(FeishuMonitorShellEvent event) {
    events.last.add(event);
  }

  void addEventError(Object error) {
    events.last.addError(error);
  }

  Future<void> closeLatestEvents() {
    return events.last.close();
  }
}

class _MutableShellClient extends _FakeShellClient {
  _MutableShellClient({required super.status, super.workerId});
}

class _FailingFetchShellClient extends _FakeShellClient {
  _FailingFetchShellClient({required super.status, required this.error});

  final Object error;

  @override
  Future<FeishuMonitorShellStatus> fetchStatus() async {
    fetchCount += 1;
    throw error;
  }
}

class _RetainedDataShellClient extends _FakeShellClient {
  _RetainedDataShellClient({required super.status});

  void Function(FeishuMonitorShellEvent event)? _oldOnData;

  @override
  Stream<FeishuMonitorShellEvent> watchEvents() {
    watchCount += 1;
    return _RetainedDataStream((onData) {
      _oldOnData = onData;
    });
  }

  void emitOldEvent(FeishuMonitorShellEvent event) {
    scheduleMicrotask(() {
      _oldOnData?.call(event);
    });
  }
}

class _RetainedDataStream extends Stream<FeishuMonitorShellEvent> {
  const _RetainedDataStream(this.captureOnData);

  final void Function(void Function(FeishuMonitorShellEvent event)? onData)
  captureOnData;

  @override
  StreamSubscription<FeishuMonitorShellEvent> listen(
    void Function(FeishuMonitorShellEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    captureOnData(onData);
    return const _RetainedDataSubscription();
  }
}

class _RetainedDataSubscription
    implements StreamSubscription<FeishuMonitorShellEvent> {
  const _RetainedDataSubscription();

  @override
  Future<void> cancel() async {}

  @override
  void onData(void Function(FeishuMonitorShellEvent data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Future<E>.value(futureValue);
}

class _FakeForwardingService extends FeishuMonitorForwardingService {
  _FakeForwardingService() : super(sender: _NoopTextSender());

  int callCount = 0;
  int primeCount = 0;
  FeishuMonitorForwardingSettings? lastSettings;
  List<FeishuMonitorMessageEvent> lastEvents =
      const <FeishuMonitorMessageEvent>[];
  List<FeishuMonitorMessageEvent> lastPrimedEvents =
      const <FeishuMonitorMessageEvent>[];
  bool failNextForward = false;

  @override
  Future<void> primeRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    primeCount += 1;
    lastSettings = settings;
    lastPrimedEvents = List<FeishuMonitorMessageEvent>.from(events);
  }

  @override
  Future<FeishuMonitorForwardingResult> forwardRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    if (failNextForward) {
      failNextForward = false;
      throw StateError('forward failed');
    }
    callCount += 1;
    lastSettings = settings;
    lastEvents = List<FeishuMonitorMessageEvent>.from(events);
    return FeishuMonitorForwardingResult(
      sent: events.length,
      skippedUnmatched: 0,
      failed: 0,
    );
  }
}

class _MemoryForwardingSettingsStore
    implements FeishuMonitorForwardingSettingsStore {
  const _MemoryForwardingSettingsStore(this.settings);

  final FeishuMonitorForwardingSettings settings;

  @override
  Future<FeishuMonitorForwardingSettings> load() async => settings;

  @override
  Future<void> save(FeishuMonitorForwardingSettings settings) async {}
}

class _NoopTextSender implements FeishuMonitorTextSender {
  @override
  Future<void> sendImage({
    required String channelId,
    required int channelType,
    String? channelName,
    required FeishuMonitorImageAttachment image,
    FeishuMonitorRelayIdentity? relayIdentity,
  }) async {}

  @override
  Future<void> sendText({
    required String channelId,
    required int channelType,
    String? channelName,
    required String text,
    FeishuMonitorRelayIdentity? relayIdentity,
  }) async {}
}
