# Web IM Phase 2 Auth Conversations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the standalone `web_im/` PWA to real signed HTTP login, current-user restore, and read-only conversation sync while preserving mock mode and leaving Android/Windows untouched.

**Architecture:** Keep the live backend boundary inside focused TypeScript modules under `web_im/src/config`, `web_im/src/api`, and `web_im/src/stores`. Runtime mode decides whether stores call fake data or signed live HTTP. Conversation rows are mapped into the existing UI model and cached by uid through the existing IndexedDB repository boundary.

**Tech Stack:** Vue 3, TypeScript, Pinia, Vite, Vitest, Playwright, browser `crypto.subtle`, localStorage, IndexedDB.

---

## File Structure

- Create `web_im/src/config/runtimeConfig.ts`: reads Vite env and exposes mock/live mode, API base URL, app id/key, device flag, and mode helpers.
- Create `web_im/src/config/runtimeConfig.test.ts`: covers env normalization and default mock behavior.
- Create `web_im/src/api/apiError.ts`: typed API error and helpers for unauthorized/retryable failures.
- Create `web_im/src/api/signedHttpClient.ts`: JSON serialization, MD5 signing, signed fetch, response normalization.
- Create `web_im/src/api/signedHttpClient.test.ts`: deterministic header/signature and request-body tests.
- Create `web_im/src/api/authApi.ts`: login/current-user/logout-compatible HTTP functions and response parsers.
- Create `web_im/src/api/authApi.test.ts`: login and current-user parsing tests, including direct and nested payload shapes.
- Create `web_im/src/api/conversationSyncApi.ts`: conversation sync request, row parsing, message summary mapping.
- Create `web_im/src/api/conversationSyncApi.test.ts`: real-row mapping, invalid row filtering, and safe summary tests.
- Create `web_im/src/stores/authStorage.ts`: resilient auth/device/base URL localStorage helpers.
- Create `web_im/src/stores/authStorage.test.ts`: localStorage failure coverage.
- Modify `web_im/src/models/im.ts`: extend `CurrentUser` and `Conversation` with real backend fields without breaking existing UI.
- Modify `web_im/src/stores/authStore.ts`: async login/session restore/logout, mock/live branching, current-user state.
- Modify `web_im/src/stores/authStore.test.ts`: update existing sync fake tests to async and add live restore/unauthorized coverage.
- Modify `web_im/src/stores/chatStore.ts`: own conversation list state, mock/live loading, IndexedDB persistence, retry state.
- Modify `web_im/src/stores/chatStore.test.ts`: keep unknown-channel fake chat tests and add live conversation loading tests.
- Modify `web_im/src/features/login/LoginPage.vue`: call async login, mode-aware defaults, backend errors.
- Modify `web_im/src/features/conversations/ConversationListPage.vue`: render store conversations with loading/empty/error/retry states.
- Modify `web_im/src/features/chat/ChatPage.vue`: live mode labels chat as read-only placeholder for Phase 2.
- Modify `web_im/src/features/me/MePage.vue`: show uid and live user data.
- Modify `web_im/tests/smoke.spec.ts`: keep mock smoke path.
- Create `web_im/tests/live-auth-conversations.spec.ts`: mocked-live E2E for login and conversation rendering.
- Modify `web_im/playwright.config.ts`: allow passing Vite env to the web server for live mocked E2E.

## Task 1: Runtime Mode Config

**Files:**
- Create: `web_im/src/config/runtimeConfig.ts`
- Create: `web_im/src/config/runtimeConfig.test.ts`

- [ ] **Step 1: Write the failing runtime config tests**

```ts
import { describe, expect, it } from 'vitest';
import { createRuntimeConfig, isLiveMode, isMockMode, normalizeApiBaseUrl, normalizeMode } from './runtimeConfig';

describe('runtime config', () => {
  it('defaults to mock mode and production API base URL', () => {
    const config = createRuntimeConfig({});

    expect(config.mode).toBe('mock');
    expect(config.apiBaseUrl).toBe('https://infoequity.cn');
    expect(config.appId).toBe('wukongchat');
    expect(config.appKey).toBe('25b002c6be2d539f264c');
    expect(config.deviceFlag).toBe(5);
    expect(isMockMode(config)).toBe(true);
    expect(isLiveMode(config)).toBe(false);
  });

  it('normalizes live mode and trims trailing base URL slash', () => {
    const config = createRuntimeConfig({
      VITE_WK_WEB_IM_MODE: ' LIVE ',
      VITE_WK_API_BASE_URL: 'https://infoequity.cn///',
      VITE_WK_APP_ID: 'custom-app',
      VITE_WK_APP_KEY: 'custom-key',
      VITE_WK_DEVICE_FLAG: '7',
    });

    expect(config).toMatchObject({
      mode: 'live',
      apiBaseUrl: 'https://infoequity.cn',
      appId: 'custom-app',
      appKey: 'custom-key',
      deviceFlag: 7,
    });
  });

  it('falls back safely for unsupported mode, blank base URL, and invalid device flag', () => {
    expect(normalizeMode('prod')).toBe('mock');
    expect(normalizeApiBaseUrl('   ')).toBe('https://infoequity.cn');
    expect(
      createRuntimeConfig({
        VITE_WK_WEB_IM_MODE: 'prod',
        VITE_WK_API_BASE_URL: '',
        VITE_WK_DEVICE_FLAG: 'abc',
      }),
    ).toMatchObject({
      mode: 'mock',
      apiBaseUrl: 'https://infoequity.cn',
      deviceFlag: 5,
    });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --dir web_im test -- src/config/runtimeConfig.test.ts`

