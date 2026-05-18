import 'dart:convert';

class MengxiaConfiguredSource {
  const MengxiaConfiguredSource({
    required this.conversationId,
    required this.conversationName,
  });

  final String conversationId;
  final String conversationName;

  bool get isNotEmpty =>
      conversationId.trim().isNotEmpty || conversationName.trim().isNotEmpty;
}

class MengxiaConfiguredSourceCycler {
  int _nextIndex = 0;

  MengxiaConfiguredSource? next(List<MengxiaConfiguredSource> sources) {
    if (sources.isEmpty) {
      _nextIndex = 0;
      return null;
    }
    if (_nextIndex >= sources.length) {
      _nextIndex = 0;
    }
    final source = sources[_nextIndex];
    _nextIndex = (_nextIndex + 1) % sources.length;
    return source;
  }
}

List<MengxiaConfiguredSource> mengxiaConfiguredSourcesFromDiagnostics(
  Map<String, Object?> diagnostics,
) {
  final rawSources = diagnostics['configured_media_sources'];
  if (rawSources is! List) {
    return const <MengxiaConfiguredSource>[];
  }
  final sources = <MengxiaConfiguredSource>[];
  final seen = <String>{};
  for (final rawSource in rawSources) {
    if (rawSource is! Map) {
      continue;
    }
    final conversationId = (rawSource['conversation_id'] ?? '')
        .toString()
        .trim();
    final conversationName = (rawSource['conversation_name'] ?? '')
        .toString()
        .trim();
    final source = MengxiaConfiguredSource(
      conversationId: conversationId,
      conversationName: conversationName,
    );
    if (!source.isNotEmpty) {
      continue;
    }
    final key = '$conversationId\n$conversationName';
    if (!seen.add(key)) {
      continue;
    }
    sources.add(source);
  }
  return List<MengxiaConfiguredSource>.unmodifiable(sources);
}

String mengxiaClickConfiguredSourceScript(MengxiaConfiguredSource source) {
  final sourceJson = jsonEncode(<String, String>{
    'conversation_id': source.conversationId.trim(),
    'conversation_name': source.conversationName.trim(),
  });
  return '''
(() => {
  const source = $sourceJson;
  const normalize = (value) => String(value || '').replace(/\\s+/g, ' ').trim();
  const wantedId = normalize(source.conversation_id);
  const wantedName = normalize(source.conversation_name);
  if (!wantedId && !wantedName) {
    return { handled: false, reason: 'empty-configured-source' };
  }
  const attrOf = (node, names) => {
    for (const name of names) {
      const value = node && node.getAttribute && node.getAttribute(name);
      if (value && normalize(value)) return normalize(value);
    }
    return '';
  };
  const textOf = (node) => normalize(
    node && (node.innerText || node.textContent) ? (node.innerText || node.textContent) : ''
  );
  const sourceIdOf = (node) => attrOf(node, [
    'data-conversation-id', 'data-chat-id', 'data-session-id', 'data-source-id',
    'data-group-id', 'data-room-id', 'data-circle-id', 'data-topic-id',
    'data-category-id', 'data-id'
  ]);
  const sourceNodes = Array.from(document.querySelectorAll(
    '[data-conversation-id],[data-chat-id],[data-session-id],'
    + '[data-source-id],[data-group-id],[data-room-id],[data-circle-id],'
    + '[data-topic-id],[data-category-id],[role="tab"],[role="menuitem"],'
    + '[role="listitem"],button,a,[class*="conversation"],[class*="session"],'
    + '[class*="chat"],[class*="group"],[class*="room"],[class*="circle"],'
    + '[class*="topic"],[class*="category"],[class*="nav"],[class*="menu"],'
    + '[class*="tab"]'
  )).slice(0, 240);
  const matches = (node) => {
    const id = sourceIdOf(node);
    if (wantedId && id && id === wantedId) return true;
    if (wantedId && wantedId.startsWith('fallback:')) {
      const fallbackName = wantedId.slice('fallback:'.length);
      if (fallbackName && textOf(node).split(/[：:\\n]/)[0] === fallbackName) return true;
    }
    if (!wantedName) return false;
    const text = textOf(node);
    if (!text) return false;
    return text === wantedName || text.split(/[：:\\n]/)[0] === wantedName;
  };
  const target = sourceNodes.find(matches);
  if (!target) {
    return { handled: false, reason: 'configured-source-not-visible' };
  }
  try {
    target.scrollIntoView({ block: 'center', inline: 'nearest', behavior: 'auto' });
  } catch (_) {}
  for (const type of ['pointerdown', 'mousedown', 'mouseup', 'click']) {
    target.dispatchEvent(new MouseEvent(type, {
      bubbles: true,
      cancelable: true,
      view: window
    }));
  }
  return {
    handled: true,
    reason: 'configured-source-click',
    conversation_id: wantedId,
    conversation_name: wantedName
  };
})();
''';
}
