<script setup lang="ts">
import type { ChatMessage } from '../../models/im';

const props = defineProps<{
  message: ChatMessage;
}>();

function sentTime(value: string): string {
  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return '';
  }

  return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
}

function voiceDuration(content: string): string {
  const match = content.match(/\d+/);
  return match ? `${match[0]} 秒` : '语音消息';
}

function fileMeta(content: string): string {
  return `${content} · ${(props.message.id.length % 6) + 1}.2 MB`;
}
</script>

<template>
  <article class="message-row" :class="`message-row--${message.direction}`">
    <div class="message-row__content">
      <p v-if="message.direction === 'incoming'" class="message-row__sender">{{ message.senderName }}</p>

      <div class="message-bubble" :class="`message-bubble--${message.kind}`">
        <p v-if="message.kind === 'text'" class="message-bubble__text">{{ message.content }}</p>

        <div v-else-if="message.kind === 'image'" class="message-media" aria-label="假图片预览">
          <span class="message-media__thumb" aria-hidden="true">{{ message.content.slice(-2) }}</span>
          <span class="message-media__text">{{ message.content }}</span>
        </div>

        <div v-else-if="message.kind === 'file'" class="message-file" aria-label="假文件消息">
          <span class="message-file__icon" aria-hidden="true">文</span>
          <span class="message-file__name">{{ fileMeta(message.content) }}</span>
        </div>

        <div v-else class="message-voice" aria-label="假语音消息">
          <span class="message-voice__bars" aria-hidden="true">
            <span></span>
            <span></span>
            <span></span>
          </span>
          <span>{{ voiceDuration(message.content) }}</span>
        </div>
      </div>

      <p class="message-row__meta">
        <span>{{ sentTime(message.sentAt) }}</span>
        <span v-if="message.direction === 'outgoing' && message.status === 'failed'">发送失败</span>
      </p>
    </div>
  </article>
</template>