Expected: FAIL because `web_im/src/config/runtimeConfig.ts` does not exist.

- [ ] **Step 3: Implement runtime config**

```ts
export type WebImRuntimeMode = 'mock' | 'live';

export interface WebImRuntimeConfig {
  mode: WebImRuntimeMode;
  apiBaseUrl: string;
  appId: string;
  appKey: string;
  deviceFlag: number;
}

type RuntimeEnv = Partial<Record<string, string | boolean | undefined>>;

const defaultApiBaseUrl = 'https://infoequity.cn';
const defaultAppId = 'wukongchat';
const defaultAppKey = '25b002c6be2d539f264c';
const defaultDeviceFlag = 5;

export function normalizeMode(value: unknown): WebImRuntimeMode {
  return String(value ?? '').trim().toLowerCase() === 'live' ? 'live' : 'mock';
}

export function normalizeApiBaseUrl(value: unknown): string {
  const raw = String(value ?? '').trim().replace(/\/+$/, '');
  return raw || defaultApiBaseUrl;
}

function normalizeString(value: unknown, fallback: string): string {
  const raw = String(value ?? '').trim();
  return raw || fallback;
}

function normalizeDeviceFlag(value: unknown): number {
  const parsed = Number(String(value ?? '').trim());
  return Number.isInteger(parsed) && parsed > 0 ? parsed : defaultDeviceFlag;
}

export function createRuntimeConfig(env: RuntimeEnv = import.meta.env): WebImRuntimeConfig {
  return {
    mode: normalizeMode(env.VITE_WK_WEB_IM_MODE),
    apiBaseUrl: normalizeApiBaseUrl(env.VITE_WK_API_BASE_URL),
    appId: normalizeString(env.VITE_WK_APP_ID, defaultAppId),
    appKey: normalizeString(env.VITE_WK_APP_KEY, defaultAppKey),
    deviceFlag: normalizeDeviceFlag(env.VITE_WK_DEVICE_FLAG),
  };
}

export const runtimeConfig = createRuntimeConfig();

export function isMockMode(config: Pick<WebImRuntimeConfig, 'mode'> = runtimeConfig): boolean {
  return config.mode === 'mock';
}

export function isLiveMode(config: Pick<WebImRuntimeConfig, 'mode'> = runtimeConfig): boolean {
  return config.mode === 'live';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --dir web_im test -- src/config/runtimeConfig.test.ts`

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add web_im/src/config/runtimeConfig.ts web_im/src/config/runtimeConfig.test.ts
git commit -m "feat(web-im): add runtime mode config"
```

## Task 2: Signed HTTP Client And API Errors

**Files:**
- Create: `web_im/src/api/apiError.ts`
- Create: `web_im/src/api/signedHttpClient.ts`
- Create: `web_im/src/api/signedHttpClient.test.ts`

- [ ] **Step 1: Write the failing signed HTTP tests**

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from './apiError';
import { createSignedHeaders, signedJsonRequest, stableJsonStringify } from './signedHttpClient';

describe('signed HTTP client', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('serializes objects exactly once for signing and sending', () => {
    expect(stableJsonStringify({ username: '008613800000000', password: '123456' })).toBe(
      '{"username":"008613800000000","password":"123456"}',
    );
  });

  it('builds deterministic Flutter-compatible signed headers', async () => {
    const headers = await createSignedHeaders({
      body: '{"username":"008613800000000","password":"123456"}',
      appId: 'wukongchat',
      appKey: '25b002c6be2d539f264c',
      token: 'token-a',
      now: () => 1717000000000,
      nonce: () => 'ABCDEFGHIJKLMNOP',
    });

    expect(headers).toMatchObject({
      'Content-Type': 'application/json',
      Accept: 'application/json',
      appid: 'wukongchat',
      timestamp: '1717000000000',
      noncestr: 'ABCDEFGHIJKLMNOP',
      token: 'token-a',
    });
    expect(headers.sign).toHaveLength(32);
    expect(headers.sign).toMatch(/^[a-f0-9]{32}$/);
  });

  it('sends signed JSON and unwraps data payloads', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ code: 0, data: { ok: true } }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    const result = await signedJsonRequest<{ ok: boolean }>({
      baseUrl: 'https://infoequity.cn',
      path: '/v1/example',
      method: 'POST',
      body: { a: 1 },
      appId: 'wukongchat',
      appKey: 'key',
      fetchImpl: fetchMock,
      now: () => 1,
      nonce: () => 'ABCDEFGHIJKLMNOP',
    });

    expect(result).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledWith(
      'https://infoequity.cn/v1/example',
      expect.objectContaining({
        method: 'POST',
        body: '{"a":1}',
        headers: expect.objectContaining({
          appid: 'wukongchat',
          timestamp: '1',
          noncestr: 'ABCDEFGHIJKLMNOP',
        }),
      }),
    );
  });

  it('throws typed unauthorized and retryable errors', async () => {
    const unauthorizedFetch = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ code: 401, msg: 'expired' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    await expect(
      signedJsonRequest({
        baseUrl: 'https://infoequity.cn',
        path: '/v1/user',
        method: 'GET',
        appId: 'wukongchat',
        appKey: 'key',
        fetchImpl: unauthorizedFetch,
      }),
    ).rejects.toMatchObject({ unauthorized: true, retryable: false, message: 'expired' });

    const failingFetch = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));

    await expect(
      signedJsonRequest({
        baseUrl: 'https://infoequity.cn',
        path: '/v1/user',
        method: 'GET',
        appId: 'wukongchat',
        appKey: 'key',
        fetchImpl: failingFetch,
      }),
    ).rejects.toBeInstanceOf(ApiError);
    await expect(
      signedJsonRequest({
        baseUrl: 'https://infoequity.cn',
        path: '/v1/user',
        method: 'GET',
        appId: 'wukongchat',
        appKey: 'key',
        fetchImpl: failingFetch,
      }),
    ).rejects.toMatchObject({ retryable: true, unauthorized: false });
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --dir web_im test -- src/api/signedHttpClient.test.ts`

