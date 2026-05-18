import 'package:feishu_monitor_shell/feishu_monitor_shell.dart';

const String feishuPageProbeScript = r'''
(() => {
  const observedAt = new Date().toISOString();
  const href = window.location?.href || '';
  const title = document.title || '';
  const bodyText = document.body?.innerText || '';
  const dataUrlCacheKey = '__wukongFeishuMonitorImageDataUrls';
  window[dataUrlCacheKey] = window[dataUrlCacheKey] || {};
  const postProbeMessage = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  const blobToDataUrl = async (sourceUrl) => {
    if (!sourceUrl || !String(sourceUrl).startsWith('blob:')) {
      return '';
    }
    if (window[dataUrlCacheKey][sourceUrl]) {
      return window[dataUrlCacheKey][sourceUrl];
    }
    try {
      const response = await fetch(sourceUrl);
      const blob = await response.blob();
      if (!blob || !String(blob.type || '').startsWith('image/')) {
        return '';
      }
      const dataUrl = await new Promise((resolve, reject) => {
        const reader = new FileReader();
        reader.onloadend = () => resolve(String(reader.result || ''));
        reader.onerror = () => reject(reader.error || new Error('readAsDataURL failed'));
        reader.readAsDataURL(blob);
      });
      if (dataUrl.startsWith('data:image/')) {
        window[dataUrlCacheKey][sourceUrl] = dataUrl;
        postProbeMessage({
          type: 'feishu_monitor_media_resolved',
          reason: 'blob_to_data_url',
          observed_at: new Date().toISOString()
        });
        return dataUrl;
      }
    } catch (_) {}
    return '';
  };
  const resolveImageAttachment = (attachment) => {
    if (!attachment) {
      return attachment;
    }
    const sourceUrl = String(attachment.source_url || '');
    if (!sourceUrl.startsWith('blob:')) {
      return attachment;
    }
    const cachedDataUrl = window[dataUrlCacheKey][sourceUrl] || '';
    if (cachedDataUrl) {
      return { ...attachment, source_url: cachedDataUrl };
    }
    blobToDataUrl(sourceUrl);
    return attachment;
  };
  const trimText = (value, max = 260) => {
    const text = String(value || '').replace(/\s+/g, ' ').trim();
    return text.length > max ? text.slice(0, max) : text;
  };
  const describeNode = (node) => {
    const attrs = {};
    for (const attr of Array.from(node.attributes || [])) {
      if (
        attr.name === 'id' ||
        attr.name === 'role' ||
        attr.name.startsWith('data-') ||
        attr.name === 'aria-label'
      ) {
        attrs[attr.name] = attr.value;
      }
    }
    return {
      tag: (node.tagName || '').toLowerCase(),
      id: node.id || '',
      role: node.getAttribute('role') || '',
      class_name: String(node.className || '').slice(0, 180),
      attrs,
      text: trimText(node.innerText || node.textContent || '', 360),
      child_count: node.children ? node.children.length : 0
    };
  };
  const imageAttachmentFromNode = (img) => {
    const sourceUrl =
      img.currentSrc ||
      img.src ||
      img.getAttribute('data-src') ||
      img.getAttribute('data-origin-src') ||
      img.getAttribute('data-url') ||
      '';
    if (!sourceUrl) {
      return null;
    }
    const normalizedUrl = String(sourceUrl).toLowerCase();
    const classContext = [
      img.className || '',
      img.parentElement?.className || '',
      img.closest?.(
        '.ud__avatar,.larkc-avatar,.larkw-avatar,[class*="avatar"],[class*="Avatar"]'
      ) ? 'avatar' : ''
    ].join(' ').toLowerCase();
    if (
      classContext.includes('avatar') ||
      normalizedUrl.includes('default-avatar')
    ) {
      return null;
    }
    return {
      source_url: sourceUrl,
      local_path: '',
      width: Number(img.naturalWidth || img.width || 0),
      height: Number(img.naturalHeight || img.height || 0)
    };
  };
  const backgroundImageUrlFromNode = (node) => {
    const backgroundImage = window.getComputedStyle?.(node)?.backgroundImage || '';
    const match = String(backgroundImage).match(/url\(["']?([^"')]+)["']?\)/);
    return match ? match[1] : '';
  };
  const imageAttachmentFromBackgroundNode = (node) => {
    const sourceUrl = backgroundImageUrlFromNode(node);
    if (!sourceUrl) {
      return null;
    }
    const normalizedUrl = String(sourceUrl).toLowerCase();
    const classContext = [
      node.className || '',
      node.parentElement?.className || '',
      node.closest?.(
        '.ud__avatar,.larkc-avatar,.larkw-avatar,[class*="avatar"],[class*="Avatar"]'
      ) ? 'avatar' : ''
    ].join(' ').toLowerCase();
    if (
      classContext.includes('avatar') ||
      normalizedUrl.includes('default-avatar') ||
      normalizedUrl.startsWith('data:image/svg')
    ) {
      return null;
    }
    const rect = node.getBoundingClientRect?.();
    return {
      source_url: sourceUrl,
      local_path: '',
      width: Number(rect?.width || 0),
      height: Number(rect?.height || 0)
    };
  };
  const collectImageAttachments = (node, max = 4) => {
    const seenImages = new Set();
    const attachments = [];
    const images = [
      ...(node.matches?.('img') ? [node] : []),
      ...Array.from(node.querySelectorAll('img'))
    ];
    for (const img of images) {
      const attachment = imageAttachmentFromNode(img);
      if (!attachment || seenImages.has(attachment.source_url)) {
        continue;
      }
      seenImages.add(attachment.source_url);
      attachments.push(resolveImageAttachment(attachment));
    if (attachments.length >= max) {
        break;
      }
    }
    const backgroundNodes = [
      ...(node.matches?.('[style*="background"]') ? [node] : []),
      ...Array.from(node.querySelectorAll('[style*="background"]'))
    ];
    for (const backgroundNode of backgroundNodes) {
      const attachment = imageAttachmentFromBackgroundNode(backgroundNode);
      if (!attachment || seenImages.has(attachment.source_url)) {
        continue;
      }
      seenImages.add(attachment.source_url);
      attachments.push(resolveImageAttachment(attachment));
      if (attachments.length >= max) {
        break;
      }
    }
    return attachments;
  };
  const hasExplicitMessageId = (node) =>
    Boolean(
      node.getAttribute('data-message-id') ||
      node.getAttribute('data-msg-id') ||
      node.matches?.('.js-message-item,.message-item') ||
      (node.id && /^\d{10,}$/.test(String(node.id)))
    );
  const closestMessageNode = (node) => {
    const closest = node.closest?.(
      '[data-message-id],[data-msg-id],.js-message-item,.message-item'
    );
    return closest || node;
  };
  const messageNodeId = (node) =>
    node.getAttribute('data-message-id') ||
    node.getAttribute('data-msg-id') ||
    node.getAttribute('data-id') ||
    node.getAttribute('id') ||
    '';
  const isLikelyShellContainer = (node, text) => {
    if (
      node.matches?.(
        'body,#app,.app-container,.app-shell-container,.appLayout,' +
        '.page-content-wrapper,.page-content-messenger,.messagesLayout,' +
        '.lark_feedMainList,.feed-main-list,.simplebar-content,' +
        '.simplebar-content-wrapper,.appNavbar,.navbarMenu'
      )
    ) {
      return true;
    }
    if (hasExplicitMessageId(node)) {
      return false;
    }
    const normalized = String(text || '').replace(/\s+/g, ' ').trim();
    if (normalized.length > 800) {
      return true;
    }
    if ((node.children?.length || 0) > 80) {
      return true;
    }
    const nestedMessageCount = Array.from(
      node.querySelectorAll('[data-message-id],[data-msg-id],.js-message-item,.message-item')
    ).filter((item) => item !== node).length;
    return nestedMessageCount > 0;
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
  const activeFeedConversation = (() => {
    const activeNode = document.querySelector(
      '.lark_feedMainList .a11y_feed_card_item[data-feed-active="true"],' +
      '.lark_feedMainList .a11y_feed_card_main[data-feed-active="true"],' +
      '.scroller.feed-main-list .a11y_feed_card_item[data-feed-active="true"],' +
      '.scroller.feed-main-list .a11y_feed_card_main[data-feed-active="true"]'
    );
    if (!activeNode) {
      return null;
    }
    const lines = (activeNode.innerText || '')
      .split('\n')
      .map((item) => item.trim())
      .filter(Boolean);
    const name = lines[0] || '';
    if (!name) {
      return null;
    }
    const rawId =
      activeNode.getAttribute('data-id') ||
      activeNode.getAttribute('data-feed-id') ||
      activeNode.getAttribute('data-key') ||
      '';
    return {
      id: rawId || `feed:${stableHash(name)}`,
      name
    };
  })();

  const selectors = [
    '[data-testid*="conversation"]',
    '[data-testid*="chat"]',
    '[class*="conversation"]',
    '[class*="chat-item"]',
    '[role="listitem"]'
  ];

  const seen = new Set();
  const observedConversations = [];
  const observedMessages = [];
  const feedCards = [];

  for (const selector of selectors) {
    const nodes = Array.from(document.querySelectorAll(selector));
    for (const node of nodes) {
      const lines = (node.innerText || '')
        .split('\n')
        .map((item) => item.trim())
        .filter(Boolean);
      if (lines.length === 0) {
        continue;
      }

      const id =
        node.getAttribute('data-id') ||
        node.getAttribute('data-row-key') ||
        node.getAttribute('data-conversation-id') ||
        lines[0];
      if (!id || seen.has(id)) {
        continue;
      }

      seen.add(id);
      observedConversations.push({
        id,
        name: lines[0],
        type: 'group',
        last_message_preview: lines.length > 1 ? lines[1] : '',
        observed_at: observedAt
      });

      if (observedConversations.length >= 12) {
        break;
      }
    }

    if (observedConversations.length >= 12) {
      break;
    }
  }

  const messageSelectors = [
    '.js-message-item',
    '.message-item',
    '.im-image-message',
    '[data-testid*="message"]',
    '[data-message-id]',
    '[data-msg-id]',
    '[class*="message"]',
    '[class*="msg"]',
    '[role="listitem"]'
  ];

  const seenMessages = new Set();
  const selectorHits = [];
  const messageNodeSamples = [];
  for (const selector of messageSelectors) {
    const nodes = Array.from(document.querySelectorAll(selector));
    selectorHits.push({ selector, count: nodes.length });
    if (messageNodeSamples.length < 16) {
      for (const node of nodes.slice(0, 4)) {
        messageNodeSamples.push({
          selector,
          node: describeNode(node)
        });
      }
    }
    for (const node of nodes) {
      const messageNode = closestMessageNode(node);
      const text = (messageNode.innerText || '').trim();
      const imageAttachments = collectImageAttachments(messageNode);
      if (!text && imageAttachments.length === 0) {
        continue;
      }
      if (isLikelyShellContainer(messageNode, text)) {
        continue;
      }

      const imageSourceKey = imageAttachments
        .map((item) => item.source_url || item.local_path || '')
        .filter(Boolean)
        .join('|');
      const id =
        messageNodeId(messageNode) ||
        `dom:${stableHash([
          activeFeedConversation?.id || '',
          text,
          imageSourceKey
        ].join(':'))}`;
      if (!id || seenMessages.has(id)) {
        continue;
      }

      seenMessages.add(id);
      const conversationNode = messageNode.closest(
        '[data-conversation-id],[data-chat-id],[data-id]'
      );
      observedMessages.push({
        id,
        conversation_id:
          conversationNode?.getAttribute('data-conversation-id') ||
          conversationNode?.getAttribute('data-chat-id') ||
          activeFeedConversation?.id ||
          '',
        conversation_name: activeFeedConversation?.name || '',
        sender_name:
          messageNode.getAttribute('data-sender-name') ||
          messageNode.querySelector('[class*="sender"],[class*="author"]')?.innerText?.trim() ||
          '',
        message_type: imageAttachments.length > 0 ? 'image' : 'text',
        text: text || '[图片]',
        observed_at: observedAt,
        capture_source: 'dom_probe',
        image_attachments: imageAttachments
      });

      if (observedMessages.length >= 20) {
        break;
      }
    }

    if (observedMessages.length >= 20) {
      break;
    }
  }

  const feedCardSelectors = [
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main',
    '.scroller.feed-main-list .a11y_feed_card_item',
    '.scroller.feed-main-list .a11y_feed_card_main'
  ];
  const feedCardSelectorHits = [];
  const feedCardSamples = [];
  const seenFeedCards = new Set();
  for (const selector of feedCardSelectors) {
    const nodes = Array.from(document.querySelectorAll(selector));
    feedCardSelectorHits.push({ selector, count: nodes.length });
    for (const node of nodes) {
      const text = trimText(node.innerText || node.textContent || '', 900);
      if (!text || text.length < 2) {
        continue;
      }
      const rawId =
        node.getAttribute('data-id') ||
        node.getAttribute('data-feed-id') ||
        node.getAttribute('data-key') ||
        '';
      const id = rawId || `${selector}:${text.slice(0, 80)}`;
      if (seenFeedCards.has(id)) {
        continue;
      }
      seenFeedCards.add(id);
      const card = {
        id,
        text,
        selector,
        attrs: describeNode(node).attrs,
        image_attachments: collectImageAttachments(node)
      };
      feedCards.push(card);
      if (feedCardSamples.length < 12) {
        feedCardSamples.push(card);
      }
      if (feedCards.length >= 30) {
        break;
      }
    }
    if (feedCards.length >= 30) {
      break;
    }
  }

  const leafTextSamples = Array.from(document.querySelectorAll('div,span,p'))
    .filter((node) => {
      const text = trimText(node.innerText || node.textContent || '', 260);
      return text.length >= 2 && text.length <= 260 && node.children.length <= 3;
    })
    .slice(0, 80)
    .map((node) => describeNode(node));

  const mediaNodeSamples = Array.from(
    document.querySelectorAll(
      'img,[style*="background"],[class*="image"],[class*="Image"],' +
      '[class*="media"],[class*="Media"],[class*="photo"],[class*="Photo"]'
    )
  )
    .slice(0, 80)
    .map((node) => ({
      ...describeNode(node),
      src:
        node.currentSrc ||
        node.src ||
        node.getAttribute?.('data-src') ||
        node.getAttribute?.('data-origin-src') ||
        node.getAttribute?.('data-url') ||
        '',
      background_image: backgroundImageUrlFromNode(node)
    }));

  const topFeedCardSummaries = feedCardSamples.slice(0, 8).map((card) => ({
    id: card.id || '',
    text: card.text || '',
    active: card.attrs?.['data-feed-active'] === 'true',
    image_count: Array.isArray(card.image_attachments)
      ? card.image_attachments.length
      : 0
  }));
  const feedContentSignature = stableHash(
    topFeedCardSummaries.map((card) => card.text || '').join('|')
  );
  const latestMessageSummaries = observedMessages.slice(0, 8).map((message) => ({
    id: message.id || '',
    conversation_id: message.conversation_id || '',
    conversation_name: message.conversation_name || '',
    sender_name: message.sender_name || '',
    message_type: message.message_type || '',
    text: message.text || '',
    image_count: Array.isArray(message.image_attachments)
      ? message.image_attachments.length
      : 0
  }));

  const classNameSamples = Array.from(document.querySelectorAll('[class]'))
    .map((node) => String(node.className || ''))
    .filter(Boolean)
    .slice(0, 300)
    .reduce((acc, className) => {
      for (const part of className.split(/\s+/).filter(Boolean)) {
        acc[part] = (acc[part] || 0) + 1;
      }
      return acc;
    }, {});

  let pageKind = 'unknown';
  const normalizedHref = href.toLowerCase();
  const normalizedBody = bodyText.toLowerCase();
  if (
    normalizedHref.includes('login') ||
    normalizedHref.includes('passport') ||
    normalizedHref.includes('accounts') ||
    normalizedBody.includes('scan qr code')
  ) {
    pageKind = 'login';
  } else if (
    normalizedHref.includes('messenger') ||
    normalizedHref.includes('/im') ||
    observedConversations.length > 0
  ) {
    pageKind = 'messenger';
  }

  return {
    runtime_url: href,
    page_title: title,
    body_text: bodyText.slice(0, 2000),
    page_kind: pageKind,
    observed_at: observedAt,
    probe_diagnostics: {
      selector_hits: selectorHits,
      message_node_samples: messageNodeSamples,
      feed_card_selector_hits: feedCardSelectorHits,
      feed_card_samples: feedCardSamples,
      top_feed_card_summaries: topFeedCardSummaries,
      feed_card_count: feedCards.length,
      feed_content_signature: feedContentSignature,
      latest_message_summaries: latestMessageSummaries,
      leaf_text_samples: leafTextSamples,
      media_node_samples: mediaNodeSamples,
      class_name_samples: classNameSamples
    },
    observed_conversations: observedConversations,
    observed_messages: observedMessages,
    feed_cards: feedCards
  };
})();
''';

