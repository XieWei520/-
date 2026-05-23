#!/usr/bin/env node

import { pathToFileURL } from 'node:url';

const UNWIRED_LABEL = '接口未接入';
const SENTINEL_UID = '__admin_probe_never_real_uid__';
const SENTINEL_MESSAGE_ID = '__admin_probe_never_real_message_id__';
const SENTINEL_JOB_ID = '__admin_probe_never_real_job_id__';
const DEFAULT_TIMEOUT_MS = 10000;

const readProbes = [
  {
    id: 'audit-log-presence',
    group: 'audit endpoint presence',
    method: 'GET',
    path: '/manager/audit/logs',
    query: { page_index: '1', page_size: '1' },
    contract: 'paged-list'
  },
  {
    id: 'forbidden-word-policy-presence',
    group: 'forbidden word policy endpoint presence',
    method: 'GET',
    path: '/manager/message/prohibit_word_policies',
    query: { page_index: '1', page_size: '1' },
    contract: 'paged-list'
  },
  {
    id: 'forbidden-word-hit-log-presence',
    group: 'forbidden word hit-log endpoint presence',
    method: 'GET',
    path: '/manager/message/prohibit_word_hit_logs',
    query: { page_index: '1', page_size: '1' },
    contract: 'paged-list'
  },
  {
    id: 'group-message-audit-presence',
    group: 'message audit endpoint presence',
    method: 'GET',
    path: '/manager/message/record',
    query: { page_index: '1', page_size: '1' },
    contract: 'paged-list'
  },
  {
    id: 'personal-message-audit-presence',
    group: 'message audit endpoint presence',
    method: 'GET',
    path: '/manager/message/recordpersonal',
    query: { page_index: '1', page_size: '1' },
    contract: 'paged-list'
  },
  {
    id: 'user-purge-preview-presence',
    group: 'user purge endpoint presence',
    method: 'GET',
    path: `/manager/users/${SENTINEL_UID}/purge-preview`,
    resourceNotFoundIsAmbiguous: true,
    contract: 'purge-preview'
  },
  {
    id: 'user-purge-job-presence',
    group: 'user purge endpoint presence',
    method: 'GET',
    path: `/manager/users/purge-jobs/${SENTINEL_JOB_ID}`,
    resourceNotFoundIsAmbiguous: true,
    contract: 'purge-job'
  }
];

const authRequiredProbes = readProbes.map(probe => ({
  ...probe,
  id: `${probe.id}-auth-required`,
  group: 'auth-required'
}));

const optionsProbes = [
  {
    id: 'report-handle-presence',
    group: 'report moderation endpoint presence',
    method: 'OPTIONS',
    path: '/manager/report/handle'
  },
  {
    id: 'message-delete-presence',
    group: 'high-risk endpoint presence',
    method: 'OPTIONS',
    path: '/manager/message'
  },
  {
    id: 'vip-set-presence',
    group: 'high-risk endpoint presence',
    method: 'OPTIONS',
    path: '/manager/user/set_vip'
  },
  {
    id: 'customer-service-set-presence',
    group: 'high-risk endpoint presence',
    method: 'OPTIONS',
    path: '/manager/user/set_customer_service'
  },
  {
    id: 'user-purge-execute-presence',
    group: 'user purge endpoint presence',
    method: 'OPTIONS',
    path: `/manager/users/${SENTINEL_UID}/purge`
  }
];

const reasonRequiredProbes = [
  {
    id: 'message-delete-reason-required',
    group: 'reason-required',
    method: 'DELETE',
    path: '/manager/message',
    body: {
      channel_id: SENTINEL_UID,
      channel_type: 1,
      from_uid: SENTINEL_UID,
      list: [{ message_id: SENTINEL_MESSAGE_ID }]
    }
  },
  {
    id: 'vip-set-reason-required',
    group: 'reason-required',
    method: 'POST',
    path: '/manager/user/set_vip',
    body: {
      uid: SENTINEL_UID,
      vip_level: 0
    }
  },
  {
    id: 'customer-service-set-reason-required',
    group: 'reason-required',
    method: 'POST',
    path: '/manager/user/set_customer_service',
    body: {
      uid: SENTINEL_UID,
      enabled: false,
      is_default: false
    }
  },
  {
    id: 'user-purge-reason-required',
    group: 'reason-required',
    method: 'DELETE',
    path: `/manager/users/${SENTINEL_UID}/purge`,
    body: {
      confirm_uid: SENTINEL_UID
    }
  }
];

