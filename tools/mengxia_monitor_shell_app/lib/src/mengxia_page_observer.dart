String mengxiaManualWheelScrollFallbackScript({
  required double clientX,
  required double clientY,
  required double deltaX,
  required double deltaY,
}) {
  final x = _jsNumber(clientX);
  final y = _jsNumber(clientY);
  final dx = _jsNumber(deltaX);
  final dy = _jsNumber(deltaY);
  return '''
(() => {
  const helper = window.__wukongMengxiaManualWheelScroll;
  if (!helper || typeof helper.scrollAt !== 'function') {
    return { handled: false, reason: 'manual-wheel-helper-missing' };
  }
  const now = Date.now();
  if (helper.lastManualScrollAt && now - helper.lastManualScrollAt < 180) {
    return { handled: false, reason: 'manual-wheel-already-handled' };
  }
  return helper.scrollAt($x, $y, $dy, $dx, { source: 'flutter-pointer-signal' });
})();
''';
}

String _jsNumber(double value) =>
    value.isFinite ? value.toStringAsFixed(2) : '0';

const String mengxiaPageObserverScript = r'''
(() => {
  const stateKey = '__wukongMengxiaMonitorObserver';
  const post = (payload) => {
    try {
      if (window.chrome && window.chrome.webview) {
        window.chrome.webview.postMessage(JSON.stringify(payload));
      }
    } catch (_) {}
  };
  const notify = (reason) => post({
    type: 'mengxia_monitor_page_changed',
    reason,
    observed_at: new Date().toISOString()
  });
  const installManualWheelScroll = () => {
    const wheelStateKey = '__wukongMengxiaManualWheelScroll';
    const existingWheel = window[wheelStateKey];
    if (existingWheel && existingWheel.installed) {
      if (typeof existingWheel.ensureStyles === 'function') {
        existingWheel.ensureStyles();
      }
      return existingWheel;
    }
    const styleId = 'wukong-mengxia-scrollbar-style';
    const indicatorId = 'wukong-mengxia-scroll-indicator';
    let api = null;
    let notifyTimer = 0;

    const ensureStyles = () => {
      if (!document || document.getElementById(styleId)) return;
      const root = document.head || document.documentElement;
      if (!root) return;
      const style = document.createElement('style');
      style.id = styleId;
      style.textContent = `
        html, body, * {
          scrollbar-width: auto !important;
          scrollbar-color: rgba(27, 111, 92, 0.78) rgba(27, 111, 92, 0.12) !important;
        }
        html::-webkit-scrollbar,
        body::-webkit-scrollbar,
        *::-webkit-scrollbar {
          width: 12px !important;
          height: 12px !important;
          display: block !important;
        }
        html::-webkit-scrollbar-track,
        body::-webkit-scrollbar-track,
        *::-webkit-scrollbar-track {
          background: rgba(27, 111, 92, 0.10) !important;
          border-radius: 999px !important;
        }
        html::-webkit-scrollbar-thumb,
        body::-webkit-scrollbar-thumb,
        *::-webkit-scrollbar-thumb {
          background: rgba(27, 111, 92, 0.78) !important;
          border: 3px solid rgba(255, 255, 255, 0.76) !important;
          border-radius: 999px !important;
          min-height: 30px !important;
        }
        html::-webkit-scrollbar-thumb:hover,
        body::-webkit-scrollbar-thumb:hover,
        *::-webkit-scrollbar-thumb:hover {
          background: rgba(13, 83, 70, 0.92) !important;
        }
        #${indicatorId} {
          position: fixed !important;
          top: 88px !important;
          right: 8px !important;
          bottom: 18px !important;
          width: 8px !important;
          z-index: 2147483647 !important;
          pointer-events: none !important;
          border-radius: 999px !important;
          background: rgba(27, 111, 92, 0.10) !important;
          box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.82), 0 10px 24px rgba(15, 42, 35, 0.18) !important;
          opacity: 0 !important;
          transition: opacity 150ms ease !important;
        }
        #${indicatorId}.is-visible {
          opacity: 1 !important;
        }
        #${indicatorId} .wukong-mengxia-scroll-indicator__thumb {
          position: absolute !important;
          left: 1px !important;
          right: 1px !important;
          min-height: 28px !important;
          border-radius: 999px !important;
          background: linear-gradient(180deg, rgba(34, 139, 112, 0.96), rgba(10, 82, 69, 0.96)) !important;
          box-shadow: 0 2px 8px rgba(5, 45, 38, 0.28) !important;
        }
      `;
      root.appendChild(style);
    };

    const rootScroller = () => (
      document.scrollingElement ||
      document.documentElement ||
      document.body
    );

    const isElement = (node) => node && node.nodeType === Node.ELEMENT_NODE;

    const allowsScroll = (node) => {
      if (!isElement(node)) return false;
      try {
        const style = window.getComputedStyle(node);
        const overflow = `${style.overflowY || ''} ${style.overflow || ''}`;
        return !/hidden/i.test(overflow) || node.scrollHeight > node.clientHeight + 40;
      } catch (_) {
        return true;
      }
    };

    const canScroll = (node) => {
      if (!node || !allowsScroll(node)) return false;
      const height = node.clientHeight || 0;
      const scrollHeight = node.scrollHeight || 0;
      return scrollHeight > height + 6;
    };

    const parentOf = (node) => {
      if (!node) return null;
      if (node.parentElement) return node.parentElement;
      const root = node.getRootNode && node.getRootNode();
      return root && root.host ? root.host : null;
    };

    const pointInside = (rect, x, y) => (
      Number.isFinite(x) &&
      Number.isFinite(y) &&
      rect.left <= x &&
      x <= rect.right &&
      rect.top <= y &&
      y <= rect.bottom
    );

    const scrollableCandidates = (x, y, target) => {
      const candidates = [];
      let start = null;
      if (Number.isFinite(x) && Number.isFinite(y) && document.elementFromPoint) {
        start = document.elementFromPoint(x, y);
      }
      if (!start && target) {
        start = isElement(target) ? target : target.parentElement;
      }
      for (let node = start; node && node !== document; node = parentOf(node)) {
        if (canScroll(node)) candidates.push(node);
      }
      const root = rootScroller();
      if (canScroll(root) && !candidates.includes(root)) {
        candidates.push(root);
      }
      const containingVisibleScrollable = Array.from(document.querySelectorAll('*'))
        .filter((node) => {
          if (!canScroll(node) || candidates.includes(node)) return false;
          try {
            const rect = node.getBoundingClientRect();
            return rect.width > 40 &&
              rect.height > 40 &&
              pointInside(rect, x, y);
          } catch (_) {
            return false;
          }
        })
        .sort((a, b) => {
          const aRect = a.getBoundingClientRect();
          const bRect = b.getBoundingClientRect();
          return (aRect.width * aRect.height) - (bRect.width * bRect.height);
        })
        .slice(0, 24);
      for (const node of containingVisibleScrollable) {
        if (!candidates.includes(node)) candidates.push(node);
      }
      return candidates;
    };

    const ensureIndicator = () => {
      let indicator = document.getElementById(indicatorId);
      if (indicator) return indicator;
      const root = document.body || document.documentElement;
      if (!root) return null;
      indicator = document.createElement('div');
      indicator.id = indicatorId;
      const thumb = document.createElement('div');
      thumb.className = 'wukong-mengxia-scroll-indicator__thumb';
      indicator.appendChild(thumb);
      root.appendChild(indicator);
      return indicator;
    };

    const updateIndicator = (scroller) => {
      const indicator = ensureIndicator();
      if (!indicator || !scroller) return;
      const thumb = indicator.querySelector('.wukong-mengxia-scroll-indicator__thumb');
      if (!thumb) return;
      const maxTop = Math.max(0, (scroller.scrollHeight || 0) - (scroller.clientHeight || 0));
      const ratio = maxTop <= 0 ? 1 : Math.min(1, Math.max(0, (scroller.scrollTop || 0) / maxTop));
      const visibleRatio = Math.min(
        1,
        Math.max(0.10, (scroller.clientHeight || 1) / Math.max(scroller.scrollHeight || 1, 1))
      );
      const trackHeight = Math.max(48, indicator.clientHeight || Math.floor(window.innerHeight * 0.72));
      const thumbHeight = Math.max(28, Math.floor(trackHeight * visibleRatio));
      const top = Math.floor((trackHeight - thumbHeight) * ratio);
      thumb.style.height = `${thumbHeight}px`;
      thumb.style.transform = `translateY(${top}px)`;
      indicator.classList.add('is-visible');
      clearTimeout(indicator.__wukongHideTimer);
      indicator.__wukongHideTimer = setTimeout(() => {
        indicator.classList.remove('is-visible');
      }, 1100);
    };

    const scheduleScrollNotify = () => {
      clearTimeout(notifyTimer);
      notifyTimer = setTimeout(() => notify('manual-wheel-scroll'), 240);
    };

    const normalizedDelta = (value, mode, scroller) => {
      if (!Number.isFinite(value) || value === 0) return 0;
      if (mode === 1) return value * 40;
      if (mode === 2) return value * Math.max(320, scroller.clientHeight || window.innerHeight || 600);
      return value;
    };

    const scrollNode = (node, deltaY, deltaX, deltaMode) => {
      const dy = normalizedDelta(deltaY, deltaMode, node);
      const dx = normalizedDelta(deltaX, deltaMode, node);
      const maxTop = Math.max(0, (node.scrollHeight || 0) - (node.clientHeight || 0));
      const maxLeft = Math.max(0, (node.scrollWidth || 0) - (node.clientWidth || 0));
      const beforeTop = node.scrollTop || 0;
      const beforeLeft = node.scrollLeft || 0;
      try {
        node.scrollBy({ top: dy, left: dx, behavior: 'auto' });
      } catch (_) {
        if (maxTop > 0 && dy !== 0) {
          node.scrollTop = Math.max(0, Math.min(maxTop, beforeTop + dy));
        }
        if (maxLeft > 0 && dx !== 0) {
          node.scrollLeft = Math.max(0, Math.min(maxLeft, beforeLeft + dx));
        }
      }
      return (node.scrollTop || 0) !== beforeTop || (node.scrollLeft || 0) !== beforeLeft;
    };

    const scrollAt = (x, y, deltaY, deltaX = 0, options = {}) => {
      ensureStyles();
      const target = options.target || null;
      const deltaMode = options.deltaMode || 0;
      const candidates = scrollableCandidates(x, y, target);
      for (const node of candidates) {
        if (scrollNode(node, deltaY, deltaX, deltaMode)) {
          if (api) {
            api.lastManualScrollAt = Date.now();
            api.lastScroller = node;
          }
          updateIndicator(node);
          scheduleScrollNotify();
          return { handled: true, reason: 'manual-wheel-scroll', source: options.source || 'unknown' };
        }
      }
      return { handled: false, reason: 'no-scrollable-target', source: options.source || 'unknown' };
    };

    const onWheel = (event) => {
      if (api) api.lastWheelAt = Date.now();
      const result = scrollAt(
        event.clientX,
        event.clientY,
        event.deltaY,
        event.deltaX,
        { target: event.target, deltaMode: event.deltaMode, source: 'dom-wheel' }
      );
      if (result.handled) {
        event.preventDefault();
        event.stopPropagation();
      }
    };

    api = {
      installed: true,
      lastWheelAt: 0,
      lastManualScrollAt: 0,
      lastScroller: null,
      ensureStyles,
      scrollAt,
      disconnect: () => {
        document.removeEventListener('wheel', onWheel, { capture: true });
        clearTimeout(notifyTimer);
      }
    };
    ensureStyles();
    if (!document.getElementById(styleId)) {
      document.addEventListener('DOMContentLoaded', ensureStyles, { once: true });
    }
    document.addEventListener('wheel', onWheel, { capture: true, passive: false });
    window[wheelStateKey] = api;
    return api;
  };
  const manualWheelScroll = installManualWheelScroll();
  const existing = window[stateKey];
  if (existing && existing.installed) {
    return { installed: true, reused: true, manual_wheel_scroll: true };
  }
  const observer = new MutationObserver(() => notify('mutation'));
  observer.observe(document.documentElement || document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });
  window[stateKey] = {
    installed: true,
    manualWheelScroll,
    disconnect: () => {
      observer.disconnect();
      if (manualWheelScroll && typeof manualWheelScroll.disconnect === 'function') {
        manualWheelScroll.disconnect();
      }
    }
  };
  notify('installed');
  return { installed: true, reused: false, manual_wheel_scroll: true };
})();
''';