const String feishuStorageProbeScript = r'''
(() => {
  const stateKey = '__wukongFeishuStorageProbe';
  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  const nowIso = () => new Date().toISOString();
  const maxSamples = 40;
  const totalRecordBudget = 240;
  const interestingTokens = [
    'chat_id',
    'channel_id',
    'conversation_id',
    'download_url',
    'file_key',
    'image',
    'image_key',
    'media',
    'message_id',
    'msg_id',
    'origin_key',
    'origin_url',
    'preview_url',
    'resource_key',
    'sender_name',
    'static-resource'
  ];
  const imageTokens = [
    'download_url',
    'file_key',
    'image',
    'image_key',
    'media',
    'origin_key',
    'origin_url',
    'preview_url',
    'resource_key',
    'static-resource'
  ];
  const messageTokens = [
    'chat_id',
    'channel_id',
    'conversation_id',
    'message_id',
    'msg_id',
    'sender_name'
  ];
  const cap = (value, limit = 360) => {
    const text = (value == null ? '' : String(value)).replace(/\s+/g, ' ').trim();
    return text.length > limit ? text.slice(0, limit) : text;
  };
  const snippet = (value, tokens) => {
    const raw = cap(value, 1800);
    const lower = raw.toLowerCase();
    const windows = [];
    for (const token of tokens.slice(0, 4)) {
      const index = lower.indexOf(token);
      if (index < 0) {
        continue;
      }
      const start = Math.max(0, index - 80);
      const end = Math.min(raw.length, index + token.length + 120);
      windows.push(raw.slice(start, end));
    }
    return cap(windows.join(' ... '), 720);
  };
  const redact = (value, tokens = []) => {
    let text = snippet(value, tokens);
    text = text.replace(
      /("?(?:access_token|authorization|cookie|credential|csrf|file_key|from_name|image_key|jwt|name|origin_key|resource_key|sender_name|session|sign|signature|token)"?\s*[:=]\s*)("[^"]+"|[^\s,;}\]]+)/gi,
      '$1<redacted>'
    );
    text = text.replace(
      /\b(chat_id|channel_id|conversation_id|message_id|msg_id)\b\s*[:=]\s*([A-Za-z0-9._~/-]+)/gi,
      '$1=<redacted>'
    );
    text = text.replace(
      /\b(?:https?|blob|data):[^\s"'<>]+/gi,
      '<redacted_url>'
    );
    return text || '<redacted>';
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
  const tokensFor = (value) => {
    const lower = String(value || '').toLowerCase();
    return interestingTokens.filter((token) => lower.includes(token)).sort();
  };
  const fieldPathsFor = (value, prefix = '', paths = []) => {
    if (!value || typeof value !== 'object' || paths.length >= 24) {
      return paths;
    }
    if (Array.isArray(value)) {
      for (const item of value.slice(0, 3)) {
        fieldPathsFor(item, `${prefix}[]`, paths);
        if (paths.length >= 24) {
          break;
        }
      }
      return paths;
    }
    for (const key of Object.keys(value).slice(0, 24)) {
      const path = prefix ? `${prefix}.${key}` : key;
      const lower = path.toLowerCase();
      if (interestingTokens.some((token) => lower.includes(token))) {
        paths.push(path);
      }
      fieldPathsFor(value[key], path, paths);
      if (paths.length >= 24) {
        break;
      }
    }
    return paths;
  };
  const sampleFrom = (value) => {
    if (value == null) {
      return '';
    }
    if (typeof value === 'string') {
      return value;
    }
    try {
      return JSON.stringify(value);
    } catch (_) {
      return String(value);
    }
  };
  const pushSample = (samples, sample, seen, extra = {}) => {
    const raw = sampleFrom(sample);
    if (!raw) {
      return;
    }
    const tokens = tokensFor(raw);
    if (tokens.length === 0) {
      return;
    }
    const key = `${extra.scope || ''}:${tokens.join(',')}:${stableHash(raw)}`;
    if (seen.has(key)) {
      return;
    }
    seen.add(key);
    samples.push({
      ...extra,
      tokens,
      field_paths: fieldPathsFor(sample).slice(0, 12),
      sample_hash: stableHash(raw),
      sample: redact(raw, tokens)
    });
  };
  const requestToPromise = (request) =>
    new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error || new Error('indexeddb request failed'));
    });
  const transactionComplete = (transaction) =>
    new Promise((resolve) => {
      transaction.oncomplete = () => resolve();
      transaction.onabort = () => resolve();
      transaction.onerror = () => resolve();
    });
  const scanWebStorage = (storage, storageName, samples, seen) => {
    if (!storage) {
      return 0;
    }
    let count = 0;
    try {
      const length = Number(storage.length || 0);
      for (let index = 0; index < length && samples.length < maxSamples; index += 1) {
        const key = storage.key(index) || '';
        const value = storage.getItem(key) || '';
        count += 1;
        pushSample(samples, `${key} ${value}`, seen, {
          scope: storageName,
          kind: storageName,
          key_hash: stableHash(key),
          value_length: String(value).length
        });
      }
    } catch (_) {}
    return count;
  };
  const databaseNames = async () => {
    if (!window.indexedDB) {
      return [];
    }
    if (typeof indexedDB.databases === 'function') {
      try {
        const databases = await indexedDB.databases();
        return databases
          .map((database) => database && database.name ? String(database.name) : '')
          .filter(Boolean)
          .slice(0, 16);
      } catch (_) {}
    }
    return [];
  };
  const scanIndexedDb = async (samples, seen, errors) => {
    const names = await databaseNames();
    let storeCount = 0;
    let recordCount = 0;
    let recordBudgetUsed = 0;
    for (const name of names) {
      if (samples.length >= maxSamples || recordBudgetUsed >= totalRecordBudget) {
        break;
      }
      try {
        const db = await requestToPromise(indexedDB.open(name));
        try {
          const storeNames = Array.from(db.objectStoreNames || []).slice(0, 24);
          for (const storeName of storeNames) {
            if (samples.length >= maxSamples || recordBudgetUsed >= totalRecordBudget) {
              break;
            }
            storeCount += 1;
            try {
              const directionSamples = [
                { direction: 'next', limit: 8 },
                { direction: 'prev', limit: 8 }
              ];
              for (const directionSample of directionSamples) {
                if (samples.length >= maxSamples || recordBudgetUsed >= totalRecordBudget) {
                  break;
                }
                try {
                  const transaction = db.transaction(storeName, 'readonly');
                  const store = transaction.objectStore(storeName);
                  let cursorCount = 0;
                  await new Promise((resolve) => {
                    const request = store.openCursor(null, directionSample.direction);
                    request.onsuccess = () => {
                      const cursor = request.result;
                      if (
                        !cursor ||
                        cursorCount >= directionSample.limit ||
                        samples.length >= maxSamples
                      ) {
                        resolve();
                        return;
                      }
                      cursorCount += 1;
                      recordCount += 1;
                      recordBudgetUsed += 1;
                      pushSample(samples, { key: cursor.key, value: cursor.value }, seen, {
                        scope: `indexeddb:${stableHash(name)}:${stableHash(storeName)}`,
                        kind: 'indexeddb',
                        cursor_direction: directionSample.direction,
                        cursor_key_hash: stableHash(sampleFrom(cursor.key)),
                        database_name_hash: stableHash(name),
                        database_name_length: name.length,
                        store_name_hash: stableHash(storeName),
                        store_name_length: String(storeName).length
                      });
                      if (recordBudgetUsed >= totalRecordBudget) {
                        resolve();
                        return;
                      }
                      cursor.continue();
                    };
                    request.onerror = () => resolve();
                  });
                  await transactionComplete(transaction);
                } catch (error) {
                  errors.push({
                    kind: 'indexeddb_store_direction',
                    cursor_direction: directionSample.direction,
                    database_name_hash: stableHash(name),
                    database_name_length: name.length,
                    store_name_hash: stableHash(storeName),
                    store_name_length: String(storeName).length,
                    error: cap(error && error.message ? error.message : error, 160)
                  });
                }
              }
            } catch (error) {
              errors.push({
                kind: 'indexeddb_store',
                database_name_hash: stableHash(name),
                database_name_length: name.length,
                store_name_hash: stableHash(storeName),
                store_name_length: String(storeName).length,
                error: cap(error && error.message ? error.message : error, 160)
              });
            }
          }
        } finally {
          try {
            db.close();
          } catch (_) {}
        }
      } catch (error) {
        errors.push({
          kind: 'indexeddb_open',
          database_name_hash: stableHash(name),
          database_name_length: name.length,
          error: cap(error && error.message ? error.message : error, 160)
        });
      }
    }
    return {
      database_count: names.length,
      database_name_hashes: names.slice(0, 12).map(stableHash),
      indexeddb_store_count: storeCount,
      indexeddb_record_scan_count: recordCount,
      indexeddb_record_scan_budget: totalRecordBudget,
      indexeddb_record_budget_used: recordBudgetUsed
    };
  };
  const run = async () => {
    const existing = window[stateKey] || {};
    if (existing.running) {
      return {
        installed: true,
        reused: true,
        running: true,
        last_probe_at: existing.last_probe_at || ''
      };
    }
    if (
      existing.last_probe_epoch_ms &&
      Date.now() - Number(existing.last_probe_epoch_ms) < 120000
    ) {
      return {
        installed: true,
        reused: true,
        throttled: true,
        last_probe_at: existing.last_probe_at || ''
      };
    }
    const state = {
      installed: true,
      running: true,
      started_at: nowIso(),
      last_probe_at: existing.last_probe_at || '',
      last_probe_epoch_ms: Number(existing.last_probe_epoch_ms || 0),
      probe_count: Number(existing.probe_count || 0)
    };
    window[stateKey] = state;
    const samples = [];
    const seen = new Set();
    const errors = [];
    let webStorageCount = 0;
    try {
      webStorageCount += scanWebStorage(window.localStorage, 'localStorage', samples, seen);
      webStorageCount += scanWebStorage(window.sessionStorage, 'sessionStorage', samples, seen);
    } catch (_) {}
    let indexedDbSummary = {
      database_count: 0,
      database_name_hashes: [],
      indexeddb_store_count: 0,
      indexeddb_record_scan_count: 0,
      indexeddb_record_scan_budget: totalRecordBudget,
      indexeddb_record_budget_used: 0
    };
    try {
      indexedDbSummary = await scanIndexedDb(samples, seen, errors);
    } catch (error) {
      errors.push({
        kind: 'indexeddb_scan',
        error: cap(error && error.message ? error.message : error, 160)
      });
    }
    const tokenSet = new Set();
    for (const sample of samples) {
      for (const token of sample.tokens || []) {
        tokenSet.add(token);
      }
    }
    const tokens = Array.from(tokenSet).sort();
    const result = {
      type: 'feishu_monitor_storage_probe',
      kind: 'storage_probe',
      observed_at: nowIso(),
      ...indexedDbSummary,
      web_storage_item_count: webStorageCount,
      sample_count: samples.length,
      samples: samples.slice(0, 20),
      tokens,
      has_image_hint: tokens.some((token) => imageTokens.includes(token)),
      has_message_hint: tokens.some((token) => messageTokens.includes(token)),
      errors: errors.slice(0, 8)
    };
    state.running = false;
    state.last_probe_at = result.observed_at;
    state.last_probe_epoch_ms = Date.now();
    state.probe_count += 1;
    state.last_result = result;
    post(result);
    return {
      installed: true,
      reused: false,
      scheduled: true,
      observed_at: result.observed_at
    };
  };
  run();
  return {
    installed: true,
    reused: !!window[stateKey],
    scheduled: true,
    observed_at: nowIso()
  };
})();
''';

