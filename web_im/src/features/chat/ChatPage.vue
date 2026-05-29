<script setup lang="ts">
import { computed, watch } from 'vue';
import { useRoute } from 'vue-router';
import ChatComposer from './ChatComposer.vue';
import ChatHeader from './ChatHeader.vue';
import VirtualMessageList from './VirtualMessageList.vue';
import { useChatStore } from '../../stores/chatStore';
import type { ChannelType } from '../../models/im';

const route = useRoute();
const chat = useChatStore();

const channelType = computed<ChannelType | null>(() => {
  const value = Number(route.params.channelType);
  return value === 1 || value === 2 ? value : null;
});
const channelId = computed(() => {
  const value = route.params.channelId;
  return typeof value === 'string' && value.trim() ? value : null;
});
const canOpenChannel = computed(() => Boolean(channelType.value && channelId.value));
const title = computed(() => chat.activeConversation?.title || '聊天');

watch(
  [channelType, channelId],
  ([nextType, nextId]) => {
    if (nextType && nextId) {
      chat.openChannel(nextType, nextId);
    }
  },
  { immediate: true },
);
</script>

<template>
  <main class="chat-page">
    <ChatHeader :title="title" status-text="假数据会话" />

    <section v-if="canOpenChannel" class="chat-page__body" aria-label="聊天内容">
      <VirtualMessageList :messages="chat.activeMessages" @load-older="chat.prependOlderMessages" />
      <ChatComposer @send="chat.sendText" />
    </section>

    <section v-else class="chat-empty-state" role="status">
      <p class="chat-empty-state__title">无法打开会话</p>
      <p class="chat-empty-state__text">当前聊天地址不完整，请返回会话列表重新选择。</p>
    </section>
  </main>
</template>
