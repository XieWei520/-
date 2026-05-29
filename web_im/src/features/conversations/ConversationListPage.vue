<script setup lang="ts">
import { useRouter } from 'vue-router';
import { fakeConversations } from '../../mocks/fakeImData';
import type { ChannelType } from '../../models/im';

const router = useRouter();

function openConversation(channelType: ChannelType, channelId: string) {
  router.push(`/chat/${channelType}/${channelId}`);
}
</script>

<template>
  <main class="page">
    <header class="page-header">
      <h1>会话</h1>
      <p>本地假数据，仅用于 Phase 1 移动端壳验证</p>
    </header>

    <ul class="list" aria-label="会话列表">
      <li v-for="item in fakeConversations" :key="item.id">
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
