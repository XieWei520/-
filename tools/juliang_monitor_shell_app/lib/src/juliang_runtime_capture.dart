import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

import 'juliang_page_probe.dart';
import 'juliang_runtime_snapshot_mapper.dart';

class JuliangRuntimeCapture {
  JuliangRuntimeCapture({required this.store, required this.events});

  final ShellStore store;
  final ShellEventBus events;

  Future<ShellSnapshot> applyProbe(
    JuliangPageProbe probe, {
    DateTime? updatedAt,
  }) async {
    final mapped = mapJuliangRuntimeSnapshot(
      probe,
      updatedAt: updatedAt ?? DateTime.now().toUtc(),
    );
    final next = await store.update((current) {
      final configuredSources = _configuredSourcesFromDiagnostics(
        current.probeDiagnostics,
      );
      final incomingEvents = _filterEventsForConfiguredSources(
        mapped.recentEvents,
        configuredSources,
      );
      final isLoginPage = probe.pageKind == JuliangPageKind.login;
      final mergedEvents = isLoginPage
          ? const <NormalizedMessageEvent>[]
          : mergeRecentEvents(current.recentEvents, incomingEvents);
      return current.copyWith(
        shellState: mapped.shellState,
        captureState: mapped.captureState,
        loginState: mapped.loginState,
        hookState: mapped.hookState,
        runtimeUrl: mapped.runtimeUrl,
        pageTitle: mapped.pageTitle,
        webviewAvailable: mapped.webviewAvailable,
        shellMode: mapped.shellMode,
        pageKind: mapped.pageKind,
        probeObservedAt: probe.observedAt,
        probeDiagnostics: <String, dynamic>{
          ...current.probeDiagnostics,
          ...mapped.probeDiagnostics,
        },
        observedConversations: mapped.observedConversations,
        observedMessages: const <ObservedMessageCandidate>[],
        recentEvents: mergedEvents,
        messagesToday: mergedEvents.length,
        queueDepth: 0,
        lastUpdatedAt: mapped.lastUpdatedAt,
        lastError: '',
      );
    }, preserveCaptureState: false);
    events.publish(
      ShellEvent(
        type: ShellEventType.snapshotUpdated,
        reason: 'juliang_probe',
        updatedAt: next.lastUpdatedAt,
        recentEventsCount: next.recentEvents.length,
        observedConversationsCount: next.observedConversations.length,
      ),
    );
    return next;
  }

  Future<void> close() => events.close();
}

List<_ConfiguredSource> _configuredSourcesFromDiagnostics(
  Map<String, dynamic> diagnostics,
) {
  final rawSources = diagnostics['configured_media_sources'];
  if (rawSources is! List) {
    return const <_ConfiguredSource>[];
  }
  final sources = <_ConfiguredSource>[];
  final seen = <String>{};
  for (final rawSource in rawSources) {
    if (rawSource is! Map) {
      continue;
    }
    final id = (rawSource['conversation_id'] ?? '').toString().trim();
    final name = _normalizeSourceName(
      (rawSource['conversation_name'] ?? '').toString(),
    );
    if (id.isEmpty && name.isEmpty) {
      continue;
    }
    final key = '$id\n$name';
    if (!seen.add(key)) {
      continue;
    }
    sources.add(_ConfiguredSource(id: id, normalizedName: name));
  }
  return List<_ConfiguredSource>.unmodifiable(sources);
}

List<NormalizedMessageEvent> _filterEventsForConfiguredSources(
  List<NormalizedMessageEvent> events,
  List<_ConfiguredSource> configuredSources,
) {
  if (configuredSources.isEmpty) {
    return events;
  }
  return events
      .where((event) {
        final eventId = event.conversationId.trim();
        if (eventId.isNotEmpty &&
            configuredSources.any((source) => source.id == eventId)) {
          return true;
        }
        final eventName = _normalizeSourceName(event.conversationName);
        return eventName.isNotEmpty &&
            configuredSources.any(
              (source) => source.normalizedName == eventName,
            );
      })
      .toList(growable: false);
}

String _normalizeSourceName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

class _ConfiguredSource {
  const _ConfiguredSource({required this.id, required this.normalizedName});

  final String id;
  final String normalizedName;
}
