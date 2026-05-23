const WK_PWA_CACHE = 'wk-pwa-offline-v1';
const WK_PWA_ASSETS = [
  'offline.html',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-maskable-192.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(WK_PWA_CACHE)
      .then((cache) => cache.addAll(WK_PWA_ASSETS))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys
            .filter((key) => key.startsWith('wk-pwa-offline-') && key !== WK_PWA_CACHE)
            .map((key) => caches.delete(key)),
        ),
      )
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.mode !== 'navigate') {
    return;
  }
  event.respondWith(
    fetch(event.request).catch(() =>
      caches
        .open(WK_PWA_CACHE)
        .then((cache) => cache.match('offline.html'))
        .then(
          (response) =>
            response ||
            new Response('Offline', {
              status: 503,
              headers: { 'Content-Type': 'text/plain; charset=utf-8' },
            }),
        ),
    ),
  );
});

function parseNotificationClickData(rawData) {
  if (!rawData) {
    return {};
  }
  if (typeof rawData === 'string') {
    try {
      const parsed = JSON.parse(rawData);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch (_) {
      return {};
    }
  }
  return typeof rawData === 'object' ? rawData : {};
}

function normalizeNotificationClickUrl(rawUrl) {
  if (typeof rawUrl !== 'string') {
    return '/';
  }
  const trimmed = rawUrl.trim();
  if (!trimmed) {
    return '/';
  }
  try {
    const url = new URL(trimmed, self.location.origin);
    if (url.origin !== self.location.origin) {
      return '/';
    }
    return `${url.pathname}${url.search}${url.hash}`;
  } catch (_) {
    return '/';
  }
}

function normalizeChannelType(value) {
  if (typeof value === 'number' && Number.isFinite(value)) {
    return String(Math.trunc(value));
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (/^\d+$/.test(trimmed)) {
      return trimmed;
    }
  }
  return '';
}

function resolveConversationRoute(data) {
  const payload = data && typeof data.payload === 'object' ? data.payload : {};
  const channelId = firstNonEmptyString(
    data.channel_id,
    data.channelId,
    data.conversation_id,
    payload.channel_id,
    payload.channelId,
    payload.conversation_id,
  );
  const channelType = normalizeChannelType(
    data.channel_type ||
      data.channelType ||
      payload.channel_type ||
      payload.channelType,
  );
  if (!channelId || !channelType) {
    return '';
  }
  return `/chat/${encodeURIComponent(channelType)}/${encodeURIComponent(channelId)}`;
}

function resolveNotificationClickTarget(data) {
  const payload = data && typeof data.payload === 'object' ? data.payload : {};
  const explicitTarget = normalizeNotificationClickUrl(
    data.url ||
      data.click_action ||
      data.clickAction ||
      payload.url ||
      payload.click_action ||
      payload.clickAction ||
      '/',
  );
  if (explicitTarget !== '/') {
    return explicitTarget;
  }
  return resolveConversationRoute(data) || '/';
}

function parsePushNotificationData(event) {
  if (!event.data) {
    return {};
  }
  try {
    const parsed = event.data.json();
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch (_) {
    try {
      return { body: event.data.text() };
    } catch (_) {
      return {};
    }
  }
}

function firstNonEmptyString(...values) {
  for (const value of values) {
    if (typeof value !== 'string') {
      continue;
    }
    const trimmed = value.trim();
    if (trimmed) {
      return trimmed;
    }
  }
  return '';
}

function buildPushNotificationPayload(rawData) {
  const data = rawData && typeof rawData.data === 'object' ? rawData.data : {};
  const notification =
    rawData && typeof rawData.notification === 'object' ? rawData.notification : {};
  const payload = rawData && typeof rawData.payload === 'object'
    ? rawData.payload
    : data && typeof data.payload === 'object'
      ? data.payload
      : {};
  const title = firstNonEmptyString(
    rawData.title,
    notification.title,
    data.title,
    payload.title,
    payload.sender_name,
    payload.conversation_name,
    '信息平权',
  );
  const body = firstNonEmptyString(
    rawData.body,
    notification.body,
    data.body,
    payload.body,
    payload.content,
    '收到一条新消息',
  );
  const channelType =
    payload.channel_type ||
    payload.channelType ||
    data.channel_type ||
    data.channelType ||
    rawData.channel_type ||
    rawData.channelType ||
    '';
  const channelId = firstNonEmptyString(
    payload.channel_id,
    payload.channelId,
    data.channel_id,
    data.channelId,
    rawData.channel_id,
    rawData.channelId,
  );
  const messageId = firstNonEmptyString(
    payload.message_id,
    payload.messageId,
    data.message_id,
    data.messageId,
    rawData.message_id,
    rawData.messageId,
  );
  const tag = firstNonEmptyString(
    rawData.tag,
    messageId,
    channelId && channelType ? `wk-message-${channelType}-${channelId}` : '',
    'wk-message',
  );

  return {
    title,
    options: {
      body,
      tag,
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-maskable-192.png',
      data: {
        ...rawData,
        payload: Object.keys(payload).length > 0 ? payload : data,
        title,
        body,
      },
      renotify: true,
      requireInteraction: false,
      vibrate: [120, 60, 120],
    },
  };
}

function broadcastClientMessage(message) {
  return self.clients
    .matchAll({ type: 'window', includeUncontrolled: true })
    .then((clientList) => {
      for (const client of clientList) {
        client.postMessage(message);
      }
    });
}

self.addEventListener('push', (event) => {
  const rawData = parsePushNotificationData(event);
  const notification = buildPushNotificationPayload(rawData);
  event.waitUntil(
    self.registration.showNotification(notification.title, notification.options),
  );
});

self.addEventListener('pushsubscriptionchange', (event) => {
  event.waitUntil(
    broadcastClientMessage({
      type: 'wk.push.subscriptionchange',
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const data = parseNotificationClickData(event.notification.data);
  const targetUrl = resolveNotificationClickTarget(data);
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        for (const client of clientList) {
          if ('focus' in client) {
            client.postMessage({
              type: 'wk.notification.click',
              payload: data,
            });
            if ('navigate' in client) {
              return client.navigate(targetUrl).then((navigatedClient) => {
                const focusedClient = navigatedClient || client;
                if ('focus' in focusedClient) {
                  return focusedClient.focus();
                }
                return focusedClient;
              });
            }
            return client.focus();
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow(targetUrl);
        }
        return undefined;
      }),
  );
});
