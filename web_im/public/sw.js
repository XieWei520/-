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

  if (!trimmedUrl) {
    return null;
  }

  try {
    const parsedUrl = new URL(trimmedUrl, self.location.origin);
    if (parsedUrl.origin === self.location.origin && parsedUrl.pathname.startsWith('/im/')) {
      return `${parsedUrl.pathname}${parsedUrl.search}${parsedUrl.hash}`;
    }
  } catch {
    return null;
  }

  return null;
}

// Keep this resolver aligned with src/push/notificationTarget.ts.
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
      .catch(() => undefined)
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
      return cachedOfflinePage ?? new Response('当前离线，请稍后重试。', {
        status: 503,
        headers: { 'Content-Type': 'text/plain; charset=utf-8' },
      });
    }),
  );
});

async function openTargetWindow(targetUrl) {
  if (!self.clients.openWindow) {
    return undefined;
  }

  try {
    return await self.clients.openWindow(targetUrl);
  } catch {
    return undefined;
  }
}

async function focusOrNavigateClient(client, targetUrl) {
  try {
    if ('focus' in client) {
      await client.focus();
    }

    if ('navigate' in client) {
      return await client.navigate(targetUrl);
    }

    return client;
  } catch {
    return undefined;
  }
}

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  const targetUrl = resolveNotificationTarget(event.notification.data);

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(async (clientList) => {
      for (const client of clientList) {
        const clientUrl = new URL(client.url);
        if (clientUrl.origin === self.location.origin && clientUrl.pathname.startsWith('/im/')) {
          const routedClient = await focusOrNavigateClient(client, targetUrl);
          if (routedClient) {
            return routedClient;
          }
        }
      }

      return openTargetWindow(targetUrl);
    }),
  );
});