const String feishuOpenLatestMediaFeedScript = r'''
(() => {
  const pendingTarget = window.__wukongFeishuMonitorPendingMediaTarget || {};
  const pendingKey = String(pendingTarget.key || '').trim();
  const pendingText = String(pendingTarget.text || '').replace(/\s+/g, ' ').trim();
  const mediaPreviewTokens = [
    '[图片]',
    '[鍥剧墖]',
    '[Image]',
    '[Photo]'
  ];
  const clickNewestTip = () => {
    const newestTip = document.querySelector(
      '.messageTip__toNewestTip,' +
      '[class*="messageTip__toNewestTip"],' +
      '[class*="toNewestTip"]'
    );
    if (!newestTip) {
      return false;
    }
    newestTip.click();
    return true;
  };
  const selectors = [
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main',
    '.scroller.feed-main-list .a11y_feed_card_item',
    '.scroller.feed-main-list .a11y_feed_card_main'
  ];
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const cardId = (card) =>
    card.getAttribute('data-id') ||
    card.getAttribute('data-feed-id') ||
    card.getAttribute('data-key') ||
    '';
  const feedCardMatchesPendingTarget = (card, text) => {
    if (!pendingKey && !pendingText) {
      return true;
    }
    const id = cardId(card);
    if (pendingKey && id && id === pendingKey) {
      return true;
    }
    if (!pendingText) {
      return false;
    }
    const normalizedText = normalize(text);
    return normalizedText === pendingText || normalizedText.includes(pendingText);
  };
  let sawMediaCard = false;
  for (const selector of selectors) {
    const cards = Array.from(document.querySelectorAll(selector));
    for (const card of cards) {
      const text = normalize(card.innerText || card.textContent || '');
      if (!text || !mediaPreviewTokens.some((token) => text.includes(token))) {
        continue;
      }
      sawMediaCard = true;
      if (!feedCardMatchesPendingTarget(card, text)) {
        continue;
      }
      const active =
        card.getAttribute('data-feed-active') === 'true' ||
        card.closest?.('[data-feed-active="true"]');
      if (active) {
        const jumped = clickNewestTip();
        return {
          opened: jumped,
          reason: jumped ? 'jumped_active_media_feed_to_newest' : 'already_active',
          text,
          id: cardId(card)
        };
      }
      const target =
        card.querySelector?.('[role="button"],button,a') ||
        card.closest?.('.a11y_feed_card_item,.a11y_feed_card_main') ||
        card;
      target.scrollIntoView({ block: 'center', inline: 'nearest' });
      target.click();
      return {
        opened: true,
        reason: 'opened_media_feed',
        text,
        id: cardId(card)
      };
    }
  }
  return {
    opened: false,
    reason: sawMediaCard ? 'pending_media_feed_not_found' : 'not_found',
    pending_key: pendingKey,
    pending_text: pendingText
  };
})();
''';

const String feishuOpenLatestMediaPreviewScript = r'''
(() => {
  const stateKey = '__wukongFeishuMonitorMediaPreviewOpen';
  const state = window[stateKey] || {
    opened_keys: {},
    retry_ms: 8000
  };
  window[stateKey] = state;
  const now = Date.now();
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const visible = (node) => {
    if (!node || !node.getBoundingClientRect) {
      return false;
    }
    const rect = node.getBoundingClientRect();
    const style = window.getComputedStyle ? window.getComputedStyle(node) : null;
    return rect.width >= 40 &&
      rect.height >= 40 &&
      rect.bottom > 0 &&
      rect.right > 0 &&
      (!style || (style.visibility !== 'hidden' && style.display !== 'none'));
  };
  const imageSource = (img) =>
    img.currentSrc ||
    img.src ||
    img.getAttribute('data-src') ||
    img.getAttribute('data-origin-src') ||
    img.getAttribute('data-url') ||
    '';
  const hashString = (value) => {
    const text = String(value || '');
    let hash = 2166136261;
    for (let i = 0; i < text.length; i += 1) {
      hash ^= text.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16);
  };
  const isAvatarOrChrome = (img, sourceUrl) => {
    const lowerUrl = String(sourceUrl || '').toLowerCase();
    const classContext = [
      img.className || '',
      img.parentElement?.className || '',
      img.closest?.(
        '.ud__avatar,.larkc-avatar,.larkw-avatar,[class*="avatar"],[class*="Avatar"],' +
        '[class*="toolbar"],[class*="Toolbar"],[class*="icon"],[class*="Icon"]'
      ) ? 'avatar_or_chrome' : ''
    ].join(' ').toLowerCase();
    return classContext.includes('avatar') ||
      classContext.includes('toolbar') ||
      classContext.includes('icon') ||
      lowerUrl.includes('default-avatar') ||
      lowerUrl.startsWith('data:image/svg');
  };
  const messageImageSelectors = [
    '.js-message-item img',
    '.message-item img',
    '.im-image-message img',
    '[data-message-id] img',
    '[data-msg-id] img',
    '[class*="message"] img',
    '[class*="msg"] img'
  ];
  const candidates = [];
  const seen = new Set();
  for (const selector of messageImageSelectors) {
    for (const img of Array.from(document.querySelectorAll(selector))) {
      const sourceUrl = imageSource(img);
      if (!sourceUrl || seen.has(sourceUrl) || !visible(img)) {
        continue;
      }
      if (isAvatarOrChrome(img, sourceUrl)) {
        continue;
      }
      seen.add(sourceUrl);
      const rect = img.getBoundingClientRect();
      const key = [
        hashString(sourceUrl),
        Math.round(rect.width),
        Math.round(rect.height),
        normalize(img.closest?.('[data-message-id],[data-msg-id],.js-message-item,.message-item')?.innerText || '').slice(0, 120)
      ].join('|');
      candidates.push({
        img,
        sourceUrl,
        key,
        width: Number(img.naturalWidth || rect.width || 0),
        height: Number(img.naturalHeight || rect.height || 0),
        bottom: rect.bottom,
        area: rect.width * rect.height
      });
    }
  }
  candidates.sort((left, right) =>
    (right.bottom - left.bottom) || (right.area - left.area)
  );
  for (const candidate of candidates) {
    const lastOpenedAt = Number(state.opened_keys[candidate.key] || 0);
    if (lastOpenedAt > 0 && now - lastOpenedAt < state.retry_ms) {
      return {
        opened: false,
        reason: 'same_media_preview_recently_opened',
        width: candidate.width,
        height: candidate.height,
        retry_after_ms: state.retry_ms - (now - lastOpenedAt)
      };
    }
    const target =
      candidate.img.closest?.('[role="button"],button,a,[class*="image"],[class*="Image"]') ||
      candidate.img;
    state.opened_keys[candidate.key] = now;
    target.scrollIntoView({ block: 'center', inline: 'nearest' });
    target.click();
    return {
      opened: true,
      reason: 'opened_media_preview_image',
      width: candidate.width,
      height: candidate.height,
      source_kind: String(candidate.sourceUrl).startsWith('blob:')
        ? 'blob'
        : String(candidate.sourceUrl).startsWith('data:')
        ? 'data'
        : 'url'
    };
  }
  return {
    opened: false,
    reason: 'no_message_image_to_preview',
    candidate_count: candidates.length
  };
})();
''';

