<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from 'vue';
import MessageBubble from './MessageBubble.vue';
import { computeVirtualWindow, preservePrependAnchor } from './virtualList';
import type { ChatMessage } from '../../models/im';

const ROW_HEIGHT = 72;
const OVERSCAN = 6;

const props = defineProps<{
  messages: ChatMessage[];
}>();

const emit = defineEmits<{
  loadOlder: [];
}>();

const scroller = ref<HTMLElement | null>(null);
const scrollTop = ref(0);
const viewportHeight = ref(0);

const virtualWindow = computed(() =>
  computeVirtualWindow({
    itemCount: props.messages.length,
    rowHeight: ROW_HEIGHT,
    scrollTop: scrollTop.value,
    viewportHeight: viewportHeight.value,
    overscan: OVERSCAN,
  }),
);

const visibleMessages = computed(() => props.messages.slice(virtualWindow.value.start, virtualWindow.value.end));

function syncViewport() {
  const element = scroller.value;

  if (!element) {
    return;
  }

  scrollTop.value = element.scrollTop;
  viewportHeight.value = element.clientHeight;
}

function onScroll() {
  syncViewport();
}

function isNearBottom(element: HTMLElement): boolean {
  return element.scrollHeight - element.scrollTop - element.clientHeight < ROW_HEIGHT * 2;
}

async function loadOlder() {
  const element = scroller.value;
  const previousScrollTop = element?.scrollTop ?? 0;
  const previousLength = props.messages.length;

  emit('loadOlder');
  await nextTick();

  const insertedCount = Math.max(0, props.messages.length - previousLength);
  const nextScrollTop = preservePrependAnchor({
    previousScrollTop,
    insertedCount,
    rowHeight: ROW_HEIGHT,
  });

  if (element) {
    element.scrollTop = nextScrollTop;
    syncViewport();
  }
}

watch(
  () => props.messages.length,
  async (nextLength, previousLength) => {
    const element = scroller.value;
    const shouldStickToBottom = element ? previousLength === 0 || isNearBottom(element) : false;

    await nextTick();
    syncViewport();

    if (shouldStickToBottom && nextLength > previousLength && element) {
      element.scrollTop = element.scrollHeight;
      syncViewport();
    }
  },
);

onMounted(() => {
  syncViewport();

  if (scroller.value) {
    scroller.value.scrollTop = scroller.value.scrollHeight;
    syncViewport();
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('resize', syncViewport);
  }
});

onUnmounted(() => {
  if (typeof window !== 'undefined') {
    window.removeEventListener('resize', syncViewport);
  }
});
</script>

<template>
  <div ref="scroller" class="virtual-message-list" role="log" aria-live="polite" @scroll="onScroll">
    <div v-if="messages.length === 0" class="chat-empty-state" role="status">
      <p class="chat-empty-state__title">暂无消息</p>
      <p class="chat-empty-state__text">发送第一条消息后，这里会显示本地假数据会话。</p>
    </div>

    <template v-else>
      <div class="virtual-message-list__load">
        <button class="older-button" type="button" @click="loadOlder">加载更早消息</button>
      </div>
      <div :style="{ height: `${virtualWindow.beforeHeight}px` }" aria-hidden="true"></div>
      <MessageBubble v-for="message in visibleMessages" :key="message.id" :message="message" />
      <div :style="{ height: `${virtualWindow.afterHeight}px` }" aria-hidden="true"></div>
    </template>
  </div>
</template>