Expected: FAIL because `web_im/src/api/signedHttpClient.ts` and `web_im/src/api/apiError.ts` do not exist.

- [ ] **Step 3: Implement API error and signed HTTP client**

```ts
export interface ApiErrorOptions {
  status?: number;
  code?: number;
  retryable?: boolean;
  unauthorized?: boolean;
}

export class ApiError extends Error {
  readonly status?: number;
  readonly code?: number;
  readonly retryable: boolean;
  readonly unauthorized: boolean;

  constructor(message: string, options: ApiErrorOptions = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = options.status;
    this.code = options.code;
    this.unauthorized = options.unauthorized ?? options.status === 401 || options.status === 403 || options.code === 401;
    this.retryable = options.retryable ?? (!this.unauthorized && (!options.status || options.status >= 500));
  }
}

export function toUserMessage(error: unknown, fallback: string): string {
  if (error instanceof ApiError && error.message.trim()) {
    return error.message;
  }
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  return fallback;
}
```

```ts
import { ApiError } from './apiError';

export type FetchLike = typeof fetch;
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';

export interface SignedHeaderOptions {
  body?: string;
  appId: string;
  appKey: string;
  token?: string | null;
  now?: () => number;
  nonce?: () => string;
}

export interface SignedJsonRequestOptions<TBody = unknown> extends SignedHeaderOptions {
  baseUrl: string;
  path: string;
  method: HttpMethod;
  body?: TBody;
  fetchImpl?: FetchLike;
}

export function stableJsonStringify(value: unknown): string {
  return value === undefined ? '' : JSON.stringify(value);
}

function defaultNonce(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  const seed = Date.now();
  return Array.from({ length: 16 }, (_, index) => chars[(seed + index * 17) % chars.length]).join('');
}

async function md5Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('MD5', bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function createSignedHeaders(options: SignedHeaderOptions): Promise<Record<string, string>> {
  const timestamp = String(options.now?.() ?? Date.now());
  const noncestr = options.nonce?.() ?? defaultNonce();
  const body = options.body ?? '';
  const sign = await md5Hex(`${body}${noncestr}${timestamp}${options.appKey}`);

  return {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    appid: options.appId,
    timestamp,
    noncestr,
    sign,
    ...(options.token ? { token: options.token } : {}),
  };
}

function joinUrl(baseUrl: string, path: string): string {
  return `${baseUrl.replace(/\/+$/, '')}/${path.replace(/^\/+/, '')}`;
}

function readBodyMessage(body: Record<string, unknown>, fallback: string): string {
  const message = body.msg ?? body.message;
  return typeof message === 'string' && message.trim() ? message : fallback;
}

function readBodyCode(body: Record<string, unknown>, status: number): number {
  const raw = body.code ?? body.status;
  if (typeof raw === 'number') {
    return raw;
  }
  if (typeof raw === 'string') {
    return Number.parseInt(raw, 10) || (status >= 400 ? status : 0);
  }
  return status >= 400 ? status : 0;
}

async function readJson(response: Response): Promise<Record<string, unknown>> {
  const text = await response.text();
  if (!text.trim()) {
    return {};
  }
  try {
    const parsed = JSON.parse(text);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : { data: parsed };
  } catch {
    return { message: text };
  }
}

export async function signedJsonRequest<TResult = unknown, TBody = unknown>(
  options: SignedJsonRequestOptions<TBody>,
): Promise<TResult> {
  const body = options.method === 'GET' ? '' : stableJsonStringify(options.body);
  const headers = await createSignedHeaders({ ...options, body });
  const fetchImpl = options.fetchImpl ?? fetch;

  let response: Response;
  try {
    response = await fetchImpl(joinUrl(options.baseUrl, options.path), {
      method: options.method,
      headers,
      body: body || undefined,
    });
  } catch (error) {
    throw new ApiError(error instanceof Error ? error.message : 'Network request failed', {
      retryable: true,
      unauthorized: false,
    });
  }

  const json = await readJson(response);
  const code = readBodyCode(json, response.status);
  if (!response.ok || code !== 0) {
    throw new ApiError(readBodyMessage(json, `Request failed (${response.status || code})`), {
      status: response.status,
      code,
      retryable: response.status >= 500,
    });
  }

  return (json.data === undefined ? json : json.data) as TResult;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm --dir web_im test -- src/api/signedHttpClient.test.ts`

Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add web_im/src/api/apiError.ts web_im/src/api/signedHttpClient.ts web_im/src/api/signedHttpClient.test.ts
git commit -m "feat(web-im): add signed http client"
```

## Task 3: Auth API, Storage, And Auth Store

**Files:**
- Create: `web_im/src/api/authApi.ts`
- Create: `web_im/src/api/authApi.test.ts`
- Create: `web_im/src/stores/authStorage.ts`
- Create: `web_im/src/stores/authStorage.test.ts`
- Modify: `web_im/src/models/im.ts`
- Modify: `web_im/src/stores/authStore.ts`
- Modify: `web_im/src/stores/authStore.test.ts`

- [ ] **Step 1: Write failing auth API and storage tests**

```ts
import { describe, expect, it, vi } from 'vitest';
import { loginWithPhone, mapCurrentUser, parseLoginResponse } from './authApi';

