# DingTalk Custom Group Robot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a DingTalk custom robot compatibility path so group admins can generate a webhook and secret, then receive DingTalk-style group robot messages inside WuKongIM groups.

**Architecture:** Keep the DingTalk flow parallel to the existing Feishu group robot flow. Implement the backend receiver and config storage first, then add the Flutter group-detail entry, API client, model, and settings page on top of the backend contract.

**Tech Stack:** Go, Gin, existing `modules/robot` backend module, Flutter, Dio, flutter_test

---

## File Structure

### Backend files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_db.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot_test.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\sql\robot-20260422-01.sql`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\api.go`

### Flutter files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_dingtalk_robot_config.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_dingtalk_bot_page.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_dingtalk_bot_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\group_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_detail_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_detail_page_parity_test.dart`

## Verification Commands

- `go test ./modules/robot -run DingTalk`
- `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`
- `flutter test test/wukong_uikit/group/group_detail_page_parity_test.dart`

## Task 1: Lock Backend Contract With Failing Tests

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot_test.go`

- [ ] Write tests for:
  - webhook URL generation from a base URL
  - token extraction from either raw token or full webhook URL
  - signature generation and validation
  - message text resolution for `text`, `markdown`, `link`, `actionCard`, and `feedCard`
- [ ] Run `go test ./modules/robot -run DingTalk`
- [ ] Confirm the package fails because DingTalk helpers do not exist yet

## Task 2: Implement Backend Storage And Routes

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_db.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\sql\robot-20260422-01.sql`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\api.go`

- [ ] Add a new `robot_dingtalk_group` table migration
- [ ] Add DB helpers to query, insert, update, delete, and update push state
- [ ] Register:
  - `GET /v1/groups/:group_no/robot/dingtalk`
  - `PUT /v1/groups/:group_no/robot/dingtalk`
  - `DELETE /v1/groups/:group_no/robot/dingtalk`
  - `POST /v1/groups/:group_no/robot/dingtalk/test`
  - `POST /v1/groups/:group_no/robot/dingtalk/webhook/:token`
- [ ] Re-run `go test ./modules/robot -run DingTalk`
- [ ] Confirm failures move from missing symbols to behavior mismatches

## Task 3: Implement Backend Webhook Parsing And IM Delivery

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`

- [ ] Implement config response and CRUD handlers parallel to the Feishu handlers
- [ ] Implement token generation, webhook URL generation, and token extraction helpers
- [ ] Implement DingTalk signature validation using `timestamp` and `sign`
- [ ] Implement payload decoding and text-first compatibility mapping
- [ ] Implement local test-message delivery into the IM group
- [ ] Re-run `go test ./modules/robot -run DingTalk`
- [ ] Confirm the DingTalk backend tests pass

## Task 4: Lock Flutter UI And API With Failing Tests

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_dingtalk_bot_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_detail_page_parity_test.dart`

- [ ] Add a parity test asserting `钉钉机器人` appears in the Android row order when the user can manage the group
- [ ] Add a widget test asserting the new DingTalk bot page renders readable labels and loads mocked config data
- [ ] Run:
  - `flutter test test/wukong_uikit/group/group_detail_page_parity_test.dart`
  - `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`
- [ ] Confirm the tests fail because the DingTalk page and row do not exist yet

## Task 5: Implement Flutter Model, API, And Page

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_dingtalk_robot_config.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_dingtalk_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\group_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_detail_page.dart`

- [ ] Add the DingTalk config model
- [ ] Add GroupApi methods for get, update, delete, and test
- [ ] Build the DingTalk page by reusing the Feishu page interaction pattern and adapting labels and fields
- [ ] Add the new group-detail entry and page navigation
- [ ] Re-run:
  - `flutter test test/wukong_uikit/group/group_detail_page_parity_test.dart`
  - `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`
- [ ] Confirm the targeted Flutter tests pass

## Task 6: Focused Verification And Manual QA Handoff

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\superpowers\artifacts\2026-04-20-interactive-test-session-log-continuation.md`

- [ ] Run the focused backend and Flutter verification commands again
- [ ] If Flutter code changed successfully, rebuild the Windows desktop app
- [ ] Append the session log with the DingTalk design, implementation, verification results, and manual QA entry points
- [ ] Report the exact group-detail path the user should open for live DingTalk testing

## Notes

- This workspace snapshot does not expose a normal `.git` directory, so the plan intentionally omits commit steps.
- Keep the DingTalk implementation separate from Feishu to minimize regression risk during the current interactive QA cycle.