const String feishuTriggerMediaPreviewOriginalScript = r'''
(() => {
  const stateKey = '__wukongFeishuMonitorMediaPreviewOriginal';
  const state = window[stateKey] || {
    clicked_keys: {},
    exported_body_keys: {},
    retry_ms: 12000
  };
  window[stateKey] = state;
  state.clicked_keys = state.clicked_keys || {};
  state.exported_body_keys = state.exported_body_keys || {};
  state.retry_ms = state.retry_ms || 12000;
  const now = Date.now();
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const lower = (value) => normalize(value).toLowerCase();
  const visible = (node) => {
    if (!node || !node.getBoundingClientRect) {
      return false;
    }
    const rect = node.getBoundingClientRect();
    const style = window.getComputedStyle ? window.getComputedStyle(node) : null;
    return rect.width >= 8 &&
      rect.height >= 8 &&
      rect.bottom > 0 &&
      rect.right > 0 &&
      (!style || (style.visibility !== 'hidden' && style.display !== 'none'));
  };
  const hashString = (value) => {
    const text = String(value || '');
    let hash = 2166136261;
    for (let i = 0; i < text.length; i += 1) {
      hash ^= text.charCodeAt(i);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16);
  };
  const cap = (value, limit = 240) => {
    const text = normalize(value);
    return text.length > limit ? text.slice(0, limit) : text;
  };
  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  const sourceKind = (sourceUrl) => {
    if (String(sourceUrl || '').startsWith('blob:')) {
      return 'blob';
    }
    if (String(sourceUrl || '').startsWith('data:')) {
      return 'data';
    }
    return 'url';
  };
  const feedSelectors = [
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main',
    '.scroller.feed-main-list .a11y_feed_card_item',
    '.scroller.feed-main-list .a11y_feed_card_main'
  ];
  const activeFeedCard = () => {
    for (const selector of feedSelectors) {
      const direct = document.querySelector(`${selector}[data-feed-active="true"]`);
      if (direct) {
        return direct;
      }
      const nested = document.querySelector(`${selector} [data-feed-active="true"]`);
      if (nested) {
        return nested.closest(selector) || nested;
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
    } else {
      const splitIndex = clean.indexOf(':');
      if (splitIndex >= 0) {
        conversationName = cap(clean.slice(0, splitIndex), 120);
        messageText = cap(clean.slice(splitIndex + 1), 240);
      }
    }
    return { conversationName, senderName, displayTime, messageText };
  };
  const activeFeedContext = () => {
    const card = activeFeedCard();
    const pending = window.__wukongFeishuMonitorPendingMediaTarget || {};
    const cardText = card ? cap(card.innerText || card.textContent || '', 500) : '';
    const pendingText = cap(pending.text || '', 500);
    const contextText = cardText || pendingText;
    const parsed = parseFeedText(contextText);
    const identity = feedCardId(card) || hashString(parsed.conversationName || contextText);
    return {
      conversation_id: identity ? `feed:${identity}` : '',
      conversation_name: parsed.conversationName,
      sender_name: parsed.senderName,
      display_time: parsed.displayTime,
      message_text: parsed.messageText || '[Image]',
      feed_card_id: identity,
      feed_card_text: contextText,
      confidence: contextText ? 0.72 : 0.0,
      confidence_label: contextText ? 'medium' : 'low',
      evidence: contextText
        ? ['browser_preview_blob_body', 'active_feed_context']
        : ['browser_preview_blob_body']
    };
  };
  const blobToBase64 = (blob) => new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const dataUrl = String(reader.result || '');
      const comma = dataUrl.indexOf(',');
      resolve(comma >= 0 ? dataUrl.slice(comma + 1) : '');
    };
    reader.onerror = () => reject(reader.error || new Error('readAsDataURL failed'));
    reader.readAsDataURL(blob);
  });
  const exportPreviewImageBody = async (entry) => {
    const sourceUrl = String(entry.source_url || '');
    if (!sourceUrl.startsWith('blob:')) {
      return;
    }
    const exportKey = hashString(`${sourceUrl}:${entry.width}x${entry.height}`);
    if (state.exported_body_keys[exportKey]) {
      return;
    }
    state.exported_body_keys[exportKey] = now;
    try {
      const response = await fetch(sourceUrl);
      const blob = await response.blob();
      if (!blob || !String(blob.type || '').startsWith('image/')) {
        return;
      }
      if (Number(blob.size || 0) <= 0 || Number(blob.size || 0) > 25 * 1024 * 1024) {
        return;
      }
      const bodyBase64 = await blobToBase64(blob);
      if (!bodyBase64) {
        return;
      }
      const context = activeFeedContext();
      post({
        type: 'feishu_monitor_browser_image_body',
        source_url: sourceUrl,
        mime_type: blob.type || '',
        body_base64: bodyBase64,
        body_size: Number(blob.size || 0),
        width: Number(entry.width || 0),
        height: Number(entry.height || 0),
        conversation_id: context.conversation_id,
        conversation_name: context.conversation_name,
        sender_name: context.sender_name,
        display_time: context.display_time,
        message_text: context.message_text,
        feed_card_id: context.feed_card_id,
        feed_card_text: context.feed_card_text,
        confidence: context.confidence,
        confidence_label: context.confidence_label,
        reason: 'preview_blob_body',
        observed_at: new Date().toISOString(),
        evidence: context.evidence
      });
    } catch (_) {}
  };
  const exportPreviewImageBodies = (root) => {
    const entries = Array.from(root.querySelectorAll('img'))
      .filter((img) => visible(img) && !!closestPreviewRoot(img))
      .map((img) => {
        const rect = img.getBoundingClientRect();
        const sourceUrl = String(img.currentSrc || img.src || '');
        return {
          source_url: sourceUrl,
          source_kind: sourceKind(sourceUrl),
          width: Number(img.naturalWidth || rect.width || 0),
          height: Number(img.naturalHeight || rect.height || 0),
          display_width: Math.round(rect.width || 0),
          display_height: Math.round(rect.height || 0)
        };
      })
      .filter((entry) => entry.source_kind === 'blob')
      .sort((left, right) =>
        (right.display_width * right.display_height) -
        (left.display_width * left.display_height)
      );
    for (const entry of entries.slice(0, 2)) {
      exportPreviewImageBody(entry);
    }
    return {
      attempted: entries.length > 0,
      candidate_count: entries.length,
      queued_count: Math.min(entries.length, 2)
    };
  };
  const rootText = (node) => lower([
    node?.getAttribute?.('role') || '',
    node?.getAttribute?.('aria-modal') || '',
    node?.getAttribute?.('aria-label') || '',
    node?.getAttribute?.('data-testid') || '',
    node?.id || '',
    node?.className || ''
  ].join(' '));
  const isLikelyPreviewRoot = (node) => {
    if (!visible(node)) {
      return false;
    }
    const text = rootText(node);
    if (
      text.includes('page-content-wrapper') ||
      text.includes('page-content-messenger') ||
      text.includes('lark_feedmainlist') ||
      text.includes('feed-main-list') ||
      text.includes('messenger-chat') ||
      text.includes('chatwindow')
    ) {
      return false;
    }
    const hasPreviewMarker =
      node.getAttribute?.('role') === 'dialog' ||
      node.getAttribute?.('aria-modal') === 'true' ||
      text.includes('preview') ||
      text.includes('viewer') ||
      text.includes('photo-viewer') ||
      text.includes('imageviewer') ||
      text.includes('image-viewer') ||
      text.includes('media-viewer') ||
      text.includes('lightbox');
    if (!hasPreviewMarker) {
      return false;
    }
    const images = [
      ...(node.matches?.('img') ? [node] : []),
      ...Array.from(node.querySelectorAll?.('img') || [])
    ];
    return images.some((img) => {
      if (!visible(img)) {
        return false;
      }
      const rect = img.getBoundingClientRect();
      return rect.width >= 120 && rect.height >= 80;
    });
  };
  const previewRoots = () => Array.from(
    document.querySelectorAll(
      '[role="dialog"],[aria-modal="true"],' +
      '[class*="preview"],[class*="Preview"],[class*="viewer"],[class*="Viewer"],' +
      '[class*="imageViewer"],[class*="ImageViewer"],' +
      '[class*="image-viewer"],[class*="Image-Viewer"],' +
      '[class*="photo-viewer"],[class*="PhotoViewer"],' +
      '[class*="media-viewer"],[class*="MediaViewer"],' +
      '[class*="lightbox"],[class*="Lightbox"]'
    )
  ).filter(isLikelyPreviewRoot);
  const closestPreviewRoot = (node) => {
    let current = node;
    while (current && current !== document.body) {
      if (isLikelyPreviewRoot(current)) {
        return current;
      }
      current = current.parentElement;
    }
    return null;
  };
  const previewRoot = previewRoots()[0] || null;
  const describeControl = (node) => {
    const rect = node.getBoundingClientRect?.();
    const attrs = {};
    for (const attr of Array.from(node.attributes || [])) {
      if (
        attr.name === 'id' ||
        attr.name === 'role' ||
        attr.name === 'title' ||
        attr.name === 'aria-label' ||
        attr.name === 'data-testid' ||
        attr.name === 'data-key' ||
        attr.name === 'data-id'
      ) {
        attrs[attr.name] = attr.value;
      }
    }
    const text = normalize([
      node.innerText || node.textContent || '',
      node.getAttribute?.('aria-label') || '',
      node.getAttribute?.('title') || '',
      node.getAttribute?.('data-testid') || '',
      node.getAttribute?.('data-key') || '',
      node.getAttribute?.('data-id') || '',
      node.className || '',
      node.parentElement?.className || '',
      node.closest?.('[class*="toolbar"],[class*="Toolbar"],[class*="operator"],[class*="Operator"]')?.className || ''
    ].join(' '));
    return {
      tag: String(node.tagName || '').toLowerCase(),
      role: node.getAttribute?.('role') || '',
      text: text.slice(0, 240),
      class_name: String(node.className || '').slice(0, 180),
      attrs,
      in_preview_root: !!closestPreviewRoot(node),
      width: Math.round(rect?.width || 0),
      height: Math.round(rect?.height || 0)
    };
  };
  const controlText = (node) => lower([
    node.innerText || node.textContent || '',
    node.getAttribute?.('aria-label') || '',
    node.getAttribute?.('title') || '',
    node.getAttribute?.('data-testid') || '',
    node.getAttribute?.('data-key') || '',
    node.getAttribute?.('data-id') || '',
    node.className || ''
  ].join(' '));
  const originalControlTokens = [
    '原图',
    '查看原图',
    '加载原图',
    '发送原图',
    'original',
    'origin',
    'source image',
    'view original',
    'load original'
  ];
  const downloadControlTokens = [
    '下载',
    '保存',
    '另存',
    'download',
    'save',
    'save as'
  ];
  const moreControlTokens = [
    '更多',
    'more',
    'menu',
    'overflow',
    'ellipsis',
    'ud-icon-more',
    'toolbar-more'
  ];
  const isExcludedChrome = (node, text) =>
    text.includes('关闭') ||
    text.includes('close') ||
    text.includes('zoom') ||
    text.includes('放大') ||
    text.includes('缩小') ||
    text.includes('rotate') ||
    text.includes('旋转') ||
    text.includes('copy') ||
    text.includes('复制');
  const allControls = () => Array.from(
    document.querySelectorAll(
      'button,[role="button"],a,[title],[aria-label],[data-testid]'
    )
  )
    .filter(visible)
    .map((node) => ({ node, description: describeControl(node), text: controlText(node) }))
    .filter((entry) => !!closestPreviewRoot(entry.node));
  const clickEntry = (entry, reason) => {
    const key = hashString(`${reason}:${entry.text}:${entry.description.class_name}:${entry.description.attrs.title || ''}`);
    const lastClickedAt = Number(state.clicked_keys[key] || 0);
    if (lastClickedAt > 0 && now - lastClickedAt < state.retry_ms) {
      return {
        clicked: false,
        reason: `${reason}_recently_clicked`,
        retry_after_ms: state.retry_ms - (now - lastClickedAt),
        control: entry.description
      };
    }
    state.clicked_keys[key] = now;
    entry.node.scrollIntoView?.({ block: 'center', inline: 'nearest' });
    entry.node.click();
    return {
      clicked: true,
      reason,
      control: entry.description
    };
  };
  const findByTokens = (tokens, controls) => {
    for (const entry of controls) {
      if (isExcludedChrome(entry.node, entry.text)) {
        continue;
      }
      if (tokens.some((token) => entry.text.includes(lower(token)))) {
        return entry;
      }
    }
    return null;
  };
  if (!previewRoot) {
    return {
      clicked: false,
      reason: 'no_media_preview_overlay',
      preview_root_samples: Array.from(
        document.querySelectorAll('[role="dialog"],[aria-modal="true"],[class*="preview"],[class*="Preview"],[class*="viewer"],[class*="Viewer"]')
      )
        .filter(visible)
        .slice(0, 10)
        .map((node) => describeControl(node))
    };
  }
  const previewImages = Array.from(previewRoot.querySelectorAll('img'))
    .filter((img) => visible(img) && !!closestPreviewRoot(img))
    .map((img) => {
      const rect = img.getBoundingClientRect();
      const sourceUrl = String(img.currentSrc || img.src || '');
      return {
        source_kind: sourceUrl.startsWith('blob:')
          ? 'blob'
          : sourceUrl.startsWith('data:')
          ? 'data'
          : 'url',
        width: Number(img.naturalWidth || rect.width || 0),
        height: Number(img.naturalHeight || rect.height || 0),
        display_width: Math.round(rect.width || 0),
        display_height: Math.round(rect.height || 0)
      };
    })
    .sort((left, right) => (right.display_width * right.display_height) - (left.display_width * left.display_height));
  const browserImageBodyExport = exportPreviewImageBodies(previewRoot);
  const previewControlSamples = allControls().slice(0, 20).map((entry) => entry.description);
  const clickMoreControls = () => {
    const more = findByTokens(moreControlTokens, allControls());
    if (!more) {
      return { clicked: false, reason: 'no_media_preview_more_control' };
    }
    return clickEntry(more, 'clicked_media_preview_more_control');
  };
  const original = findByTokens(originalControlTokens, allControls());
  if (original) {
    return {
      ...clickEntry(original, 'clicked_media_preview_original_control'),
      browser_image_body_export: browserImageBodyExport,
      preview_image_samples: previewImages.slice(0, 6),
      preview_control_samples: previewControlSamples
    };
  }
  const download = findByTokens(downloadControlTokens, allControls());
  if (download) {
    return {
      ...clickEntry(download, 'clicked_media_preview_download_control'),
      browser_image_body_export: browserImageBodyExport,
      preview_image_samples: previewImages.slice(0, 6),
      preview_control_samples: previewControlSamples
    };
  }
  const moreResult = clickMoreControls();
  if (moreResult.clicked) {
    const controlsAfterMore = allControls();
    const originalAfterMore = findByTokens(originalControlTokens, controlsAfterMore);
    if (originalAfterMore) {
      return {
        ...clickEntry(originalAfterMore, 'clicked_media_preview_original_control'),
        opened_more_first: true,
        more_control: moreResult.control,
        browser_image_body_export: browserImageBodyExport,
        preview_image_samples: previewImages.slice(0, 6),
        preview_control_samples: controlsAfterMore.slice(0, 20).map((entry) => entry.description)
      };
    }
    const downloadAfterMore = findByTokens(downloadControlTokens, controlsAfterMore);
    if (downloadAfterMore) {
      return {
        ...clickEntry(downloadAfterMore, 'clicked_media_preview_download_control'),
        opened_more_first: true,
        more_control: moreResult.control,
        browser_image_body_export: browserImageBodyExport,
        preview_image_samples: previewImages.slice(0, 6),
        preview_control_samples: controlsAfterMore.slice(0, 20).map((entry) => entry.description)
      };
    }
  }
  return {
    clicked: false,
    reason: moreResult.reason || 'no_media_preview_original_or_download_control',
    more_result: moreResult,
    browser_image_body_export: browserImageBodyExport,
    preview_image_samples: previewImages.slice(0, 6),
    preview_control_samples: previewControlSamples
  };
})();
''';

