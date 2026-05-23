<template>
  <MessageAuditTable :title="title" mode="personal" :uid="uid" :touid="touid" />
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
const uid = computed(() => route.query.uid as string);
const touid = computed(() => route.query.touid as string);
const title = computed(() => `${route.query.name || ''} 和 ${route.query.toname || ''} 聊天记录`);
</script>
