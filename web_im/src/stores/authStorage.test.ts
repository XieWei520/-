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
