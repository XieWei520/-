<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/authStore';

const auth = useAuthStore();
const router = useRouter();

async function logout() {
  auth.logout();
  await router.replace('/login');
}
</script>

<template>
  <main class="page">
    <header class="page-header">
      <h1>我的</h1>
      <p>当前登录用户和 PWA 状态占位</p>
    </header>

    <section class="profile-block" aria-label="用户资料">
      <span class="avatar large-avatar" aria-hidden="true">{{ auth.user?.avatarText ?? '我' }}</span>
      <div class="row-main">
        <strong class="profile-name">{{ auth.user?.name ?? '未登录' }}</strong>
        <span class="row-subtitle">{{ auth.user?.phone ?? '暂无手机号' }}</span>
      </div>
    </section>

    <section class="status-list" aria-label="应用状态">
      <div class="list-row static-row">
        <span class="row-main">
          <span class="row-title">PWA 状态</span>
          <span class="row-subtitle">等待 Task 5 接入安装和缓存状态</span>
        </span>
      </div>
      <div class="list-row static-row">
        <span class="row-main">
          <span class="row-title">通知状态</span>
          <span class="row-subtitle">等待 Task 5 接入通知权限检测</span>
        </span>
      </div>
    </section>

    <button class="secondary-button" type="button" @click="logout">退出登录</button>
  </main>
</template>
