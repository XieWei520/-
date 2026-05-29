<script setup lang="ts">
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/authStore';

const auth = useAuthStore();
const router = useRouter();

const phone = ref('13800138000');
const password = ref('1234');
const errorMessage = ref('');
const isSubmitting = ref(false);

async function submitLogin() {
  errorMessage.value = '';
  isSubmitting.value = true;

  try {
    auth.login(phone.value, password.value);
    await router.replace('/conversations');
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : '登录失败，请稍后重试';
  } finally {
    isSubmitting.value = false;
  }
}
</script>

<template>
  <main class="login-page">
    <form class="login-panel" aria-labelledby="login-title" @submit.prevent="submitLogin">
      <p class="eyebrow">WuKong IM</p>
      <h1 id="login-title">登录</h1>

      <label class="field-label" for="phone">手机号</label>
      <input
        id="phone"
        v-model="phone"
        class="text-input"
        inputmode="tel"
        autocomplete="tel"
        placeholder="请输入手机号"
      >

      <label class="field-label" for="password">密码</label>
      <input
        id="password"
        v-model="password"
        class="text-input"
        type="password"
        autocomplete="current-password"
        placeholder="请输入密码"
      >

      <p v-if="errorMessage" class="form-error" role="alert">{{ errorMessage }}</p>

      <button class="primary-button" type="submit" :disabled="isSubmitting">
        {{ isSubmitting ? '登录中' : '登录' }}
      </button>
    </form>
  </main>
</template>