describe('auth api', () => {
  it('parses nested and direct login response shapes', () => {
    expect(parseLoginResponse({ code: 0, data: { uid: 'u1', token: 't1', im_token: 'im1', name: 'Alice' } })).toMatchObject({
      uid: 'u1',
      token: 't1',
      imToken: 'im1',
      name: 'Alice',
    });
    expect(parseLoginResponse({ uid: 'u2', token: 't2' })).toMatchObject({
      uid: 'u2',
      token: 't2',
      imToken: 't2',
    });
  });

  it('rejects login verification code 110 as unsupported in phase 2', () => {
    expect(() => parseLoginResponse({ code: 110, data: { uid: 'u1' }, msg: 'check phone' })).toThrow(
      '当前 Web 版本暂不支持登录二次验证',
    );
  });

  it('maps current user fields with safe fallbacks', () => {
    expect(mapCurrentUser({ uid: 'u1', name: 'Alice', phone: '13800000000', avatar: '' })).toEqual({
      id: 'u1',
      uid: 'u1',
      name: 'Alice',
      phone: '13800000000',
      avatarText: 'A',
      avatarUrl: '',
      connectionState: 'connected',
    });
  });

  it('posts phone login with 0086 username and configured device flag', async () => {
    const request = vi.fn().mockResolvedValue({ uid: 'u1', token: 't1' });
    const result = await loginWithPhone({
      phone: '13800000000',
      password: '123456',
      request,
      config: {
        mode: 'live',
        apiBaseUrl: 'https://infoequity.cn',
        appId: 'wukongchat',
        appKey: 'key',
        deviceFlag: 5,
      },
      device: {
        deviceId: 'web-device',
        deviceInstallId: 'install',
        deviceName: 'Web PWA',
        deviceModel: 'iPhone',
      },
    });

    expect(result).toMatchObject({ uid: 'u1', token: 't1', imToken: 't1' });
    expect(request).toHaveBeenCalledWith(
      expect.objectContaining({
        path: '/v1/user/login',
        method: 'POST',
        body: {
          username: '008613800000000',
          password: '123456',
          flag: 5,
          device: {
            device_id: 'web-device',
            device_install_id: 'install',
            device_name: 'Web PWA',
            device_model: 'iPhone',
          },
        },
      }),
    );
  });
});
```

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { clearAuthSnapshot, loadAuthSnapshot, loadOrCreateDeviceIdentity, saveAuthSnapshot } from './authStorage';

describe('auth storage', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    window.localStorage.clear();
  });

  it('round trips auth snapshots', () => {
    saveAuthSnapshot({
      uid: 'u1',
      token: 't1',
      imToken: 'im1',
      user: { id: 'u1', uid: 'u1', name: 'Alice', phone: '', avatarText: 'A', connectionState: 'connected' },
      savedAt: 1,
    });

    expect(loadAuthSnapshot()).toMatchObject({ uid: 'u1', token: 't1', imToken: 'im1' });
    clearAuthSnapshot();
    expect(loadAuthSnapshot()).toBeNull();
  });

  it('does not throw when storage is blocked', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError');
    });
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError');
    });
    vi.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => {
      throw new DOMException('blocked', 'SecurityError');
    });

    expect(loadAuthSnapshot()).toBeNull();
    expect(() =>
      saveAuthSnapshot({
        uid: 'u1',
        token: 't1',
        imToken: 't1',
        user: { id: 'u1', uid: 'u1', name: 'Alice', phone: '', avatarText: 'A', connectionState: 'connected' },
        savedAt: 1,
      }),
    ).not.toThrow();
    expect(() => clearAuthSnapshot()).not.toThrow();
  });

  it('creates a stable web device identity', () => {
    const first = loadOrCreateDeviceIdentity();
    const second = loadOrCreateDeviceIdentity();

    expect(first.deviceId).toBe(second.deviceId);
    expect(first.deviceInstallId).toBe(second.deviceInstallId);
    expect(first.deviceName).toBe('Web PWA');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pnpm --dir web_im test -- src/api/authApi.test.ts src/stores/authStorage.test.ts`

Expected: FAIL because new files do not exist.

- [ ] **Step 3: Implement auth API and storage**

Use the interfaces below exactly so stores can depend on them.

```ts
// web_im/src/models/im.ts additions
export interface CurrentUser {
  id: string;
  uid?: string;
  name: string;
  phone: string;
  avatarText: string;
  avatarUrl?: string;
  connectionState: ConnectionState;
}
```

```ts
// web_im/src/stores/authStorage.ts
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
  try {
    const raw = window.localStorage.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

function writeJson(key: string, value: unknown): void {
  try {
    window.localStorage.setItem(key, JSON.stringify(value));
  } catch {}
}

export function loadAuthSnapshot(): AuthSnapshot | null {
  const snapshot = readJson<AuthSnapshot>(authKey);
  if (!snapshot?.uid || !snapshot.token) {
    return null;
  }
  return snapshot;
}

export function saveAuthSnapshot(snapshot: AuthSnapshot): void {
  writeJson(authKey, snapshot);
}

export function clearAuthSnapshot(): void {
  try {
    window.localStorage.removeItem(authKey);
  } catch {}
}

function createId(prefix: string): string {
  const random = crypto.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`;
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
    deviceModel: navigator.userAgent || 'Web Browser',
  };
  writeJson(deviceKey, created);
  return created;
}
```

```ts
// web_im/src/api/authApi.ts
import type { WebImRuntimeConfig } from '../config/runtimeConfig';
import type { CurrentUser } from '../models/im';
import type { WebDeviceIdentity } from '../stores/authStorage';
import type { SignedJsonRequestOptions } from './signedHttpClient';
import { ApiError } from './apiError';
import { signedJsonRequest } from './signedHttpClient';

