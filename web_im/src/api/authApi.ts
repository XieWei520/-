import type { WebImRuntimeConfig } from '../config/runtimeConfig';
import type { CurrentUser } from '../models/im';
import type { WebDeviceIdentity } from '../stores/authStorage';
import { ApiError } from './apiError';
import { signedJsonRequest, type SignedJsonRequestOptions } from './signedHttpClient';

const unsupportedLoginVerificationMessage = '褰撳墠 Web 鐗堟湰鏆備笉鏀寔鐧诲綍浜屾楠岃瘉';

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

type AuthRequest = <TResult, TBody = unknown>(options: SignedJsonRequestOptions<TBody>) => Promise<TResult>;

interface RequestContext {
  config: WebImRuntimeConfig;
  request?: AuthRequest;
}

export interface LoginWithPhoneOptions extends RequestContext {
  phone: string;
  password: string;
  device: WebDeviceIdentity;
}

export interface FetchCurrentUserOptions extends RequestContext {
  uid: string;
  token: string;
}

interface CurrentUserFallback {
  uid?: string;
  name?: string;
  username?: string;
  phone?: string;
  avatar?: string;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function readString(record: Record<string, unknown> | null, key: string): string | undefined {
  const value = record?.[key];
  return typeof value === 'string' ? value.trim() : undefined;
}

function normalizeCode(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function dataRecord(raw: unknown): Record<string, unknown> | null {
  const root = asRecord(raw);
  return asRecord(root?.data) ?? root;
}

export function parseLoginResponse(raw: unknown): LoginCredential {
  const root = asRecord(raw);
  const code = normalizeCode(root?.code);
  if (code === 110) {
    throw new ApiError(unsupportedLoginVerificationMessage, { code, retryable: false });
  }

  const data = dataRecord(raw);
  const uid = readString(data, 'uid');
  const token = readString(data, 'token');
  if (!uid || !token) {
    const message = readString(root, 'msg') ?? readString(root, 'message') ?? 'Login response missing uid or token';
    throw new ApiError(message, { code, retryable: false });
  }

  return {
    uid,
    token,
    imToken: readString(data, 'im_token') ?? readString(data, 'imToken') ?? token,
    name: readString(data, 'name'),
    username: readString(data, 'username'),
    avatar: readString(data, 'avatar'),
    phone: readString(data, 'phone'),
    zone: readString(data, 'zone'),
  };
}

export function mapCurrentUser(raw: unknown, fallback: CurrentUserFallback = {}): CurrentUser {
  const data = dataRecord(raw);
  const uid = readString(data, 'uid') ?? fallback.uid ?? '';
  const name = readString(data, 'name') ?? readString(data, 'username') ?? fallback.name ?? fallback.username ?? uid ?? '鎴?';
  const phone = readString(data, 'phone') ?? fallback.phone ?? '';
  const avatarUrl = readString(data, 'avatar') ?? fallback.avatar ?? '';

  return {
    id: uid,
    uid,
    name,
    phone,
    avatarText: name.charAt(0).toUpperCase() || '鎴?',
    avatarUrl,
    connectionState: 'connected',
  };
}

export async function loginWithPhone(options: LoginWithPhoneOptions): Promise<LoginCredential> {
  const request = options.request ?? signedJsonRequest;
  let raw: unknown;

  try {
    raw = await request({
      baseUrl: options.config.apiBaseUrl,
      appId: options.config.appId,
      appKey: options.config.appKey,
      path: '/v1/user/login',
      method: 'POST',
      body: {
        username: `0086${options.phone.trim()}`,
        password: options.password,
        flag: options.config.deviceFlag,
        device: {
          device_id: options.device.deviceId,
          device_install_id: options.device.deviceInstallId,
          device_name: options.device.deviceName,
          device_model: options.device.deviceModel,
        },
      },
    });
  } catch (error) {
    if (error instanceof ApiError && error.code === 110) {
      throw new ApiError(unsupportedLoginVerificationMessage, { code: error.code, retryable: false });
    }
    throw error;
  }

  return parseLoginResponse(raw);
}

export async function fetchCurrentUser(options: FetchCurrentUserOptions): Promise<CurrentUser> {
  const request = options.request ?? signedJsonRequest;
  const raw = await request({
    baseUrl: options.config.apiBaseUrl,
    appId: options.config.appId,
    appKey: options.config.appKey,
    token: options.token,
    path: `/v1/users/${encodeURIComponent(options.uid)}`,
    method: 'GET',
  });

  return mapCurrentUser(raw, { uid: options.uid });
}