const help = `
Admin backend contract probe

Required:
  ADMIN_API_BASE_URL     Backend API base URL, including version prefix.
                         Example: https://example.com/v1

Optional:
  ADMIN_TOKEN            Admin token. Sent using ADMIN_TOKEN_HEADER.
  ADMIN_TOKEN_HEADER     Token header name. Defaults to "token".
  ADMIN_PROBE_MUTATIONS  Defaults to false. When true, sends high-risk
                         POST/DELETE probes with sentinel IDs and no reason.
  ADMIN_PROBE_TIMEOUT_MS Request timeout. Defaults to ${DEFAULT_TIMEOUT_MS}.

Commands:
  pnpm probe:admin-backend
  ADMIN_API_BASE_URL=https://example.com/v1 pnpm probe:admin-backend

Safety:
  Default probes use GET and OPTIONS only. reason-required mutation checks are
  skipped unless ADMIN_PROBE_MUTATIONS=true and ADMIN_TOKEN is present.
`.trim();

function hasFlag(name) {
  return process.argv.includes(name);
}

function readBooleanEnv(name, defaultValue = false) {
  const value = process.env[name];
  if (value === undefined || value === '') {
    return defaultValue;
  }
  return ['1', 'true', 'yes', 'on'].includes(value.toLowerCase());
}

function normalizeBaseUrl(rawBaseUrl) {
  if (!rawBaseUrl) {
    throw new Error('ADMIN_API_BASE_URL is required. Use --help for examples.');
  }
  const url = new URL(rawBaseUrl);
  return url.toString().replace(/\/+$/, '');
}

function buildUrl(baseUrl, path, query = {}) {
  const url = new URL(`${baseUrl}/${path.replace(/^\/+/, '')}`);
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(key, value);
    }
  }
  return url;
}

