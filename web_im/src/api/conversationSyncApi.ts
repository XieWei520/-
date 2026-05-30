import type { WebImRuntimeConfig } from '../config/runtimeConfig';
import type { ChannelType, Conversation } from '../models/im';
import { signedJsonRequest, type SignedJsonRequestOptions } from './signedHttpClient';

type ConversationSyncRequest = <TResult, TBody = unknown>(
  options: SignedJsonRequestOptions<TBody>,
) => Promise<TResult>;

interface ConversationSyncOptions {
  uid: string;
  token: string;
  deviceUuid: string;
  config: WebImRuntimeConfig;
  request?: ConversationSyncRequest;
}

interface ConversationSyncBody {
  version: 0;
  last_msg_seqs: '';
  msg_count: 200;
  device_uuid: string;
}

export function readRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

export function readInt(record: Record<string, unknown> | null, key: string): number | undefined {
  const value = record?.[key];
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : undefined;
  }
  return undefined;
}

export function readString(record: Record<string, unknown> | null, key: string): string | undefined {
  const value = record?.[key];
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
}

export function parsePayload(value: unknown): Record<string, unknown> | null {
  if (typeof value === 'string') {
    try {
      return readRecord(JSON.parse(value));
    } catch {
      return null;
    }
  }

  return readRecord(value);
}

function readFirstString(record: Record<string, unknown> | null, keys: string[]): string | undefined {
  for (const key of keys) {
    const value = readString(record, key);
    if (value) return value;
  }
  return undefined;
}

function readableTail(value: string, length = 4): string {
  return value.length <= length ? value : value.slice(-length);
}

function channelFallbackTitle(channelId: string, channelType: ChannelType): string {
  return `${channelType === 2 ? '群聊' : '用户'} ${readableTail(channelId)}`;
}

function avatarTextFromTitle(title: string, channelType: ChannelType): string {
  const first = Array.from(title.trim())[0];
  return first || (channelType === 2 ? '群' : '用');
}

export function formatConversationTimestamp(timestamp?: number): string {
  if (!timestamp) return '';

  const date = new Date(timestamp * 1000);
  if (Number.isNaN(date.getTime())) return '';

  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const startOfTarget = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  const dayDelta = Math.round((startOfToday - startOfTarget) / 86_400_000);
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');

  if (dayDelta === 0) return `${hours}:${minutes}`;
  if (dayDelta === 1) return '昨天';

  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  if (date.getFullYear() === now.getFullYear()) {
    return `${month}-${day}`;
  }
  return `${date.getFullYear()}-${month}-${day}`;
}

export function summarizeRecentMessage(raw: unknown): string {
  const record = readRecord(raw);
  if (!record || Object.keys(record).length === 0) {
    return '[暂无消息]';
  }

  const payload = parsePayload(record.payload);
  if (!payload) {
    return '[不支持的消息]';
  }

  const content = readString(payload, 'content') ?? readString(payload, 'text');
  if (content) return content;

  switch (readInt(payload, 'type')) {
    case 2:
      return '[图片]';
    case 4:
      return '[语音]';
    case 5:
    case 6:
      return '[文件]';
    default:
      return '[不支持的消息]';
  }
}

function latestRecent(recents: unknown): Record<string, unknown> | null {
  if (!Array.isArray(recents)) return null;

  return recents.reduce<Record<string, unknown> | null>((latest, item) => {
    const current = readRecord(item);
    if (!current) return latest;
    if (!latest) return current;

    const currentSeq = readInt(current, 'message_seq') ?? readInt(current, 'messageSeq') ?? 0;
    const latestSeq = readInt(latest, 'message_seq') ?? readInt(latest, 'messageSeq') ?? 0;
    if (currentSeq !== latestSeq) {
      return currentSeq > latestSeq ? current : latest;
    }

    const currentTimestamp = readInt(current, 'timestamp') ?? 0;
    const latestTimestamp = readInt(latest, 'timestamp') ?? 0;
    return currentTimestamp > latestTimestamp ? current : latest;
  }, null);
}

export function mapConversationSyncRows(rows: unknown): Conversation[] {
  if (!Array.isArray(rows)) return [];

  return rows.flatMap((row): Conversation[] => {
    const record = readRecord(row);
    if (!record) return [];

    const channelId = readString(record, 'channel_id') ?? readString(record, 'channelId');
    const channelType = readInt(record, 'channel_type') ?? readInt(record, 'channelType');
    if (!channelId || (channelType !== 1 && channelType !== 2)) return [];

    const latest = latestRecent(record.recents);
    const timestamp = readInt(latest, 'timestamp') ?? readInt(record, 'timestamp');
    const lastMsgSeq =
      readInt(latest, 'message_seq') ??
      readInt(latest, 'messageSeq') ??
      readInt(record, 'last_msg_seq') ??
      readInt(record, 'lastMsgSeq');
    const lastClientMsgNo =
      readString(latest, 'client_msg_no') ??
      readString(latest, 'clientMsgNo') ??
      readString(record, 'last_client_msg_no') ??
      readString(record, 'lastClientMsgNo');
    const rawTitle =
      readFirstString(record, ['channel_name', 'channelName', 'name', 'remark', 'display_name', 'displayName']) ??
      readFirstString(parsePayload(record.extra), ['channel_name', 'channelName', 'name', 'remark', 'display_name', 'displayName']);
    const title = rawTitle ?? channelFallbackTitle(channelId, channelType as ChannelType);

    return [
      {
        id: `${channelType}:${channelId}`,
        channelId,
        channelType: channelType as ChannelType,
        title,
        avatarText: avatarTextFromTitle(title, channelType as ChannelType),
        lastMessage: latest ? summarizeRecentMessage(latest) : '[暂无消息]',
        lastMessageAt: formatConversationTimestamp(timestamp),
        unreadCount: readInt(record, 'unread') ?? readInt(record, 'unreadCount') ?? 0,
        muted: false,
        lastMsgSeq,
        lastClientMsgNo,
      },
    ];
  });
}

export async function loadConversationSync(options: ConversationSyncOptions): Promise<Conversation[]> {
  const request = options.request ?? signedJsonRequest;
  const raw = await request<unknown, ConversationSyncBody>({
    baseUrl: options.config.apiBaseUrl,
    appId: options.config.appId,
    appKey: options.config.appKey,
    token: options.token,
    path: '/v1/conversation/sync',
    method: 'POST',
    body: {
      version: 0,
      last_msg_seqs: '',
      msg_count: 200,
      device_uuid: options.deviceUuid,
    },
  });

  const root = readRecord(raw);
  const data = readRecord(root?.data);
  return mapConversationSyncRows(root?.conversations ?? data?.conversations);
}
