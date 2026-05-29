<script setup lang="ts">
import { useRouter } from 'vue-router';

defineProps<{
  title: string;
  statusText?: string;
}>();

const router = useRouter();

function goBack() {
  router.push('/conversations');
}
</script>

<template>
  <header class="chat-header">
    <button class="chat-header__back" type="button" aria-label="返回会话列表" @click="goBack">
      <span aria-hidden="true">‹</span>
    </button>
    <div class="chat-header__main">
      <h1 class="chat-header__title">{{ title }}</h1>
      <p v-if="statusText" class="chat-header__status">{{ statusText }}</p>
    </div>
  </header>
</template>