const String feishuCloseMediaPreviewScript = r'''
(() => {
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const lower = (value) => normalize(value).toLowerCase();
  const visible = (node) => {
    if (!node || !node.getBoundingClientRect) {
      return false;
    }
    const rect = node.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  };
  const previewRoot = Array.from(
    document.querySelectorAll(
      '[role="dialog"],[aria-modal="true"],[class*="preview"],[class*="Preview"],' +
      '[class*="viewer"],[class*="Viewer"],[class*="image-viewer"],[class*="ImageViewer"]'
    )
  ).find((node) => visible(node) && node.querySelector?.('img'));
  if (!previewRoot) {
    return { closed: false, reason: 'no_media_preview_overlay' };
  }
  const controls = Array.from(
    previewRoot.querySelectorAll('button,[role="button"],a,[title],[aria-label],[class]')
  ).filter(visible);
  for (const control of controls) {
    const text = lower([
      control.innerText || control.textContent || '',
      control.getAttribute?.('aria-label') || '',
      control.getAttribute?.('title') || '',
      control.getAttribute?.('data-testid') || '',
      control.className || ''
    ].join(' '));
    if (
      text.includes('close') ||
      text.includes('viewer-icon-close') ||
      text.includes('sd-iv-close')
    ) {
      control.click();
      return {
        closed: true,
        reason: 'closed_media_preview',
        control_text: text.slice(0, 160)
      };
    }
  }
  return { closed: false, reason: 'media_preview_close_control_not_found' };
})();
''';

const String feishuJumpActiveConfiguredMediaFeedToNewestScript = r'''
(() => {
  const configuredSources = window.__wukongFeishuMonitorConfiguredMediaSources || {};
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const normalizedName = (value) => normalize(value).toLowerCase();
  const configuredNames = new Set(
    Array.isArray(configuredSources.configured_names)
      ? configuredSources.configured_names
          .map((item) => normalizedName(item))
          .filter(Boolean)
      : []
  );
  const configuredIds = new Set(
    Array.isArray(configuredSources.configured_ids)
      ? configuredSources.configured_ids
          .map((item) => String(item || '').trim())
          .filter(Boolean)
      : []
  );
  if (configuredNames.size === 0 && configuredIds.size === 0) {
    return {
      attempted: false,
      jumped: false,
      matched: false,
      reason: 'no_configured_media_sources'
    };
  }
  const cardId = (card) =>
    card.getAttribute('data-id') ||
    card.getAttribute('data-feed-id') ||
    card.getAttribute('data-key') ||
    '';
  const conversationNameFromText = (text) => {
    const clean = normalize(text);
    const match = clean.match(/(?:^|\s)(?:\d{1,2}:\d{2}|昨天|前天|\d{1,2}月\d{1,2}日)(?:\s|$)/);
    if (!match) {
      return clean;
    }
    return normalize(clean.slice(0, match.index));
  };
  const cardMatchesConfiguredSource = (card, text) => {
    const id = cardId(card);
    if (id && configuredIds.has(id)) {
      return true;
    }
    const name = normalizedName(conversationNameFromText(text));
    if (name && configuredNames.has(name)) {
      return true;
    }
    const normalizedText = normalizedName(text);
    for (const configuredName of configuredNames) {
      if (configuredName && normalizedText.startsWith(configuredName + ' ')) {
        return true;
      }
    }
    return false;
  };
  const scrollMessagePaneToBottom = () => {
    const candidates = Array.from(
      document.querySelectorAll(
        '.messageContainer,.message-container,.message-list,.messageList,' +
        '[class*="messageContainer"],[class*="message-list"],[class*="MessageList"],' +
        '.simplebar-content-wrapper,[data-scrollable="true"]'
      )
    ).filter((node) => {
      const rect = node.getBoundingClientRect?.();
      return rect && rect.height > 120 && node.scrollHeight > node.clientHeight;
    });
    const ranked = candidates
      .map((node) => ({
        node,
        score:
          (node.querySelectorAll?.('.js-message-item,.message-item,.im-image-message')?.length || 0) * 1000 +
          node.scrollHeight
      }))
      .sort((left, right) => right.score - left.score);
    const target = ranked.length > 0 ? ranked[0].node : document.scrollingElement;
    if (!target) {
      return false;
    }
    const setScrollToBottom = (node) => {
      node.scrollTop = node.scrollHeight;
    };
    setScrollToBottom(target);
    target.dispatchEvent?.(new Event('scroll', { bubbles: true }));
    return true;
  };
  const selectors = [
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main',
    '.scroller.feed-main-list .a11y_feed_card_item',
    '.scroller.feed-main-list .a11y_feed_card_main'
  ];
  for (const selector of selectors) {
    const cards = Array.from(document.querySelectorAll(selector));
    for (const card of cards) {
      const active =
        card.getAttribute('data-feed-active') === 'true' ||
        card.closest?.('[data-feed-active="true"]');
      if (!active) {
        continue;
      }
      const text = normalize(card.innerText || card.textContent || '');
      if (!text || !cardMatchesConfiguredSource(card, text)) {
        continue;
      }
      const newestTip = document.querySelector(
        '.messageTip__toNewestTip,' +
        '[class*="messageTip__toNewestTip"],' +
        '[class*="toNewestTip"]'
      );
      if (!newestTip) {
        const scrolled = scrollMessagePaneToBottom();
        return {
          attempted: true,
          jumped: false,
          matched: true,
          reason: scrolled
            ? 'scrolled_active_configured_media_feed_to_bottom'
            : 'active_configured_media_feed_no_newest_tip',
          scrolled,
          text,
          id: cardId(card)
        };
      }
      newestTip.click();
      const scrolled = scrollMessagePaneToBottom();
      return {
        attempted: true,
        jumped: true,
        matched: true,
        reason: 'jumped_active_configured_media_feed_to_newest',
        scrolled,
        text,
        id: cardId(card)
      };
    }
  }
  return {
    attempted: true,
    jumped: false,
    matched: false,
    reason: 'active_configured_media_feed_not_found',
    configured_names: Array.from(configuredNames),
    configured_ids: Array.from(configuredIds)
  };
})();
''';

