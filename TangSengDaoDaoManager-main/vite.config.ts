import { defineConfig, ConfigEnv, UserConfig } from 'vite';
import { resolve } from 'path';
import VueDevTools from 'vite-plugin-vue-devtools';
import vue from '@vitejs/plugin-vue';
import vueJsx from '@vitejs/plugin-vue-jsx';
import unocss from '@unocss/vite';
import { createHtmlPlugin } from 'vite-plugin-html';
import AutoImport from 'unplugin-auto-import/vite';
import Components from 'unplugin-vue-components/vite';
import setupExtend from 'unplugin-vue-setup-extend-plus/vite';
import Layouts from 'vite-plugin-vue-meta-layouts';
import Pages from 'vite-plugin-pages';
import compression from 'vite-plugin-compression';

const normalizeBasePath = (basePath?: string) => {
  const value = (basePath || '/admin/').trim();
  if (!value || value === '/') {
    return '/';
  }
  return `/${value.replace(/^\/+|\/+$/g, '')}/`;
};

const getAdminBasePath = () => normalizeBasePath(process.env.APP_BASE_PATH);

const getPlugins = (_command?: string) => {
  const adminBasePath = getAdminBasePath();
  return [
    AutoImport({
      include: [/\.[tj]sx?$/, /\.vue\?vue/, /\.md$/],
      imports: ['vue', 'vue-router', 'pinia'],
      resolvers: [],
      dts: 'src/types/auto-imports.d.ts'
    }),
    Components({
      include: [/\.vue$/, /\.vue\?vue/, /\.md$/],
      resolvers: [],
      dts: 'src/types/components.d.ts'
    }),
    VueDevTools(),
    vue({
      template: {}
    }),
    vueJsx(),
    createHtmlPlugin({
      inject: {
        data: {
          title: 'TangSengDaoDao Admin',
          injectScript: process.env.IS_CONFIG ? `<script src="${adminBasePath}tsdd-config.js"></script>` : null
        }
      }
    }),
    unocss(),
    setupExtend({}),
    Layouts({
      defaultLayout: 'index'
    }),
    Pages({
      dirs: 'src/pages',
      exclude: ['**/components/*.vue']
    }),
    compression({
      ext: '.gz',
      deleteOriginFile: false
    })
  ];
};

export default defineConfig(({ command }: ConfigEnv): UserConfig => {
  return {
    base: getAdminBasePath(),
    resolve: {
      alias: {
        '@': resolve(__dirname, 'src'),
        'vue-i18n': 'vue-i18n/dist/vue-i18n.cjs.js'
      }
    },
    define: {
      'process.env': {
        APP_ENV: process.env.APP_ENV
      }
    },
    plugins: getPlugins(command),
    css: {
      postcss: {
        plugins: [
          {
            postcssPlugin: 'internal:charset-removal',
            AtRule: {
              charset: atRule => {
                if (atRule.name === 'charset') {
                  atRule.remove();
                }
              }
            }
          }
        ]
      },
      preprocessorOptions: {
        scss: {
          additionalData: `@import "@/styles/var.scss";`
        }
      }
    },
    server: {
      host: '0.0.0.0',
      proxy: {
        '/api': {
          target: process.env.API_PROXY_TARGET || 'https://api.botgate.cn',
          changeOrigin: true,
          secure: false
        }
      }
    },
    build: {
      cssCodeSplit: false,
      sourcemap: false,
      emptyOutDir: true,
      chunkSizeWarningLimit: 1500,
      rollupOptions: {
        output: {
          chunkFileNames: 'static/js/[name]-[hash].js',
          entryFileNames: 'static/js/[name]-[hash].js',
          assetFileNames: 'static/[ext]/[name]-[hash].[ext]',
          manualChunks: {
            vue: ['vue', 'vue-router', 'pinia', 'vue-i18n'],
            'element-plus': ['element-plus'],
            'element-icons': ['@element-plus/icons-vue'],
            fancybox: ['@fancyapps/ui']
          }
        }
      }
    }
  };
});
