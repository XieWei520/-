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
assert.equal(
  existsSync(join(dist, 'icons', 'wukong-im-icon.svg')),
  true,
  'dist/icons/wukong-im-icon.svg must exist',
);
const index = readFileSync(join(dist, 'index.html'), 'utf8');
const manifest = readFileSync(join(dist, 'manifest.webmanifest'), 'utf8');
assert.match(index, /<div id="app"><\/div>/, 'index must keep Vue mount node');
assert.match(index, /manifest\.webmanifest/, 'index must reference PWA manifest');
assert.match(index, /apple-touch-icon/, 'index must reference iOS home screen icon');
assert.match(manifest, /wukong-im-icon\.svg/, 'manifest must reference PWA icon');
assert.match(manifest, /"purpose":\s*"any maskable"/, 'manifest icon must support maskable purpose');