const String mengxiaPageProbeScript = r'''
(() => {
  const textOf = (node) => (node && node.innerText ? node.innerText : '')
    .replace(/\s+/g, ' ')
    .trim();
  const rawTextOf = (node) => (node && (node.innerText || node.textContent)
    ? (node.innerText || node.textContent)
    : '').trim();
  const attrOf = (node, names) => {
    for (const name of names) {
      const value = node.getAttribute && node.getAttribute(name);
      if (value && String(value).trim()) return String(value).trim();
    }
    return '';
  };
  const shortHash = (value) => {
    let hash = 0;
    for (let i = 0; i < value.length; i += 1) {
      hash = ((hash << 5) - hash + value.charCodeAt(i)) | 0;
    }
    return Math.abs(hash).toString(36);
  };
  const sourceNameBlocklist = new Set([
    '首页', '我的', '设置', '搜索', '返回', '登录', '注册', '确定', '取消',
    '发送', '评论', '点赞', '分享', '收藏', '更多', '全部', '推荐', '加载中',
    '暂无数据', '请输入', '上一页', '下一页', '开通', '开通卡密', '卡密',
    '购买', '充值', '续费', '会员', '超级会员', '立即开通', '我知道了',
    '账号', '请输入账号', '密码', '请输入密码', '验证码', '请输入验证码',
    '忘记密码', '节点地址', '保存', '配置', '每日签到', '立即前往APP签到',
    '每天需要签到使用', '每天仅需签到一次', 'VIP特权', '搜索直播间名称',
    '搜索直播间消息', '选择日期', '向右滑动->', '公告', '历史记录'
  ]);
  const normalizeSourceName = (value) => String(value || '')
    .replace(/\s+/g, ' ')
    .replace(/(?:99\+|\d{1,4}|new|NEW|未读|已读)$/g, '')
    .trim();
  const isLikelySourceName = (value) => {
    const rawValue = String(value || '');
    if (/\\n|\\r|\n|\r/.test(rawValue)) return false;
    const name = normalizeSourceName(rawValue);
    if (name.length < 2 || name.length > 40) return false;
    if (sourceNameBlocklist.has(name)) return false;
    if (/\[图片\]|\[文件\]|签到|搜索直播间|立即前往APP|每天需要|VIP特权/.test(name)) return false;
    if (/^【[^】]+】/.test(name)) return false;
    if (/祝大家|周末愉快|回调|老师还是|前期涨太多|推老奶奶|下午|开始回程|其实/.test(name)) return false;
    if (/[：:]/.test(name)) return false;
    if (/[，。！？,.!?；;]/.test(name)) return false;
    if (/^\d{1,4}([-/]\d{0,2}){1,2}$/.test(name)) return false;
    if (/\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}:\d{2}/.test(name)) return false;
    return /[\u4e00-\u9fffA-Za-z0-9]/.test(name);
  };
  const addSourceCandidate = (items, seen, node, rawName) => {
    const name = normalizeSourceName(rawName);
    if (!isLikelySourceName(name)) return;
    const id = attrOf(node, [
      'data-source-id', 'data-group-id', 'data-room-id', 'data-circle-id',
      'data-topic-id', 'data-category-id', 'data-id'
    ]) || `fallback:${name}`;
    const key = `${id}\n${name}`;
    if (seen.has(key)) return;
    seen.add(key);
    items.push({
      id,
      name,
      type: 'unknown',
      last_message_preview: name
    });
  };
  const isVisibleSourceNode = (node) => {
    if (!node || node.nodeType !== 1) return false;
    const style = window.getComputedStyle(node);
    if (!style || style.display === 'none' || style.visibility === 'hidden'
        || Number(style.opacity || '1') === 0) {
      return false;
    }
    const rect = node.getBoundingClientRect();
    if (!rect || rect.width < 4 || rect.height < 4) return false;
    const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
    if (rect.bottom < 0 || rect.right < 0) return false;
    if (viewportWidth > 0 && rect.left > viewportWidth) return false;
    if (viewportHeight > 0 && rect.top > viewportHeight) return false;
    return true;
  };
  const isInsideMessageLikeNode = (node) => {
    const blocked = node.closest && node.closest(
      '[data-message-id],[data-msg-id],[class*="message"],[class*="msg"],'
      + '[class*="comment"],[class*="reply"],[class*="answer"]'
    );
    return !!blocked;
  };
  const sourceNodeHint = (node) => {
    const value = [
      node.getAttribute && node.getAttribute('class'),
      node.getAttribute && node.getAttribute('id'),
      node.getAttribute && node.getAttribute('role'),
      node.getAttribute && node.getAttribute('aria-label'),
      node.getAttribute && node.getAttribute('title')
    ].filter(Boolean).join(' ').toLowerCase();
    return value;
  };
  const hasSourceLikeContext = (node) => {
    const sourceLike = node.closest && node.closest(
      'button,a,[role="tab"],[role="menuitem"],[role="listitem"],[onclick],'
      + '[data-source-id],[data-group-id],[data-room-id],[data-circle-id],'
      + '[data-topic-id],[data-category-id],[data-channel-id],'
      + '[class*="group"],[class*="room"],[class*="circle"],[class*="topic"],'
      + '[class*="category"],[class*="cate"],[class*="channel"],'
      + '[class*="column"],[class*="plate"],[class*="nav"],[class*="menu"],'
      + '[class*="tab"],[class*="side"],[class*="list"],[class*="item"],'
      + '[class*="cell"]'
    );
    return !!sourceLike;
  };
  const isLikelySourceColumn = (node) => {
    if (!node || !node.closest) return false;
    const sourceColumn = node.closest(
      '[data-source-id],[data-group-id],[data-room-id],[data-circle-id],'
      + '[data-topic-id],[data-category-id],[data-channel-id],'
      + '[class*="group"],[class*="room"],[class*="circle"],[class*="topic"],'
      + '[class*="category"],[class*="cate"],[class*="channel"],'
      + '[class*="column"],[class*="plate"],[class*="nav"],[class*="menu"],'
      + '[class*="tab"],[class*="side"]'
    );
    if (sourceColumn) return true;
    const listItem = node.closest('[role="tab"],[role="menuitem"],[role="listitem"],[class*="list"],[class*="item"],[class*="cell"]');
    if (!listItem) return false;
    const rect = listItem.getBoundingClientRect();
    const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
    return viewportWidth <= 0 || rect.left < Math.max(360, viewportWidth * 0.42);
  };
  const hasVisibleChildWithSameText = (node, text) => {
    for (const child of Array.from(node.children || [])) {
      if (!isVisibleSourceNode(child)) continue;
      if (rawTextOf(child) === text) return true;
    }
    return false;
  };
  const collectLeafSourceCandidateNodes = () => {
    const root = document.body || document.documentElement;
    if (!root) return [];
    const selector = [
      'uni-view', 'uni-text', 'view', 'text', 'li', 'span', 'div', 'p',
      'button', 'a', '[role="tab"]', '[role="menuitem"]', '[role="listitem"]'
    ].join(',');
    const nodes = Array.from(root.querySelectorAll(selector)).slice(0, 2600);
    const items = [];
    const viewportWidth = window.innerWidth || document.documentElement.clientWidth || 0;
    const viewportHeight = window.innerHeight || document.documentElement.clientHeight || 0;
    for (const node of nodes) {
      if (items.length >= 160) break;
      if (!isVisibleSourceNode(node) || isInsideMessageLikeNode(node)) continue;
      const raw = rawTextOf(node);
      if (!raw || raw.length > 140) continue;
      const lines = raw.split(/\n+/).map((line) => line.trim()).filter(Boolean);
      if (lines.length < 1 || lines.length > 6) continue;
      if (hasVisibleChildWithSameText(node, raw)) continue;
      const rect = node.getBoundingClientRect();
      const contextHint = sourceNodeHint(node);
      const sourceContext = hasSourceLikeContext(node);
      const sourceColumn = isLikelySourceColumn(node);
      const nearNavigationArea =
        rect.top < Math.min(520, Math.max(220, viewportHeight * 0.55))
        || rect.left < Math.min(420, Math.max(240, viewportWidth * 0.48))
        || rect.height <= 58;
      const hintLooksSource =
        /group|room|circle|topic|category|cate|channel|column|plate|nav|menu|tab|side|list|item|cell/.test(contextHint);
      if (!sourceColumn) continue;
      if (!sourceContext && !hintLooksSource && !nearNavigationArea) continue;
      for (const line of lines) {
        if (items.length >= 160) break;
        items.push({ node, text: line });
      }
    }
    return items;
  };
  const imageAttachmentsOf = (node) => {
    const images = Array.from(node.querySelectorAll('img')).slice(0, 6);
    const attachments = [];
    const seenImages = new Set();
    for (const image of images) {
      const sourceUrl = image.currentSrc || image.src || image.getAttribute('data-src')
        || image.getAttribute('data-original') || '';
      const normalized = String(sourceUrl || '').trim();
      if (!normalized || seenImages.has(normalized)) continue;
      const lower = normalized.toLowerCase();
      if (!lower.startsWith('http://') && !lower.startsWith('https://')
          && !lower.startsWith('data:image/')) {
        continue;
      }
      seenImages.add(normalized);
      attachments.push({
        source_url: normalized,
        local_path: '',
        width: Number(image.naturalWidth || image.width || 0) || 0,
        height: Number(image.naturalHeight || image.height || 0) || 0
      });
    }
    return attachments;
  };
  const bodyText = textOf(document.body || document.documentElement);
  const normalizedRuntimeUrl = String(window.location.href || '').toLowerCase();
  const normalizedTitle = String(document.title || '').toLowerCase();
  const loginLikePage =
    normalizedRuntimeUrl.includes('login') ||
    normalizedRuntimeUrl.includes('passport') ||
    normalizedRuntimeUrl.includes('account') ||
    normalizedTitle.includes('login') ||
    normalizedTitle.includes('登录') ||
    (bodyText.includes('账号') && bodyText.includes('密码') && bodyText.includes('登录'));
  const conversationNodes = loginLikePage ? [] : Array.from(document.querySelectorAll(
    '[data-conversation-id],[data-chat-id],[data-session-id],'
    + '[class*="conversation"],[class*="session"],[class*="chat"]'
  )).slice(0, 30);
  const conversations = [];
  const seenConversations = new Set();
  for (const node of conversationNodes) {
    const text = textOf(node);
    if (!text || text.length < 2) continue;
    const id = attrOf(node, ['data-conversation-id', 'data-chat-id', 'data-session-id', 'data-id'])
      || `dom:${shortHash(text.slice(0, 120))}`;
    if (seenConversations.has(id)) continue;
    seenConversations.add(id);
    conversations.push({
      id,
      name: text.split(/[：:\n]/)[0].slice(0, 80),
      type: 'unknown',
      last_message_preview: text.slice(0, 160)
    });
  }
  const sourceCandidateNodes = loginLikePage ? [] : Array.from(document.querySelectorAll(
    '[data-source-id],[data-group-id],[data-room-id],[data-circle-id],'
    + '[data-topic-id],[data-category-id],[data-channel-id],[role="tab"],[role="menuitem"],'
    + '[role="listitem"],button,a,[class*="group"],[class*="room"],'
    + '[class*="circle"],[class*="topic"],[class*="category"],'
    + '[class*="cate"],[class*="channel"],[class*="column"],'
    + '[class*="plate"],[class*="nav"],[class*="menu"],[class*="tab"],'
    + '[class*="side"],[class*="list"],[class*="item"],[class*="cell"]'
  )).slice(0, 600);
  const sourceCandidates = [];
  const seenSourceCandidates = new Set();
  for (const node of sourceCandidateNodes) {
    if (!isLikelySourceColumn(node)) continue;
    const raw = rawTextOf(node);
    if (!raw || raw.length > 600) continue;
    const lines = raw.split(/\n+/).map((line) => line.trim()).filter(Boolean);
    if (lines.length > 0 && lines.length <= 12) {
      for (const line of lines) {
        addSourceCandidate(sourceCandidates, seenSourceCandidates, node, line);
      }
    } else {
      addSourceCandidate(sourceCandidates, seenSourceCandidates, node, raw);
    }
    if (sourceCandidates.length >= 240) break;
  }
  const fallbackSourceCandidateNodes = loginLikePage
    ? []
    : collectLeafSourceCandidateNodes();
  for (const item of fallbackSourceCandidateNodes) {
    addSourceCandidate(sourceCandidates, seenSourceCandidates, item.node, item.text);
    if (sourceCandidates.length >= 320) break;
  }
  const messageNodes = loginLikePage ? [] : Array.from(document.querySelectorAll(
    '[data-message-id],[data-msg-id],[class*="message"],[class*="msg"]'
  )).slice(-30);
  const events = [];
  const seenEvents = new Set();
  const fallbackConversation = conversations[0] || {
    id: '',
    name: document.title || 'Mengxia',
    type: 'unknown'
  };
  for (const node of messageNodes) {
    const text = textOf(node);
    const imageAttachments = imageAttachmentsOf(node);
    if ((!text || text.length < 1) && imageAttachments.length < 1) continue;
    if (text.length > 2000) continue;
    const messageId = attrOf(node, ['data-message-id', 'data-msg-id', 'data-id'])
      || `dom:${shortHash(text || imageAttachments.map((item) => item.source_url).join('|'))}`;
    const conversationId = attrOf(node, ['data-conversation-id', 'data-chat-id', 'data-session-id'])
      || fallbackConversation.id;
    const key = `${conversationId}:${messageId}:${shortHash(text || imageAttachments.map((item) => item.source_url).join('|'))}`;
    if (seenEvents.has(key)) continue;
    seenEvents.add(key);
    events.push({
      event_id: key,
      dedupe_key: key,
      conversation_id: conversationId,
      conversation_name: fallbackConversation.name || document.title || 'Mengxia',
      conversation_type: fallbackConversation.type || 'unknown',
      message_id: messageId,
      sender_name: '',
      message_type: imageAttachments.length > 0 && !text ? 'image' : 'text',
      text,
      capture_source: 'dom_probe',
      image_attachments: imageAttachments
    });
  }
  return {
    runtime_url: window.location.href,
    page_title: document.title || '',
    body_text: bodyText.slice(0, 5000),
    has_forwardable_content: conversations.length > 0 || events.length > 0
      || sourceCandidates.length > 0,
    conversations,
    source_candidates: sourceCandidates,
    events,
    observed_at: new Date().toISOString(),
    probe_diagnostics: {
      conversation_count: conversations.length,
      source_candidate_count: sourceCandidates.length,
      fallback_source_candidate_count: loginLikePage ? 0 : fallbackSourceCandidateNodes.length,
      login_like_page: loginLikePage,
      event_count: events.length
    }
  };
})();
''';

class MengxiaPageObserverMessage {
  const MengxiaPageObserverMessage({
    required this.type,
    required this.reason,
    required this.observedAt,
  });

  final String type;
  final String reason;
  final DateTime? observedAt;

  bool get isPageChanged => type == 'mengxia_monitor_page_changed';

  factory MengxiaPageObserverMessage.fromJson(Map<String, Object?> json) {
    return MengxiaPageObserverMessage(
      type: (json['type'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      observedAt: DateTime.tryParse((json['observed_at'] ?? '').toString()),
    );
  }
}
