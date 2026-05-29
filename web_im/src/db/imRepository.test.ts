import { describe, expect, it } from 'vitest';
import 'fake-indexeddb/auto';

import { createImRepository } from './imRepository';

describe('imRepository', () => {
  it('stores and reads conversations by uid', async () => {
    const repo = createImRepository('wk-web-im-test-conversations');
    await repo.clearAll();
    await repo.putConversations('u1', [
      {
        id: '2_group-product',
        channelId: 'group-product',
        channelType: 2,
        title: '产品交付群',
        avatarText: '产',
        lastMessage: 'hello',
        lastMessageAt: 1,
        unread: 2,
        pinned: true,
        muted: false,
      },
    ]);

    const rows = await repo.getConversations('u1');
    expect(rows).toHaveLength(1);
    expect(rows[0].title).toBe('产品交付群');
  });

  it('stores messages by channel key', async () => {
    const repo = createImRepository('wk-web-im-test-messages');
    await repo.clearAll();
    await repo.putMessages('u1', '2_group-product', [
      {
        id: 'm1',
        clientMsgNo: 'c1',
        channelId: 'group-product',
        channelType: 2,
        fromUid: 'u2',
        fromName: '对方',
        direction: 'incoming',
        kind: 'text',
        text: 'hello',
        timestamp: 1,
        status: 'sent',
      },
    ]);

    const rows = await repo.getMessages('u1', '2_group-product', { limit: 20 });
    expect(rows.map((item) => item.id)).toEqual(['m1']);
  });
});