const String feishuOpenLatestFeedScript = r'''
(() => {
  const openNewestFeed = () => {
    const selectors = [
      '.lark_feedMainList .a11y_feed_card_item',
      '.lark_feedMainList .a11y_feed_card_main',
      '.scroller.feed-main-list .a11y_feed_card_item',
      '.scroller.feed-main-list .a11y_feed_card_main'
    ];
    for (const selector of selectors) {
      const cards = Array.from(document.querySelectorAll(selector));
      for (const card of cards) {
        const text = String(card.innerText || card.textContent || '')
          .replace(/\s+/g, ' ')
          .trim();
        if (!text) {
          continue;
        }
        const active =
          card.getAttribute('data-feed-active') === 'true' ||
          card.closest?.('[data-feed-active="true"]');
        if (active) {
          return {
            opened: false,
            reason: 'already_active_latest_feed',
            text,
            id:
              card.getAttribute('data-id') ||
              card.getAttribute('data-feed-id') ||
              card.getAttribute('data-key') ||
              ''
          };
        }
        const target =
          card.querySelector?.('[role="button"],button,a') ||
          card.closest?.('.a11y_feed_card_item,.a11y_feed_card_main') ||
          card;
        target.scrollIntoView({ block: 'center', inline: 'nearest' });
        target.click();
        return {
          opened: true,
          reason: 'opened_latest_feed',
          text,
          id:
            card.getAttribute('data-id') ||
            card.getAttribute('data-feed-id') ||
            card.getAttribute('data-key') ||
            ''
        };
      }
    }
    return { opened: false, reason: 'no_feed_card' };
  };
  return openNewestFeed();
})();
''';

const String feishuOpenConfiguredMediaFeedScript = r'''
(() => {
  const configuredSources = window.__wukongFeishuMonitorConfiguredMediaSources || {};
  const configuredNames = new Set(
    Array.isArray(configuredSources.configured_names)
      ? configuredSources.configured_names
          .map((item) => String(item || '').replace(/\s+/g, ' ').trim().toLowerCase())
          .filter(Boolean)
      : []
  );
  const configuredIds = new Set(
    Array.isArray(configuredSources.configured_ids)
      ? configuredSources.configured_ids
          .map((item) => String(item || '').trim())
          .filter(Boolean)
      : []
  );
  const selectors = [
    '.lark_feedMainList .a11y_feed_card_item',
    '.lark_feedMainList .a11y_feed_card_main',
    '.scroller.feed-main-list .a11y_feed_card_item',
    '.scroller.feed-main-list .a11y_feed_card_main'
  ];
  const normalize = (value) => String(value || '').replace(/\s+/g, ' ').trim();
  const normalizedName = (value) => normalize(value).toLowerCase();
  const preferredName = normalizedName(configuredSources.preferred_name || '');
  const preferredId = String(configuredSources.preferred_id || '').trim();
  const cardId = (card) =>
    card.getAttribute('data-id') ||
    card.getAttribute('data-feed-id') ||
    card.getAttribute('data-key') ||
    '';
  const conversationNameFromText = (text) => {
    const clean = normalize(text);
    const match = clean.match(/(?:^|\s)(?:\d{1,2}:\d{2}|昨天|前天|\d{1,2}月\d{1,2}日)(?:\s|$)/);
    if (!match) {
      return clean;
    }
    return normalize(clean.slice(0, match.index));
  };
  const cardMatchesConfiguredSource = (card, text) => {
    const id = cardId(card);
    if (id && configuredIds.has(id)) {
      return true;
    }
    const name = normalizedName(conversationNameFromText(text));
    if (name && configuredNames.has(name)) {
      return true;
    }
    for (const configuredName of configuredNames) {
      if (configuredName && normalizedName(text).startsWith(configuredName + ' ')) {
        return true;
      }
    }
    return false;
  };
  const cardMatchesPreferredSource = (entry) => {
    if (!preferredId && !preferredName) {
      return false;
    }
    if (preferredId && entry.id === preferredId) {
      return true;
    }
    if (preferredName && entry.name === preferredName) {
      return true;
    }
    if (preferredName && normalizedName(entry.text).startsWith(preferredName + ' ')) {
      return true;
    }
    return false;
  };
  const clickNewestTip = () => {
    const newestTip = document.querySelector(
      '.messageTip__toNewestTip,' +
      '[class*="messageTip__toNewestTip"],' +
      '[class*="toNewestTip"]'
    );
    if (!newestTip) {
      return false;
    }
    newestTip.click();
    return true;
  };
  const matchingCards = [];
  for (const selector of selectors) {
    const cards = Array.from(document.querySelectorAll(selector));
    for (const card of cards) {
      const text = normalize(card.innerText || card.textContent || '');
      if (!text || !cardMatchesConfiguredSource(card, text)) {
        continue;
      }
      matchingCards.push({
        card,
        text,
        id: cardId(card),
        name: normalizedName(conversationNameFromText(text))
      });
    }
  }
  const orderedCards = [
    ...matchingCards.filter(cardMatchesPreferredSource),
    ...matchingCards.filter((entry) => !cardMatchesPreferredSource(entry))
  ];
  for (const entry of orderedCards) {
      const card = entry.card;
      const text = entry.text;
      const active =
        card.getAttribute('data-feed-active') === 'true' ||
        card.closest?.('[data-feed-active="true"]');
      if (active) {
        const jumped = clickNewestTip();
        return {
          opened: true,
          matched: true,
          reason: jumped
            ? 'jumped_active_configured_media_feed_to_newest'
            : 'refreshed_active_configured_media_feed',
          text,
          id: entry.id,
          preferred_name: preferredName,
          preferred_id: preferredId,
          configured_names: Array.from(configuredNames),
          configured_ids: Array.from(configuredIds)
        };
      }
      const target =
        card.querySelector?.('[role="button"],button,a') ||
        card.closest?.('.a11y_feed_card_item,.a11y_feed_card_main') ||
        card;
      target.scrollIntoView({ block: 'center', inline: 'nearest' });
      target.click();
      return {
        opened: true,
        matched: true,
        reason: 'opened_configured_media_feed',
        text,
        id: entry.id,
        preferred_name: preferredName,
        preferred_id: preferredId,
        configured_names: Array.from(configuredNames),
        configured_ids: Array.from(configuredIds)
      };
  }
  return {
    opened: false,
    matched: false,
    reason: 'configured_media_feed_not_found',
    preferred_name: preferredName,
    preferred_id: preferredId,
    configured_names: Array.from(configuredNames),
    configured_ids: Array.from(configuredIds)
  };
})();
''';

class FeishuPageProbe {
  const FeishuPageProbe({
    required this.runtimeUrl,
    required this.pageTitle,
    required this.bodyText,
    required this.pageKind,
    required this.observedAt,
    this.probeDiagnostics = const <String, dynamic>{},
    required this.observedConversations,
    required this.observedMessages,
    this.hasPendingMediaFeedCard = false,
    this.pendingMediaFeedCardKey = '',
    this.pendingMediaFeedCardText = '',
  });

  final String runtimeUrl;
  final String pageTitle;
  final String bodyText;
  final String pageKind;
  final DateTime? observedAt;
  final Map<String, dynamic> probeDiagnostics;
  final List<ObservedConversation> observedConversations;
  final List<ObservedMessageCandidate> observedMessages;
  final bool hasPendingMediaFeedCard;
  final String pendingMediaFeedCardKey;
  final String pendingMediaFeedCardText;

  factory FeishuPageProbe.fromScriptResult(Map<String, dynamic> json) {
    final runtimeUrl = (json['runtime_url'] ?? '').toString();
    final pageTitle = (json['page_title'] ?? '').toString();
    final bodyText = (json['body_text'] ?? '').toString();
    var observedConversations = _readObservedConversations(
      json['observed_conversations'],
    );
    var observedMessages = _readObservedMessages(json['observed_messages']);
    final feedCards = _readFeedCardsFromResult(json);
    final diagnostics = _readDiagnostics(json['probe_diagnostics']);
    final feedCardObservations = _deriveObservationsFromFeedCards(
      feedCards,
      json['observed_at'],
    );
    final pendingMediaFeedCard = _pendingMediaFeedCard(
      feedCardObservations.messages,
      observedMessages,
      configuredSourceIds: configuredMediaSourceIdsFromDiagnostics(diagnostics),
      configuredSourceNames: configuredMediaSourceNamesFromDiagnostics(
        diagnostics,
      ),
    );
    final pendingMediaFeedCardKey = pendingMediaFeedCard?.id.trim() ?? '';
    final pendingMediaFeedCardText = pendingMediaFeedCardKey.isEmpty
        ? ''
        : feedCardObservations.messageRawTexts[pendingMediaFeedCardKey] ?? '';
    final hasPendingMediaFeedCard = pendingMediaFeedCardKey.isNotEmpty;
    if (pendingMediaFeedCard != null) {
      observedMessages = _filterObservedMessagesForPendingMediaFeedCard(
        pendingMediaFeedCard,
        observedMessages,
      );
    }
    if (feedCardObservations.messages.isNotEmpty) {
      observedMessages = _mergeObservedMessages(
        observedMessages,
        feedCardObservations.messages,
      );
    }
    if (feedCardObservations.conversations.isNotEmpty) {
      observedConversations = _mergeObservedConversations(
        observedConversations,
        feedCardObservations.conversations,
      );
    }
    final explicitPageKind = (json['page_kind'] ?? '').toString().trim();
    final pageKind = explicitPageKind.isNotEmpty
        ? explicitPageKind
        : derivePageKind(
            runtimeUrl: runtimeUrl,
            pageTitle: pageTitle,
            bodyText: bodyText,
            hasObservedConversations: observedConversations.isNotEmpty,
          );
    if (pageKind == 'messenger' &&
        observedConversations.isEmpty &&
        observedMessages.isEmpty) {
      observedConversations = _deriveConversationsFromBodyText(
        bodyText,
        json['observed_at'],
      );
      observedMessages = _deriveMessagesFromBodyText(
        bodyText,
        json['observed_at'],
        observedConversations,
      );
    }

    return FeishuPageProbe(
      runtimeUrl: runtimeUrl,
      pageTitle: pageTitle,
      bodyText: bodyText,
      pageKind: pageKind,
      observedAt: _readDateTime(json['observed_at']),
      probeDiagnostics: diagnostics,
      observedConversations: observedConversations,
      observedMessages: observedMessages,
      hasPendingMediaFeedCard: hasPendingMediaFeedCard,
      pendingMediaFeedCardKey: pendingMediaFeedCardKey,
      pendingMediaFeedCardText: pendingMediaFeedCardText,
    );
  }
}

