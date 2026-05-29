const CACHE_NAME = 'wk-im-shell-v1';
const FALLBACK_TARGET = '/im/conversations';
const SHELL_ASSETS = ['/im/offline.html', '/im/manifest.webmanifest'];

function normalizeChannelType(value) {
  const channelType = String(value ?? '').trim();
  return channelType === '1' || channelType === '2' ? channelType : null;
}

function normalizeChannelId(value) {
  const channelId = String(value ?? '').trim();
  return channelId || null;
}

function field(payload, snakeName, camelName) {
  return payload?.[snakeName] ?? payload?.[camelName] ?? payload?.payload?.[snakeName] ?? payload?.payload?.[camelName];
}

function explicitTarget(payload) {
  const url = payload?.url ?? payload?.payload?.url;

  if (typeof url !== 'string') {
    return null;
  }

  const trimmedUrl = url.trim();
  return trimmedUrl.startsWith('/im/') ? trimmedUrl : null;
}

function resolveNotificationTarget(payload = {}) {
  const explicitUrl = explicitTarget(payload);

  if (explicitUrl) {
    return explicitUrl;
  }

  const channelType = normalizeChannelType(field(payload, 'channel_type', 'channelType'));
  const channelId = normalizeChannelId(field(payload, 'channel_id', 'channelId'));

  if (!channelType || !channelId) {
    return FALLBACK_TARGET;
  }

  return `/im/chat/${encodeURIComponent(channelType)}/${encodeURIComponent(channelId)}`;
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE_NAME)
      .then((cache) => cache.addAll(SHELL_ASSETS))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  if (event.request.mode !== 'navigate') {
    return;
  }

  event.respondWith(
    fetch(event.request).catch(async () => {
      const cachedOfflinePage = await caches.match('/im/offline.html');
      return cachedOfflinePage ?? Response.error();
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = resolveNotificationTarget(event.notification.data);

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async (clientList) => {
      for (const client of clientList) {
        const clientUrl = new URL(client.url);
        if (clientUrl.pathname.startsWith('/im/') && 'focus' in client) {
          await client.focus();
          if ('navigate' in client) {
            return client.navigate(targetUrl);
          }
          return undefined;
        }
      }

      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }

      return undefined;
    }),
  );
});
