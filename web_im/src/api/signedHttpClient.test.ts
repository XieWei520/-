import { beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError } from './apiError';
import { createSignedHeaders, signedJsonRequest, stableJsonStringify } from './signedHttpClient';

describe('signed HTTP client', () => {
  beforeEach(() => {
    vi.restoreAllMocks();
  });

  it('serializes objects exactly once for signing and sending', () => {
    expect(stableJsonStringify({ username: '008613800000000', password: '123456' })).toBe(
      '{"username":"008613800000000","password":"123456"}',
    );
  });

  it('builds deterministic Flutter-compatible signed headers', async () => {
    const headers = await createSignedHeaders({
      body: '{"username":"008613800000000","password":"123456"}',
      appId: 'wukongchat',
      appKey: '25b002c6be2d539f264c',
      token: 'token-a',
      now: () => 1717000000000,
      nonce: () => 'ABCDEFGHIJKLMNOP',
    });

    expect(headers).toMatchObject({
      'Content-Type': 'application/json',
      Accept: 'application/json',
      appid: 'wukongchat',
      timestamp: '1717000000000',
      noncestr: 'ABCDEFGHIJKLMNOP',
      token: 'token-a',
    });
    expect(headers.sign).toHaveLength(32);
    expect(headers.sign).toMatch(/^[a-f0-9]{32}$/);
    expect(headers.sign).toBe('ad4431a046fca758eb045c9fa15310ac');
  });

  it('sends signed JSON and unwraps data payloads', async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ code: 0, data: { ok: true } }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    const result = await signedJsonRequest<{ ok: boolean }>({
      baseUrl: 'https://infoequity.cn',
      path: '/v1/example',
      method: 'POST',
      body: { a: 1 },
      appId: 'wukongchat',
      appKey: 'key',
      fetchImpl: fetchMock,
      now: () => 1,
      nonce: () => 'ABCDEFGHIJKLMNOP',
    });

    expect(result).toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledWith(
      'https://infoequity.cn/v1/example',
      expect.objectContaining({
        method: 'POST',
        body: '{"a":1}',
        headers: expect.objectContaining({
          appid: 'wukongchat',
          timestamp: '1',
          noncestr: 'ABCDEFGHIJKLMNOP',
        }),
      }),
    );
  });

  it('throws typed unauthorized and retryable errors', async () => {
    const unauthorizedFetch = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ code: 401, msg: 'expired' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      }),
    );

    await expect(
      signedJsonRequest({
        baseUrl: 'https://infoequity.cn',
        path: '/v1/user',
        method: 'GET',
        appId: 'wukongchat',
        appKey: 'key',
        fetchImpl: unauthorizedFetch,
      }),
    ).rejects.toMatchObject({ unauthorized: true, retryable: false, message: 'expired' });

    const failingFetch = vi.fn().mockRejectedValue(new TypeError('Failed to fetch'));

    await expect(
      signedJsonRequest({
        baseUrl: 'https://infoequity.cn',
        path: '/v1/user',
        method: 'GET',
        appId: 'wukongchat',
        appKey: 'key',
        fetchImpl: failingFetch,
      }),
    ).rejects.toBeInstanceOf(ApiError);
    await expect(
      signedJsonRequest({
        baseUrl: 'https://infoequity.cn',
        path: '/v1/user',
        method: 'GET',
        appId: 'wukongchat',
        appKey: 'key',
        fetchImpl: failingFetch,
      }),
    ).rejects.toMatchObject({ retryable: true, unauthorized: false });
  });
});
