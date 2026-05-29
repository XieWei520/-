import { ApiError } from './apiError';

export type FetchLike = typeof fetch;
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';

export interface SignedHeaderOptions {
  body?: string;
  appId: string;
  appKey: string;
  token?: string | null;
  now?: () => number;
  nonce?: () => string;
}

export interface SignedJsonRequestOptions<TBody = unknown> extends Omit<SignedHeaderOptions, 'body'> {
  baseUrl: string;
  path: string;
  method: HttpMethod;
  body?: TBody;
  fetchImpl?: FetchLike;
}

interface ApiResponseBody {
  code?: unknown;
  status?: unknown;
  msg?: unknown;
  message?: unknown;
  data?: unknown;
}

export function stableJsonStringify(value: unknown): string {
  return value === undefined ? '' : JSON.stringify(value);
}

export async function createSignedHeaders(options: SignedHeaderOptions): Promise<Record<string, string>> {
  const timestamp = String(options.now?.() ?? Date.now());
  const noncestr = options.nonce?.() ?? defaultNonce();
  const body = options.body ?? '';
  const sign = md5Hex(`${body}${noncestr}${timestamp}${options.appKey}`);

  return {
    'Content-Type': 'application/json',
    Accept: 'application/json',
    appid: options.appId,
    timestamp,
    noncestr,
    sign,
    ...(options.token ? { token: options.token } : {}),
  };
}

export async function signedJsonRequest<TResult = unknown, TBody = unknown>(
  options: SignedJsonRequestOptions<TBody>,
): Promise<TResult> {
  const isGet = options.method === 'GET';
  const body = isGet ? '' : stableJsonStringify(options.body);
  const headers = await createSignedHeaders({ ...options, body });
  const fetchImpl = options.fetchImpl ?? fetch;

  let response: Response;
  try {
    response = await fetchImpl(joinUrl(options.baseUrl, options.path), {
      method: options.method,
      headers,
      ...(isGet ? {} : { body }),
    });
  } catch (error) {
    throw new ApiError(error instanceof Error ? error.message : 'Network request failed', {
      retryable: true,
      unauthorized: false,
    });
  }

  const json = await readJsonResponse(response);
  const apiCode = normalizeCode(json.code ?? json.status);

  if (!response.ok || (apiCode !== undefined && apiCode !== 0)) {
    throw new ApiError(responseMessage(json, response), {
      status: response.status,
      code: apiCode,
    });
  }

  return (json.data !== undefined ? json.data : json) as TResult;
}

function joinUrl(baseUrl: string, path: string): string {
  return `${baseUrl.replace(/\/+$/, '')}/${path.replace(/^\/+/, '')}`;
}

function defaultNonce(): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let value = '';
  for (let index = 0; index < 16; index += 1) {
    value += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return value;
}

async function readJsonResponse(response: Response): Promise<ApiResponseBody> {
  const text = await response.text();
  if (!text.trim()) return {};

  try {
    const parsed = JSON.parse(text);
    return isRecord(parsed) ? parsed : { data: parsed };
  } catch {
    return { message: text };
  }
}

function responseMessage(json: ApiResponseBody, response: Response): string {
  const message = stringValue(json.msg) ?? stringValue(json.message);
  return message ?? `HTTP ${response.status}`;
}

function normalizeCode(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : undefined;
  }
  return undefined;
}

function stringValue(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value : undefined;
}

