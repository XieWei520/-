<template>
  <MessageAuditTable :title="title" mode="group" :channel-id="groupNo" />
</template>

<route lang="yaml">
meta:
  title: 聊天记录
  isAffix: false
</route>

<script lang="ts" setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import MessageAuditTable from './components/MessageAuditTable.vue';

const route = useRoute();
const groupNo = computed(() => route.query.groupNo as string);
const title = computed(() => `${route.query.name || ''} 的聊天记录`);
</script>
