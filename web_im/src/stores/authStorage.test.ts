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

  it('returns null for malformed auth snapshots missing live auth fields', () => {
    window.localStorage.setItem(
      'wk_web_im_auth_v1',
      JSON.stringify({
        uid: 'u1',
        token: 't1',
        savedAt: 1,
      }),
    );

    expect(loadAuthSnapshot()).toBeNull();

    window.localStorage.setItem(
      'wk_web_im_auth_v1',
      JSON.stringify({
        uid: 'u1',
        token: 't1',
        imToken: 'im1',
        user: { id: 'u1', name: 'Alice' },
        savedAt: 1,
      }),
    );

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

  it('uses a short backend-safe device model instead of the full browser user agent', () => {
    const longIosSafariUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
    Object.defineProperty(window.navigator, 'userAgent', {
      configurable: true,
      value: longIosSafariUserAgent,
    });

    const identity = loadOrCreateDeviceIdentity();

    expect(identity.deviceModel).toBe('iOS Safari');
    expect(identity.deviceModel.length).toBeLessThanOrEqual(32);
  });

  it('normalizes previously stored full user-agent device models', () => {
    const longIosSafariUserAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1';
    window.localStorage.setItem(
      'wk_web_im_device_v1',
      JSON.stringify({
        deviceId: 'web-existing',
        deviceInstallId: 'install-existing',
        deviceName: 'Web PWA',
        deviceModel: longIosSafariUserAgent,
      }),
    );

    const identity = loadOrCreateDeviceIdentity();

    expect(identity.deviceId).toBe('web-existing');
    expect(identity.deviceInstallId).toBe('install-existing');
    expect(identity.deviceModel).toBe('iOS Safari');
    expect(JSON.parse(window.localStorage.getItem('wk_web_im_device_v1') ?? '{}').deviceModel).toBe('iOS Safari');
  });
});
