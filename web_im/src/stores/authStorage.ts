import type { CurrentUser } from '../models/im';

export interface AuthSnapshot {
  uid: string;
  token: string;
  imToken: string;
  user: CurrentUser;
  savedAt: number;
}

export interface WebDeviceIdentity {
  deviceId: string;
  deviceInstallId: string;
  deviceName: string;
  deviceModel: string;
}

const authKey = 'wk_web_im_auth_v1';
const deviceKey = 'wk_web_im_device_v1';
const maxDeviceModelLength = 32;

function readJson<T>(key: string): T | null {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

function writeJson(key: string, value: unknown): void {
  if (typeof window === 'undefined') {
    return;
  }

  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {}
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isValidCurrentUser(value: unknown): value is CurrentUser {
  if (!isRecord(value)) {
    return false;
  }

  return (
    (isNonEmptyString(value.id) || isNonEmptyString(value.uid)) &&
    isNonEmptyString(value.name) &&
    isNonEmptyString(value.avatarText) &&
    (value.connectionState === 'connected' || value.connectionState === 'connecting' || value.connectionState === 'offline')
  );
}

function isValidAuthSnapshot(value: unknown): value is AuthSnapshot {
  if (!isRecord(value)) {
    return false;
  }

  return (
    isNonEmptyString(value.uid) &&
    isNonEmptyString(value.token) &&
    isNonEmptyString(value.imToken) &&
    isValidCurrentUser(value.user)
  );
}

export function loadAuthSnapshot(): AuthSnapshot | null {
  const snapshot = readJson<unknown>(authKey);
  return isValidAuthSnapshot(snapshot) ? snapshot : null;
}

export function saveAuthSnapshot(snapshot: AuthSnapshot): void {
  writeJson(authKey, snapshot);
}

export function clearAuthSnapshot(): void {
  if (typeof window === 'undefined') {
    return;
  }

  try {
    window.localStorage.removeItem(authKey);
  } catch {}
}

function createId(prefix: string): string {
  const random = globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `${prefix}-${random}`;
}

function detectWebDeviceModel(userAgent: string): string {
  const ua = userAgent.toLowerCase();
  const isIos = /\b(iphone|ipad|ipod)\b/.test(ua) || (ua.includes('macintosh') && ua.includes('mobile'));
  const isAndroid = ua.includes('android');
  const isWindows = ua.includes('windows');
  const isMac = ua.includes('mac os x') || ua.includes('macintosh');
  const isFirefox = ua.includes('firefox') || ua.includes('fxios');
  const isEdge = ua.includes('edg/') || ua.includes('edgios');
  const isChrome = ua.includes('chrome') || ua.includes('crios');
  const isSafari = ua.includes('safari') && !isChrome && !isEdge && !ua.includes('android');

  if (isIos && isFirefox) return 'iOS Firefox';
  if (isIos && isEdge) return 'iOS Edge';
  if (isIos && isChrome) return 'iOS Chrome';
  if (isIos && isSafari) return 'iOS Safari';
  if (isIos) return 'iOS Web';
  if (isAndroid && isEdge) return 'Android Edge';
  if (isAndroid && isChrome) return 'Android Chrome';
  if (isAndroid && isFirefox) return 'Android Firefox';
  if (isAndroid) return 'Android Web';
  if (isWindows && isEdge) return 'Windows Edge';
  if (isWindows && isChrome) return 'Windows Chrome';
  if (isWindows && isFirefox) return 'Windows Firefox';
  if (isWindows) return 'Windows Web';
  if (isMac && isSafari) return 'macOS Safari';
  if (isMac && isChrome) return 'macOS Chrome';
  if (isMac && isFirefox) return 'macOS Firefox';
  if (isMac) return 'macOS Web';
  return 'Web Browser';
}

function normalizeDeviceModel(value: unknown): string {
  const candidate = typeof value === 'string' ? value.trim() : '';
  const userAgent = typeof navigator === 'undefined' ? '' : navigator.userAgent || '';
  const source = candidate || userAgent;
  const normalized = detectWebDeviceModel(source);
  return normalized.length <= maxDeviceModelLength ? normalized : normalized.slice(0, maxDeviceModelLength);
}

export function loadOrCreateDeviceIdentity(): WebDeviceIdentity {
  const existing = readJson<WebDeviceIdentity>(deviceKey);
  if (existing?.deviceId && existing.deviceInstallId) {
    const normalized = {
      ...existing,
      deviceName: existing.deviceName || 'Web PWA',
      deviceModel: normalizeDeviceModel(existing.deviceModel),
    };
    if (normalized.deviceName !== existing.deviceName || normalized.deviceModel !== existing.deviceModel) {
      writeJson(deviceKey, normalized);
    }
    return normalized;
  }
  const created: WebDeviceIdentity = {
    deviceId: createId('web'),
    deviceInstallId: createId('install'),
    deviceName: 'Web PWA',
    deviceModel: normalizeDeviceModel(undefined),
  };
  writeJson(deviceKey, created);
  return created;
}
