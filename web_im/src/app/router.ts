import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router';
import { useAuthStore } from '../stores/authStore';
import LoginPage from '../features/login/LoginPage.vue';
import MobileShell from '../features/shell/MobileShell.vue';
import ConversationListPage from '../features/conversations/ConversationListPage.vue';
import ContactsPage from '../features/contacts/ContactsPage.vue';
import MePage from '../features/me/MePage.vue';
import ChatPage from '../features/chat/ChatPage.vue';

export const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: LoginPage,
  },
  {
    path: '/',
    name: 'home',
    redirect: '/conversations',
  },
  {
    path: '/conversations',
    name: 'conversations',
    component: MobileShell,
    children: [
      {
        path: '',
        name: 'conversation-list',
        component: ConversationListPage,
      },
    ],
  },
  {
    path: '/contacts',
    name: 'contacts',
    component: MobileShell,
    children: [
      {
        path: '',
        name: 'contact-list',
        component: ContactsPage,
      },
    ],
  },
  {
    path: '/me',
    name: 'me',
    component: MobileShell,
    children: [
      {
        path: '',
        name: 'me-page',
        component: MePage,
      },
    ],
  },
  {
    path: '/chat/:channelType/:channelId',
    name: 'chat',
    component: MobileShell,
    children: [
      {
        path: '',
        name: 'chat-page',
        component: ChatPage,
      },
    ],
  },
];

export const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
});

router.beforeEach((to) => {
  const auth = useAuthStore();

  if (to.path === '/login' && auth.isLoggedIn) {
    return '/conversations';
  }

  if (to.path !== '/login' && !auth.isLoggedIn) {
    return '/login';
  }

  return true;
});
