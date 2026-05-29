import { describe, expect, it } from 'vitest';
import { routes } from './router';

describe('web im routes', () => {
  it('defines the mobile-first phase 1 route surface', () => {
    expect(routes.map((route) => route.path)).toEqual([
      '/login',
      '/',
      '/conversations',
      '/contacts',
      '/me',
      '/chat/:channelType/:channelId',
    ]);
  });
});
