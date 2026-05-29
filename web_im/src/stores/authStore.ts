import { computed, ref } from 'vue';
import { defineStore } from 'pinia';
import { fakeCurrentUser } from '../mocks/fakeImData';
import type { CurrentUser } from '../models/im';

const tokenKey = 'wk_web_im_fake_token';

function getStoredToken(): string | null {
  if (typeof window === 'undefined') {
    return null;
  }

  return window.localStorage.getItem(tokenKey);
}

function setStoredToken(token: string): void {
  window.localStorage.setItem(tokenKey, token);
}

function clearStoredToken(): void {
  window.localStorage.removeItem(tokenKey);
}

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(getStoredToken());
  const user = ref<CurrentUser | null>(token.value ? { ...fakeCurrentUser } : null);
  const isLoggedIn = computed(() => Boolean(token.value && user.value));

  function login(phone: string, password: string): void {
    const normalizedPhone = phone.trim();

    if (!/^1\d{10}$/.test(normalizedPhone)) {
      throw new Error('请输入 11 位中国大陆手机号');
    }

    if (password.length < 4) {
      throw new Error('密码至少需要 4 位');
    }

    const nextToken = `fake-token-${normalizedPhone}`;
    setStoredToken(nextToken);
    token.value = nextToken;
    user.value = {
      ...fakeCurrentUser,
      phone: normalizedPhone,
    };
  }

  function logout(): void {
    clearStoredToken();
    token.value = null;
    user.value = null;
  }

  return {
    token,
    user,
    isLoggedIn,
    login,
    logout,
  };
});
