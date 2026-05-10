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
    final feedCardObservations = _deriveObservationsFromFeedCards(
      feedCards,
      json['observed_at'],
    );
    final pendingMediaFeedCard = _pendingMediaFeedCard(
      feedCardObservations.messages,
      observedMessages,
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
      probeDiagnostics: _readDiagnostics(json['probe_diagnostics']),
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
  List<ObservedMessageCandidate> observedMessages,
) {
  for (final message in feedCardMessages) {
    if (message.captureSource != 'feed_card_probe') {
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

bool _hasExtractedMediaForFeedCard(
  ObservedMessageCandidate feedCardMessage,
  List<ObservedMessageCandidate> observedMessages,
) {
  final feedObservedAt = DateTime.tryParse(feedCardMessage.observedAt.trim());
  for (final observedMessage in observedMessages) {
    if (observedMessage.imageAttachments.isEmpty ||
        !_sameObservedConversation(feedCardMessage, observedMessage)) {
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
