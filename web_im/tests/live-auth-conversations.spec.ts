import { expect, test, type BrowserContext } from '@playwright/test';

test.skip(process.env.WK_WEB_IM_E2E_LIVE !== '1', 'live-mode coverage runs with WK_WEB_IM_E2E_LIVE=1');
test.use({ serviceWorkers: 'block' });

async function installBackendMocks(context: BrowserContext) {
  await context.route('**/*', async (route) => {
    const request = route.request();
    const url = new URL(request.url());

    if (url.hostname !== 'infoequity.cn') {
      await route.continue();
      return;
    }

    if (url.pathname === '/v1/user/login') {
      expect(request.headers().appid).toBe('wukongchat');
      const body = request.postDataJSON() as {
        username?: string;
        password?: string;
        flag?: number;
      };

      expect(body).toEqual(expect.objectContaining({
        username: '008613800000000',
        password: '123456',
        flag: 1,
      }));

      await route.fulfill({
        contentType: 'application/json',
        body: JSON.stringify({
          code: 0,
          data: {
            uid: 'u-live',
            token: 'token-live',
            im_token: 'im-live',
            name: '真实用户',
          },
        }),
      });
      return;
    }

    if (url.pathname === '/v1/users/u-live') {
      await route.fulfill({
        contentType: 'application/json',
        body: JSON.stringify({
          code: 0,
          data: {
            uid: 'u-live',
            name: '真实用户',
            phone: '13800000000',
          },
        }),
      });
      return;
    }

    if (url.pathname === '/v1/conversation/sync') {
      await route.fulfill({
        contentType: 'application/json',
        body: JSON.stringify({
          code: 0,
          data: {
            conversations: [
              {
                channel_id: 'u-customer-live',
                channel_type: 1,
                unread: 2,
                timestamp: 1717000000,
                recents: [
                  {
                    message_seq: 9,
                    timestamp: 1717000001,
                    payload: {
                      type: 1,
                      content: '真实会话消息',
                    },
                  },
                ],
              },
            ],
          },
        }),
      });
      return;
    }

    await route.fulfill({
      status: 500,
      contentType: 'application/json',
      body: JSON.stringify({
        code: 500,
        message: `Unexpected live E2E backend request: ${request.method()} ${url.pathname}`,
      }),
    });
    throw new Error(`Unexpected live E2E backend request: ${request.method()} ${request.url()}`);
  });
}

test.beforeEach(async ({ context }) => {
  await installBackendMocks(context);
});

test('live auth loads backend conversation sync results', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => window.localStorage.clear());
  await page.reload();

  await page.locator('#phone').fill('13800000000');
  await page.locator('#password').fill('123456');
  await page.locator('button[type="submit"]').click();

  await expect(page).toHaveURL(/\/im\/conversations$/);
  await expect(page.getByText('真实会话消息')).toBeVisible();
  await expect(page.getByText('u-customer-live')).toBeVisible();
});
