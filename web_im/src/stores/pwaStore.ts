import { ref } from 'vue';
import { defineStore } from 'pinia';
import { isStandalonePwa } from '../app/pwaLifecycle';

type NotificationPermissionState = NotificationPermission | 'unsupported';

function currentOnlineState(): boolean {
  if (typeof navigator === 'undefined' || typeof navigator.onLine !== 'boolean') {
    return true;
  }

  return navigator.onLine;
}

function currentNotificationPermission(): NotificationPermissionState {
  if (typeof Notification === 'undefined') {
    return 'unsupported';
  }

  return Notification.permission;
}

export const usePwaStore = defineStore('pwa', () => {
  const standalone = ref(false);
  const online = ref(true);
  const serviceWorkerReady = ref(false);
  const notificationPermission = ref<NotificationPermissionState>('unsupported');

  function syncOnlineState(): void {
    standalone.value = isStandalonePwa();
    online.value = currentOnlineState();
    notificationPermission.value = currentNotificationPermission();
  }

  async function registerServiceWorker(): Promise<void> {
    if (typeof navigator === 'undefined' || !('serviceWorker' in navigator)) {
      serviceWorkerReady.value = false;
      return;
    }

    try {
      await navigator.serviceWorker.register('/im/sw.js', { scope: '/im/' });
      await navigator.serviceWorker.ready;
      serviceWorkerReady.value = true;
    } catch {
      serviceWorkerReady.value = false;
    } finally {
      syncOnlineState();
    }
  }

  syncOnlineState();

  return {
    standalone,
    online,
    serviceWorkerReady,
    notificationPermission,
    registerServiceWorker,
    syncOnlineState,
  };
});
