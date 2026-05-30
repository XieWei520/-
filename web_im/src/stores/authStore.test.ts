import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useAuthStore } from './authStore';
import { saveAuthSnapshot } from './authStorage';

const { runtimeConfig } = vi.hoisted(() => ({
  runtimeConfig: {
    mode: 'mock',
    apiBaseUrl: 'https://infoequity.cn',
    appId: 'wukongchat',
    appKey: 'key',
    deviceFlag: 5,
  },
}));

vi.mock('../config/runtimeConfig', () => ({
  runtimeConfig,
  isMockMode: vi.fn((config: { mode: string }) => config.mode === 'mock'),
  isLiveMode: vi.fn((config: { mode: string }) => config.mode === 'live'),
}));

describe('auth store storage resilience', () => {
  beforeEach(() => {
    runtimeConfig.mode = 'mock';
    setActivePinia(createPinia());
    vi.restoreAllMocks();
    window.localStorage.clear();
  });

  it('treats unavailable localStorage as logged out', () => {
    vi.spyOn(Storage.prototype, 'getItem').mockImplementation(() => {
      throw new DOMException('storage disabled', 'SecurityError');
    });

    expect(() => useAuthStore()).not.toThrow();
    expect(useAuthStore().isLoggedIn).toBe(false);
  });

  it('does not crash login or logout when localStorage writes fail', async () => {
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('storage disabled', 'SecurityError');
    });
    vi.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => {
      throw new DOMException('storage disabled', 'SecurityError');
    });

    const auth = useAuthStore();

    await expect(auth.login('13800138000', '1234')).resolves.toBeUndefined();
    expect(auth.isLoggedIn).toBe(true);
    expect(() => auth.logout()).not.toThrow();
    expect(auth.isLoggedIn).toBe(false);
  });

  it('clears live auth when session restore is unauthorized', async () => {
    saveAuthSnapshot({
      uid: 'u1',
      token: 't1',
      imToken: 't1',
      user: { id: 'u1', uid: 'u1', name: 'Alice', phone: '', avatarText: 'A', connectionState: 'connected' },
      savedAt: 1,
    });
    const auth = useAuthStore();

    await auth.restoreSession(async () => {
      throw Object.assign(new Error('expired'), { unauthorized: true });
    });

    expect(auth.isLoggedIn).toBe(false);
    expect(auth.user).toBeNull();
  });

  it('restores live auth from a saved snapshot with an optional user loader', async () => {
    saveAuthSnapshot({
      uid: 'u1',
      token: 't1',
      imToken: 'im1',
      user: { id: 'u1', uid: 'u1', name: 'Alice', phone: '', avatarText: 'A', connectionState: 'connected' },
      savedAt: 1,
    });
    const auth = useAuthStore();

    await auth.restoreSession(() => ({
      id: 'u1',
      uid: 'u1',
      name: 'Alice Updated',
      phone: '',
      avatarText: 'A',
      connectionState: 'connected',
    }));

    expect(auth.isLoggedIn).toBe(true);
    expect(auth.uid).toBe('u1');
    expect(auth.imToken).toBe('im1');
    expect(auth.user?.name).toBe('Alice Updated');
  });

  it('ignores fake localStorage tokens in live mode', () => {
    window.localStorage.setItem('wk_web_im_fake_token', 'fake-token-13800138000');
    runtimeConfig.mode = 'live';

    const auth = useAuthStore();

    expect(auth.isLoggedIn).toBe(false);
    expect(auth.user).toBeNull();
    expect(auth.token).toBeNull();
  });

  it('restores fake localStorage tokens in mock mode', () => {
    window.localStorage.setItem('wk_web_im_fake_token', 'fake-token-13800138000');

    const auth = useAuthStore();

    expect(auth.isLoggedIn).toBe(true);
    expect(auth.user).not.toBeNull();
    expect(auth.token).toBe('fake-token-13800138000');
  });
});
