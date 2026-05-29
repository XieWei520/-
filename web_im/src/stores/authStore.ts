import { computed, ref } from 'vue';
import { defineStore } from 'pinia';
import { fetchCurrentUser, loginWithPhone } from '../api/authApi';
import { isMockMode, runtimeConfig } from '../config/runtimeConfig';
import { fakeCurrentUser } from '../mocks/fakeImData';
import type { CurrentUser } from '../models/im';
import {
  clearAuthSnapshot,
  loadAuthSnapshot,
  loadOrCreateDeviceIdentity,
  saveAuthSnapshot,
  type AuthSnapshot,
} from './authStorage';

const tokenKey = 'wk_web_im_fake_token';

function getStoredToken(): string | null {
  if (typeof window === 'undefined') {
    return null;
  }

  try {
    return window.localStorage.getItem(tokenKey);
  } catch {
    return null;
  }
}

function setStoredToken(token: string): void {
  if (typeof window === 'undefined') {
    return;
  }

  try {
    window.localStorage.setItem(tokenKey, token);
  } catch {
    // Storage can be unavailable in iOS private or locked-down contexts.
  }
}

function clearStoredToken(): void {
  if (typeof window === 'undefined') {
    return;
  }

  try {
    window.localStorage.removeItem(tokenKey);
  } catch {
    // Ignore storage failures so logout can still clear in-memory auth state.
  }
}

export const useAuthStore = defineStore('auth', () => {
  const snapshot = loadAuthSnapshot();
  const fakeToken = snapshot ? null : getStoredToken();
  const uid = ref<string | null>(snapshot?.uid ?? null);
  const token = ref<string | null>(snapshot?.token ?? fakeToken);
  const imToken = ref<string | null>(snapshot?.imToken ?? null);
  const user = ref<CurrentUser | null>(snapshot?.user ?? (fakeToken ? { ...fakeCurrentUser } : null));
  const isLoggedIn = computed(() => Boolean(token.value && user.value));
  const sessionForConversationSync = computed(() => {
    if (!uid.value || !token.value || !imToken.value) {
      return null;
    }

    return {
      uid: uid.value,
      token: token.value,
      imToken: imToken.value,
      deviceUuid: loadOrCreateDeviceIdentity().deviceId,
    };
  });

  function loginMock(phone: string, password: string): void {
    const normalizedPhone = phone.trim();

    if (!/^1\d{10}$/.test(normalizedPhone)) {
      throw new Error('请输入 11 位中国大陆手机号');
    }

    if (password.length < 4) {
      throw new Error('密码至少需要 4 位');
    }

    const nextToken = `fake-token-${normalizedPhone}`;
    setStoredToken(nextToken);
    uid.value = null;
    token.value = nextToken;
    imToken.value = null;
    user.value = {
      ...fakeCurrentUser,
      phone: normalizedPhone,
    };
  }

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

    uid.value = credential.uid;
    token.value = credential.token;
    imToken.value = credential.imToken;
    user.value = currentUser;
    saveAuthSnapshot({
      uid: credential.uid,
      token: credential.token,
      imToken: credential.imToken,
      user: currentUser,
      savedAt: Date.now(),
    });
  }

  function clearState(): void {
    uid.value = null;
    token.value = null;
    imToken.value = null;
    user.value = null;
  }

  function logout(): void {
    clearStoredToken();
    clearAuthSnapshot();
    clearState();
  }

  function applyLiveSession(snapshot: AuthSnapshot): void {
    uid.value = snapshot.uid;
    token.value = snapshot.token;
    imToken.value = snapshot.imToken;
    user.value = snapshot.user;
  }

  function setLiveSessionForTest(snapshot: AuthSnapshot): void {
    applyLiveSession(snapshot);
    saveAuthSnapshot(snapshot);
  }

  async function restoreSessionForTest(loader?: (snapshot: AuthSnapshot) => Promise<CurrentUser> | CurrentUser): Promise<void> {
    const existing = loadAuthSnapshot();
    if (!existing) {
      clearState();
      return;
    }

    try {
      const restoredUser = loader ? await loader(existing) : existing.user;
      const restored = { ...existing, user: restoredUser };
      applyLiveSession(restored);
      saveAuthSnapshot(restored);
    } catch (error) {
      if (typeof error === 'object' && error !== null && 'unauthorized' in error && error.unauthorized) {
        clearAuthSnapshot();
        clearState();
        return;
      }
      throw error;
    }
  }

  return {
    uid,
    token,
    imToken,
    user,
    isLoggedIn,
    sessionForConversationSync,
    login,
    logout,
    setLiveSessionForTest,
    restoreSessionForTest,
  };
});
