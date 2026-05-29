import { describe, expect, it, vi } from 'vitest';
import { ApiError } from './apiError';
import { loginWithPhone, mapCurrentUser, parseLoginResponse } from './authApi';

describe('auth api', () => {
  it('parses nested and direct login response shapes', () => {
    expect(parseLoginResponse({ code: 0, data: { uid: 'u1', token: 't1', im_token: 'im1', name: 'Alice' } })).toMatchObject({
      uid: 'u1',
      token: 't1',
      imToken: 'im1',
      name: 'Alice',
    });
    expect(parseLoginResponse({ uid: 'u2', token: 't2' })).toMatchObject({
      uid: 'u2',
      token: 't2',
      imToken: 't2',
    });
  });

  it('rejects login verification code 110 as unsupported in phase 2', () => {
    expect(() => parseLoginResponse({ code: 110, data: { uid: 'u1' }, msg: 'check phone' })).toThrow(
      '褰撳墠 Web 鐗堟湰鏆備笉鏀寔鐧诲綍浜屾楠岃瘉',
    );
  });

  it('maps current user fields with safe fallbacks', () => {
    expect(mapCurrentUser({ uid: 'u1', name: 'Alice', phone: '13800000000', avatar: '' })).toEqual({
      id: 'u1',
      uid: 'u1',
      name: 'Alice',
      phone: '13800000000',
      avatarText: 'A',
      avatarUrl: '',
      connectionState: 'connected',
    });
  });

  it('ignores blank current user fields and uses fallback user values', () => {
    expect(
      mapCurrentUser(
        { uid: '', name: '', phone: '', avatar: '' },
        { uid: 'u-fallback', name: 'Fallback', phone: '13900000000', avatar: 'avatar.png' },
      ),
    ).toEqual({
      id: 'u-fallback',
      uid: 'u-fallback',
      name: 'Fallback',
      phone: '13900000000',
      avatarText: 'F',
      avatarUrl: 'avatar.png',
      connectionState: 'connected',
    });
  });

  it('posts phone login with 0086 username and configured device flag', async () => {
    const request = vi.fn().mockResolvedValue({ uid: 'u1', token: 't1' });
    const result = await loginWithPhone({
      phone: '13800000000',
      password: '123456',
      request,
      config: {
        mode: 'live',
        apiBaseUrl: 'https://infoequity.cn',
        appId: 'wukongchat',
        appKey: 'key',
        deviceFlag: 5,
      },
      device: {
        deviceId: 'web-device',
        deviceInstallId: 'install',
        deviceName: 'Web PWA',
        deviceModel: 'iPhone',
      },
    });

    expect(result).toMatchObject({ uid: 'u1', token: 't1', imToken: 't1' });
    expect(request).toHaveBeenCalledWith(
      expect.objectContaining({
        path: '/v1/user/login',
        method: 'POST',
        body: {
          username: '008613800000000',
          password: '123456',
          flag: 5,
          device: {
            device_id: 'web-device',
            device_install_id: 'install',
            device_name: 'Web PWA',
            device_model: 'iPhone',
          },
        },
      }),
    );
  });

  it('remaps request-layer login verification code 110 to the unsupported verification message', async () => {
    const request = vi.fn().mockRejectedValue(new ApiError('check phone', { code: 110, retryable: false }));

    await expect(
      loginWithPhone({
        phone: '13800000000',
        password: '123456',
        request,
        config: {
          mode: 'live',
          apiBaseUrl: 'https://infoequity.cn',
          appId: 'wukongchat',
          appKey: 'key',
          deviceFlag: 5,
        },
        device: {
          deviceId: 'web-device',
          deviceInstallId: 'install',
          deviceName: 'Web PWA',
          deviceModel: 'iPhone',
        },
      }),
    ).rejects.toMatchObject({
      message: '褰撳墠 Web 鐗堟湰鏆備笉鏀寔鐧诲綍浜屾楠岃瘉',
      retryable: false,
    });
  });
});
