import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const root = fileURLToPath(new URL('..', import.meta.url));
const dist = join(root, 'dist');

assert.equal(existsSync(join(dist, 'index.html')), true, 'dist/index.html must exist');
assert.equal(
  existsSync(join(dist, 'manifest.webmanifest')),
  true,
  'dist/manifest.webmanifest must exist',
);
assert.equal(existsSync(join(dist, 'sw.js')), true, 'dist/sw.js must exist');
assert.equal(existsSync(join(dist, 'offline.html')), true, 'dist/offline.html must exist');
const index = readFileSync(join(dist, 'index.html'), 'utf8');
assert.match(index, /<div id="app"><\/div>/, 'index must keep Vue mount node');
assert.match(index, /manifest\.webmanifest/, 'index must reference PWA manifest');