export interface LoginCredential {
  uid: string;
  token: string;
  imToken: string;
  name?: string;
  username?: string;
  avatar?: string;
  phone?: string;
  zone?: string;
}

type RequestFn = <TResult, TBody = unknown>(options: SignedJsonRequestOptions<TBody>) => Promise<TResult>;

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function readString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : value == null ? '' : String(value).trim();
}

export function parseLoginResponse(raw: unknown): LoginCredential {
  const body = asRecord(raw);
  const code = Number(body.code ?? 0);
  if (code === 110) {
    throw new ApiError('当前 Web 版本暂不支持登录二次验证', { code, retryable: false });
  }
  const data = asRecord(body.data) && Object.keys(asRecord(body.data)).length > 0 ? asRecord(body.data) : body;
  const uid = readString(data.uid);
  const token = readString(data.token);
  if (!uid || !token) {
    throw new ApiError(readString(body.msg ?? body.message) || '登录结果缺少 uid 或 token', { code, retryable: false });
  }
  return {
    uid,
    token,
    imToken: readString(data.im_token ?? data.imToken) || token,
    name: readString(data.name),
    username: readString(data.username),
    avatar: readString(data.avatar),
    phone: readString(data.phone),
    zone: readString(data.zone),
  };
}

export function mapCurrentUser(raw: unknown, fallback?: LoginCredential): CurrentUser {
  const body = asRecord(raw);
  const data = asRecord(body.data) && Object.keys(asRecord(body.data)).length > 0 ? asRecord(body.data) : body;
  const uid = readString(data.uid) || fallback?.uid || '';
  const name = readString(data.name) || readString(data.username) || fallback?.name || fallback?.username || uid || '我';
  const avatarUrl = readString(data.avatar) || fallback?.avatar || '';
  return {
    id: uid,
    uid,
    name,
    phone: readString(data.phone) || fallback?.phone || '',
    avatarText: name.slice(0, 1).toUpperCase() || '我',
    avatarUrl,
    connectionState: 'connected',
  };
}

export async function loginWithPhone(options: {
  phone: string;
  password: string;
  config: WebImRuntimeConfig;
  device: WebDeviceIdentity;
  request?: RequestFn;
}): Promise<LoginCredential> {
  const request = options.request ?? signedJsonRequest;
  const body = {
    username: `0086${options.phone.trim()}`,
    password: options.password,
    flag: options.config.deviceFlag,
    device: {
      device_id: options.device.deviceId,
      device_name: options.device.deviceName,
      device_model: options.device.deviceModel,
      device_install_id: options.device.deviceInstallId,
    },
  };
  const raw = await request<unknown, typeof body>({
    baseUrl: options.config.apiBaseUrl,
    path: '/v1/user/login',
    method: 'POST',
    body,
    appId: options.config.appId,
    appKey: options.config.appKey,
  });
  return parseLoginResponse(raw);
}

export async function fetchCurrentUser(options: {
  uid: string;
  token: string;
  config: WebImRuntimeConfig;
  request?: RequestFn;
}): Promise<CurrentUser> {
  const request = options.request ?? signedJsonRequest;
  const raw = await request<unknown>({
    baseUrl: options.config.apiBaseUrl,
    path: `/v1/users/${encodeURIComponent(options.uid)}`,
    method: 'GET',
    appId: options.config.appId,
    appKey: options.config.appKey,
    token: options.token,
  });
  return mapCurrentUser(raw, { uid: options.uid, token: options.token, imToken: options.token });
}
```

- [ ] **Step 4: Update auth store tests for async behavior**

Add this test to `web_im/src/stores/authStore.test.ts` after existing tests.

```ts
it('clears live auth when session restore is unauthorized', async () => {
  const auth = useAuthStore();
  await auth.setLiveSessionForTest({
    uid: 'u1',
    token: 't1',
    imToken: 't1',
    user: { id: 'u1', uid: 'u1', name: 'Alice', phone: '', avatarText: 'A', connectionState: 'connected' },
    savedAt: 1,
  });

  await auth.restoreSessionForTest(async () => {
    throw Object.assign(new Error('expired'), { unauthorized: true });
  });

  expect(auth.isLoggedIn).toBe(false);
  expect(auth.user).toBeNull();
});
```

- [ ] **Step 5: Implement auth store async login/restore**

Keep fake mode behavior intact, but make `login` return `Promise<void>`.

```ts
// web_im/src/stores/authStore.ts public actions
async function login(phone: string, password: string): Promise<void> {
  if (isMockMode(runtimeConfig)) {
    loginMock(phone, password);
    return;
  }
  const credential = await loginWithPhone({
    phone,
    password,
    config: runtimeConfig,
    device: loadOrCreateDeviceIdentity(),
  });
  const currentUser = await fetchCurrentUser({
    uid: credential.uid,
    token: credential.token,
    config: runtimeConfig,
  });
  token.value = credential.token;
  uid.value = credential.uid;
  imToken.value = credential.imToken;
  user.value = currentUser;
  saveAuthSnapshot({ uid: credential.uid, token: credential.token, imToken: credential.imToken, user: currentUser, savedAt: Date.now() });
}
```

Also expose `setLiveSessionForTest` and `restoreSessionForTest` only as harmless test seams on the returned store. They must not perform network requests unless passed a loader.

- [ ] **Step 6: Run tests to verify auth green**

Run: `pnpm --dir web_im test -- src/api/authApi.test.ts src/stores/authStorage.test.ts src/stores/authStore.test.ts`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add web_im/src/models/im.ts web_im/src/api/authApi.ts web_im/src/api/authApi.test.ts web_im/src/stores/authStorage.ts web_im/src/stores/authStorage.test.ts web_im/src/stores/authStore.ts web_im/src/stores/authStore.test.ts
git commit -m "feat(web-im): connect auth store to live login"
```

