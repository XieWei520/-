import { describe, expect, it } from 'vitest';
import { createRuntimeConfig, isLiveMode, isMockMode, normalizeApiBaseUrl, normalizeMode } from './runtimeConfig';

describe('runtime config', () => {
  it('defaults to mock mode and production API base URL', () => {
    const config = createRuntimeConfig({});

    expect(config.mode).toBe('mock');
    expect(config.apiBaseUrl).toBe('https://infoequity.cn');
    expect(config.appId).toBe('wukongchat');
    expect(config.appKey).toBe('25b002c6be2d539f264c');
    expect(config.deviceFlag).toBe(1);
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
      deviceFlag: 1,
    });
  });
});
