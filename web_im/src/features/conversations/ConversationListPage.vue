<script setup lang="ts">
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/authStore';
import { useChatStore } from '../../stores/chatStore';
import type { ChannelType } from '../../models/im';

const router = useRouter();
const auth = useAuthStore();
const chat = useChatStore();

onMounted(() => {
  void chat.loadConversations(auth.sessionForConversationSync);
});

function retryLoad() {
  void chat.loadConversations(auth.sessionForConversationSync);
}

function openConversation(channelType: ChannelType, channelId: string) {
  router.push(`/chat/${channelType}/${channelId}`);
}
</script>

<template>
  <main class="page">
    <header class="page-header">
      <h1>会话</h1>
      <p>
        {{
          chat.isLiveConversationMode
            ? '正在显示后端同步的只读会话'
            : '本地假数据，仅用于 Phase 1 移动端壳验证'
        }}
      </p>
    </header>

    <section v-if="chat.isLoadingConversations" class="status-list" role="status">正在加载会话...</section>

    <section v-else-if="chat.conversationError" class="status-list" role="alert">
      <p>{{ chat.conversationError }}</p>
      <button class="secondary-button" type="button" @click="retryLoad">重试</button>
    </section>

    <section v-else-if="chat.conversations.length === 0" class="status-list" role="status">暂无会话</section>

    <ul v-else class="list" aria-label="会话列表">
      <li v-for="item in chat.conversations" :key="item.id">
        <button class="list-row" type="button" @click="openConversation(item.channelType, item.channelId)">
          <span class="avatar" aria-hidden="true">{{ item.avatarText }}</span>
          <span class="row-main">
            <span class="row-title">{{ item.title }}</span>
            <span class="row-subtitle">{{ item.lastMessage }}</span>
          </span>
          <span class="row-meta">
            <span class="time-text">{{ item.lastMessageAt }}</span>
            <span v-if="item.unreadCount" class="badge" aria-label="未读消息">
              {{ item.unreadCount }}
            </span>
          </span>
        </button>
      </li>
    </ul>
  </main>
</template>
