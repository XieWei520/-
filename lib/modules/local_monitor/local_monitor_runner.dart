class LocalMonitorStartupEventSplit<T> {
  const LocalMonitorStartupEventSplit({
    required this.startupEvents,
    required this.liveEvents,
  });

  final List<T> startupEvents;
  final List<T> liveEvents;
}

List<TEvent> mergeLocalMonitorStatusEvents<TStatus, TEvent>({
  required Iterable<TStatus> statuses,
  required bool Function(TStatus status) isStatusForwardable,
  required Iterable<TEvent> Function(TStatus status) eventsForStatus,
  required String Function(TEvent event) dedupeKeyForEvent,
  bool Function(TEvent event)? includeEvent,
}) {
  final events = <TEvent>[];
  final seen = <String>{};
  for (final status in statuses) {
    if (!isStatusForwardable(status)) {
      continue;
    }
    for (final event in eventsForStatus(status)) {
      if (includeEvent != null && !includeEvent(event)) {
        continue;
      }
      final key = dedupeKeyForEvent(event);
      if (key.isNotEmpty && !seen.add(key)) {
        continue;
      }
      events.add(event);
    }
  }
  return events;
}

LocalMonitorStartupEventSplit<T> splitLocalMonitorStartupEvents<T>({
  required Iterable<T> events,
  required DateTime? startedAt,
  required DateTime? Function(T event) observedAtForEvent,
}) {
  final startupEvents = <T>[];
  final liveEvents = <T>[];
  for (final event in events) {
    if (wasLocalMonitorEventObservedAfterStart(
      startedAt: startedAt,
      observedAt: observedAtForEvent(event),
    )) {
      liveEvents.add(event);
    } else {
      startupEvents.add(event);
    }
  }
  return LocalMonitorStartupEventSplit<T>(
    startupEvents: startupEvents,
    liveEvents: liveEvents,
  );
}

bool wasLocalMonitorEventObservedAfterStart({
  required DateTime? startedAt,
  required DateTime? observedAt,
}) {
  if (startedAt == null || observedAt == null) {
    return false;
  }
  return !observedAt.toUtc().isBefore(startedAt.toUtc());
}

String localMonitorMessageDedupeKey({
  required String dedupeKey,
  required String eventId,
  String messageId = '',
}) {
  final normalizedDedupeKey = dedupeKey.trim();
  if (normalizedDedupeKey.isNotEmpty) {
    return normalizedDedupeKey;
  }
  final normalizedEventId = eventId.trim();
  if (normalizedEventId.isNotEmpty) {
    return normalizedEventId;
  }
  return messageId.trim();
}