## Task 4: Conversation Sync API And Chat Store

**Files:**
- Create: `web_im/src/api/conversationSyncApi.ts`
- Create: `web_im/src/api/conversationSyncApi.test.ts`
- Modify: `web_im/src/models/im.ts`
- Modify: `web_im/src/stores/chatStore.ts`
- Modify: `web_im/src/stores/chatStore.test.ts`

- [ ] **Step 1: Write failing conversation sync tests**

```ts
import { describe, expect, it, vi } from 'vitest';
import { loadConversationSync, mapConversationSyncRows, summarizeRecentMessage } from './conversationSyncApi';

describe('conversation sync api', () => {
  it('maps valid rows and skips invalid rows', () => {
    const conversations = mapConversationSyncRows([
      {
        channel_id: 'u2',
        channel_type: 1,
        unread: 3,
        timestamp: 1717000000,
        recents: [{ message_seq: 8, timestamp: 1717000001, payload: { type: 1, content: 'hello' } }],
      },
      { channel_id: '', channel_type: 1 },
      { channel_id: 'bad', channel_type: 99 },
    ]);

    expect(conversations).toEqual([
      expect.objectContaining({
        id: '1:u2',
        channelId: 'u2',
        channelType: 1,
        unreadCount: 3,
        lastMessage: 'hello',
      }),
    ]);
  });

  it('summarizes malformed and media payloads safely', () => {
    expect(summarizeRecentMessage({ payload: '{"type":2}' })).toBe('[图片]');
    expect(summarizeRecentMessage({ payload: { type: 4 } })).toBe('[语音]');
    expect(summarizeRecentMessage({ payload: '{bad json' })).toBe('[不支持的消息]');
    expect(summarizeRecentMessage({})).toBe('[暂无消息]');
  });

  it('posts Flutter-compatible conversation sync body', async () => {
    const request = vi.fn().mockResolvedValue({ conversations: [] });

    await loadConversationSync({
      uid: 'u1',
      token: 't1',
      deviceUuid: 'device',
      config: {
        mode: 'live',
        apiBaseUrl: 'https://infoequity.cn',
        appId: 'wukongchat',
        appKey: 'key',
        deviceFlag: 5,
      },
      request,
    });

    expect(request).toHaveBeenCalledWith(
      expect.objectContaining({
        path: '/v1/conversation/sync',
        method: 'POST',
        token: 't1',
        body: {
          version: 0,
          last_msg_seqs: '',
          msg_count: 200,
          device_uuid: 'device',
        },
      }),
    );
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm --dir web_im test -- src/api/conversationSyncApi.test.ts`

Expected: FAIL because `conversationSyncApi.ts` does not exist.

- [ ] **Step 3: Implement conversation sync API**

```ts
import type { WebImRuntimeConfig } from '../config/runtimeConfig';
import type { Conversation } from '../models/im';
import type { SignedJsonRequestOptions } from './signedHttpClient';
import { signedJsonRequest } from './signedHttpClient';

type RequestFn = <TResult, TBody = unknown>(options: SignedJsonRequestOptions<TBody>) => Promise<TResult>;

function readRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : {};
}

function readInt(value: unknown): number {
  return typeof value === 'number' ? value : Number.parseInt(String(value ?? ''), 10) || 0;
}

function readString(value: unknown): string {
  return typeof value === 'string' ? value.trim() : value == null ? '' : String(value).trim();
}

function parsePayload(payload: unknown): Record<string, unknown> {
  if (typeof payload === 'string') {
    try {
      return readRecord(JSON.parse(payload));
    } catch {
      return {};
    }
  }
  return readRecord(payload);
}

export function summarizeRecentMessage(raw: unknown): string {
  const message = readRecord(raw);
  const payload = parsePayload(message.payload);
  const type = readInt(payload.type ?? payload.content_type);
  const text = readString(payload.content ?? payload.text);
  if (text) return text;
  if (type === 2) return '[图片]';
  if (type === 4) return '[语音]';
  if (type === 5 || type === 6) return '[文件]';
  return Object.keys(message).length === 0 ? '[暂无消息]' : '[不支持的消息]';
}

function latestRecent(recents: unknown): Record<string, unknown> | null {
  if (!Array.isArray(recents)) return null;
  return recents
    .map(readRecord)
    .sort((a, b) => readInt(b.message_seq) - readInt(a.message_seq) || readInt(b.timestamp) - readInt(a.timestamp))[0] ?? null;
}

export function mapConversationSyncRows(rows: unknown): Conversation[] {
  if (!Array.isArray(rows)) return [];
  return rows.flatMap((row) => {
    const item = readRecord(row);
    const channelId = readString(item.channel_id ?? item.channelId);
    const channelType = readInt(item.channel_type ?? item.channelType);
    if (!channelId || (channelType !== 1 && channelType !== 2)) return [];
    const recent = latestRecent(item.recents);
    const timestamp = readInt(item.timestamp) || readInt(recent?.timestamp);
    return [{
      id: `${channelType}:${channelId}`,
      channelId,
      channelType,
      title: channelId,
      avatarText: channelId.slice(0, 1).toUpperCase(),
      lastMessage: summarizeRecentMessage(recent ?? {}),
      lastMessageAt: timestamp > 0 ? new Date(timestamp * 1000).toISOString() : '',
      unreadCount: readInt(item.unread ?? item.unread_count),
      muted: false,
      lastMsgSeq: readInt(item.last_msg_seq),
      lastClientMsgNo: readString(item.last_client_msg_no),
    } satisfies Conversation];
  });
}

export async function loadConversationSync(options: {
  uid: string;
  token: string;
  deviceUuid: string;
  config: WebImRuntimeConfig;
  request?: RequestFn;
}): Promise<Conversation[]> {
  const request = options.request ?? signedJsonRequest;
  const raw = await request<unknown, Record<string, unknown>>({
    baseUrl: options.config.apiBaseUrl,
    path: '/v1/conversation/sync',
    method: 'POST',
    token: options.token,
    appId: options.config.appId,
    appKey: options.config.appKey,
    body: {
      version: 0,
      last_msg_seqs: '',
      msg_count: 200,
      device_uuid: options.deviceUuid,
    },
  });
  const body = readRecord(raw);
  return mapConversationSyncRows(body.conversations ?? readRecord(body.data).conversations);
}
```

