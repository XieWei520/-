const normalizeBasePath = (basePath?: string) => {
  const value = (basePath || '/admin/').trim();
  if (!value || value === '/') {
    return '/';
  }
  return `/${value.replace(/^\/+|\/+$/g, '')}/`;
};

export const normalizeApiBaseUrl = (baseUrl?: string) => {
  const value = (baseUrl || '/api/v1/').trim();
  if (!value) {
    return '/api/v1/';
  }
  if (/^https?:\/\//i.test(value)) {
    return value.endsWith('/') ? value : `${value}/`;
  }
  return `/${value.replace(/^\/+|\/+$/g, '')}/`;
};

export const APP_BASE_PATH = normalizeBasePath(import.meta.env.BASE_URL);

export const HOME_URL = '/home';

export const LOGIN_URL = '/login';

export const DEFAULT_PRIMARY = '#E4633B';

export const ROUTER_WHITE_LIST: string[] = [LOGIN_URL];

const modules: Record<string, any> = {};
const moduleFiles = import.meta.glob('./modules/*.ts', { import: 'default', eager: true });

Object.keys(moduleFiles).forEach(name => {
  const key = name.replace('./modules/', '').replace('.ts', '').trim();
  modules[key] = moduleFiles[name];
});

type AdminRuntimeConfig = Partial<{
  APP_ENV: string;
  APP_TITLE: string;
  APP_TITLE_SHORT: string;
  APP_URL: string;
}>;

const runtimeConfig: AdminRuntimeConfig = window.TSDD_CONFIG ? window.TSDD_CONFIG : {};
const envConfig: AdminRuntimeConfig = modules[process.env.APP_ENV as any] || {};

export const BU_DOU_CONFIG = {
  APP_TITLE: 'TangSengDaoDao Admin',
  APP_TITLE_SHORT: 'Admin',
  ...envConfig,
  ...runtimeConfig,
  APP_BASE_PATH,
  APP_URL: normalizeApiBaseUrl(runtimeConfig.APP_URL || envConfig.APP_URL)
};
