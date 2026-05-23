import axios, { AxiosError, AxiosInstance, AxiosResponse, InternalAxiosRequestConfig } from 'axios';
import { ElMessage } from 'element-plus';
import { BU_DOU_CONFIG, LOGIN_URL } from '@/config';
import { useUserStore } from '@/stores/modules/user';
import router from '@/router';

export interface AdminApiError {
  status: number;
  code?: number | string;
  msg: string;
  data?: unknown;
  raw?: unknown;
}

const normalizeRequestUrl = (url?: string) => {
  if (!url || /^https?:\/\//i.test(url)) {
    return url;
  }
  return `/${url.replace(/^\/+/, '')}`;
};

const toAdminApiError = (error: AxiosError<any>): AdminApiError => {
  const status = error.response?.status || 0;
  const responseData = error.response?.data;
  const message = responseData?.msg || responseData?.message || responseData?.error || error.message || 'Request failed';

  return {
    status,
    code: responseData?.code,
    msg: message,
    data: responseData,
    raw: error
  };
};

const resetLoginState = () => {
  const userStore = useUserStore();
  userStore.setToken('');
  userStore.setUserInfo({ name: 'Admin', uid: '' });
};

const axiosInstance: AxiosInstance = axios.create({
  baseURL: BU_DOU_CONFIG.APP_URL,
  withCredentials: false
});

axiosInstance.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const userStore = useUserStore();
    config.url = normalizeRequestUrl(config.url);
    if (userStore.token) {
      config.headers.set('token', userStore.token);
    }
    return config;
  },
  (error: AxiosError) => Promise.reject(toAdminApiError(error))
);

axiosInstance.interceptors.response.use(
  (response: AxiosResponse) => Promise.resolve(response.data),
  (error: AxiosError<any>) => {
    const adminError = toAdminApiError(error);

    if (adminError.status === 401) {
      resetLoginState();
      if (router.currentRoute.value.path !== LOGIN_URL) {
        router.replace(LOGIN_URL);
      }
      ElMessage.error('Login expired. Please sign in again.');
      return Promise.reject(adminError);
    }

    if (adminError.status === 403) {
      ElMessage.error(adminError.msg || 'Permission denied.');
      return Promise.reject(adminError);
    }

    if (adminError.status >= 500 || adminError.status === 0) {
      ElMessage.error(adminError.msg || 'Service unavailable.');
      return Promise.reject(adminError);
    }

    return Promise.reject(adminError);
  }
);

export default axiosInstance;
