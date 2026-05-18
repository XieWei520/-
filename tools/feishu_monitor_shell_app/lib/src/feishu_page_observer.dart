import 'feishu_browser_image_body_cache.dart';
import 'feishu_network_capture.dart';

const String feishuPageKeepAliveScript = r'''
(() => {
  const keepAliveKey = '__wukongFeishuMonitorKeepAlive';
  const existingKeepAlive = window[keepAliveKey];
  if (
    existingKeepAlive &&
    existingKeepAlive.installed &&
    existingKeepAlive.version === 2 &&
    existingKeepAlive.interval_ms === 5000
  ) {
    return existingKeepAlive;
  }
  if (existingKeepAlive && existingKeepAlive.timer) {
    try {
      clearInterval(existingKeepAlive.timer);
    } catch (_) {}
  }
  const state = {
    installed: true,
    version: 2,
    installed_at: new Date().toISOString(),
    interval_ms: 5000,
    tick_count: 0,
    last_tick_at: ''
  };
  try {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      get: () => false
    });
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      get: () => 'visible'
    });
    if (typeof document.hasFocus === 'function') {
      document.hasFocus = () => true;
    }
    Object.defineProperty(navigator, 'onLine', {
      configurable: true,
      get: () => true
    });
  } catch (_) {}
  const tick = () => {
    state.tick_count += 1;
    state.last_tick_at = new Date().toISOString();
    for (const eventName of [
      'visibilitychange',
      'focus',
      'focusin',
      'pageshow',
      'online',
      'resume'
    ]) {
      try {
        const event = new Event(eventName);
        window.dispatchEvent(event);
        document.dispatchEvent(new Event(eventName));
        document.body?.dispatchEvent(new Event(eventName));
      } catch (_) {}
    }
  };
  tick();
  state.timer = setInterval(tick, state.interval_ms);
  state.disconnect = () => {
    try {
      clearInterval(state.timer);
    } catch (_) {}
    state.installed = false;
  };
  window[keepAliveKey] = state;
  return state;
})();
''';

const String feishuPageObserverScript = r'''
(() => {
  const stateKey = '__wukongFeishuMonitorObserver';
  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  const keepAlive = window.__wukongFeishuMonitorKeepAlive || {};
  const selectors = [
    '.lark_feedMainList',
    '.feed-main-list',
    '.a11y_feed_main_list',
    '.scroller.feed-main-list',
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main'
  ];
  const feedMutationSelectors = [
    '.lark_feedMainList',
    '.feed-main-list',
    '.a11y_feed_main_list',
    '.a11y_feed_card_item',
    '.a11y_feed_card_main'
  ];
  const findRoot = () => {
    for (const selector of selectors) {
      const node = document.querySelector(selector);
      if (node) {
        return node.closest('.lark_feedMainList') || node;
      }
    }
    return document.body;
  };
  const root = findRoot();
  const isBodyFallback = root === document.body;
  const existing = window[stateKey];
  if (existing && existing.installed) {
    const canReuse =
      existing.root_node &&
      existing.root_node.isConnected &&
      existing.root_node === root &&
      (!existing.body_fallback || isBodyFallback);
    if (canReuse) {
      return {
        installed: true,
        reused: true,
        body_fallback: !!existing.body_fallback,
        keep_alive: {
          installed: !!keepAlive.installed,
          tick_count: keepAlive.tick_count || 0,
          last_tick_at: keepAlive.last_tick_at || ''
        }
      };
    }
    try {
      existing.disconnect();
    } catch (_) {}
  }
  let timer = 0;
  let firstObservedAt = 0;
  const notify = (reason) => {
    const now = Date.now();
    if (!firstObservedAt) {
      firstObservedAt = now;
    }
    if (timer) {
      clearTimeout(timer);
    }
    const elapsed = now - firstObservedAt;
    const delay = elapsed >= 800 ? 0 : 150;
    timer = setTimeout(() => {
      timer = 0;
      firstObservedAt = 0;
      post({
        type: 'feishu_monitor_feed_changed',
        reason,
        observed_at: new Date().toISOString()
      });
    }, delay);
  };
  const isRelevantMutation = (mutation) => {
    const nodes = [];
    if (mutation.target) {
      nodes.push(mutation.target);
    }
    for (const node of Array.from(mutation.addedNodes || [])) {
      nodes.push(node);
    }
    for (const node of Array.from(mutation.removedNodes || [])) {
      nodes.push(node);
    }
    return nodes.some((node) => {
      if (!node || node.nodeType !== 1) {
        return false;
      }
      for (const selector of feedMutationSelectors) {
        if (node.matches?.(selector) || node.closest?.(selector)) {
          return true;
        }
      }
      return false;
    });
  };
  const observer = new MutationObserver((mutations) => {
    if (!mutations || mutations.length === 0) {
      return;
    }
    if (!isBodyFallback && !mutations.some(isRelevantMutation)) {
      return;
    }
    notify('mutation');
  });
  observer.observe(root, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
    attributeFilter: ['data-feed-active', 'aria-label', 'class']
  });
  window[stateKey] = {
    installed: true,
    installed_at: new Date().toISOString(),
    body_fallback: isBodyFallback,
    root_node: root,
    root: root.tagName || '',
    disconnect: () => observer.disconnect()
  };
  post({
    type: 'feishu_monitor_observer_installed',
    reason: 'installed',
    observed_at: new Date().toISOString(),
    keep_alive: {
      installed: !!keepAlive.installed,
      tick_count: keepAlive.tick_count || 0,
      last_tick_at: keepAlive.last_tick_at || ''
    }
  });
  return {
    installed: true,
    reused: false,
    body_fallback: isBodyFallback,
    root: root.tagName || '',
    keep_alive: {
      installed: !!keepAlive.installed,
      tick_count: keepAlive.tick_count || 0,
      last_tick_at: keepAlive.last_tick_at || ''
    }
  };
})();
''';

