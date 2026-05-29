import { computed, ref } from 'vue';
import { defineStore } from 'pinia';
import { loadConversationSync } from '../api/conversationSyncApi';
import { toUserMessage } from '../api/apiError';
import { isLiveMode, isMockMode, runtimeConfig } from '../config/runtimeConfig';
import { buildFakeMessages, fakeConversations, fakeCurrentUser } from '../mocks/fakeImData';
import type { ChannelType, ChatMessage, Conversation } from '../models/im';

type ChannelKey = `${ChannelType}_${string}`;
type ActiveChannel = {
  channelType: ChannelType;
  channelId: string;
};
type ConversationSyncAuth = {
  uid: string;
  token: string;
  imToken?: string;
  deviceUuid: string;
} | null;

const conversationTitles: Record<string, string> = {
  'g-delivery': '产品交付群',
  'u-customer-a': '客户 A',
  'g-ops': '运维通知',
};

const incomingNames = ['李明', '客户 A', '陈晨'];
const textSamples = [
  '收到，我会在今天下午更新进度。',
  '请确认最新版本的交付范围。',
  '会议纪要已经放到共享目录。',
  '这个问题需要后端同学一起看一下。',
  '我先拉一版测试数据给大家验证。',
];

function channelKey(channelType: ChannelType, channelId: string): ChannelKey {
  return `${channelType}_${channelId}`;
}

function parseChannelKey(key: ChannelKey | null): ActiveChannel | null {
  if (!key) {
    return null;
  }

  const separatorIndex = key.indexOf('_');
  const channelType = Number(key.slice(0, separatorIndex));
  const channelId = key.slice(separatorIndex + 1);

  if ((channelType !== 1 && channelType !== 2) || !channelId) {
    return null;
  }

  return {
    channelType,
    channelId,
  };
}

function cleanFakeMessage(message: ChatMessage, index: number): ChatMessage {
  const senderName = message.direction === 'outgoing' ? '吴小空' : incomingNames[index % incomingNames.length];

  if (message.kind === 'image') {
    return { ...message, senderName, content: `现场截图 ${String(index + 1).padStart(2, '0')}` };
  }

  if (message.kind === 'file') {
    return { ...message, senderName, content: `交付文档-${String(index + 1).padStart(2, '0')}.pdf` };
  }

  if (message.kind === 'voice') {
    return { ...message, senderName, content: `${8 + (index % 24)} 秒语音` };
  }

  return { ...message, senderName, content: textSamples[index % textSamples.length] };
}

export const useChatStore = defineStore('chat', () => {
  const conversations = ref<Conversation[]>([...fakeConversations]);
  const isLoadingConversations = ref(false);
  const conversationError = ref('');
  const messagesByChannel = ref<Record<string, ChatMessage[]>>({});
  const activeChannelKey = ref<ChannelKey | null>(null);
  const isLiveConversationMode = computed(() => isLiveMode(runtimeConfig));
  let localMessageSeq = 0;

  const activeMessages = computed(() => {
    if (!activeChannelKey.value) {
      return [];
    }

    return messagesByChannel.value[activeChannelKey.value] ?? [];
  });

  const activeConversation = computed(() => {
    if (!activeChannelKey.value) {
      return undefined;
    }

    const conversation = conversations.value.find((item) => channelKey(item.channelType, item.channelId) === activeChannelKey.value);

    if (!conversation) {
      return undefined;
    }

    return {
      ...conversation,
      title: conversationTitles[conversation.channelId] ?? conversation.title,
    };
  });

  const activeChannel = computed(() => parseChannelKey(activeChannelKey.value));

  function openChannel(channelType: ChannelType, channelId: string): void {
    const key = channelKey(channelType, channelId);
    activeChannelKey.value = key;

    if (!messagesByChannel.value[key]) {
      messagesByChannel.value[key] = buildFakeMessages(channelId).map((message) => ({
        ...message,
        channelType,
      })).map(cleanFakeMessage);
    }
  }

  function sendText(text: string): void {
    const normalizedText = text.trim();
    const channel = activeChannel.value;

    if (!normalizedText || !activeChannelKey.value || !channel) {
      return;
    }

    localMessageSeq += 1;
    const clientMsgNo = `local-${channel.channelId}-${Date.now()}-${localMessageSeq}`;
    const message: ChatMessage & { clientMsgNo: string } = {
      id: clientMsgNo,
      clientMsgNo,
      channelId: channel.channelId,
      channelType: channel.channelType,
      senderId: fakeCurrentUser.id,
      senderName: '吴小空',
      direction: 'outgoing',
      kind: 'text',
      content: normalizedText,
      sentAt: new Date().toISOString(),
      status: 'sent',
    };

    messagesByChannel.value[activeChannelKey.value] = [...activeMessages.value, message];
  }

  function prependOlderMessages(): number {
    const channel = activeChannel.value;

    if (!activeChannelKey.value || !channel) {
      return 0;
    }

    const current = activeMessages.value;
    const firstSentAt = current[0]?.sentAt ? new Date(current[0].sentAt).getTime() : Date.now();
    const olderMessages = Array.from({ length: 20 }, (_, index): ChatMessage => {
      const olderIndex = 20 - index;
      const sentAt = new Date(firstSentAt - olderIndex * 90_000).toISOString();

      return {
        id: `older-${channel.channelId}-${firstSentAt}-${index}`,
        channelId: channel.channelId,
        channelType: channel.channelType,
        senderId: `u-history-${index % 4}`,
        senderName: ['李明', '客户 A', '陈晨', '系统通知'][index % 4],
        direction: index % 4 === 0 ? 'outgoing' : 'incoming',
        kind: 'text',
        content: `更早的聊天记录 ${index + 1}：这是一条本地假数据消息。`,
        sentAt,
        status: 'sent',
      };
    });

    messagesByChannel.value[activeChannelKey.value] = [...olderMessages, ...current];
    return olderMessages.length;
  }

  async function loadConversations(auth: ConversationSyncAuth): Promise<void> {
    if (isMockMode(runtimeConfig)) {
      conversations.value = [...fakeConversations];
      conversationError.value = '';
      isLoadingConversations.value = false;
      return;
    }

    if (!auth?.uid || !auth.token || !auth.deviceUuid) {
      conversations.value = [];
      conversationError.value = 'Conversation sync requires an active session.';
      isLoadingConversations.value = false;
      return;
    }

    isLoadingConversations.value = true;
    conversationError.value = '';

    try {
      conversations.value = await loadConversationSync({
        uid: auth.uid,
        token: auth.token,
        deviceUuid: auth.deviceUuid,
        config: runtimeConfig,
      });
    } catch (error) {
      conversationError.value = toUserMessage(error, 'Failed to load conversations.');
    } finally {
      isLoadingConversations.value = false;
    }
  }

  return {
    conversations,
    isLoadingConversations,
    conversationError,
    isLiveConversationMode,
    messagesByChannel,
    activeChannelKey,
    activeMessages,
    activeConversation,
    openChannel,
    sendText,
    prependOlderMessages,
    loadConversations,
  };
});
