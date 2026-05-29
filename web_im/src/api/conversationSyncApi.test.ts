import { describe, expect, it, vi } from 'vitest';
import { loadConversationSync, mapConversationSyncRows, summarizeRecentMessage } from './conversationSyncApi';

describe('conversation sync api', () => {
  it('maps valid rows and skips invalid rows', () => {
    const conversations = mapConversationSyncRows([
      {
        channel_id: 'u2',
        channel_type: 1,
        unread: 3,
        timestamp: 1717000000,
        recents: [{ message_seq: 8, timestamp: 1717000001, payload: { type: 1, content: 'hello' } }],
      },
      { channel_id: '', channel_type: 1 },
      { channel_id: 'bad', channel_type: 99 },
    ]);

    expect(conversations).toEqual([
      expect.objectContaining({
        id: '1:u2',
        channelId: 'u2',
        channelType: 1,
        unreadCount: 3,
        lastMessage: 'hello',
      }),
    ]);
  });

  it('summarizes malformed and media payloads safely', () => {
    expect(summarizeRecentMessage({ payload: '{"type":2}' })).toBe('[鍥剧墖]');
    expect(summarizeRecentMessage({ payload: { type: 4 } })).toBe('[璇煶]');
    expect(summarizeRecentMessage({ payload: '{bad json' })).toBe('[涓嶆敮鎸佺殑娑堟伅]');
    expect(summarizeRecentMessage({})).toBe('[鏆傛棤娑堟伅]');
  });

  it('posts Flutter-compatible conversation sync body', async () => {
    const request = vi.fn().mockResolvedValue({ conversations: [] });

    await loadConversationSync({
      uid: 'u1',
      token: 't1',
      deviceUuid: 'device',
      config: {
        mode: 'live',
        apiBaseUrl: 'https://infoequity.cn',
        appId: 'wukongchat',
        appKey: 'key',
        deviceFlag: 5,
      },
      request,
    });

    expect(request).toHaveBeenCalledWith(
      expect.objectContaining({
        path: '/v1/conversation/sync',
        method: 'POST',
        token: 't1',
        body: {
          version: 0,
          last_msg_seqs: '',
          msg_count: 200,
          device_uuid: 'device',
        },
      }),
    );
  });
});
