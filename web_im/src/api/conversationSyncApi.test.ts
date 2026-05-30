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

  it('formats live conversation titles and times for narrow mobile cards', () => {
    vi.useFakeTimers();
    try {
      vi.setSystemTime(new Date(2026, 4, 30, 14, 0, 0));
      const yesterday = Math.floor(new Date(2026, 4, 29, 15, 24, 26).getTime() / 1000);
      const older = Math.floor(new Date(2026, 4, 28, 6, 42, 21).getTime() / 1000);

      const conversations = mapConversationSyncRows([
        {
          channel_id: '120e9a7649e248428c9897a2464a2d6c',
          channel_type: 1,
          unread: 39,
          timestamp: yesterday,
          recents: [{ message_seq: 8, timestamp: yesterday, payload: { type: 2 } }],
        },
        {
          channel_id: 'a4056433146e479fb000000000000001',
          channel_type: 2,
          extra: JSON.stringify({ displayName: '项目交付群' }),
          timestamp: older,
          recents: [{ message_seq: 7, timestamp: older, payload: { type: 1, content: '新消息 **李欣放** 说...' } }],
        },
      ]);

      expect(conversations[0]).toMatchObject({
        title: '用户 2d6c',
        avatarText: '用',
        lastMessage: '[图片]',
        lastMessageAt: '昨天',
      });
      expect(conversations[0].title).not.toContain('120e9a7649e248428c9897a2464a2d6c');
      expect(conversations[0].lastMessageAt).not.toContain('T');

      expect(conversations[1]).toMatchObject({
        title: '项目交付群',
        avatarText: '项',
        lastMessageAt: '05-28',
      });
    } finally {
      vi.useRealTimers();
    }
  });

  it('preserves row-level last message markers when recents are empty or absent', () => {
    const conversations = mapConversationSyncRows([
      {
        channel_id: 'u-empty',
        channel_type: 1,
        last_msg_seq: 42,
        last_client_msg_no: 'client-empty',
        recents: [],
      },
      {
        channelId: 'g-absent',
        channelType: 2,
        lastMsgSeq: '84',
        lastClientMsgNo: 'client-absent',
      },
    ]);

    expect(conversations).toEqual([
      expect.objectContaining({
        channelId: 'u-empty',
        lastMsgSeq: 42,
        lastClientMsgNo: 'client-empty',
      }),
      expect.objectContaining({
        channelId: 'g-absent',
        lastMsgSeq: 84,
        lastClientMsgNo: 'client-absent',
      }),
    ]);
  });

  it('summarizes malformed and media payloads safely', () => {
    expect(summarizeRecentMessage({ payload: '{"type":2}' })).toBe('[图片]');
    expect(summarizeRecentMessage({ payload: { type: 4 } })).toBe('[语音]');
    expect(summarizeRecentMessage({ payload: '{bad json' })).toBe('[不支持的消息]');
    expect(summarizeRecentMessage({})).toBe('[暂无消息]');
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