const String feishuNetworkImageAttributionScript = r'''
(() => {
  const stateKey = '__wukongFeishuNetworkImageAttribution';
  const existing = window[stateKey];
  if (existing && existing.installed) {
    return {
      installed: true,
      reused: true,
      object_url_count: existing.object_urls ? existing.object_urls.size : 0
    };
  }

  const cap = (value, limit = 240) => {
    const text = (value == null ? '' : String(value)).replace(/\s+/g, ' ').trim();
    return text.length > limit ? text.slice(0, limit) : text;
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

  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };

  const state = {
    installed: true,
    installed_at: new Date().toISOString(),
    object_urls: new Map(),
    observed_sources: new Set(),
    observer: null,
    original_create_object_url: URL.createObjectURL
  };

  const feedSelectors = [
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main',
    '.scroller.feed-main-list .a11y_feed_card_item',
    '.scroller.feed-main-list .a11y_feed_card_main'
  ];

  const findFeedCard = (node) => {
    if (!node || !node.closest) {
      return null;
    }
    for (const selector of feedSelectors) {
      const card = node.closest(selector);
      if (card) {
        return card;
      }
    }
    return null;
  };

  const activeFeedCard = () => {
    for (const selector of feedSelectors) {
      const card = document.querySelector(`${selector}[data-feed-active="true"]`);
      if (card) {
        return card;
      }
    }
    return null;
  };

  const feedCardId = (card) =>
    cap(
      card?.getAttribute?.('data-feed-id') ||
      card?.getAttribute?.('data-id') ||
      card?.getAttribute?.('data-key') ||
      card?.id ||
      '',
      120
    );

  const parseFeedText = (text) => {
    const clean = cap(text, 500);
    const timeMatch = clean.match(/(?:^|\s)(\d{1,2}:\d{2}|昨天|前天|\d{1,2}月\d{1,2}日|周[一二三四五六日天]|星期[一二三四五六日天])(?:\s|$)/);
    const colonIndex = clean.indexOf(':', timeMatch ? timeMatch.index + timeMatch[0].length : 0);
    const displayTime = timeMatch ? timeMatch[1] : '';
    let conversationName = '';
    let senderName = '';
    let messageText = clean;
    if (timeMatch) {
      conversationName = cap(clean.slice(0, timeMatch.index), 120);
      const afterTime = clean.slice(timeMatch.index + timeMatch[0].length).trim();
      const splitIndex = afterTime.indexOf(':');
      if (splitIndex >= 0) {
        senderName = cap(afterTime.slice(0, splitIndex), 80);
        messageText = cap(afterTime.slice(splitIndex + 1), 240);
      } else {
        messageText = cap(afterTime, 240);
      }
    } else if (colonIndex >= 0) {
      conversationName = cap(clean.slice(0, colonIndex), 120);
      messageText = cap(clean.slice(colonIndex + 1), 240);
    }
    return { conversationName, senderName, displayTime, messageText };
  };

  const sourceKind = (sourceUrl) => {
    if (sourceUrl.startsWith('blob:')) {
      return 'blob';
    }
    if (sourceUrl.startsWith('data:')) {
      return 'data';
    }
    return 'url';
  };

  const postAttribution = (sourceUrl, reason, node, evidence) => {
    if (!sourceUrl || state.observed_sources.has(sourceUrl)) {
      return;
    }
    state.observed_sources.add(sourceUrl);

    const card = findFeedCard(node);
    const fallbackCard = card || activeFeedCard();
    const attributionCard = card || fallbackCard;
    const feedCardText = card ? cap(card.innerText || card.textContent || '', 500) : '';
    const activeFeedCardText = !card && fallbackCard
      ? cap(fallbackCard.innerText || fallbackCard.textContent || '', 500)
      : '';
    const contextText = feedCardText || activeFeedCardText;
    const parsed = parseFeedText(contextText);
    const blobInfo = state.object_urls.get(sourceUrl) || {};
    const hasFeedContext = !!feedCardText;
    const hasActiveFeedContext = !!activeFeedCardText;
    if (!hasFeedContext && !hasActiveFeedContext) {
      return;
    }
    const confidence = hasFeedContext ? 0.92 : hasActiveFeedContext ? 0.72 : 0.5;
    const confidenceLabel = hasFeedContext ? 'high' : hasActiveFeedContext ? 'medium' : 'low';
    const nextEvidence = evidence.slice(0, 6);
    if (hasActiveFeedContext && !nextEvidence.includes('active_feed_context')) {
      nextEvidence.push('active_feed_context');
    }
    const feedIdentity = feedCardId(attributionCard) || stableHash(contextText);

    post({
      type: 'feishu_monitor_image_attribution',
      source_url: sourceUrl,
      source_kind: sourceKind(sourceUrl),
      blob_mime_type: blobInfo.mime_type || '',
      blob_size: blobInfo.size || 0,
      conversation_id: feedIdentity ? `feed:${feedIdentity}` : '',
      conversation_name: parsed.conversationName,
      message_id: cap(node?.closest?.('[data-message-id],[data-msg-id]')?.getAttribute('data-message-id') ||
          node?.closest?.('[data-message-id],[data-msg-id]')?.getAttribute('data-msg-id') || '', 120),
      sender_name: parsed.senderName,
      display_time: parsed.displayTime,
      message_text: parsed.messageText,
      feed_card_id: feedIdentity,
      feed_card_text: contextText,
      confidence,
      confidence_label: confidenceLabel,
      reason,
      observed_at: new Date().toISOString(),
      evidence: nextEvidence
    });
  };

  const inspectImageNode = (node) => {
    if (!node || node.nodeType !== 1) {
      return;
    }
    if (node.tagName === 'IMG') {
      const src = node.currentSrc || node.src || node.getAttribute('src') || '';
      if (src) {
        postAttribution(src, 'dom_img_src', node, ['exact_dom_node', 'feed_card_context']);
      }
    }
    const background = window.getComputedStyle(node).backgroundImage || '';
    const match = background.match(/url\(["']?([^"')]+)["']?\)/);
    if (match && match[1]) {
      postAttribution(match[1], 'dom_background_image', node, [
        'background_style',
        'feed_card_context'
      ]);
    }
  };

  const scan = (root = document) => {
    try {
      if (root.querySelectorAll) {
        for (const node of root.querySelectorAll('img,[style*="background"]')) {
          inspectImageNode(node);
        }
      }
      if (root.matches && (root.matches('img') || root.matches('[style*="background"]'))) {
        inspectImageNode(root);
      }
    } catch (_) {}
  };

  URL.createObjectURL = function(object) {
    const url = state.original_create_object_url.call(URL, object);
    try {
      const isImage = object && typeof object.type === 'string' && object.type.startsWith('image/');
      if (isImage) {
        state.object_urls.set(url, {
          mime_type: object.type || '',
          size: Number(object.size || 0)
        });
      }
    } catch (_) {}
    return url;
  };

  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations || []) {
      if (mutation.type === 'attributes') {
        inspectImageNode(mutation.target);
      }
      for (const node of Array.from(mutation.addedNodes || [])) {
        scan(node);
      }
    }
  });
  observer.observe(document.documentElement || document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['src', 'style', 'class']
  });
  state.observer = observer;
  state.disconnect = () => {
    try {
      observer.disconnect();
    } catch (_) {}
    try {
      URL.createObjectURL = state.original_create_object_url;
    } catch (_) {}
    state.installed = false;
  };
  window[stateKey] = state;
  scan(document);
  return {
    installed: true,
    reused: false,
    object_url_count: state.object_urls.size
  };
})();
''';

