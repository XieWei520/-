import type { WebImRuntimeConfig } from '../config/runtimeConfig';
import type { Conversation } from '../models/im';
import { readRecord, readString } from './conversationSyncApi';
import { signedJsonRequest, type SignedJsonRequestOptions } from './signedHttpClient';

type ProfileRequest = <TResult, TBody = unknown>(
  options: SignedJsonRequestOptions<TBody>,
) => Promise<TResult>;

interface HydrateConversationTitlesOptions {
  token: string;
  cacheScope?: string;
  config: WebImRuntimeConfig;
  request?: ProfileRequest;
}

interface ConversationProfile {
  title: string;
}

const titleCache = new Map<string, ConversationProfile>();
const titleKeys = [
  'remark',
  'name',
  'username',
  'group_name',
  'groupName',
  'channel_name',
  'channelName',
  'display_name',
  'displayName',
];

function cacheKey(conversation: Pick<Conversation, 'channelType' | 'channelId'>, cacheScope = 'default'): string {
  return `${cacheScope}:${conversation.channelType}:${conversation.channelId}`;
}

function avatarTextFromTitle(title: string, fallback: string): string {
  return Array.from(title.trim())[0] ?? fallback;
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

function isPlaceholderGroupTitle(conversation: Conversation): boolean {
  if (conversation.channelType !== 2) return false;

  const title = conversation.title.trim();
  const channelId = conversation.channelId.trim();
  if (!title || !channelId) return false;

  return title === channelId || title === `群聊 ${readableTail(channelId)}`;
}

export function mapConversationProfile(raw: unknown): ConversationProfile | null {
  const root = readRecord(raw);
  const data = readRecord(root?.data) ?? root;
  const title = readFirstString(data, titleKeys);
  return title ? { title } : null;
}

function shouldHydrate(conversation: Conversation): boolean {
  if (conversation.titleSource === 'fallback') return true;
  if (conversation.channelType === 2 && conversation.titleSource !== 'hydrated') return true;
  return isPlaceholderGroupTitle(conversation);
}

async function fetchConversationProfile(
  conversation: Conversation,
  options: HydrateConversationTitlesOptions,
): Promise<ConversationProfile | null> {
  const request = options.request ?? signedJsonRequest;
  const path =
    conversation.channelType === 2
      ? `/v1/groups/${encodeURIComponent(conversation.channelId)}`
      : `/v1/users/${encodeURIComponent(conversation.channelId)}`;
  const raw = await request({
    baseUrl: options.config.apiBaseUrl,
    appId: options.config.appId,
    appKey: options.config.appKey,
    token: options.token,
    path,
    method: 'GET',
  });
  return mapConversationProfile(raw);
}

export async function hydrateConversationTitles(
  conversations: Conversation[],
  options: HydrateConversationTitlesOptions,
): Promise<Conversation[]> {
  return Promise.all(
    conversations.map(async (conversation) => {
      if (!shouldHydrate(conversation)) return conversation;

      const key = cacheKey(conversation, options.cacheScope);
      let profile = titleCache.get(key) ?? null;
      if (!profile) {
        try {
          profile = await fetchConversationProfile(conversation, options);
          if (profile) titleCache.set(key, profile);
        } catch {
          return conversation;
        }
      }

      if (!profile) return conversation;

      return {
        ...conversation,
        title: profile.title,
        avatarText: avatarTextFromTitle(profile.title, conversation.avatarText),
        titleSource: 'hydrated',
      };
    }),
  );
}

export function clearConversationTitleCacheForTest(): void {
  titleCache.clear();
}