Also add optional fields to `Conversation` in `web_im/src/models/im.ts`:

```ts
lastMsgSeq?: number;
lastClientMsgNo?: string;
```

- [ ] **Step 4: Add chat store live conversation loading test**

```ts
it('loads live conversations into store state', async () => {
  const chat = useChatStore();

  await chat.loadLiveConversationsForTest([
    {
      id: '1:u2',
      channelId: 'u2',
      channelType: 1,
      title: 'u2',
      avatarText: 'U',
      lastMessage: 'hello',
      lastMessageAt: '2026-05-29T00:00:00.000Z',
      unreadCount: 2,
      muted: false,
    },
  ]);

  expect(chat.conversations).toHaveLength(1);
  expect(chat.conversations[0]).toMatchObject({ channelId: 'u2', unreadCount: 2 });
});
```

- [ ] **Step 5: Implement chat store conversation state**

Add these public state values to `useChatStore` while preserving existing fake message functions:

```ts
const conversations = ref<Conversation[]>([...fakeConversations]);
const isLoadingConversations = ref(false);
const conversationError = ref('');

async function loadLiveConversationsForTest(items: Conversation[]): Promise<void> {
  conversations.value = items;
}
```

Then add a production `loadConversations(auth)` action that uses mock data in mock mode and `loadConversationSync` in live mode. It must set loading/error state and not throw into the UI.

- [ ] **Step 6: Run tests to verify conversation green**

Run: `pnpm --dir web_im test -- src/api/conversationSyncApi.test.ts src/stores/chatStore.test.ts`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add web_im/src/models/im.ts web_im/src/api/conversationSyncApi.ts web_im/src/api/conversationSyncApi.test.ts web_im/src/stores/chatStore.ts web_im/src/stores/chatStore.test.ts
git commit -m "feat(web-im): load live conversation sync"
```

## Task 5: UI Integration

**Files:**
- Modify: `web_im/src/features/login/LoginPage.vue`
- Modify: `web_im/src/features/conversations/ConversationListPage.vue`
- Modify: `web_im/src/features/chat/ChatPage.vue`
- Modify: `web_im/src/features/me/MePage.vue`
- Modify: `web_im/src/stores/authStore.test.ts`
- Modify: `web_im/src/stores/chatStore.test.ts`

- [ ] **Step 1: Update login page for async login**

Replace:

```ts
auth.login(phone.value, password.value);
await router.replace('/conversations');
```

with:

```ts
await auth.login(phone.value, password.value);
await router.replace('/conversations');
```

Keep the existing error region and loading button state.

- [ ] **Step 2: Update conversation page to use store state**

Replace the direct `fakeConversations` import with:

```ts
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/authStore';
import { useChatStore } from '../../stores/chatStore';
import type { ChannelType } from '../../models/im';

const router = useRouter();
const auth = useAuthStore();
const chat = useChatStore();

onMounted(() => {
  void chat.loadConversations(auth.sessionForConversationSync);
});

function retryLoad() {
  void chat.loadConversations(auth.sessionForConversationSync);
}

function openConversation(channelType: ChannelType, channelId: string) {
  router.push(`/chat/${channelType}/${channelId}`);
}
```

Template states must be:

```vue
<section v-if="chat.isLoadingConversations" class="status-list" role="status">正在加载会话...</section>
<section v-else-if="chat.conversationError" class="status-list" role="alert">
  <p>{{ chat.conversationError }}</p>
  <button class="secondary-button" type="button" @click="retryLoad">重试</button>
</section>
<section v-else-if="chat.conversations.length === 0" class="status-list" role="status">暂无会话</section>
<ul v-else class="list" aria-label="会话列表">...</ul>
```

- [ ] **Step 3: Update chat page status text**

Change the `ChatHeader` status text to derive from mode/store:

```vue
<ChatHeader :title="title" :status-text="chat.isLiveConversationMode ? 'Phase 2 只读会话，消息收发将在下一阶段接入' : '假数据会话'" />
```

- [ ] **Step 4: Update Me page profile display**

Add uid below phone:

```vue
<span class="row-subtitle">{{ auth.user?.phone || auth.user?.uid || '暂无手机号' }}</span>
<span v-if="auth.user?.uid" class="row-subtitle">UID: {{ auth.user.uid }}</span>
```

- [ ] **Step 5: Run focused tests**

Run: `pnpm --dir web_im test -- src/stores/authStore.test.ts src/stores/chatStore.test.ts`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add web_im/src/features/login/LoginPage.vue web_im/src/features/conversations/ConversationListPage.vue web_im/src/features/chat/ChatPage.vue web_im/src/features/me/MePage.vue web_im/src/stores/authStore.test.ts web_im/src/stores/chatStore.test.ts
git commit -m "feat(web-im): wire live auth conversations ui"
```

