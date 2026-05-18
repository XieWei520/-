import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_runner.dart';

void main() {
  test('mergeLocalMonitorStatusEvents filters statuses and dedupes events', () {
    final merged = mergeLocalMonitorStatusEvents<_Status, _Event>(
      statuses: <_Status>[
        _Status(
          online: true,
          capturing: true,
          events: <_Event>[
            _Event(id: 'event-1', dedupeKey: 'same', text: 'first'),
            _Event(id: 'event-2', dedupeKey: 'same', text: 'duplicate'),
            _Event(id: 'event-3', text: 'empty-key-a'),
            _Event(id: 'event-4', text: 'empty-key-b'),
          ],
        ),
        _Status(
          online: false,
          capturing: true,
          events: <_Event>[_Event(id: 'event-offline', text: 'offline')],
        ),
        _Status(
          online: true,
          capturing: false,
          events: <_Event>[_Event(id: 'event-stopped', text: 'stopped')],
        ),
      ],
      isStatusForwardable: (status) => status.online && status.capturing,
      eventsForStatus: (status) => status.events,
      dedupeKeyForEvent: (event) => event.dedupeKey,
    );

    expect(merged.map((event) => event.text), <String>[
      'first',
      'empty-key-a',
      'empty-key-b',
    ]);
  });

  test('mergeLocalMonitorStatusEvents applies optional event filter', () {
    final merged = mergeLocalMonitorStatusEvents<_Status, _Event>(
      statuses: <_Status>[
        _Status(
          online: true,
          capturing: true,
          events: <_Event>[
            _Event(id: 'event-1', text: 'keep'),
            _Event(id: 'event-2', text: 'drop', stale: true),
          ],
        ),
      ],
      isStatusForwardable: (status) => status.online && status.capturing,
      eventsForStatus: (status) => status.events,
      dedupeKeyForEvent: (event) => event.id,
      includeEvent: (event) => !event.stale,
    );

    expect(merged.map((event) => event.text), <String>['keep']);
  });

  test('splitLocalMonitorStartupEvents separates old and live events', () {
    final startedAt = DateTime.parse('2026-05-13T01:00:00Z');

    final split = splitLocalMonitorStartupEvents<_Event>(
      events: <_Event>[
        _Event(
          id: 'old',
          text: 'old',
          observedAt: startedAt.subtract(const Duration(milliseconds: 1)),
        ),
        _Event(id: 'unknown', text: 'unknown'),
        _Event(id: 'same-time', text: 'same-time', observedAt: startedAt),
        _Event(
          id: 'new',
          text: 'new',
          observedAt: startedAt.add(const Duration(milliseconds: 1)),
        ),
      ],
      startedAt: startedAt,
      observedAtForEvent: (event) => event.observedAt,
    );

    expect(split.startupEvents.map((event) => event.text), <String>[
      'old',
      'unknown',
    ]);
    expect(split.liveEvents.map((event) => event.text), <String>[
      'same-time',
      'new',
    ]);
  });

  test('localMonitorMessageDedupeKey returns the first non-empty key', () {
    expect(
      localMonitorMessageDedupeKey(dedupeKey: ' dedupe ', eventId: 'event'),
      'dedupe',
    );
    expect(
      localMonitorMessageDedupeKey(dedupeKey: '', eventId: ' event '),
      'event',
    );
    expect(
      localMonitorMessageDedupeKey(
        dedupeKey: '',
        eventId: '',
        messageId: ' message ',
      ),
      'message',
    );
  });
}

class _Status {
  const _Status({
    required this.online,
    required this.capturing,
    required this.events,
  });

  final bool online;
  final bool capturing;
  final List<_Event> events;
}

class _Event {
  const _Event({
    required this.id,
    this.dedupeKey = '',
    required this.text,
    this.observedAt,
    this.stale = false,
  });

  final String id;
  final String dedupeKey;
  final String text;
  final DateTime? observedAt;
  final bool stale;
}
