import { expect, type Page, test } from '@playwright/test';

async function login(page: Page) {
  await page.goto('/');
  await page.evaluate(() => window.localStorage.clear());
  await page.reload();

  await expect(page.getByRole('heading', { name: '登录' })).toBeVisible();
  await page.getByLabel('手机号').fill('13800000000');
  await page.getByLabel('密码').fill('123456');
  await page.getByRole('button', { name: '登录' }).click();
}

test('login opens mobile conversation workspace and chat route', async ({ page }) => {
  await login(page);

  await expect(page.getByRole('heading', { name: '会话' })).toBeVisible();
  await page.getByRole('button', { name: /产品交付群/ }).click();
  await expect(page.getByRole('heading', { name: '产品交付群' })).toBeVisible();
  await expect(page.getByRole('textbox', { name: '输入消息' })).toBeVisible();
});

test('chat can send a fake text message', async ({ page }) => {
  await login(page);

  await page.getByRole('button', { name: /产品交付群/ }).click();
  await page.getByRole('textbox', { name: '输入消息' }).fill('这是一条 PWA 测试消息');
  await page.getByRole('button', { name: '发送' }).click();

  await expect(page.getByText('这是一条 PWA 测试消息')).toBeVisible();
});
