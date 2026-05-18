import 'package:local_monitor_shell_core/local_monitor_shell_core.dart';

import 'mengxia_page_probe.dart';

ShellSnapshot applyMengxiaRuntimeSnapshot({
  required ShellSnapshot current,
  required Map<String, Object?> snapshot,
  required MengxiaPageProbe probe,
  required DateTime updatedAt,
  List<NormalizedMessageEvent> networkEvents = const <NormalizedMessageEvent>[],
  Map<String, dynamic> networkDiagnostics = const <String, dynamic>{},
}) {
  final events = _eventList(snapshot['recent_events']);
  final recentEvents = mergeRecentEvents(
    current.recentEvents,
    <NormalizedMessageEvent>[...events, ...networkEvents],
  );
  final incomingConversations = _conversationList(
    snapshot['observed_conversations'],
  );
  final observedConversations = probe.pageKind == MengxiaPageKind.login
      ? incomingConversations
      : _mergeObservedConversations(
          current.observedConversations,
          incomingConversations,
        );
  return current.copyWith(
    shellState: (snapshot['shell_state'] ?? 'online').toString(),
    captureState: (snapshot['capture_state'] ?? 'stopped').toString(),
    loginState: (snapshot['login_state'] ?? 'login_required').toString(),
    hookState: (snapshot['hook_state'] ?? 'healthy').toString(),
    runtimeUrl: (snapshot['runtime_url'] ?? '').toString(),
    pageTitle: (snapshot['page_title'] ?? '').toString(),
    webviewAvailable: snapshot['webview_available'] == true,
    shellMode: (snapshot['shell_mode'] ?? 'desktop_shell').toString(),
    pageKind: (snapshot['page_kind'] ?? 'unknown').toString(),
    probeObservedAt: probe.observedAt,
    probeDiagnostics: _mergeDiagnostics(
      current.probeDiagnostics,
      <String, dynamic>{
        ..._diagnostics(snapshot['probe_diagnostics']),
        ...networkDiagnostics,
      },
    ),
    observedConversations: observedConversations,
    observedMessages: const <ObservedMessageCandidate>[],
    recentEvents: recentEvents,
    messagesToday: current.messagesToday + events.length + networkEvents.length,
    queueDepth: 0,
    lastUpdatedAt: updatedAt.toUtc(),
    lastError: '',
  );
}

List<ObservedConversation> _mergeObservedConversations(
  List<ObservedConversation> current,
  List<ObservedConversation> incoming, {
  int limit = 400,
}) {
  final merged = <String, ObservedConversation>{};
  for (final conversation in <ObservedConversation>[...current, ...incoming]) {
    if (!_isLikelyObservedSourceConversation(conversation)) {
      continue;
    }
    final id = conversation.id.trim();
    final name = conversation.name.trim();
    final key = id.isNotEmpty ? id : name;
    if (key.isEmpty) {
      continue;
    }
    final existing = merged[key];
    if (existing == null || _compareObservedAt(conversation, existing) >= 0) {
      merged[key] = conversation;
    }
  }
  final values = merged.values.toList()
    ..sort((a, b) => _compareObservedAt(b, a));
  return values.take(limit).toList(growable: false);
}

bool _isLikelyObservedSourceConversation(ObservedConversation conversation) {
  final name = conversation.name.trim();
  if (name.length < 2 || name.length > 40) {
    return false;
  }
  if (name.contains(r'\n') || name.contains(r'\r')) {
    return false;
  }
  if (name.contains('\n') || name.contains('\r')) {
    return false;
  }
  if (RegExp(r'\[图片\]|\[文件\]|签到|搜索直播间|VIP特权').hasMatch(name)) {
    return false;
  }
  if (RegExp(r'祝大家|周末愉快|回调|前期涨太多|老师还是|开始回程').hasMatch(name)) {
    return false;
  }
  if (RegExp(r'[：:，。！？,.!?；;]').hasMatch(name)) {
    return false;
  }
  if (RegExp(r'^\d{1,4}([-/]\d{0,2}){1,2}$').hasMatch(name)) {
    return false;
  }
  return true;
}

int _compareObservedAt(ObservedConversation a, ObservedConversation b) {
  final parsedA = DateTime.tryParse(a.observedAt);
  final parsedB = DateTime.tryParse(b.observedAt);
  if (parsedA != null && parsedB != null) {
    return parsedA.compareTo(parsedB);
  }
  return a.observedAt.compareTo(b.observedAt);
}

List<ObservedConversation> _conversationList(Object? value) {
  if (value is! List) {
    return const <ObservedConversation>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => ObservedConversation.fromJson(
          item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
        ),
      )
      .toList(growable: false);
}

List<NormalizedMessageEvent> _eventList(Object? value) {
  if (value is! List) {
    return const <NormalizedMessageEvent>[];
  }
  return value
      .whereType<Map>()
      .map(
        (item) => NormalizedMessageEvent.fromJson(
          item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
        ),
      )
      .toList(growable: false);
}

Map<String, dynamic> _diagnostics(Object? value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return value.map((key, itemValue) => MapEntry(key.toString(), itemValue));
}

Map<String, dynamic> _mergeDiagnostics(
  Map<String, dynamic> current,
  Map<String, dynamic> incoming,
) {
  return <String, dynamic>{
    ...incoming,
    if (current.containsKey('configured_media_sources'))
      'configured_media_sources': current['configured_media_sources'],
    if (current.containsKey('configured_media_source_count'))
      'configured_media_source_count': current['configured_media_source_count'],
  };
}
