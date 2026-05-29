import { afterEach, describe, expect, it } from 'vitest';
import 'fake-indexeddb/auto';

import { createImRepository, type ImConversation, type ImMessage } from './imRepository';

let dbSeq = 0;
const dbNames: string[] = [];

function createTestRepository(label: string) {
  const dbName = `wk-web-im-test-${label}-${dbSeq}`;
  dbSeq += 1;
  dbNames.push(dbName);
  return createImRepository(dbName);
}

function deleteDatabase(dbName: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.deleteDatabase(dbName);

    request.onsuccess = () => {
      resolve();
    };

    request.onerror = () => {
      reject(request.error ?? new Error(`Failed to delete test database ${dbName}`));
    };

    request.onblocked = () => {
      reject(new Error(`Deleting test database ${dbName} was blocked`));
    };
  });
}

function conversation(overrides: Partial<ImConversation> = {}): ImConversation {
  return {
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
    ...overrides,
  };
}

function message(overrides: Partial<ImMessage> = {}): ImMessage {
  return {
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
    ...overrides,
  };
}

afterEach(async () => {
  const names = dbNames.splice(0);
  await Promise.all(names.map((dbName) => deleteDatabase(dbName)));
});

describe('imRepository', () => {
  it('stores and reads conversations by uid', async () => {
    const repo = createTestRepository('conversations');
    await repo.putConversations('u1', [conversation()]);

    const rows = await repo.getConversations('u1');
    expect(rows).toHaveLength(1);
    expect(rows[0].title).toBe('产品交付群');
  });

  it('stores messages by channel key', async () => {
    const repo = createTestRepository('messages');
    await repo.putMessages('u1', '2_group-product', [message()]);

    const rows = await repo.getMessages('u1', '2_group-product', { limit: 20 });
    expect(rows.map((item) => item.id)).toEqual(['m1']);
  });

  it('isolates conversations for similar uid prefixes', async () => {
    const repo = createTestRepository('uid-isolation');
    await repo.putConversations('u1', [conversation({ id: '2_group-product', title: '产品交付群' })]);
    await repo.putConversations('u10', [conversation({ id: '2_group-product', title: '十号用户群' })]);

    const rows = await repo.getConversations('u1');
    expect(rows.map((item) => item.title)).toEqual(['产品交付群']);
  });

  it('isolates messages for similar channel key prefixes', async () => {
    const repo = createTestRepository('channel-isolation');
    await repo.putMessages('u1', '2_group', [message({ id: 'm-short', channelId: 'group', text: '短群消息' })]);
    await repo.putMessages('u1', '2_group-product', [message({ id: 'm-long', text: '产品群消息' })]);

    const rows = await repo.getMessages('u1', '2_group', { limit: 20 });
    expect(rows.map((item) => item.id)).toEqual(['m-short']);
  });

  it('stores, reads, and overwrites drafts', async () => {
    const repo = createTestRepository('drafts');
    await repo.putDraft('u1', '2_group-product', '第一版草稿');
    await repo.putDraft('u1', '2_group-product', '第二版草稿');

    await expect(repo.getDraft('u1', '2_group-product')).resolves.toBe('第二版草稿');
    await expect(repo.getDraft('u10', '2_group-product')).resolves.toBe('');
  });

  it('orders messages by timestamp then key and applies limit after sorting', async () => {
    const repo = createTestRepository('message-ordering');
    await repo.putMessages('u1', '2_group-product', [
      message({ id: 'm3', timestamp: 3 }),
      message({ id: 'm2', timestamp: 1 }),
      message({ id: 'm1', timestamp: 1 }),
      message({ id: 'm4', timestamp: 2 }),
    ]);

    const rows = await repo.getMessages('u1', '2_group-product', { limit: 3 });
    expect(rows.map((item) => item.id)).toEqual(['m1', 'm2', 'm4']);
  });

  it('returns domain objects without internal persistence fields', async () => {
    const repo = createTestRepository('domain-objects');
    await repo.putConversations('u1', [conversation()]);
    await repo.putMessages('u1', '2_group-product', [message()]);

    const [storedConversation] = await repo.getConversations('u1');
    const [storedMessage] = await repo.getMessages('u1', '2_group-product', { limit: 20 });

    expect(storedConversation).not.toHaveProperty('key');
    expect(storedConversation).not.toHaveProperty('uid');
    expect(storedMessage).not.toHaveProperty('key');
    expect(storedMessage).not.toHaveProperty('uid');
    expect(storedMessage).not.toHaveProperty('channelKey');
  });
});
