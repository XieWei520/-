<script setup lang="ts">
import { computed, ref } from 'vue';

const emit = defineEmits<{
  send: [text: string];
}>();

const text = ref('');
const canSend = computed(() => text.value.trim().length > 0);

function sendMessage() {
  const nextText = text.value.trim();

  if (!nextText) {
    return;
  }

  emit('send', nextText);
  text.value = '';
}
</script>

<template>
  <form class="chat-composer" @submit.prevent="sendMessage">
    <label class="sr-only" for="chat-message-input">输入消息</label>
    <textarea
      id="chat-message-input"
      v-model="text"
      class="chat-composer__input"
      rows="1"
      placeholder="输入消息"
      autocomplete="off"
    ></textarea>
    <button class="chat-composer__send" type="submit" :disabled="!canSend">发送</button>
  </form>
</template>
