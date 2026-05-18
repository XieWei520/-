import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

import 'juliang_page_probe.dart';
import 'juliang_text_event_parser.dart';

ShellSnapshot mapJuliangRuntimeSnapshot(
  JuliangPageProbe probe, {
  DateTime? updatedAt,
}) {
  final isLoginPage = probe.pageKind == JuliangPageKind.login;
  final normalizedEvents = isLoginPage
      ? const <NormalizedMessageEvent>[]
      : normalizeJuliangProbeMessageEvents(
          probe.events,
          observedAt: probe.observedAt,
        );
  final conversations = _mergeConversations(
    conversations: isLoginPage
        ? const <JuliangProbeConversation>[]
        : probe.conversations,
    events: normalizedEvents,
    observedAt: probe.observedAt,
  );
  return ShellSnapshot.initial().copyWith(
    shellState: 'online',
    hookState: 'healthy',
    webviewAvailable: true,
    shellMode: 'desktop_shell',
    runtimeUrl: probe.runtimeUrl,
    pageTitle: probe.pageTitle,
    pageKind: probe.pageKind.wireName,
    loginState: isLoginPage ? 'login_required' : 'logged_in',
    captureState: isLoginPage ? 'stopped' : 'running',
    probeObservedAt: probe.observedAt,
    probeDiagnostics: Map<String, dynamic>.unmodifiable(
      probe.probeDiagnostics.map(
        (key, value) => MapEntry(key, _jsonSafeValue(value)),
      ),
    ),
    observedConversations: conversations,
    observedMessages: const <ObservedMessageCandidate>[],
    recentEvents: normalizedEvents,
    messagesToday: normalizedEvents.length,
    queueDepth: 0,
    deliveriesSucceededToday: 0,
    deliveriesFailedToday: 0,
    lastUpdatedAt: updatedAt?.toUtc() ?? DateTime.now().toUtc(),
    lastError: '',
  );
}

List<ObservedConversation> _mergeConversations({
  required List<JuliangProbeConversation> conversations,
  required List<NormalizedMessageEvent> events,
  required DateTime observedAt,
}) {
  final observedAtText = observedAt.toUtc().toIso8601String();
  final merged = <String, ObservedConversation>{};
  for (final conversation in conversations) {
    final id = conversation.id.trim().isNotEmpty
        ? conversation.id.trim()
        : fallbackJuliangConversationId(conversation.name);
    if (id.isEmpty) {
      continue;
    }
    merged[id] = ObservedConversation(
      id: id,
      name: conversation.name.trim(),
      type: conversation.type.trim().isEmpty
          ? 'unknown'
          : conversation.type.trim(),
      lastMessagePreview: conversation.lastMessagePreview.trim(),
      observedAt: observedAtText,
    );
  }

  for (final event in events) {
    final id = event.conversationId.trim();
    if (id.isEmpty || merged.containsKey(id)) {
      continue;
    }
    final name = event.conversationName.trim().isEmpty
        ? id
        : event.conversationName.trim();
    merged[id] = ObservedConversation(
      id: id,
      name: name,
      type: event.conversationType.trim().isEmpty
          ? 'unknown'
          : event.conversationType.trim(),
      lastMessagePreview: event.text,
      observedAt: event.observedAt.trim().isEmpty
          ? observedAtText
          : event.observedAt.trim(),
    );
  }
  return List<ObservedConversation>.unmodifiable(merged.values);
}

Object? _jsonSafeValue(Object? value) {
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _jsonSafeValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_jsonSafeValue).toList(growable: false);
  }
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  return value.toString();
}