class FeishuPageObserverMessage {
  const FeishuPageObserverMessage({
    required this.type,
    required this.reason,
    required this.observedAt,
    this.imageAttribution,
    this.browserImageBody,
  });

  final String type;
  final String reason;
  final DateTime? observedAt;
  final FeishuNetworkImageAttribution? imageAttribution;
  final FeishuBrowserImageBody? browserImageBody;

  bool get isFeedChanged => type == 'feishu_monitor_feed_changed';
  bool get isMediaResolved => type == 'feishu_monitor_media_resolved';
  bool get isObserverInstalled => type == 'feishu_monitor_observer_installed';
  bool get isImageAttribution => imageAttribution != null;
  bool get isBrowserImageBody => browserImageBody != null;
  bool get isStorageProbe => type == 'feishu_monitor_storage_probe';

  factory FeishuPageObserverMessage.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    return FeishuPageObserverMessage(
      type: type,
      reason: (json['reason'] ?? '').toString(),
      observedAt: DateTime.tryParse((json['observed_at'] ?? '').toString()),
      imageAttribution: type == 'feishu_monitor_image_attribution'
          ? FeishuNetworkImageAttribution.fromJson(json)
          : null,
      browserImageBody: type == 'feishu_monitor_browser_image_body'
          ? FeishuBrowserImageBody.fromJson(json)
          : null,
    );
  }
}
