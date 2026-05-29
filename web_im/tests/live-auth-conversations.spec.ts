import { expect, test } from '@playwright/test';

test.skip(process.env.WK_WEB_IM_E2E_LIVE !== '1', 'live-mode coverage runs with WK_WEB_IM_E2E_LIVE=1');

test('live auth loads backend conversation sync results', async ({ page }) => {
  await page.route('**/v1/user/login', async (route) => {
    const request = route.request();
    expect(request.headers().appid).toBe('wukongchat');
    const body = request.postDataJSON() as {
      username?: string;
      password?: string;
      flag?: number;
    };

    expect(body).toEqual(expect.objectContaining({
      username: '008613800000000',
      password: '123456',
      flag: 5,
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
  });

  await page.route('**/v1/users/u-live', async (route) => {
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
  });

  await page.route('**/v1/conversation/sync', async (route) => {
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
  });

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
