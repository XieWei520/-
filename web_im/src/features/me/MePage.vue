<script setup lang="ts">
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/authStore';
import { usePwaStore } from '../../stores/pwaStore';

const auth = useAuthStore();
const pwa = usePwaStore();
const router = useRouter();

function notificationPermissionText(permission: string): string {
  const labels: Record<string, string> = {
    default: '未询问',
    denied: '已拒绝',
    granted: '已允许',
    unsupported: '当前浏览器不支持',
  };

  return labels[permission] ?? permission;
}

async function logout() {
  auth.logout();
  await router.replace('/login');
}
</script>

<template>
  <main class="page">
    <header class="page-header">
      <h1>我的</h1>
      <p>查看当前登录用户和 iOS PWA 运行状态</p>
    </header>

    <section class="profile-block" aria-label="用户资料">
      <span class="avatar large-avatar" aria-hidden="true">{{ auth.user?.avatarText ?? '我' }}</span>
      <div class="row-main">
        <strong class="profile-name">{{ auth.user?.name ?? '未登录' }}</strong>
        <span class="row-subtitle">{{ auth.user?.phone || auth.user?.uid || '暂无手机号' }}</span>
        <span v-if="auth.user?.uid" class="row-subtitle">UID: {{ auth.user.uid }}</span>
      </div>
    </section>

    <section class="status-list" aria-label="应用状态">
      <div class="list-row static-row">
        <span class="row-main">
          <span class="row-title">主屏幕模式</span>
          <span class="row-subtitle">{{ pwa.standalone ? '已从主屏幕打开' : '浏览器标签页中运行' }}</span>
        </span>
      </div>
      <div class="list-row static-row">
        <span class="row-main">
          <span class="row-title">网络状态</span>
          <span class="row-subtitle">{{ pwa.online ? '在线' : '离线' }}</span>
        </span>
      </div>
      <div class="list-row static-row">
        <span class="row-main">
          <span class="row-title">离线缓存</span>
          <span class="row-subtitle">{{ pwa.serviceWorkerReady ? 'Service Worker 已就绪' : 'Service Worker 未就绪' }}</span>
        </span>
      </div>
      <div class="list-row static-row">
        <span class="row-main">
          <span class="row-title">通知权限</span>
          <span class="row-subtitle">{{ notificationPermissionText(pwa.notificationPermission) }}</span>
        </span>
      </div>
    </section>

    <button class="secondary-button" type="button" @click="logout">退出登录</button>
  </main>
</template>
