import { runStore } from './indexedDb';
import { STORE_DRAFTS } from './schema';

void runStore('wk-web-im-type-contract', STORE_DRAFTS, 'readonly', (store) => store.get('draft-key'));
void runStore('wk-web-im-type-contract', STORE_DRAFTS, 'readonly', () => 'draft text');

// @ts-expect-error runStore callbacks must synchronously enqueue IDB work before the transaction auto-closes.
void runStore('wk-web-im-type-contract', STORE_DRAFTS, 'readonly', async () => 'draft text');
