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
const defaultDeviceFlag = 1;

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
