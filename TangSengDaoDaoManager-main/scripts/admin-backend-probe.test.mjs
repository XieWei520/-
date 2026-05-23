import test from 'node:test';
import assert from 'node:assert/strict';

import {
  buildUrl,
  classifyReadPresence,
  extractJsonBody,
  validateResponseContract
} from './admin-backend-probe.mjs';

test('buildUrl keeps the /v1 base prefix and appends query params', () => {
  const url = buildUrl('https://example.test/v1', '/manager/audit/logs', {
    page_index: '1',
    empty: ''
  });

  assert.equal(url.toString(), 'https://example.test/v1/manager/audit/logs?page_index=1');
});

test('extractJsonBody returns null for invalid JSON', () => {
  assert.equal(extractJsonBody('not json'), null);
});

test('validateResponseContract accepts paged list contracts', () => {
  const result = validateResponseContract(
    { list: [{ id: 1 }], count: 1 },
    { contract: 'paged-list' }
  );

  assert.deepEqual(result, { ok: true, message: 'response contract ok' });
});

test('validateResponseContract rejects a wrapped paged list that the admin UI cannot consume', () => {
  const result = validateResponseContract(
    { data: { list: [], count: 0 } },
    { contract: 'paged-list' }
  );

  assert.equal(result.ok, false);
  assert.match(result.message, /top-level list/);
});

test('validateResponseContract accepts user purge preview contracts', () => {
  const result = validateResponseContract(
    {
      uid: 'u1',
      can_purge: true,
      counts: {},
      verification: {}
    },
    { contract: 'purge-preview' }
  );

  assert.deepEqual(result, { ok: true, message: 'response contract ok' });
});

test('validateResponseContract accepts user purge job contracts', () => {
  const result = validateResponseContract(
    {
      job_id: 'job1',
      uid: 'u1',
      status: 'succeeded'
    },
    { contract: 'purge-job' }
  );

  assert.deepEqual(result, { ok: true, message: 'response contract ok' });
});

test('classifyReadPresence fails 2xx responses with the wrong contract shape', () => {
  const result = classifyReadPresence(200, JSON.stringify({ data: { list: [], count: 0 } }), {
    contract: 'paged-list'
  });

  assert.equal(result.level, 'fail');
  assert.match(result.message, /top-level list/);
});

test('classifyReadPresence accepts long successful JSON responses', () => {
  const result = classifyReadPresence(
    200,
    JSON.stringify({
      list: [{ id: 'x'.repeat(1000) }],
      count: 1
    }),
    { contract: 'paged-list' }
  );

  assert.equal(result.level, 'pass');
});
