<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { fakeConversations } from '../../mocks/fakeImData';

const route = useRoute();

const channelType = computed(() => String(route.params.channelType));
const channelId = computed(() => String(route.params.channelId));
const title = computed(() => {
  return fakeConversations.find((item) => item.channelId === channelId.value)?.title ?? '聊天';
});
</script>

<template>
  <main class="page chat-placeholder">
    <header class="page-header">
      <h1>{{ title }}</h1>
      <p>聊天页将在 Task 3 实现</p>
    </header>

    <p class="placeholder-text">
      channelType: {{ channelType }} - channelId: {{ channelId }}
    </p>
  </main>
</template>
