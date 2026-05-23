<template>
  <ReportModeration title="举报群聊" channel-type="2" target-kind="group" />
</template>

<route lang="yaml">
meta:
  title: 举报群聊
  isAffix: false
</route>

<script lang="ts" setup>
import ReportModeration from './components/ReportModeration.vue';
</script>
