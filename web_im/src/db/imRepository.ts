import { runStore } from './indexedDb';
import { STORE_CONVERSATIONS, STORE_DRAFTS, STORE_MESSAGES } from './schema';

type ChannelType = 1 | 2;
type MessageDirection = 'incoming' | 'outgoing';
type MessageKind = 'text' | 'image' | 'file' | 'voice';
type MessageStatus = 'sent' | 'sending' | 'failed';

export interface ImConversation {
  id: string;
  channelId: string;
  channelType: ChannelType;
  title: string;
  avatarText: string;
  lastMessage: string;
  lastMessageAt: number;
  unread: number;
  pinned: boolean;
  muted: boolean;
}

export interface ImMessage {
  id: string;
  clientMsgNo?: string;
  channelId: string;
  channelType: ChannelType;
  fromUid: string;
  fromName: string;
  direction: MessageDirection;
  kind: MessageKind;
  text: string;
  timestamp: number;
  status: MessageStatus;
}

interface ConversationRow extends ImConversation {
  key: string;
  uid: string;
}

interface MessageRow extends ImMessage {
  key: string;
  uid: string;
  channelKey: string;
}

interface DraftRow {
  key: string;
  uid: string;
  channelKey: string;
  text: string;
}

const withoutKey = <T extends { key: string }>(row: T): Omit<T, 'key'> => {
  const { key: _key, ...domain } = row;
  return domain;
};

const conversationKey = (uid: string, conversationId: string): string => `${uid}:${conversationId}`;
const messageKey = (uid: string, channelKey: string, message: ImMessage): string =>
  `${uid}:${channelKey}:${message.timestamp}:${message.id}`;
const draftKey = (uid: string, channelKey: string): string => `${uid}:${channelKey}`;

function readAll<T>(store: IDBObjectStore): Promise<T[]> {
  return new Promise((resolve, reject) => {
    const request = store.getAll() as IDBRequest<T[]>;

    request.onsuccess = () => {
      resolve(request.result);
    };

    request.onerror = () => {
      reject(request.error ?? new Error('Failed to read IndexedDB rows'));
    };
  });
}

function writeRows<T extends { key: string }>(store: IDBObjectStore, rows: T[]): Promise<void> {
  return new Promise((resolve, reject) => {
    if (rows.length === 0) {
      resolve();
      return;
    }

    let remaining = rows.length;

    for (const row of rows) {
      const request = store.put(row);

      request.onsuccess = () => {
        remaining -= 1;
        if (remaining === 0) {
          resolve();
        }
      };

      request.onerror = () => {
        reject(request.error ?? new Error('Failed to write IndexedDB row'));
      };
    }
  });
}

export function createImRepository(dbName = 'wk-web-im') {
  return {
    putConversations(uid: string, conversations: ImConversation[]): Promise<void> {
      const rows: ConversationRow[] = conversations.map((conversation) => ({
        ...conversation,
        key: conversationKey(uid, conversation.id),
        uid,
      }));

      return runStore(dbName, STORE_CONVERSATIONS, 'readwrite', (store) => writeRows(store, rows));
    },

    async getConversations(uid: string): Promise<ImConversation[]> {
      const rows = await runStore(dbName, STORE_CONVERSATIONS, 'readonly', (store) => readAll<ConversationRow>(store));

      return rows
        .filter((row) => row.uid === uid)
        .sort((left, right) => left.key.localeCompare(right.key))
        .map((row) => {
          const { uid: _uid, ...domain } = withoutKey(row);
          return domain;
        });
    },

    putMessages(uid: string, channelKey: string, messages: ImMessage[]): Promise<void> {
      const rows: MessageRow[] = messages.map((message) => ({
        ...message,
        key: messageKey(uid, channelKey, message),
        uid,
        channelKey,
      }));

      return runStore(dbName, STORE_MESSAGES, 'readwrite', (store) => writeRows(store, rows));
    },

    async getMessages(uid: string, channelKey: string, options: { limit: number }): Promise<ImMessage[]> {
      const rows = await runStore(dbName, STORE_MESSAGES, 'readonly', (store) => readAll<MessageRow>(store));

      return rows
        .filter((row) => row.uid === uid && row.channelKey === channelKey)
        .sort((left, right) => left.timestamp - right.timestamp || left.key.localeCompare(right.key))
        .slice(0, options.limit)
        .map((row) => {
          const { uid: _uid, channelKey: _channelKey, ...domain } = withoutKey(row);
          return domain;
        });
    },

    putDraft(uid: string, channelKey: string, text: string): Promise<void> {
      const row: DraftRow = {
        key: draftKey(uid, channelKey),
        uid,
        channelKey,
        text,
      };

      return runStore(dbName, STORE_DRAFTS, 'readwrite', (store) =>
        new Promise<void>((resolve, reject) => {
          const request = store.put(row);

          request.onsuccess = () => {
            resolve();
          };

          request.onerror = () => {
            reject(request.error ?? new Error('Failed to write IndexedDB draft'));
          };
        }),
      );
    },

    async getDraft(uid: string, channelKey: string): Promise<string> {
      const key = draftKey(uid, channelKey);
      const row = await runStore(dbName, STORE_DRAFTS, 'readonly', (store) => store.get(key) as IDBRequest<DraftRow | undefined>);
      return row?.text ?? '';
    },

    async clearAll(): Promise<void> {
      await runStore(dbName, STORE_CONVERSATIONS, 'readwrite', (store) => store.clear());
      await runStore(dbName, STORE_MESSAGES, 'readwrite', (store) => store.clear());
      await runStore(dbName, STORE_DRAFTS, 'readwrite', (store) => store.clear());
    },
  };
}
