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

export function loadOrCreateDeviceIdentity(): WebDeviceIdentity {
  const existing = readJson<WebDeviceIdentity>(deviceKey);
  if (existing?.deviceId && existing.deviceInstallId) {
    return existing;
  }
  const created: WebDeviceIdentity = {
    deviceId: createId('web'),
    deviceInstallId: createId('install'),
    deviceName: 'Web PWA',
    deviceModel: typeof navigator === 'undefined' ? 'Web Browser' : navigator.userAgent || 'Web Browser',
  };
  writeJson(deviceKey, created);
  return created;
}
