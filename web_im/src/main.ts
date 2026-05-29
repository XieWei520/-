import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import { installPwaLifecycle } from './app/pwaLifecycle';
import { router } from './app/router';
import { installViewportHeightVariable } from './app/safeArea';
import { usePwaStore } from './stores/pwaStore';
import './styles/base.css';

installViewportHeightVariable();

const app = createApp(App);
const pinia = createPinia();

app.use(pinia);
app.use(router);
app.mount('#app');

const pwa = usePwaStore(pinia);

installPwaLifecycle({
  onVisible: pwa.syncOnlineState,
  onHidden: pwa.syncOnlineState,
  onOnline: pwa.syncOnlineState,
  onOffline: pwa.syncOnlineState,
});

void pwa.registerServiceWorker();
