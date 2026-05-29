import { defineConfig, devices } from '@playwright/test';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  use: {
    baseURL: 'http://127.0.0.1:5174/im/',
    trace: 'retain-on-failure',
  },
  webServer: {
    command: 'pnpm dev',
    cwd: __dirname,
    url: 'http://127.0.0.1:5174/im/',
    reuseExistingServer: !process.env.CI,
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