function isRecord(value: unknown): value is ApiResponseBody {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function md5Hex(input: string): string {
  const bytes = toUtf8Bytes(input);
  const words: number[] = [];

  for (let index = 0; index < bytes.length; index += 1) {
    words[index >> 2] = (words[index >> 2] ?? 0) | (bytes[index] << ((index % 4) * 8));
  }

  words[bytes.length >> 2] = (words[bytes.length >> 2] ?? 0) | (0x80 << ((bytes.length % 4) * 8));
  words[(((bytes.length + 8) >> 6) << 4) + 14] = bytes.length * 8;

  let a = 0x67452301;
  let b = 0xefcdab89;
  let c = 0x98badcfe;
  let d = 0x10325476;

  for (let index = 0; index < words.length; index += 16) {
    const oldA = a;
    const oldB = b;
    const oldC = c;
    const oldD = d;

    a = ff(a, b, c, d, words[index] ?? 0, 7, -680876936);
    d = ff(d, a, b, c, words[index + 1] ?? 0, 12, -389564586);
    c = ff(c, d, a, b, words[index + 2] ?? 0, 17, 606105819);
    b = ff(b, c, d, a, words[index + 3] ?? 0, 22, -1044525330);
    a = ff(a, b, c, d, words[index + 4] ?? 0, 7, -176418897);
    d = ff(d, a, b, c, words[index + 5] ?? 0, 12, 1200080426);
    c = ff(c, d, a, b, words[index + 6] ?? 0, 17, -1473231341);
    b = ff(b, c, d, a, words[index + 7] ?? 0, 22, -45705983);
    a = ff(a, b, c, d, words[index + 8] ?? 0, 7, 1770035416);
    d = ff(d, a, b, c, words[index + 9] ?? 0, 12, -1958414417);
    c = ff(c, d, a, b, words[index + 10] ?? 0, 17, -42063);
    b = ff(b, c, d, a, words[index + 11] ?? 0, 22, -1990404162);
    a = ff(a, b, c, d, words[index + 12] ?? 0, 7, 1804603682);
    d = ff(d, a, b, c, words[index + 13] ?? 0, 12, -40341101);
    c = ff(c, d, a, b, words[index + 14] ?? 0, 17, -1502002290);
    b = ff(b, c, d, a, words[index + 15] ?? 0, 22, 1236535329);

    a = gg(a, b, c, d, words[index + 1] ?? 0, 5, -165796510);
    d = gg(d, a, b, c, words[index + 6] ?? 0, 9, -1069501632);
    c = gg(c, d, a, b, words[index + 11] ?? 0, 14, 643717713);
    b = gg(b, c, d, a, words[index] ?? 0, 20, -373897302);
    a = gg(a, b, c, d, words[index + 5] ?? 0, 5, -701558691);
    d = gg(d, a, b, c, words[index + 10] ?? 0, 9, 38016083);
    c = gg(c, d, a, b, words[index + 15] ?? 0, 14, -660478335);
    b = gg(b, c, d, a, words[index + 4] ?? 0, 20, -405537848);
    a = gg(a, b, c, d, words[index + 9] ?? 0, 5, 568446438);
    d = gg(d, a, b, c, words[index + 14] ?? 0, 9, -1019803690);
    c = gg(c, d, a, b, words[index + 3] ?? 0, 14, -187363961);
    b = gg(b, c, d, a, words[index + 8] ?? 0, 20, 1163531501);
    a = gg(a, b, c, d, words[index + 13] ?? 0, 5, -1444681467);
    d = gg(d, a, b, c, words[index + 2] ?? 0, 9, -51403784);
    c = gg(c, d, a, b, words[index + 7] ?? 0, 14, 1735328473);
    b = gg(b, c, d, a, words[index + 12] ?? 0, 20, -1926607734);

    a = hh(a, b, c, d, words[index + 5] ?? 0, 4, -378558);
    d = hh(d, a, b, c, words[index + 8] ?? 0, 11, -2022574463);
    c = hh(c, d, a, b, words[index + 11] ?? 0, 16, 1839030562);
    b = hh(b, c, d, a, words[index + 14] ?? 0, 23, -35309556);
    a = hh(a, b, c, d, words[index + 1] ?? 0, 4, -1530992060);
    d = hh(d, a, b, c, words[index + 4] ?? 0, 11, 1272893353);
    c = hh(c, d, a, b, words[index + 7] ?? 0, 16, -155497632);
    b = hh(b, c, d, a, words[index + 10] ?? 0, 23, -1094730640);
    a = hh(a, b, c, d, words[index + 13] ?? 0, 4, 681279174);
    d = hh(d, a, b, c, words[index] ?? 0, 11, -358537222);
    c = hh(c, d, a, b, words[index + 3] ?? 0, 16, -722521979);
    b = hh(b, c, d, a, words[index + 6] ?? 0, 23, 76029189);
    a = hh(a, b, c, d, words[index + 9] ?? 0, 4, -640364487);
    d = hh(d, a, b, c, words[index + 12] ?? 0, 11, -421815835);
    c = hh(c, d, a, b, words[index + 15] ?? 0, 16, 530742520);
    b = hh(b, c, d, a, words[index + 2] ?? 0, 23, -995338651);

    a = ii(a, b, c, d, words[index] ?? 0, 6, -198630844);
    d = ii(d, a, b, c, words[index + 7] ?? 0, 10, 1126891415);
    c = ii(c, d, a, b, words[index + 14] ?? 0, 15, -1416354905);
    b = ii(b, c, d, a, words[index + 5] ?? 0, 21, -57434055);
    a = ii(a, b, c, d, words[index + 12] ?? 0, 6, 1700485571);
    d = ii(d, a, b, c, words[index + 3] ?? 0, 10, -1894986606);
    c = ii(c, d, a, b, words[index + 10] ?? 0, 15, -1051523);
    b = ii(b, c, d, a, words[index + 1] ?? 0, 21, -2054922799);
    a = ii(a, b, c, d, words[index + 8] ?? 0, 6, 1873313359);
    d = ii(d, a, b, c, words[index + 15] ?? 0, 10, -30611744);
    c = ii(c, d, a, b, words[index + 6] ?? 0, 15, -1560198380);
    b = ii(b, c, d, a, words[index + 13] ?? 0, 21, 1309151649);
    a = ii(a, b, c, d, words[index + 4] ?? 0, 6, -145523070);
    d = ii(d, a, b, c, words[index + 11] ?? 0, 10, -1120210379);
    c = ii(c, d, a, b, words[index + 2] ?? 0, 15, 718787259);
    b = ii(b, c, d, a, words[index + 9] ?? 0, 21, -343485551);

    a = add32(a, oldA);
    b = add32(b, oldB);
    c = add32(c, oldC);
    d = add32(d, oldD);
  }

  return [a, b, c, d].map(wordToHex).join('');
}

function toUtf8Bytes(input: string): number[] {
  return Array.from(new TextEncoder().encode(input));
}

function wordToHex(word: number): string {
  let value = '';
  for (let index = 0; index < 4; index += 1) {
    value += ((word >> (index * 8)) & 0xff).toString(16).padStart(2, '0');
  }
  return value;
}

function cmn(q: number, a: number, b: number, x: number, s: number, t: number): number {
  return add32(rotateLeft(add32(add32(a, q), add32(x, t)), s), b);
}

function ff(a: number, b: number, c: number, d: number, x: number, s: number, t: number): number {
  return cmn((b & c) | (~b & d), a, b, x, s, t);
}

function gg(a: number, b: number, c: number, d: number, x: number, s: number, t: number): number {
  return cmn((b & d) | (c & ~d), a, b, x, s, t);
}

function hh(a: number, b: number, c: number, d: number, x: number, s: number, t: number): number {
  return cmn(b ^ c ^ d, a, b, x, s, t);
}

function ii(a: number, b: number, c: number, d: number, x: number, s: number, t: number): number {
  return cmn(c ^ (b | ~d), a, b, x, s, t);
}

function rotateLeft(value: number, bits: number): number {
  return (value << bits) | (value >>> (32 - bits));
}

function add32(a: number, b: number): number {
  return (a + b) | 0;
}