bool probeHasPendingMediaFeedCard(FeishuPageProbe probe) {
  return probe.hasPendingMediaFeedCard;
}

String probePendingMediaFeedCardKey(FeishuPageProbe probe) {
  return probe.pendingMediaFeedCardKey;
}

String probePendingMediaFeedCardText(FeishuPageProbe probe) {
  return probe.pendingMediaFeedCardText;
}

String configuredDomImageSignature(FeishuPageProbe probe) {
  final sourceIds = configuredMediaSourceIdsFromDiagnostics(
    probe.probeDiagnostics,
  );
  final sourceNames = configuredMediaSourceNamesFromDiagnostics(
    probe.probeDiagnostics,
  );
  ObservedMessageCandidate? selectedMessage;
  for (final message in probe.observedMessages) {
    if (message.captureSource.trim() != 'dom_probe' ||
        message.imageAttachments.isEmpty) {
      continue;
    }
    if (!pendingMediaFeedCardMatchesConfiguredSources(
      conversationId: message.conversationId,
      conversationName: message.conversationName,
      configuredSourceIds: sourceIds,
      configuredSourceNames: sourceNames,
    )) {
      continue;
    }
    final attachment = message.imageAttachments.first;
    final source = attachment.sourceUrl.trim().isNotEmpty
        ? attachment.sourceUrl.trim()
        : attachment.localPath.trim();
    if (source.isEmpty) {
      continue;
    }
    if (selectedMessage == null ||
        _compareObservedMessageRecency(message, selectedMessage) > 0) {
      selectedMessage = message;
    }
  }
  final message = selectedMessage;
  if (message == null) {
    return '';
  }
  final attachment = message.imageAttachments.first;
  final source = attachment.sourceUrl.trim().isNotEmpty
      ? attachment.sourceUrl.trim()
      : attachment.localPath.trim();
  if (source.isEmpty) {
    return '';
  }
  return [
    message.conversationId.trim(),
    _normalizeConfiguredMediaSourceName(message.conversationName),
    message.id.trim(),
    source,
    attachment.width,
    attachment.height,
  ].join('|');
}

int _compareObservedMessageRecency(
  ObservedMessageCandidate left,
  ObservedMessageCandidate right,
) {
  final leftObservedAt = DateTime.tryParse(left.observedAt.trim());
  final rightObservedAt = DateTime.tryParse(right.observedAt.trim());
  if (leftObservedAt != null && rightObservedAt != null) {
    final comparison = leftObservedAt.compareTo(rightObservedAt);
    if (comparison != 0) {
      return comparison;
    }
  } else {
    final comparison = left.observedAt.trim().compareTo(right.observedAt.trim());
    if (comparison != 0) {
      return comparison;
    }
  }
  return _compareMessageIdValue(left.id, right.id);
}

int _compareMessageIdValue(String left, String right) {
  final normalizedLeft = left.trim();
  final normalizedRight = right.trim();
  final leftNumber = int.tryParse(normalizedLeft);
  final rightNumber = int.tryParse(normalizedRight);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  return normalizedLeft.compareTo(normalizedRight);
}

bool isFeishuMediaPreviewText(String value) {
  return _isMediaPreviewText(value);
}

String derivePageKind({
  required String runtimeUrl,
  required String pageTitle,
  required String bodyText,
  required bool hasObservedConversations,
}) {
  final normalizedUrl = runtimeUrl.trim().toLowerCase();
  final normalizedTitle = pageTitle.trim().toLowerCase();
  final normalizedBody = bodyText.trim().toLowerCase();

  if (normalizedUrl.contains('login') ||
      normalizedUrl.contains('passport') ||
      normalizedUrl.contains('accounts') ||
      normalizedBody.contains('scan qr code') ||
      normalizedBody.contains('扫码') ||
      normalizedTitle.contains('login')) {
    return 'login';
  }

  if (normalizedUrl.contains('messenger') ||
      normalizedUrl.contains('/im') ||
      normalizedTitle.contains('feishu') ||
      normalizedBody.contains('消息') ||
      hasObservedConversations) {
    return 'messenger';
  }

  return 'unknown';
}

List<ObservedConversation> _readObservedConversations(dynamic value) {
  if (value is! List) {
    return const <ObservedConversation>[];
  }

  final conversations = <ObservedConversation>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final json = Map<String, dynamic>.from(
      item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
    );
    final id = (json['id'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty) {
      continue;
    }
    conversations.add(ObservedConversation.fromJson(json));
  }
  return List<ObservedConversation>.unmodifiable(conversations);
}

List<ObservedMessageCandidate> _readObservedMessages(dynamic value) {
  if (value is! List) {
    return const <ObservedMessageCandidate>[];
  }

  final messages = <ObservedMessageCandidate>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final json = Map<String, dynamic>.from(
      item.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
    );
    final id = (json['id'] ?? '').toString().trim();
    final imageAttachments = MessageImageAttachment.listFromJson(
      json['image_attachments'],
    );
    final text = (json['text'] ?? '').toString().trim();
    final captureSource = (json['capture_source'] ?? '').toString().trim();
    if (id.isEmpty || (text.isEmpty && imageAttachments.isEmpty)) {
      continue;
    }
    if (_isOversizedDomContainerCandidate(
      id: id,
      text: text,
      captureSource: captureSource,
    )) {
      continue;
    }
    if (text.isEmpty && imageAttachments.isNotEmpty) {
      json['text'] = '[图片]';
    }
    if ((json['message_type'] ?? '').toString().trim().isEmpty &&
        imageAttachments.isNotEmpty) {
      json['message_type'] = 'image';
    }
    messages.add(ObservedMessageCandidate.fromJson(json));
  }
  return List<ObservedMessageCandidate>.unmodifiable(messages);
}

List<ObservedMessageCandidate> _filterObservedMessagesForPendingMediaFeedCard(
  ObservedMessageCandidate pendingMediaFeedCard,
  List<ObservedMessageCandidate> observedMessages,
) {
  if (observedMessages.isEmpty) {
    return observedMessages;
  }
  return List<ObservedMessageCandidate>.unmodifiable(
    observedMessages.where((message) {
      if (message.imageAttachments.isEmpty ||
          message.captureSource.trim() != 'dom_probe') {
        return true;
      }
      return _sameObservedConversation(pendingMediaFeedCard, message);
    }),
  );
}

dynamic _readFeedCardsFromResult(Map<String, dynamic> json) {
  final feedCards = json['feed_cards'];
  if (feedCards is List && feedCards.isNotEmpty) {
    return feedCards;
  }

  final diagnostics = json['probe_diagnostics'];
  if (diagnostics is! Map) {
    return feedCards;
  }
  final summaries = diagnostics['top_feed_card_summaries'];
  if (summaries is! List || summaries.isEmpty) {
    return feedCards;
  }
  return summaries;
}

List<ObservedConversation> _mergeObservedConversations(
  List<ObservedConversation> primary,
  List<ObservedConversation> secondary,
) {
  if (primary.isEmpty) {
    return secondary;
  }
  if (secondary.isEmpty) {
    return primary;
  }

  final merged = <ObservedConversation>[];
  final seen = <String>{};
  for (final conversation in <ObservedConversation>[...primary, ...secondary]) {
    final key = conversation.id.trim().isNotEmpty
        ? conversation.id.trim()
        : conversation.name.trim();
    if (key.isEmpty || !seen.add(key)) {
      continue;
    }
    merged.add(conversation);
  }
  return List<ObservedConversation>.unmodifiable(merged);
}

List<ObservedMessageCandidate> _mergeObservedMessages(
  List<ObservedMessageCandidate> primary,
  List<ObservedMessageCandidate> secondary,
) {
  if (primary.isEmpty) {
    return secondary;
  }
  if (secondary.isEmpty) {
    return primary;
  }

  final merged = <ObservedMessageCandidate>[];
  final seen = <String>{};
  for (final message in <ObservedMessageCandidate>[...primary, ...secondary]) {
    final key = _observedMessageMergeKey(message);
    if (key.isEmpty || !seen.add(key)) {
      continue;
    }
    merged.add(message);
  }
  return List<ObservedMessageCandidate>.unmodifiable(merged);
}

String _observedMessageMergeKey(ObservedMessageCandidate message) {
  final id = message.id.trim();
  if (id.isNotEmpty) {
    final conversationId = message.conversationId.trim();
    final conversationName = message.conversationName.trim();
    final conversationScope = conversationId.isNotEmpty
        ? conversationId
        : conversationName;
    return <String>[
      message.captureSource.trim(),
      conversationScope,
      id,
    ].join(':');
  }
  final normalizedText = message.text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalizedText.isEmpty) {
    return '';
  }
  return <String>[
    message.captureSource.trim(),
    message.conversationId.trim(),
    message.conversationName.trim(),
    message.senderName.trim(),
    normalizedText,
  ].join(':');
}

bool _isOversizedDomContainerCandidate({
  required String id,
  required String text,
  required String captureSource,
}) {
  if (captureSource != 'dom_probe' || !id.startsWith('dom:')) {
    return false;
  }
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 800) {
    return false;
  }
  final shellTokenCount = <String>[
    '搜索',
    '消息',
    '知识问答',
    '会议',
    '日历',
    '云文档',
    '通讯录',
    '邮箱',
    '任务',
    '工作台',
    'Ctrl+K',
  ].where(normalized.contains).length;
  return shellTokenCount >= 4;
}

ObservedMessageCandidate? _pendingMediaFeedCard(
  List<ObservedMessageCandidate> feedCardMessages,
  List<ObservedMessageCandidate> observedMessages, {
  Set<String> configuredSourceIds = const <String>{},
  Set<String> configuredSourceNames = const <String>{},
}) {
  for (final message in feedCardMessages) {
    if (message.captureSource != 'feed_card_probe') {
      continue;
    }
    if (!pendingMediaFeedCardMatchesConfiguredSources(
      conversationId: message.conversationId,
      conversationName: message.conversationName,
      configuredSourceIds: configuredSourceIds,
      configuredSourceNames: configuredSourceNames,
    )) {
      continue;
    }
    if (!_isMediaPreviewText(message.text) ||
        message.imageAttachments.isNotEmpty) {
      return null;
    }
    if (_hasExtractedMediaForFeedCard(message, observedMessages)) {
      return null;
    }
    return message;
  }
  return null;
}

