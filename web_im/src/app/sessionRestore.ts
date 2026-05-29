import type { Router } from 'vue-router';
import type { Pinia } from 'pinia';
import { fetchCurrentUser } from '../api/authApi';
import { isLiveMode, runtimeConfig } from '../config/runtimeConfig';
import { useAuthStore } from '../stores/authStore';

export async function restoreLiveSessionOnStartup(pinia: Pinia, router: Router): Promise<void> {
  if (!isLiveMode(runtimeConfig)) {
    return;
  }

  const auth = useAuthStore(pinia);
  await auth.restoreSession(async (snapshot) =>
    fetchCurrentUser({
      uid: snapshot.uid,
      token: snapshot.token,
      config: runtimeConfig,
    }),
  );

  if (!auth.isLoggedIn && router.currentRoute.value.path !== '/login') {
    await router.replace('/login');
  }
}
