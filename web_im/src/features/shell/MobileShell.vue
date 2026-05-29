<script setup lang="ts">
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const isChatRoute = computed(() => route.name === 'chat' || route.name === 'chat-page');
</script>

<template>
  <div class="shell" :class="{ 'shell--chat': isChatRoute }">
    <RouterView />

    <nav v-if="!isChatRoute" class="bottom-tabs" aria-label="主导航">
      <RouterLink class="tab-link" to="/conversations">会话</RouterLink>
      <RouterLink class="tab-link" to="/contacts">通讯录</RouterLink>
      <RouterLink class="tab-link" to="/me">我的</RouterLink>
    </nav>
  </div>
</template>
