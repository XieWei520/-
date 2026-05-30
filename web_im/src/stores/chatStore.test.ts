import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useChatStore } from './chatStore';
import { loadConversationSync } from '../api/conversationSyncApi';
import { hydrateConversationTitles } from '../api/conversationTitleHydrationApi';
import { fakeConversations } from '../mocks/fakeImData';

const { runtimeConfig } = vi.hoisted(() => ({
  runtimeConfig: {
    mode: 'live',
    apiBaseUrl: 'https://infoequity.cn',
    appId: 'wukongchat',
    appKey: 'key',
    deviceFlag: 5,
  },
}));

vi.mock('../config/runtimeConfig', () => ({
  runtimeConfig,
  isLiveMode: vi.fn((config: { mode: string }) => config.mode === 'live'),
  isMockMode: vi.fn((config: { mode: string }) => config.mode === 'mock'),
}));

vi.mock('../api/conversationSyncApi', () => ({
  loadConversationSync: vi.fn(),
}));

vi.mock('../api/conversationTitleHydrationApi', () => ({
  hydrateConversationTitles: vi.fn(),
}));

const loadConversationSyncMock = vi.mocked(loadConversationSync);
const hydrateConversationTitlesMock = vi.mocked(hydrateConversationTitles);

describe('chat store unknown active channels', () => {
  beforeEach(() => {
    runtimeConfig.mode = 'live';
    loadConversationSyncMock.mockReset();
    hydrateConversationTitlesMock.mockReset();
    setActivePinia(createPinia());
  });

  it('sends text to an unknown but valid active channel with a client message number', () => {
    runtimeConfig.mode = 'mock';
    const chat = useChatStore();

    chat.openChannel(1, 'u-unknown');
    const previousLength = chat.activeMessages.length;
    chat.sendText('  你好  ');

    expect(chat.activeMessages).toHaveLength(previousLength + 1);
    expect(chat.activeMessages.at(-1)).toMatchObject({
      channelId: 'u-unknown',
      channelType: 1,
      direction: 'outgoing',
      kind: 'text',
      content: '你好',
      status: 'sent',
    });
    expect(chat.activeMessages.at(-1)).toHaveProperty('clientMsgNo');
    expect(chat.activeMessages.at(-1)?.id).toBe(chat.activeMessages.at(-1)?.clientMsgNo);
  });

  it('does not populate fake messages when opening a live channel', () => {
    const chat = useChatStore();

    chat.openChannel(1, 'u-live');

    expect(chat.activeChannelKey).toBe('1_u-live');
    expect(chat.activeMessages).toEqual([]);
  });

  it('does not append local messages in live read-only mode', () => {
    const chat = useChatStore();

    chat.openChannel(1, 'u-live');
    chat.sendText('should not be sent');

    expect(chat.activeMessages).toEqual([]);
  });

  it('does not synthesize older local history in live read-only mode', () => {
    const chat = useChatStore();

    chat.openChannel(1, 'u-live');

    expect(chat.prependOlderMessages()).toBe(0);
    expect(chat.activeMessages).toEqual([]);
  });

  it('populates fake messages when opening an unknown mock channel', () => {
    runtimeConfig.mode = 'mock';
    const chat = useChatStore();

    chat.openChannel(1, 'u-mock');

    expect(chat.activeChannelKey).toBe('1_u-mock');
    expect(chat.activeMessages.length).toBeGreaterThan(0);
  });

  it('prepends older messages to an unknown but valid active channel', () => {
    runtimeConfig.mode = 'mock';
    const chat = useChatStore();

    chat.openChannel(2, 'g-unknown');
    const previousLength = chat.activeMessages.length;
    const insertedCount = chat.prependOlderMessages();

    expect(insertedCount).toBe(20);
    expect(chat.activeMessages).toHaveLength(previousLength + 20);
    expect(chat.activeMessages[0]).toMatchObject({
      channelId: 'g-unknown',
      channelType: 2,
      kind: 'text',
      status: 'sent',
    });
  });

  it('loads live conversations from sync API and clears loading state', async () => {
    const chat = useChatStore();
    const syncedConversations = [
      {
        id: '1:u2',
        channelId: 'u2',
        channelType: 1 as const,
        title: 'u2',
        avatarText: 'U',
        lastMessage: 'hello',
        lastMessageAt: '2026-05-29T00:00:00.000Z',
        unreadCount: 2,
        muted: false,
      },
    ];

    chat.conversationError = 'previous error';
    loadConversationSyncMock.mockResolvedValue(syncedConversations);
    hydrateConversationTitlesMock.mockResolvedValue(syncedConversations);

    await chat.loadConversations({
      uid: 'u1',
      token: 'token',
      deviceUuid: 'device',
    });

    expect(loadConversationSyncMock).toHaveBeenCalledWith({
      uid: 'u1',
      token: 'token',
      deviceUuid: 'device',
      config: runtimeConfig,
    });
    expect(hydrateConversationTitlesMock).toHaveBeenCalledWith(syncedConversations, {
      token: 'token',
      cacheScope: 'u1',
      config: runtimeConfig,
    });
    expect(chat.conversations).toEqual(syncedConversations);
    expect(chat.conversationError).toBe('');
    expect(chat.isLoadingConversations).toBe(false);
  });

  it('hydrates fallback live conversation titles without changing channel identity', async () => {
    const chat = useChatStore();
    const syncedConversations = [
      {
        id: '1:120e9a7649e248428c9897a2464a2d6c',
        channelId: '120e9a7649e248428c9897a2464a2d6c',
        channelType: 1 as const,
        title: '用户 2d6c',
        avatarText: '用',
        lastMessage: '[图片]',
        lastMessageAt: '昨天',
        unreadCount: 39,
        muted: false,
        titleSource: 'fallback' as const,
      },
      {
        id: '2:group-8487',
        channelId: 'group-8487',
        channelType: 2 as const,
        title: '群聊 8487',
        avatarText: '群',
        lastMessage: '我也有白屏',
        lastMessageAt: '昨天',
        unreadCount: 1,
        muted: false,
        titleSource: 'fallback' as const,
      },
    ];
    const hydratedConversations = [
      { ...syncedConversations[0], title: '李欣放', avatarText: '李', titleSource: 'hydrated' as const },
      { ...syncedConversations[1], title: '项目交付群', avatarText: '项', titleSource: 'hydrated' as const },
    ];
    loadConversationSyncMock.mockResolvedValue(syncedConversations);
    hydrateConversationTitlesMock.mockResolvedValue(hydratedConversations);

    await chat.loadConversations({
      uid: 'u1',
      token: 'token',
      deviceUuid: 'device',
    });

    expect(chat.conversations).toEqual(hydratedConversations);
    expect(chat.conversations[0]).toMatchObject({
      channelId: '120e9a7649e248428c9897a2464a2d6c',
      channelType: 1,
      title: '李欣放',
      avatarText: '李',
    });
    expect(chat.conversations[1]).toMatchObject({
      channelId: 'group-8487',
      channelType: 2,
      title: '项目交付群',
      avatarText: '项',
    });
  });

  it('keeps synced fallback titles when title hydration fails', async () => {
    const chat = useChatStore();
    const syncedConversations = [
      {
        id: '1:120e9a7649e248428c9897a2464a2d6c',
        channelId: '120e9a7649e248428c9897a2464a2d6c',
        channelType: 1 as const,
        title: '用户 2d6c',
        avatarText: '用',
        lastMessage: '[图片]',
        lastMessageAt: '昨天',
        unreadCount: 39,
        muted: false,
        titleSource: 'fallback' as const,
      },
    ];
    loadConversationSyncMock.mockResolvedValue(syncedConversations);
    hydrateConversationTitlesMock.mockRejectedValue(new Error('profile unavailable'));

    await chat.loadConversations({
      uid: 'u1',
      token: 'token',
      deviceUuid: 'device',
    });

    expect(chat.conversations).toEqual(syncedConversations);
    expect(chat.conversationError).toBe('');
    expect(chat.isLoadingConversations).toBe(false);
  });

  it('exposes whether conversation data is using live mode', () => {
    const chat = useChatStore();

    expect(chat.isLiveConversationMode).toBe(true);

    runtimeConfig.mode = 'mock';
    setActivePinia(createPinia());

    expect(useChatStore().isLiveConversationMode).toBe(false);
  });

  it('records live conversation sync failures without throwing', async () => {
    const chat = useChatStore();

    loadConversationSyncMock.mockRejectedValue(new Error('sync unavailable'));

    await expect(
      chat.loadConversations({
        uid: 'u1',
        token: 'token',
        deviceUuid: 'device',
      }),
    ).resolves.toBeUndefined();

    expect(chat.conversationError).toBe('sync unavailable');
    expect(hydrateConversationTitlesMock).not.toHaveBeenCalled();
    expect(chat.isLoadingConversations).toBe(false);
  });

  it('clears conversations and records an error when live auth is missing', async () => {
    const chat = useChatStore();

    await chat.loadConversations(null);

    expect(loadConversationSyncMock).not.toHaveBeenCalled();
    expect(chat.conversations).toEqual([]);
    expect(chat.conversationError).toBe('Conversation sync requires an active session.');
    expect(chat.isLoadingConversations).toBe(false);
  });

  it('resets fake conversations and clears state in mock mode', async () => {
    runtimeConfig.mode = 'mock';
    const chat = useChatStore();

    chat.conversations = [];
    chat.conversationError = 'previous error';
    chat.isLoadingConversations = true;

    await chat.loadConversations(null);

    expect(loadConversationSyncMock).not.toHaveBeenCalled();
    expect(chat.conversations).toEqual(fakeConversations);
    expect(chat.conversationError).toBe('');
    expect(chat.isLoadingConversations).toBe(false);
  });

  it('does not expose a test-only live conversation mutator', () => {
    const chat = useChatStore();

    expect(chat).not.toHaveProperty('loadLiveConversationsForTest');
  });
});
