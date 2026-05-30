import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearConversationTitleCacheForTest,
  hydrateConversationTitles,
  mapConversationProfile,
} from './conversationTitleHydrationApi';
import type { Conversation } from '../models/im';

const config = {
  mode: 'live' as const,
  apiBaseUrl: 'https://infoequity.cn',
  appId: 'wukongchat',
  appKey: 'key',
  deviceFlag: 1,
};

function conversation(overrides: Partial<Conversation> = {}): Conversation {
  return {
    id: '1:u1',
    channelId: 'u1',
    channelType: 1,
    title: '用户 u1',
    avatarText: '用',
    titleSource: 'fallback',
    lastMessage: 'hello',
    lastMessageAt: '昨天',
    unreadCount: 0,
    muted: false,
    ...overrides,
  };
}

describe('conversation title hydration api', () => {
  beforeEach(() => {
    clearConversationTitleCacheForTest();
  });

  it('maps user and group profile names from common response shapes', () => {
    expect(mapConversationProfile({ data: { remark: '客户备注', name: '客户名' } })).toEqual({ title: '客户备注' });
    expect(mapConversationProfile({ group_name: '项目交付群' })).toEqual({ title: '项目交付群' });
    expect(mapConversationProfile({ data: { displayName: '显示名' } })).toEqual({ title: '显示名' });
    expect(mapConversationProfile({ data: { name: '   ' } })).toBeNull();
  });

  it('hydrates fallback user and group conversations through signed profile requests', async () => {
    const request = vi
      .fn()
      .mockResolvedValueOnce({ data: { name: '李欣放' } })
      .mockResolvedValueOnce({ data: { group_name: '项目交付群' } });

    const result = await hydrateConversationTitles(
      [
        conversation({ id: '1:u-live', channelId: 'u-live', channelType: 1, title: '用户 live' }),
        conversation({ id: '2:g-live', channelId: 'g-live', channelType: 2, title: '群聊 live' }),
      ],
      { token: 'token', config, request },
    );

    expect(request).toHaveBeenNthCalledWith(1, expect.objectContaining({
      path: '/v1/users/u-live',
      method: 'GET',
      token: 'token',
    }));
    expect(request).toHaveBeenNthCalledWith(2, expect.objectContaining({
      path: '/v1/groups/g-live',
      method: 'GET',
      token: 'token',
    }));
    expect(result).toEqual([
      expect.objectContaining({ channelId: 'u-live', title: '李欣放', avatarText: '李', titleSource: 'hydrated' }),
      expect.objectContaining({ channelId: 'g-live', title: '项目交付群', avatarText: '项', titleSource: 'hydrated' }),
    ]);
  });

  it('hydrates group conversations that still display placeholder titles from sync metadata', async () => {
    const request = vi
      .fn()
      .mockResolvedValueOnce({ data: { name: 'Project Delivery' } })
      .mockResolvedValueOnce({ data: { name: 'Escalation Room' } });

    const result = await hydrateConversationTitles(
      [
        conversation({
          id: '2:group-8487',
          channelId: 'group-8487',
          channelType: 2,
          title: '群聊 8487',
          titleSource: 'api',
        }),
        conversation({
          id: '2:group-raw-id',
          channelId: 'group-raw-id',
          channelType: 2,
          title: 'group-raw-id',
          titleSource: 'api',
        }),
      ],
      { token: 'token', config, request },
    );

    expect(request).toHaveBeenNthCalledWith(1, expect.objectContaining({ path: '/v1/groups/group-8487' }));
    expect(request).toHaveBeenNthCalledWith(2, expect.objectContaining({ path: '/v1/groups/group-raw-id' }));
    expect(result).toEqual([
      expect.objectContaining({ channelId: 'group-8487', title: 'Project Delivery', avatarText: 'P', titleSource: 'hydrated' }),
      expect.objectContaining({ channelId: 'group-raw-id', title: 'Escalation Room', avatarText: 'E', titleSource: 'hydrated' }),
    ]);
  });

  it('skips api-provided titles and preserves fallback titles on lookup failure', async () => {
    const request = vi.fn().mockRejectedValue(new Error('not found'));
    const apiProvided = conversation({
      id: '1:u-known',
      channelId: 'u-known',
      title: '已有名称',
      avatarText: '已',
      titleSource: 'api',
    });
    const fallback = conversation({ id: '1:u-missing', channelId: 'u-missing', title: '用户 sing' });

    const result = await hydrateConversationTitles([apiProvided, fallback], { token: 'token', config, request });

    expect(request).toHaveBeenCalledTimes(1);
    expect(request).toHaveBeenCalledWith(expect.objectContaining({ path: '/v1/users/u-missing' }));
    expect(result).toEqual([apiProvided, fallback]);
  });

  it('reuses cached profile titles for repeated hydration calls', async () => {
    const request = vi.fn().mockResolvedValue({ data: { name: '缓存用户' } });
    const input = [conversation({ id: '1:u-cache', channelId: 'u-cache', title: '用户 ache' })];

    await expect(hydrateConversationTitles(input, { token: 'token', cacheScope: 'u-current', config, request })).resolves.toEqual([
      expect.objectContaining({ title: '缓存用户' }),
    ]);
    await expect(hydrateConversationTitles(input, { token: 'token', cacheScope: 'u-current', config, request })).resolves.toEqual([
      expect.objectContaining({ title: '缓存用户' }),
    ]);

    expect(request).toHaveBeenCalledTimes(1);
  });

  it('keeps cached profile titles scoped to the current signed-in user', async () => {
    const request = vi
      .fn()
      .mockResolvedValueOnce({ data: { remark: '我的客户备注' } })
      .mockResolvedValueOnce({ data: { remark: '同事客户备注' } });
    const input = [conversation({ id: '1:u-shared', channelId: 'u-shared', title: '用户 ared' })];

    await expect(hydrateConversationTitles(input, { token: 'token-a', cacheScope: 'u-current-a', config, request })).resolves.toEqual([
      expect.objectContaining({ title: '我的客户备注' }),
    ]);
    await expect(hydrateConversationTitles(input, { token: 'token-b', cacheScope: 'u-current-b', config, request })).resolves.toEqual([
      expect.objectContaining({ title: '同事客户备注' }),
    ]);

    expect(request).toHaveBeenCalledTimes(2);
  });
});
