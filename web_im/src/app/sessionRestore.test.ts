import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { reactive } from 'vue';
import { ApiError } from '../api/apiError';
import { saveAuthSnapshot } from '../stores/authStorage';
import { useAuthStore } from '../stores/authStore';
import { fetchCurrentUser } from '../api/authApi';
import { restoreLiveSessionOnStartup } from './sessionRestore';

const { runtimeConfig } = vi.hoisted(() => ({
  runtimeConfig: {
    mode: 'live',
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

vi.mock('../api/authApi', () => ({
  fetchCurrentUser: vi.fn(),
}));

const fetchCurrentUserMock = vi.mocked(fetchCurrentUser);

function createRouterStub(path = '/conversations') {
  return {
    currentRoute: {
      value: reactive({ path }),
    },
    replace: vi.fn(),
  };
}

function saveLiveSnapshot() {
  saveAuthSnapshot({
    uid: 'u1',
    token: 't1',
    imToken: 'im1',
    user: { id: 'u1', uid: 'u1', name: 'Cached', phone: '', avatarText: 'C', connectionState: 'connected' },
    savedAt: 1,
  });
}

describe('startup live session restore', () => {
  beforeEach(() => {
    runtimeConfig.mode = 'live';
    fetchCurrentUserMock.mockReset();
    window.localStorage.clear();
    setActivePinia(createPinia());
  });

  it('validates saved live auth through the current-user endpoint', async () => {
    const pinia = createPinia();
    setActivePinia(pinia);
    saveLiveSnapshot();
    const router = createRouterStub();
    fetchCurrentUserMock.mockResolvedValue({
      id: 'u1',
      uid: 'u1',
      name: 'Updated',
      phone: '',
      avatarText: 'U',
      connectionState: 'connected',
    });

    await restoreLiveSessionOnStartup(pinia, router as never);

    expect(fetchCurrentUserMock).toHaveBeenCalledWith({
      uid: 'u1',
      token: 't1',
      config: runtimeConfig,
    });
    expect(useAuthStore(pinia).user?.name).toBe('Updated');
    expect(router.replace).not.toHaveBeenCalled();
  });

  it('clears saved live auth and routes to login when validation is unauthorized', async () => {
    const pinia = createPinia();
    setActivePinia(pinia);
    saveLiveSnapshot();
    const router = createRouterStub('/me');
    fetchCurrentUserMock.mockRejectedValue(new ApiError('expired', { status: 401 }));

    await restoreLiveSessionOnStartup(pinia, router as never);

    expect(useAuthStore(pinia).isLoggedIn).toBe(false);
    expect(router.replace).toHaveBeenCalledWith('/login');
  });

  it('keeps the cached session visible when validation fails due to network', async () => {
    const pinia = createPinia();
    setActivePinia(pinia);
    saveLiveSnapshot();
    const router = createRouterStub('/conversations');
    fetchCurrentUserMock.mockRejectedValue(new ApiError('Network request failed', { retryable: true }));

    await expect(restoreLiveSessionOnStartup(pinia, router as never)).resolves.toBeUndefined();

    expect(useAuthStore(pinia).isLoggedIn).toBe(true);
    expect(useAuthStore(pinia).user?.connectionState).toBe('offline');
    expect(router.replace).not.toHaveBeenCalled();
  });

  it('does not run live restore in mock mode', async () => {
    runtimeConfig.mode = 'mock';
    const pinia = createPinia();
    setActivePinia(pinia);
    saveLiveSnapshot();
    const router = createRouterStub('/conversations');

    await restoreLiveSessionOnStartup(pinia, router as never);

    expect(fetchCurrentUserMock).not.toHaveBeenCalled();
    expect(router.replace).not.toHaveBeenCalled();
  });
});
