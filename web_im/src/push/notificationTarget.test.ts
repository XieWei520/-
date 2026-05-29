import { describe, expect, it } from 'vitest';
import { resolveNotificationTarget } from './notificationTarget';

describe('resolveNotificationTarget', () => {
  it('builds chat route from channel payload', () => {
    expect(resolveNotificationTarget({ channel_id: 'abc', channel_type: 2 })).toBe('/im/chat/2/abc');
  });

  it('rejects cross-origin explicit urls', () => {
    expect(resolveNotificationTarget({ url: 'https://evil.example/chat' })).toBe('/im/conversations');
  });

  it('accepts same-app explicit relative urls', () => {
    expect(resolveNotificationTarget({ url: '/im/chat/1/customer-a' })).toBe('/im/chat/1/customer-a');
  });

  it('rejects dot segment urls that normalize outside the app', () => {
    expect(resolveNotificationTarget({ url: '/im/../admin' })).toBe('/im/conversations');
  });

  it('rejects encoded dot segment urls that normalize outside the app', () => {
    expect(resolveNotificationTarget({ url: '/im/%2e%2e/admin' })).toBe('/im/conversations');
  });

  it('builds chat route from nested channel payload', () => {
    expect(resolveNotificationTarget({ payload: { channelId: 'nested-id', channelType: 1 } })).toBe('/im/chat/1/nested-id');
  });

  it('rejects invalid channel type', () => {
    expect(resolveNotificationTarget({ channel_id: 'abc', channel_type: 3 })).toBe('/im/conversations');
  });

  it('rejects blank channel id', () => {
    expect(resolveNotificationTarget({ channel_id: '   ', channel_type: 1 })).toBe('/im/conversations');
  });
});
