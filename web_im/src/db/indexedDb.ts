import { IM_DB_VERSION, INDEX_MESSAGES_CHANNEL_SORT, STORE_CONVERSATIONS, STORE_DRAFTS, STORE_MESSAGES } from './schema';

type StoreName = typeof STORE_CONVERSATIONS | typeof STORE_MESSAGES | typeof STORE_DRAFTS;
type NonThenable<T> = T extends PromiseLike<unknown> ? never : T;
export interface IndexedDbOperation<T> {
  result: Promise<T>;
}

const stores: StoreName[] = [STORE_CONVERSATIONS, STORE_MESSAGES, STORE_DRAFTS];

function ensureMessageIndexes(store: IDBObjectStore): void {
  if (!store.indexNames.contains(INDEX_MESSAGES_CHANNEL_SORT)) {
    store.createIndex(INDEX_MESSAGES_CHANNEL_SORT, 'channelSortKey', { unique: false });
  }
}

function ensureExistingMessageSortKeys(store: IDBObjectStore): void {
  const request = store.openCursor();

  request.onsuccess = () => {
    const cursor = request.result;
    if (!cursor) {
      return;
    }

    const row = cursor.value as {
      uid?: string;
      channelKey?: string;
      timestamp?: number;
      id?: string;
      channelSortKey?: unknown;
    };

    if (!row.channelSortKey && row.uid && row.channelKey && typeof row.timestamp === 'number' && row.id) {
      cursor.update({
        ...row,
        channelSortKey: [row.uid, row.channelKey, row.timestamp, row.id],
      });
    }

    cursor.continue();
  };
}

function isIndexedDbOperation<T>(result: unknown): result is IndexedDbOperation<T> {
  return typeof result === 'object' && result !== null && 'result' in result && result.result instanceof Promise;
}

function getIndexedDb(): IDBFactory {
  if (!globalThis.indexedDB) {
    throw new Error('IndexedDB is not available in this environment');
  }

  return globalThis.indexedDB;
}

export function openDatabase(name: string): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    let request: IDBOpenDBRequest;

    try {
      request = getIndexedDb().open(name, IM_DB_VERSION);
    } catch (error) {
      reject(error);
      return;
    }

    request.onupgradeneeded = () => {
      const db = request.result;

      for (const store of stores) {
        if (!db.objectStoreNames.contains(store)) {
          const objectStore = db.createObjectStore(store, { keyPath: 'key' });
          if (store === STORE_MESSAGES) {
            ensureMessageIndexes(objectStore);
          }
        } else if (store === STORE_MESSAGES) {
          const objectStore = request.transaction!.objectStore(STORE_MESSAGES);
          ensureMessageIndexes(objectStore);
          ensureExistingMessageSortKeys(objectStore);
        }
      }
    };

    request.onsuccess = () => {
      resolve(request.result);
    };

    request.onerror = () => {
      reject(request.error ?? new Error(`Failed to open IndexedDB database ${name}`));
    };

    request.onblocked = () => {
      reject(new Error(`Opening IndexedDB database ${name} was blocked`));
    };
  });
}

export async function runStore<T>(
  dbName: string,
  storeName: StoreName,
  mode: IDBTransactionMode,
  operation: (store: IDBObjectStore) => IDBRequest<T> | IndexedDbOperation<T> | NonThenable<T>,
): Promise<T> {
  const db = await openDatabase(dbName);

  try {
    const transaction = db.transaction(storeName, mode);
    const store = transaction.objectStore(storeName);
    const transactionDone = new Promise<void>((resolve, reject) => {
      transaction.oncomplete = () => {
        resolve();
      };

      transaction.onerror = () => {
        reject(transaction.error ?? new Error(`IndexedDB transaction failed for ${storeName}`));
      };

      transaction.onabort = () => {
        reject(transaction.error ?? new Error(`IndexedDB transaction aborted for ${storeName}`));
      };
    });
    let transactionError: unknown;
    const observedTransactionDone = transactionDone.catch((error: unknown) => {
      transactionError = error;
    });

    let result: IDBRequest<T> | IndexedDbOperation<T> | NonThenable<T>;

    try {
      // IndexedDB transactions auto-close once the current task finishes.
      // Callers must enqueue all IDB requests synchronously in this callback.
      result = operation(store);
    } catch (error) {
      try {
        transaction.abort();
      } catch {
        // The transaction may already be inactive; transactionDone is still observed below.
      }

      await observedTransactionDone;
      throw error;
    }

    let value: T;

    try {
      if (result instanceof IDBRequest) {
        value = await new Promise<T>((resolve, reject) => {
          result.onsuccess = () => {
            resolve(result.result);
          };

          result.onerror = () => {
            reject(result.error ?? new Error(`IndexedDB request failed for ${storeName}`));
          };
        });
      } else if (isIndexedDbOperation<T>(result)) {
        value = await result.result;
      } else {
        value = result;
      }
    } catch (error) {
      await observedTransactionDone;
      throw error;
    }

    await observedTransactionDone;
    if (transactionError) {
      throw transactionError;
    }

    return value;
  } finally {
    db.close();
  }
}
