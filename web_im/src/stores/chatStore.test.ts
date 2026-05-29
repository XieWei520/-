import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useChatStore } from './chatStore';
import { loadConversationSync } from '../api/conversationSyncApi';
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
  isMockMode: vi.fn((config: { mode: string }) => config.mode === 'mock'),
}));

vi.mock('../api/conversationSyncApi', () => ({
  loadConversationSync: vi.fn(),
}));

const loadConversationSyncMock = vi.mocked(loadConversationSync);

describe('chat store unknown active channels', () => {
  beforeEach(() => {
    runtimeConfig.mode = 'live';
    loadConversationSyncMock.mockReset();
    setActivePinia(createPinia());
  });

  it('sends text to an unknown but valid active channel with a client message number', () => {
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

  it('prepends older messages to an unknown but valid active channel', () => {
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
    expect(chat.conversations).toEqual(syncedConversations);
    expect(chat.conversationError).toBe('');
    expect(chat.isLoadingConversations).toBe(false);
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
