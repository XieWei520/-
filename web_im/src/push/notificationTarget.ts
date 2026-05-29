export interface NotificationPayload {
  url?: unknown;
  channel_id?: unknown;
  channelId?: unknown;
  channel_type?: unknown;
  channelType?: unknown;
  payload?: NotificationPayload;
}

const fallbackTarget = '/im/conversations';
const allowedChannelTypes = new Set(['1', '2']);
const defaultOrigin = 'http://localhost';

function getChannelField(payload: NotificationPayload, snakeName: 'channel_id' | 'channel_type', camelName: 'channelId' | 'channelType'): unknown {
  return payload[snakeName] ?? payload[camelName] ?? payload.payload?.[snakeName] ?? payload.payload?.[camelName];
}

function resolveExplicitUrl(url: unknown): string | null {
  if (typeof url !== 'string') {
    return null;
  }

  const trimmedUrl = url.trim();

  if (!trimmedUrl) {
    return null;
  }

  try {
    const currentOrigin = globalThis.location?.origin ?? defaultOrigin;
    const parsedUrl = new URL(trimmedUrl, currentOrigin);
    if (parsedUrl.origin === currentOrigin && parsedUrl.pathname.startsWith('/im/')) {
      return `${parsedUrl.pathname}${parsedUrl.search}${parsedUrl.hash}`;
    }
  } catch {
    return null;
  }

  return null;
}

function normalizeChannelType(value: unknown): string | null {
  const channelType = String(value ?? '').trim();
  return allowedChannelTypes.has(channelType) ? channelType : null;
}

function normalizeChannelId(value: unknown): string | null {
  const channelId = String(value ?? '').trim();
  return channelId ? channelId : null;
}

export function resolveNotificationTarget(payload: NotificationPayload = {}): string {
  const explicitUrl = resolveExplicitUrl(payload.url ?? payload.payload?.url);

  if (explicitUrl) {
    return explicitUrl;
  }

  const channelType = normalizeChannelType(getChannelField(payload, 'channel_type', 'channelType'));
  const channelId = normalizeChannelId(getChannelField(payload, 'channel_id', 'channelId'));

  if (!channelType || !channelId) {
    return fallbackTarget;
  }

  return `/im/chat/${encodeURIComponent(channelType)}/${encodeURIComponent(channelId)}`;
}
