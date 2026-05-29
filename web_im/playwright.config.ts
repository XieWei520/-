import { defineConfig, devices } from '@playwright/test';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const isLiveE2E = process.env.WK_WEB_IM_E2E_LIVE === '1';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  use: {
    baseURL: 'http://127.0.0.1:5174/im/',
    trace: 'retain-on-failure',
  },
  webServer: {
    command: isLiveE2E ? 'pnpm exec vite --mode live --host 0.0.0.0' : 'pnpm dev',
    cwd: __dirname,
    url: 'http://127.0.0.1:5174/im/',
    reuseExistingServer: !process.env.CI && !isLiveE2E,
    timeout: 60_000,
  },
  projects: [
    {
      name: 'ios-pwa-size',
      use: {
        ...devices['iPhone 14'],
      },
    },
    {
      name: 'desktop-chromium',
      use: {
        ...devices['Desktop Chrome'],
      },
    },
  ],
});
