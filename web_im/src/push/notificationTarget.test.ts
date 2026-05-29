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
});