Set<String> configuredMediaSourceIdsFromDiagnostics(
  Map<String, dynamic> diagnostics,
) {
  final sources = diagnostics['configured_media_sources'];
  if (sources is! List) {
    return const <String>{};
  }
  return sources
      .whereType<Map>()
      .map((source) => (source['conversation_id'] ?? '').toString().trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}

Set<String> configuredMediaSourceNamesFromDiagnostics(
  Map<String, dynamic> diagnostics,
) {
  final sources = diagnostics['configured_media_sources'];
  if (sources is! List) {
    return const <String>{};
  }
  return sources
      .whereType<Map>()
      .map(
        (source) => _normalizeConfiguredMediaSourceName(
          (source['conversation_name'] ?? '').toString(),
        ),
      )
      .where((value) => value.isNotEmpty)
      .toSet();
}

bool pendingMediaFeedCardMatchesConfiguredSources({
  required String conversationId,
  required String conversationName,
  required Set<String> configuredSourceIds,
  required Set<String> configuredSourceNames,
}) {
  if (configuredSourceIds.isEmpty && configuredSourceNames.isEmpty) {
    return true;
  }
  final normalizedId = conversationId.trim();
  if (normalizedId.isNotEmpty && configuredSourceIds.contains(normalizedId)) {
    return true;
  }
  final normalizedName = _normalizeConfiguredMediaSourceName(conversationName);
  return normalizedName.isNotEmpty &&
      configuredSourceNames.contains(normalizedName);
}

String _normalizeConfiguredMediaSourceName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

bool _hasExtractedMediaForFeedCard(
  ObservedMessageCandidate feedCardMessage,
  List<ObservedMessageCandidate> observedMessages,
) {
  final feedObservedAt = DateTime.tryParse(feedCardMessage.observedAt.trim());
  for (final observedMessage in observedMessages) {
    if (observedMessage.imageAttachments.isEmpty ||
        !_sameObservedConversation(feedCardMessage, observedMessage) ||
        observedMessage.captureSource.trim() == 'dom_probe') {
      continue;
    }
    final observedAt = DateTime.tryParse(observedMessage.observedAt.trim());
    if (feedObservedAt != null &&
        observedAt != null &&
        observedAt.isBefore(feedObservedAt)) {
      continue;
    }
    return true;
  }
  return false;
}

bool _sameObservedConversation(
  ObservedMessageCandidate left,
  ObservedMessageCandidate right,
) {
  final leftId = left.conversationId.trim();
  final rightId = right.conversationId.trim();
  if (leftId.isNotEmpty && rightId.isNotEmpty && leftId == rightId) {
    return true;
  }
  final leftName = left.conversationName.trim();
  final rightName = right.conversationName.trim();
  return leftName.isNotEmpty && rightName.isNotEmpty && leftName == rightName;
}

class _FeedCardObservations {
  const _FeedCardObservations({
    required this.conversations,
    required this.messages,
    required this.messageRawTexts,
  });

  final List<ObservedConversation> conversations;
  final List<ObservedMessageCandidate> messages;
  final Map<String, String> messageRawTexts;
}

class _ParsedFeedCard {
  const _ParsedFeedCard({
    required this.conversationName,
    required this.senderName,
    required this.messageText,
    required this.displayTime,
    this.imageAttachments = const <MessageImageAttachment>[],
  });

  final String conversationName;
  final String senderName;
  final String messageText;
  final String displayTime;
  final List<MessageImageAttachment> imageAttachments;
}

_FeedCardObservations _deriveObservationsFromFeedCards(
  dynamic value,
  dynamic observedAtValue,
) {
  if (value is! List) {
    return const _FeedCardObservations(
      conversations: <ObservedConversation>[],
      messages: <ObservedMessageCandidate>[],
      messageRawTexts: <String, String>{},
    );
  }

  final observedAt = observedAtValue?.toString() ?? '';
  final conversations = <ObservedConversation>[];
  final messages = <ObservedMessageCandidate>[];
  final messageRawTexts = <String, String>{};
  final seenConversationIds = <String>{};
  final seenMessageIds = <String>{};

  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final text = _normalizeFeedCardText((item['text'] ?? '').toString());
    if (text.isEmpty) {
      continue;
    }
    final parsed = _parseFeedCardText(text);
    if (parsed == null) {
      continue;
    }
    final rawImageAttachments = MessageImageAttachment.listFromJson(
      item['image_attachments'],
    );
    final imageAttachments = _isMediaPreviewText(parsed.messageText)
        ? rawImageAttachments
        : const <MessageImageAttachment>[];
    final parsedWithAttachments = imageAttachments.isEmpty
        ? parsed
        : _ParsedFeedCard(
            conversationName: parsed.conversationName,
            senderName: parsed.senderName,
            messageText: parsed.messageText,
            displayTime: parsed.displayTime,
            imageAttachments: imageAttachments,
          );

    final conversationId =
        'feed:${_stableHash(parsedWithAttachments.conversationName).toRadixString(16)}';
    final messageSource = _feedCardMessageSource(parsedWithAttachments);
    final messageId = 'feed:${_stableHash(messageSource).toRadixString(16)}';
    if (seenMessageIds.contains(messageId)) {
      continue;
    }
    seenMessageIds.add(messageId);
    messageRawTexts[messageId] = text;

    if (seenConversationIds.add(conversationId)) {
      conversations.add(
        ObservedConversation(
          id: conversationId,
          name: parsedWithAttachments.conversationName,
          type: 'unknown',
          lastMessagePreview: parsedWithAttachments.messageText,
          observedAt: observedAt,
        ),
      );
    }
    messages.add(
      ObservedMessageCandidate(
        id: messageId,
        conversationId: conversationId,
        conversationName: parsedWithAttachments.conversationName,
        senderName: parsedWithAttachments.senderName,
        messageType: parsedWithAttachments.imageAttachments.isEmpty
            ? 'text'
            : 'image',
        text: parsedWithAttachments.messageText.length > 500
            ? parsedWithAttachments.messageText.substring(0, 500)
            : parsedWithAttachments.messageText,
        observedAt: observedAt,
        captureSource: 'feed_card_probe',
        imageAttachments: parsedWithAttachments.imageAttachments,
      ),
    );
  }

  return _FeedCardObservations(
    conversations: List<ObservedConversation>.unmodifiable(conversations),
    messages: List<ObservedMessageCandidate>.unmodifiable(messages),
    messageRawTexts: Map<String, String>.unmodifiable(messageRawTexts),
  );
}

String _normalizeFeedCardText(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

_ParsedFeedCard? _parseFeedCardText(String text) {
  final normalized = _stripLeadingUnreadCount(text);
  final timePattern = RegExp(r'(?:\b\d{1,2}:\d{2}\b|昨天|前天|\d{1,2}月\d{1,2}日)');
  final match = timePattern.firstMatch(normalized);
  if (match == null) {
    return null;
  }

  var conversationName = normalized.substring(0, match.start).trim();
  var afterTime = normalized.substring(match.end).trim();
  var inlineSenderName = '';
  if (!afterTime.contains(RegExp(r'[:：]')) &&
      RegExp(r'(?:^|\s)机器人$').hasMatch(conversationName)) {
    inlineSenderName = '机器人';
    conversationName = conversationName
        .replaceFirst(RegExp(r'(?:^|\s)机器人$'), '')
        .trim();
  }
  conversationName = _stripTrailingConversationTags(conversationName);
  if (conversationName.isEmpty || afterTime.isEmpty) {
    return null;
  }

  var senderName = inlineSenderName;
  var messageText = afterTime;
  final colonIndex = afterTime.indexOf(RegExp(r'[:：]'));
  if (colonIndex > 0) {
    senderName = afterTime.substring(0, colonIndex).trim();
    messageText = afterTime.substring(colonIndex + 1).trim();
  } else {
    final parts = afterTime.split(' ');
    if (parts.length > 1 && _looksLikeSender(parts.first)) {
      senderName = parts.first.trim();
      messageText = parts.skip(1).join(' ').trim();
    }
  }

  if (messageText.isEmpty) {
    return null;
  }

  return _ParsedFeedCard(
    conversationName: conversationName,
    senderName: senderName,
    messageText: messageText,
    displayTime: match.group(0) ?? '',
  );
}

String _feedCardMessageSource(_ParsedFeedCard parsed) {
  final normalizedMessageText = parsed.messageText
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return <String>[
    parsed.conversationName,
    parsed.senderName,
    parsed.displayTime,
    normalizedMessageText,
  ].join(':');
}

String _stripLeadingUnreadCount(String value) {
  return value.replaceFirst(RegExp(r'^\d+\s+'), '').trim();
}

String _stripTrailingConversationTags(String value) {
  var result = value.trim();
  const tags = <String>['外部', '官方', '机器人'];
  var changed = true;
  while (changed) {
    changed = false;
    for (final tag in tags) {
      final pattern = RegExp('(?:^|\\s)$tag\$');
      if (pattern.hasMatch(result)) {
        result = result.replaceFirst(pattern, '').trim();
        changed = true;
      }
    }
  }
  return result;
}

bool _looksLikeSender(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 32) {
    return false;
  }
  return normalized.contains('机器人') ||
      normalized.startsWith('用户') ||
      RegExp(r'^[A-Za-z0-9_\-\u4e00-\u9fa5]+$').hasMatch(normalized);
}

bool _isMediaPreviewText(String value) {
  final normalized = value.trim();
  return normalized == '[图片]' ||
      normalized == '[鍥剧墖]' ||
      normalized == '[Image]' ||
      normalized == '[Video]' ||
      normalized == '[File]' ||
      normalized == '[视频]' ||
      normalized == '[文件]';
}

int _stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

DateTime? _readDateTime(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

Map<String, dynamic> _readDiagnostics(dynamic value) {
  if (value is! Map) {
    return const <String, dynamic>{};
  }
  return Map<String, dynamic>.unmodifiable(
    value.map((key, itemValue) => MapEntry(key.toString(), itemValue)),
  );
}

List<ObservedConversation> _deriveConversationsFromBodyText(
  String bodyText,
  dynamic observedAtValue,
) {
  final normalized = bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return const <ObservedConversation>[];
  }
  final marker = RegExp(r'工作台\s+(.+?)(?:\s+\d+\s+|\s+账号安全中心|\s+机器人)');
  final match = marker.firstMatch(normalized);
  final name = match?.group(1)?.trim() ?? '';
  if (name.isEmpty) {
    return const <ObservedConversation>[];
  }
  final observedAt = observedAtValue?.toString() ?? '';
  return <ObservedConversation>[
    ObservedConversation(
      id: 'body:${name.hashCode}',
      name: name,
      type: 'unknown',
      lastMessagePreview: normalized,
      observedAt: observedAt,
    ),
  ];
}

List<ObservedMessageCandidate> _deriveMessagesFromBodyText(
  String bodyText,
  dynamic observedAtValue,
  List<ObservedConversation> conversations,
) {
  final normalized = bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return const <ObservedMessageCandidate>[];
  }
  final conversation = conversations.isEmpty ? null : conversations.first;
  final observedAt = observedAtValue?.toString() ?? '';
  final idSource = '$observedAt:$normalized';
  return <ObservedMessageCandidate>[
    ObservedMessageCandidate(
      id: 'body:${idSource.hashCode}',
      conversationId: conversation?.id ?? '',
      conversationName: conversation?.name ?? '',
      senderName: '',
      messageType: 'text',
      text: normalized.length > 500 ? normalized.substring(0, 500) : normalized,
      observedAt: observedAt,
      captureSource: 'body_text_probe',
    ),
  ];
}
