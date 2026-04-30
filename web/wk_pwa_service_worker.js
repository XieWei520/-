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

function resolveNotificationClickTarget(data) {
  const payload = data && typeof data.payload === 'object' ? data.payload : {};
  return normalizeNotificationClickUrl(
    data.url ||
      data.click_action ||
      data.clickAction ||
      payload.url ||
      payload.click_action ||
      payload.clickAction ||
      '/',
  );
}

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