function extractJsonBody(bodyText) {
  const value = String(bodyText || '').trim();
  if (!value) {
    return null;
  }
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function validatePagedListContract(body) {
  if (!isPlainObject(body)) {
    return { ok: false, message: 'response must be a JSON object' };
  }
  if (!Array.isArray(body.list)) {
    return { ok: false, message: 'response must expose a top-level list array' };
  }
  if (typeof body.count !== 'number') {
    return { ok: false, message: 'response must expose a top-level numeric count' };
  }
  return { ok: true, message: 'response contract ok' };
}

function validatePurgePreviewContract(body) {
  if (!isPlainObject(body)) {
    return { ok: false, message: 'response must be a JSON object' };
  }
  if (typeof body.uid !== 'string' || body.uid.trim() === '') {
    return { ok: false, message: 'purge preview must expose uid' };
  }
  if (!isPlainObject(body.counts)) {
    return { ok: false, message: 'purge preview must expose counts object' };
  }
  if (!isPlainObject(body.verification)) {
    return { ok: false, message: 'purge preview must expose verification object' };
  }
  return { ok: true, message: 'response contract ok' };
}

function validatePurgeJobContract(body) {
  if (!isPlainObject(body)) {
    return { ok: false, message: 'response must be a JSON object' };
  }
  if (typeof body.job_id !== 'string' || body.job_id.trim() === '') {
    return { ok: false, message: 'purge job must expose job_id' };
  }
  if (typeof body.uid !== 'string' || body.uid.trim() === '') {
    return { ok: false, message: 'purge job must expose uid' };
  }
  if (typeof body.status !== 'string' || body.status.trim() === '') {
    return { ok: false, message: 'purge job must expose status' };
  }
  return { ok: true, message: 'response contract ok' };
}

function validateResponseContract(body, probe = {}) {
  switch (probe.contract) {
    case 'paged-list':
      return validatePagedListContract(body);
    case 'purge-preview':
      return validatePurgePreviewContract(body);
    case 'purge-job':
      return validatePurgeJobContract(body);
    default:
      return { ok: true, message: 'response contract ok' };
  }
}

function classifyResponseContract(bodyText, probe = {}) {
  if (!probe.contract) {
    return { level: 'pass', message: 'endpoint is reachable' };
  }
  const body = extractJsonBody(bodyText);
  if (body === null) {
    return { level: 'fail', message: 'response contract failed: body is not valid JSON' };
  }
  const contract = validateResponseContract(body, probe);
  if (!contract.ok) {
    return { level: 'fail', message: `response contract failed: ${contract.message}` };
  }
  return { level: 'pass', message: `endpoint is reachable; ${contract.message}` };
}

function buildHeaders({ token, tokenHeader, hasBody }) {
  const headers = {
    Accept: 'application/json'
  };

  if (hasBody) {
    headers['Content-Type'] = 'application/json';
  }

  if (token) {
    headers[tokenHeader] = token;
  }

  return headers;
}

async function runRequest({ baseUrl, token, tokenHeader, timeoutMs, probe, includeToken }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  const body = probe.body ? JSON.stringify(probe.body) : undefined;

  try {
    const response = await fetch(buildUrl(baseUrl, probe.path, probe.query), {
      method: probe.method,
      headers: buildHeaders({
        token: includeToken ? token : '',
        tokenHeader,
        hasBody: Boolean(body)
      }),
      body,
      redirect: 'manual',
      signal: controller.signal
    });

    const text = await response.text();
    return {
      status: response.status,
      bodyText: text,
      bodyPreview: text.slice(0, 500)
    };
  } catch (error) {
    return {
      status: 0,
      bodyText: error instanceof Error ? error.message : String(error)
    };
  } finally {
    clearTimeout(timeout);
  }
}

function bodyMentionsReason(bodyText) {
  return /reason|理由|原因/i.test(bodyText);
}

function classifyAuthRequired(status, _bodyText, probe = {}) {
  if (status === 401 || status === 403) {
    return { level: 'pass', message: 'manager endpoint rejects unauthenticated requests' };
  }
  if (status === 404) {
    if (probe.resourceNotFoundIsAmbiguous) {
      return {
        level: 'warn',
        message: '404 may be resource-not-found for the sentinel id; auth guard was not proven'
      };
    }
    return { level: 'missing', message: UNWIRED_LABEL };
  }
  if (status >= 200 && status < 300) {
    return { level: 'fail', message: 'auth-required failed: unauthenticated request succeeded' };
  }
  if (status === 0) {
    return { level: 'fail', message: 'request failed before receiving an HTTP response' };
  }
  return { level: 'warn', message: `unexpected unauthenticated status ${status}` };
}

function classifyReadPresence(status, bodyText, probe = {}) {
  if (status >= 200 && status < 300) {
    return classifyResponseContract(bodyText, probe);
  }
  if (status === 401 || status === 403) {
    return { level: 'fail', message: `token was rejected with ${status}` };
  }
  if (status === 404) {
    if (probe.resourceNotFoundIsAmbiguous) {
      return {
        level: 'warn',
        message: '404 may be resource-not-found for the sentinel id; route presence is ambiguous'
      };
    }
    return { level: 'missing', message: UNWIRED_LABEL };
  }
  if (status === 0) {
    return { level: 'fail', message: 'request failed before receiving an HTTP response' };
  }
  if (status >= 500) {
    return { level: 'fail', message: `server error ${status}` };
  }
  return { level: 'warn', message: `unexpected status ${status}` };
}

function classifyOptionsPresence(status) {
  if ((status >= 200 && status < 300) || status === 401 || status === 403 || status === 405) {
    return { level: 'pass', message: 'route appears present or protected' };
  }
  if (status === 404) {
    return { level: 'missing', message: UNWIRED_LABEL };
  }
  if (status === 0) {
    return { level: 'fail', message: 'request failed before receiving an HTTP response' };
  }
  if (status >= 500) {
    return { level: 'fail', message: `server error ${status}` };
  }
  return { level: 'warn', message: `unexpected OPTIONS status ${status}` };
}

function classifyReasonRequired(status, bodyText) {
  if (status === 400 || status === 422) {
    if (bodyMentionsReason(bodyText)) {
      return { level: 'pass', message: 'backend rejects missing reason' };
    }
    return {
      level: 'warn',
      message: 'backend rejected the mutation, but the error did not explicitly mention reason'
    };
  }
  if (status === 401 || status === 403) {
    return { level: 'warn', message: `token was rejected with ${status}; reason gate could not be verified` };
  }
  if (status === 404) {
    return { level: 'missing', message: UNWIRED_LABEL };
  }
  if (status >= 200 && status < 300) {
    return { level: 'fail', message: 'reason-required failed: mutation accepted without reason' };
  }
  if (status === 0) {
    return { level: 'fail', message: 'request failed before receiving an HTTP response' };
  }
  if (status >= 500) {
    return { level: 'fail', message: `server error ${status}` };
  }
  return { level: 'warn', message: `unexpected mutation status ${status}` };
}

function formatResult(result) {
  const status = result.httpStatus === 0 ? 'NO_RESPONSE' : result.httpStatus;
  return `[${result.level.toUpperCase()}] ${result.id} ${result.method} ${result.path} -> ${status} ${result.message}`;
}

async function runProbe(probe, context, classifier, includeToken) {
  const response = await runRequest({ ...context, probe, includeToken });
  const classification = classifier(response.status, response.bodyText, probe);
  return {
    id: probe.id,
    group: probe.group,
    method: probe.method,
    path: probe.path,
    httpStatus: response.status,
    bodyText: response.bodyText,
    ...classification
  };
}

async function main() {
  if (hasFlag('--help') || hasFlag('-h')) {
    console.log(help);
    return;
  }

  const baseUrl = normalizeBaseUrl(process.env.ADMIN_API_BASE_URL);
  const token = process.env.ADMIN_TOKEN || '';
  const tokenHeader = process.env.ADMIN_TOKEN_HEADER || 'token';
  const timeoutMs = Number.parseInt(process.env.ADMIN_PROBE_TIMEOUT_MS || `${DEFAULT_TIMEOUT_MS}`, 10);
  const allowMutationProbes = readBooleanEnv('ADMIN_PROBE_MUTATIONS', false);

  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    throw new Error('ADMIN_PROBE_TIMEOUT_MS must be a positive number.');
  }

  const context = {
    baseUrl,
    token,
    tokenHeader,
    timeoutMs
  };

  const results = [];

  for (const probe of authRequiredProbes) {
    results.push(await runProbe(probe, context, classifyAuthRequired, false));
  }

  if (token) {
    for (const probe of readProbes) {
      results.push(await runProbe(probe, context, classifyReadPresence, true));
    }
  } else {
    results.push({
      id: 'authenticated-read-probes',
      group: 'read endpoint presence',
      method: 'GET',
      path: '*',
      httpStatus: 0,
      level: 'warn',
      message: 'ADMIN_TOKEN not set; authenticated read presence checks skipped'
    });
  }

  for (const probe of optionsProbes) {
    results.push(await runProbe(probe, context, classifyOptionsPresence, Boolean(token)));
  }

  if (allowMutationProbes && token) {
    for (const probe of reasonRequiredProbes) {
      results.push(await runProbe(probe, context, classifyReasonRequired, true));
    }
  } else {
    results.push({
      id: 'reason-required-mutation-probes',
      group: 'reason-required',
      method: 'POST/DELETE',
      path: '*',
      httpStatus: 0,
      level: 'warn',
      message: 'mutation probes skipped; set ADMIN_PROBE_MUTATIONS=true and ADMIN_TOKEN to verify backend reason enforcement'
    });
  }

  for (const result of results) {
    console.log(formatResult(result));
  }

  const summary = results.reduce(
    (counts, result) => {
      counts[result.level] = (counts[result.level] || 0) + 1;
      return counts;
    },
    { pass: 0, warn: 0, fail: 0, missing: 0 }
  );

  console.log(
    `Summary: pass=${summary.pass || 0} warn=${summary.warn || 0} fail=${summary.fail || 0} missing=${summary.missing || 0}`
  );

  if ((summary.fail || 0) > 0 || (summary.missing || 0) > 0) {
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

export {
  buildUrl,
  classifyReadPresence,
  extractJsonBody,
  validateResponseContract
};
