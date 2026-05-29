import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useAuthStore } from './authStore';

describe('auth store storage resilience', () => {
  beforeEach(() => {
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

  it('does not crash login or logout when localStorage writes fail', () => {
    vi.spyOn(Storage.prototype, 'setItem').mockImplementation(() => {
      throw new DOMException('storage disabled', 'SecurityError');
    });
    vi.spyOn(Storage.prototype, 'removeItem').mockImplementation(() => {
      throw new DOMException('storage disabled', 'SecurityError');
    });

    const auth = useAuthStore();

    expect(() => auth.login('13800138000', '1234')).not.toThrow();
    expect(auth.isLoggedIn).toBe(true);
    expect(() => auth.logout()).not.toThrow();
    expect(auth.isLoggedIn).toBe(false);
  });
});
