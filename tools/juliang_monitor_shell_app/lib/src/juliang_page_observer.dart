const String juliangPageObserverScript = r'''
(() => {
  const stateKey = '__wukongJuliangMonitorObserver';
  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  const notify = (reason) => post({
    type: 'juliang_monitor_page_changed',
    reason,
    observed_at: new Date().toISOString()
  });
  const existing = window[stateKey];
  if (existing && existing.installed) {
    return { installed: true, reused: true };
  }
  const observer = new MutationObserver(() => notify('mutation'));
  observer.observe(document.documentElement || document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });
  window[stateKey] = {
    installed: true,
    disconnect: () => observer.disconnect()
  };
  notify('installed');
  return { installed: true, reused: false };
})();
''';

const String juliangPageProbeScript = r'''
(() => {
  const observedAt = new Date().toISOString();
  const textOf = (node, max = 2000) => String(
    (node && (node.innerText || node.textContent)) || ''
  ).replace(/\s+/g, ' ').trim().slice(0, max);
  const attrOf = (node, names) => {
    for (const name of names) {
      const value = node && node.getAttribute && node.getAttribute(name);
      if (value && String(value).trim()) return String(value).trim();
    }
    return '';
  };
  const stableHash = (value) => {
    let hash = 0x811c9dc5;
    const text = String(value || '');
    for (let index = 0; index < text.length; index += 1) {
      hash ^= text.charCodeAt(index);
      hash = Math.imul(hash, 0x01000193);
    }
    return (hash >>> 0).toString(16);
  };
  const isVisibleElement = (node) => {
    if (!node || !node.getBoundingClientRect) return false;
    const rect = node.getBoundingClientRect();
    if (rect.width < 1 || rect.height < 1) return false;
    const style = window.getComputedStyle ? window.getComputedStyle(node) : null;
    if (!style) return true;
    return style.display !== 'none'
      && style.visibility !== 'hidden'
      && Number(style.opacity || 1) !== 0;
  };
  const likelySourceName = (value) => {
    const text = String(value || '').replace(/\s+/g, ' ').trim();
    if (text.length < 2 || text.length > 80) return '';
    if (/^(搜索|登录|退出|确定|取消|发送|暂无数据|加载中|更多)$/.test(text)) return '';
    return text;
  };
  const sourceNodes = Array.from(document.querySelectorAll(
    'ul.MuiList-root li.MuiListItem-root,'
    + 'div.MuiListItemButton-root,'
    + '[role="button"].MuiListItemButton-root,'
    + '[data-conversation-id],[data-session-id],[data-source-id]'
  )).slice(0, 120);
  const sourceCandidates = [];
  const seenSources = new Set();
  for (const node of sourceNodes) {
    const lines = String((node.innerText || node.textContent) || '')
      .split(/\n+/)
      .map((line) => likelySourceName(line))
      .filter(Boolean);
    const name = lines[0] || likelySourceName(textOf(node, 120));
    if (!name) continue;
    const id = attrOf(node, [
      'data-conversation-id',
      'data-session-id',
      'data-source-id',
      'data-id',
      'data-key'
    ]) || `fallback:${name}`;
    const key = `${id}\n${name}`;
    if (seenSources.has(key)) continue;
    seenSources.add(key);
    sourceCandidates.push({
      id,
      name,
      type: 'unknown',
      last_message_preview: lines.length > 1 ? lines.slice(1).join(' ') : ''
    });
  }

  const activeSource =
    sourceCandidates[0] || { id: '', name: document.title || 'Juliang', type: 'unknown' };
  const messageNodes = Array.from(document.querySelectorAll(
    '[data-message-id],[data-msg-id],'
    + '[role="article"],'
    + '[class*="message"],[class*="Message"],[class*="msg"],[class*="Msg"]'
  )).slice(-80);
  const events = [];
  const seenEvents = new Set();
  for (const node of messageNodes) {
    if (!isVisibleElement(node)) continue;
    const text = textOf(node, 1600);
    if (!text || text.length < 1 || text.length > 1200) continue;
    const childCount = node.children ? node.children.length : 0;
    if (childCount > 20) continue;
    const formControlCount = node.querySelectorAll
      ? node.querySelectorAll('input,textarea,button,select,a[href]').length
      : 0;
    if (formControlCount > 2) continue;
    const messageId = attrOf(node, ['data-message-id', 'data-msg-id', 'data-id'])
      || `dom:${stableHash([
        activeSource.id || activeSource.name || '',
        text
      ].join(':'))}`;
    const conversationId = attrOf(node, [
      'data-conversation-id',
      'data-session-id',
      'data-source-id'
    ]) || activeSource.id || '';
    const conversationName = activeSource.name || document.title || 'Juliang';
    const key = `${conversationId || conversationName}:${messageId}`;
    if (seenEvents.has(key)) continue;
    seenEvents.add(key);
    events.push({
      event_id: key,
      dedupe_key: key,
      conversation_id: conversationId,
      conversation_name: conversationName,
      conversation_type: activeSource.type || 'unknown',
      message_id: messageId,
      sender_name: '',
      message_type: 'text',
      text,
      observed_at: observedAt,
      capture_source: 'dom_probe'
    });
  }

  const bodyText = textOf(document.body || document.documentElement, 5000);
  return {
    runtime_url: window.location.href,
    page_title: document.title || '',
    body_text: bodyText,
    has_forwardable_content: sourceCandidates.length > 0 || events.length > 0,
    source_candidates: sourceCandidates,
    events,
    observed_at: observedAt,
    probe_diagnostics: {
      source_candidate_count: sourceCandidates.length,
      event_count: events.length
    }
  };
})();
''';

class JuliangPageObserverMessage {
  const JuliangPageObserverMessage({
    required this.type,
    required this.reason,
    required this.observedAt,
  });

  final String type;
  final String reason;
  final DateTime? observedAt;

  bool get isPageChanged => type == 'juliang_monitor_page_changed';

  factory JuliangPageObserverMessage.fromJson(Map<String, Object?> json) {
    return JuliangPageObserverMessage(
      type: (json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      observedAt: DateTime.tryParse((json['observed_at'] ?? '').toString()),
    );
  }
}
