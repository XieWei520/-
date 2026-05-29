import { beforeEach, describe, expect, it } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useChatStore } from './chatStore';

describe('chat store unknown active channels', () => {
  beforeEach(() => {
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
});
