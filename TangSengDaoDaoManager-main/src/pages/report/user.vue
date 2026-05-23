<template>
  <ReportModeration title="举报用户" channel-type="1" target-kind="user" />
</template>

<route lang="yaml">
meta:
  title: 举报用户
  isAffix: false
</route>

<script lang="ts" setup>
import ReportModeration from './components/ReportModeration.vue';
</script>
