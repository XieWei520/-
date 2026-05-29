<script setup lang="ts">
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/authStore';

type LoginField = 'phone' | 'password' | null;

const auth = useAuthStore();
const router = useRouter();

const phone = ref('13800138000');
const password = ref('1234');
const errorMessage = ref('');
const errorField = ref<LoginField>(null);
const isSubmitting = ref(false);

const errorId = 'login-error';
const phoneHasError = computed(() => errorField.value === 'phone');
const passwordHasError = computed(() => errorField.value === 'password');

function fieldFromError(error: unknown): LoginField {
  const message = error instanceof Error ? error.message : '';

  if (message.includes('手机号')) {
    return 'phone';
  }

  if (message.includes('密码')) {
    return 'password';
  }

  return null;
}

async function submitLogin() {
  errorMessage.value = '';
  errorField.value = null;
  isSubmitting.value = true;

  try {
    auth.login(phone.value, password.value);
    await router.replace('/conversations');
  } catch (error) {
    errorMessage.value = error instanceof Error ? error.message : '登录失败，请稍后重试';
    errorField.value = fieldFromError(error);
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
        required
        pattern="^1\d{10}$"
        maxlength="11"
        :aria-invalid="phoneHasError ? 'true' : 'false'"
        :aria-describedby="phoneHasError && errorMessage ? errorId : undefined"
      >

      <label class="field-label" for="password">密码</label>
      <input
        id="password"
        v-model="password"
        class="text-input"
        type="password"
        autocomplete="current-password"
        placeholder="请输入密码"
        required
        minlength="4"
        :aria-invalid="passwordHasError ? 'true' : 'false'"
        :aria-describedby="passwordHasError && errorMessage ? errorId : undefined"
      >

      <p v-if="errorMessage" :id="errorId" class="form-error" role="alert">
        {{ errorMessage }}
      </p>

      <button class="primary-button" type="submit" :disabled="isSubmitting">
        {{ isSubmitting ? '登录中' : '登录' }}
      </button>
    </form>
  </main>
</template>