## Task 6: Mock And Live E2E Coverage

**Files:**
- Modify: `web_im/tests/smoke.spec.ts`
- Create: `web_im/tests/live-auth-conversations.spec.ts`
- Modify: `web_im/playwright.config.ts`

- [ ] **Step 1: Keep mock smoke tests unchanged**

Run: `pnpm --dir web_im e2e`

Expected before live test changes: existing 4 mock smoke tests still pass.

- [ ] **Step 2: Add mocked-live Playwright test**

```ts
import { expect, test } from '@playwright/test';

test('live mode signs in and renders backend conversations', async ({ page }) => {
  await page.route('**/v1/user/login', async (route) => {
    const request = route.request();
    expect(request.headers()).toMatchObject({
      appid: 'wukongchat',
    });
    const body = request.postDataJSON();
    expect(body).toMatchObject({
      username: '008613800000000',
      password: '123456',
      flag: 5,
    });
    await route.fulfill({
      contentType: 'application/json',
      body: JSON.stringify({ code: 0, data: { uid: 'u-live', token: 'token-live', im_token: 'im-live', name: '真实用户' } }),
    });
  });

  await page.route('**/v1/users/u-live', async (route) => {
    await route.fulfill({
      contentType: 'application/json',
      body: JSON.stringify({ code: 0, data: { uid: 'u-live', name: '真实用户', phone: '13800000000' } }),
    });
  });

  await page.route('**/v1/conversation/sync', async (route) => {
    await route.fulfill({
      contentType: 'application/json',
      body: JSON.stringify({
        code: 0,
        data: {
          conversations: [
            {
              channel_id: 'u-customer-live',
              channel_type: 1,
              unread: 2,
              timestamp: 1717000000,
              recents: [{ message_seq: 9, timestamp: 1717000000, payload: { type: 1, content: '真实会话消息' } }],
            },
          ],
        },
      }),
    });
  });

  await page.goto('/');
  await page.evaluate(() => window.localStorage.clear());
  await page.reload();

  await page.getByLabel('手机号').fill('13800000000');
  await page.getByLabel('密码').fill('123456');
  await page.getByRole('button', { name: '登录' }).click();

  await expect(page.getByRole('heading', { name: '会话' })).toBeVisible();
  await expect(page.getByText('真实会话消息')).toBeVisible();
  await expect(page.getByText('u-customer-live')).toBeVisible();
});
```

- [ ] **Step 3: Make Playwright web server accept live env**

In `web_im/playwright.config.ts`, change `webServer.command` to:

```ts
command: process.env.WK_WEB_IM_E2E_LIVE === '1'
  ? 'pnpm dev -- --mode live'
  : 'pnpm dev',
```

Add a `web_im/.env.live` file only if needed:

```dotenv
VITE_WK_WEB_IM_MODE=live
VITE_WK_API_BASE_URL=https://infoequity.cn
```

If `.env.live` is created, commit it because it contains no secrets beyond existing public client config.

- [ ] **Step 4: Run mock and live E2E**

Run mock: `pnpm --dir web_im e2e`

Expected: existing mock tests pass.

Run live mocked: `$env:WK_WEB_IM_E2E_LIVE='1'; pnpm --dir web_im e2e -- tests/live-auth-conversations.spec.ts`

Expected: live mocked test passes.

- [ ] **Step 5: Commit**

```bash
git add web_im/tests/smoke.spec.ts web_im/tests/live-auth-conversations.spec.ts web_im/playwright.config.ts web_im/.env.live
git commit -m "test(web-im): cover live auth conversations flow"
```

If `.env.live` is not created, omit it from `git add`.

## Task 7: Final Verification And Release Build

**Files:**
- Modify only if a verification failure reveals a Phase 2 bug.

- [ ] **Step 1: Run unit tests**

Run: `pnpm --dir web_im test`

Expected: all Vitest files pass, including Phase 1 and Phase 2 tests.

- [ ] **Step 2: Run production build**

Run: `pnpm --dir web_im build`

Expected: `vue-tsc --noEmit`, Vite build, and `scripts/assert-build.mjs` pass.

- [ ] **Step 3: Run Playwright smoke tests**

Run: `pnpm --dir web_im e2e`

Expected: mock-mode iPhone and desktop smoke tests pass.

- [ ] **Step 4: Run release script**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/build_web_im_release.ps1`

Expected: prints `WEB_IM_RELEASE_DIR=...\web_im\dist` and exits 0.

- [ ] **Step 5: Run Flutter release script test**

Run: `flutter test test/scripts/ops/web_im_release_build_test.dart`

Expected: `All tests passed!`

- [ ] **Step 6: Inspect git status**

Run: `git status --short`

Expected: only intentional Phase 2 files are modified or clean after commits.

- [ ] **Step 7: Commit final fixes if needed**

If any verification fix was required:

```bash
git add web_im docs/superpowers/plans/2026-05-29-web-im-phase2-auth-conversations.md
git commit -m "fix(web-im): stabilize phase2 auth conversations"
```

If no fixes were required, do not create an empty commit.

## Self-Review Checklist

- Spec coverage: runtime mode, signed HTTP, login, restore, current user, conversation sync, storage, UI states, E2E, rollback are covered by Tasks 1-7.
- Android/Windows safety: no planned edits outside `web_im/` and docs.
- TDD compliance: every new behavior starts with failing Vitest or Playwright coverage before implementation.
- No backend changes: all API work uses existing endpoints.
- No send/WebSocket scope creep: chat remains Phase 2 read-only/live-placeholder.
