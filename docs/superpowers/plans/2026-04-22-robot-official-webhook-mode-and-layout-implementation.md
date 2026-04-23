# Robot Official Webhook Mode And Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add dual-mode Feishu and DingTalk robot settings pages that support `IM 接收 Webhook` and `官方 Webhook`, persist official webhook credentials with provider-domain validation, and align the shared avatar upload/clear actions.

**Architecture:** Keep the existing WuKongIM-generated inbound webhook behavior unchanged, then layer an additive `webhook_mode` plus official credential fields onto the same Feishu and DingTalk config records. On Flutter, extend the config models and `GroupApi`, add a shared mode helper/section, make each robot page mode-aware, and keep the IM-only display identity section visible in both modes. The official mode is configuration-only and must not imply inbound synchronization back into IM groups.

**Tech Stack:** Flutter, flutter_test, Dio, Go 1.20, sql-migrate SQL files, WuKongIM Flutter SDK

---

## Workspace Reality

- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` is not a git repository on this machine.
- `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main` is not a git repository on this machine.
- Replace commit steps with explicit verification checkpoints. If these paths later become git worktrees, commit after each task using the checkpoint summaries from this plan.

## File Structure

## Backend Files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\sql\robot-20260422-03.sql`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_webhook_mode.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_webhook_mode_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_db.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_db.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot_test.go`

## Flutter Files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_webhook_mode.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_webhook_mode_section.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_robot_identity_section_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_feishu_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_dingtalk_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\group_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_identity_section.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_feishu_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_dingtalk_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\group_robot_config_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_feishu_bot_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_dingtalk_bot_page_test.dart`

## Verification Commands

- Backend focused tests:
  - `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestNormalizeGroupRobotWebhookMode|TestValidateFeishuOfficialWebhookURL|TestValidateDingTalkOfficialWebhookURL|TestNewFeishuGroupRobotRespIncludesWebhookModeFields|TestNewDingTalkGroupRobotRespIncludesWebhookModeFields' -count=1`
- Flutter focused tests:
  - `flutter test test/data/models/group_robot_config_test.dart`
  - `flutter test test/wukong_uikit/group/group_robot_identity_section_test.dart`
  - `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`
  - `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`
- Windows smoke launch:
  - `flutter run -d windows --no-resident`

### Task 1: Add Backend Webhook-Mode Persistence And Official-Domain Validation Helpers

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\sql\robot-20260422-03.sql`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_webhook_mode.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_webhook_mode_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_db.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_db.go`

- [ ] **Step 1: Write the failing backend tests for webhook mode normalization and official-host validation**

```go
package robot

import "testing"

func TestNormalizeGroupRobotWebhookMode(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{name: "empty defaults to im_generated", input: "", want: groupRobotWebhookModeIMGenerated},
		{name: "official preserved", input: "official", want: groupRobotWebhookModeOfficial},
		{name: "unknown falls back", input: "unexpected", want: groupRobotWebhookModeIMGenerated},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := normalizeGroupRobotWebhookMode(tc.input)
			if got != tc.want {
				t.Fatalf("normalizeGroupRobotWebhookMode(%q) = %q, want %q", tc.input, got, tc.want)
			}
		})
	}
}

func TestValidateFeishuOfficialWebhookURL(t *testing.T) {
	valid := "https://open.feishu.cn/open-apis/bot/v2/hook/demo"
	if err := validateFeishuOfficialWebhookURL(valid); err != nil {
		t.Fatalf("expected valid feishu webhook, got error: %v", err)
	}

	invalid := "https://example.com/open-apis/bot/v2/hook/demo"
	if err := validateFeishuOfficialWebhookURL(invalid); err == nil {
		t.Fatal("expected invalid feishu webhook host error")
	}
}

func TestValidateDingTalkOfficialWebhookURL(t *testing.T) {
	validHosts := []string{
		"https://oapi.dingtalk.com/robot/send?access_token=demo",
		"https://api.dingtalk.com/v1.0/robot/oToMessages/batchSend",
	}
	for _, value := range validHosts {
		if err := validateDingTalkOfficialWebhookURL(value); err != nil {
			t.Fatalf("expected valid dingtalk webhook for %q, got %v", value, err)
		}
	}

	invalid := "https://example.com/robot/send?access_token=demo"
	if err := validateDingTalkOfficialWebhookURL(invalid); err == nil {
		t.Fatal("expected invalid dingtalk webhook host error")
	}
}
```

- [ ] **Step 2: Run the backend helper tests to verify they fail first**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestNormalizeGroupRobotWebhookMode|TestValidateFeishuOfficialWebhookURL|TestValidateDingTalkOfficialWebhookURL' -count=1`

Expected: FAIL with undefined webhook-mode constants or validation helpers

- [ ] **Step 3: Add the schema migration and persistence fields**

```sql
-- +migrate Up

ALTER TABLE `robot_feishu_group`
  ADD COLUMN `webhook_mode` varchar(32) NOT NULL DEFAULT 'im_generated' AFTER `app_secret`,
  ADD COLUMN `official_webhook_url` varchar(500) NOT NULL DEFAULT '' AFTER `webhook_mode`,
  ADD COLUMN `official_secret` varchar(255) NOT NULL DEFAULT '' AFTER `official_webhook_url`;

ALTER TABLE `robot_dingtalk_group`
  ADD COLUMN `webhook_mode` varchar(32) NOT NULL DEFAULT 'im_generated' AFTER `secret`,
  ADD COLUMN `official_webhook_url` varchar(500) NOT NULL DEFAULT '' AFTER `webhook_mode`,
  ADD COLUMN `official_secret` varchar(255) NOT NULL DEFAULT '' AFTER `official_webhook_url`;

-- +migrate Down

ALTER TABLE `robot_dingtalk_group`
  DROP COLUMN `official_secret`,
  DROP COLUMN `official_webhook_url`,
  DROP COLUMN `webhook_mode`;

ALTER TABLE `robot_feishu_group`
  DROP COLUMN `official_secret`,
  DROP COLUMN `official_webhook_url`,
  DROP COLUMN `webhook_mode`;
```

```go
type feishuGroupRobotConfig struct {
	GroupNo            string
	WebhookURL         string
	Secret             string
	AppID              string
	AppSecret          string
	WebhookMode        string
	OfficialWebhookURL string
	OfficialSecret     string
	DisplayName        string
	DisplayAvatar      string
	Enabled            int
	CreatedUID         string
	UpdatedUID         string
	LastPushAt         int64
	LastError          string
	db.BaseModel
}
```

```go
type dingTalkGroupRobotConfig struct {
	GroupNo            string
	WebhookURL         string
	Secret             string
	WebhookMode        string
	OfficialWebhookURL string
	OfficialSecret     string
	DisplayName        string
	DisplayAvatar      string
	Enabled            int
	CreatedUID         string
	UpdatedUID         string
	LastPushAt         int64
	LastError          string
	db.BaseModel
}
```

- [ ] **Step 4: Implement shared webhook-mode constants and validators**

```go
package robot

import (
	"errors"
	"net/url"
	"strings"
)

const (
	groupRobotWebhookModeIMGenerated = "im_generated"
	groupRobotWebhookModeOfficial    = "official"
)

func normalizeGroupRobotWebhookMode(raw string) string {
	switch strings.TrimSpace(strings.ToLower(raw)) {
	case groupRobotWebhookModeOfficial:
		return groupRobotWebhookModeOfficial
	default:
		return groupRobotWebhookModeIMGenerated
	}
}

func validateFeishuOfficialWebhookURL(raw string) error {
	return validateOfficialWebhookURL(raw, map[string]struct{}{
		"open.feishu.cn": {},
	}, "invalid feishu official webhook url")
}

func validateDingTalkOfficialWebhookURL(raw string) error {
	return validateOfficialWebhookURL(raw, map[string]struct{}{
		"oapi.dingtalk.com": {},
		"api.dingtalk.com":  {},
	}, "invalid dingtalk official webhook url")
}

func validateOfficialWebhookURL(raw string, allowedHosts map[string]struct{}, message string) error {
	trimmed := strings.TrimSpace(raw)
	if trimmed == "" {
		return errors.New(message)
	}
	parsed, err := url.Parse(trimmed)
	if err != nil || parsed == nil {
		return errors.New(message)
	}
	host := strings.TrimSpace(strings.ToLower(parsed.Hostname()))
	if _, ok := allowedHosts[host]; !ok {
		return errors.New(message)
	}
	if parsed.Scheme != "https" {
		return errors.New(message)
	}
	return nil
}
```

- [ ] **Step 5: Re-run the helper tests and record the checkpoint**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestNormalizeGroupRobotWebhookMode|TestValidateFeishuOfficialWebhookURL|TestValidateDingTalkOfficialWebhookURL' -count=1`

Expected: PASS

### Task 2: Extend Backend Feishu And DingTalk CRUD Contracts With Mode-Aware Official Fields

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot_test.go`

- [ ] **Step 1: Write the failing response and update-shape tests**

```go
func TestNewFeishuGroupRobotRespIncludesWebhookModeFields(t *testing.T) {
	resp := newFeishuGroupRobotResp(&feishuGroupRobotConfig{
		GroupNo:            "g_demo",
		WebhookURL:         "token_demo",
		Secret:             "sec_demo",
		WebhookMode:        groupRobotWebhookModeOfficial,
		OfficialWebhookURL: "https://open.feishu.cn/open-apis/bot/v2/hook/demo",
		OfficialSecret:     "official_secret",
		DisplayName:        "Feishu Robot",
	}, "https://im.example.com/v1/groups/g_demo/robot/feishu/webhook/token_demo")

	if resp.WebhookMode != groupRobotWebhookModeOfficial {
		t.Fatalf("unexpected webhook mode: %s", resp.WebhookMode)
	}
	if resp.OfficialWebhookURL != "https://open.feishu.cn/open-apis/bot/v2/hook/demo" {
		t.Fatalf("unexpected official webhook url: %s", resp.OfficialWebhookURL)
	}
	if resp.OfficialSecret != "official_secret" {
		t.Fatalf("unexpected official secret: %s", resp.OfficialSecret)
	}
}

func TestNewDingTalkGroupRobotRespIncludesWebhookModeFields(t *testing.T) {
	resp := newDingTalkGroupRobotResp(&dingTalkGroupRobotConfig{
		GroupNo:            "g_demo",
		WebhookURL:         "token_demo",
		Secret:             "sec_demo",
		WebhookMode:        groupRobotWebhookModeOfficial,
		OfficialWebhookURL: "https://oapi.dingtalk.com/robot/send?access_token=demo",
		OfficialSecret:     "SECdemo",
		DisplayName:        "DingTalk Robot",
	}, "https://im.example.com/v1/groups/g_demo/robot/dingtalk/webhook/token_demo")

	if resp.WebhookMode != groupRobotWebhookModeOfficial {
		t.Fatalf("unexpected webhook mode: %s", resp.WebhookMode)
	}
	if resp.OfficialWebhookURL != "https://oapi.dingtalk.com/robot/send?access_token=demo" {
		t.Fatalf("unexpected official webhook url: %s", resp.OfficialWebhookURL)
	}
	if resp.OfficialSecret != "SECdemo" {
		t.Fatalf("unexpected official secret: %s", resp.OfficialSecret)
	}
}
```

- [ ] **Step 2: Run the response-contract tests to verify they fail**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestNewFeishuGroupRobotRespIncludesWebhookModeFields|TestNewDingTalkGroupRobotRespIncludesWebhookModeFields' -count=1`

Expected: FAIL with missing response fields

- [ ] **Step 3: Implement mode-aware request/response fields and provider validation**

```go
type feishuGroupRobotResp struct {
	GroupNo            string `json:"group_no"`
	WebhookURL         string `json:"webhook_url"`
	Secret             string `json:"secret"`
	AppID              string `json:"app_id"`
	AppSecret          string `json:"app_secret"`
	WebhookMode        string `json:"webhook_mode"`
	OfficialWebhookURL string `json:"official_webhook_url"`
	OfficialSecret     string `json:"official_secret"`
	DisplayName        string `json:"display_name"`
	DisplayAvatar      string `json:"display_avatar"`
	Enabled            int    `json:"enabled"`
	SecretSet          bool   `json:"secret_set"`
	AppSecretSet       bool   `json:"app_secret_set"`
	LastPushAt         int64  `json:"last_push_at"`
	LastError          string `json:"last_error"`
	UpdatedAt          string `json:"updated_at"`
}
```

```go
type feishuGroupRobotUpsertReq struct {
	Enabled           *int    `json:"enabled"`
	RegenerateWebhook *int    `json:"regenerate_webhook"`
	RegenerateSecret  *int    `json:"regenerate_secret"`
	AppID             *string `json:"app_id"`
	AppSecret         *string `json:"app_secret"`
	WebhookMode       *string `json:"webhook_mode"`
	OfficialWebhookURL *string `json:"official_webhook_url"`
	OfficialSecret    *string `json:"official_secret"`
	DisplayName       *string `json:"display_name"`
	DisplayAvatar     *string `json:"display_avatar"`
}
```

```go
func applyFeishuWebhookModeUpdate(model *feishuGroupRobotConfig, req feishuGroupRobotUpsertReq) error {
	mode := normalizeGroupRobotWebhookMode(stringPointerValue(req.WebhookMode, model.WebhookMode))
	model.WebhookMode = mode

	if req.OfficialWebhookURL != nil {
		model.OfficialWebhookURL = strings.TrimSpace(*req.OfficialWebhookURL)
	}
	if req.OfficialSecret != nil {
		model.OfficialSecret = strings.TrimSpace(*req.OfficialSecret)
	}
	if mode == groupRobotWebhookModeOfficial {
		if err := validateFeishuOfficialWebhookURL(model.OfficialWebhookURL); err != nil {
			return err
		}
	}
	return nil
}
```

```go
func applyDingTalkWebhookModeUpdate(model *dingTalkGroupRobotConfig, req dingTalkGroupRobotUpsertReq) error {
	mode := normalizeGroupRobotWebhookMode(stringPointerValue(req.WebhookMode, model.WebhookMode))
	model.WebhookMode = mode

	if req.OfficialWebhookURL != nil {
		model.OfficialWebhookURL = strings.TrimSpace(*req.OfficialWebhookURL)
	}
	if req.OfficialSecret != nil {
		model.OfficialSecret = strings.TrimSpace(*req.OfficialSecret)
	}
	if mode == groupRobotWebhookModeOfficial {
		if err := validateDingTalkOfficialWebhookURL(model.OfficialWebhookURL); err != nil {
			return err
		}
	}
	return nil
}
```

- [ ] **Step 4: Preserve both mode payloads while keeping IM-generated behavior authoritative in IM mode**

```go
if token == "" || intPointerTrue(req.RegenerateWebhook) {
	token = generateFeishuGroupRobotToken()
}
if secret == "" || intPointerTrue(req.RegenerateSecret) {
	secret = generateFeishuGroupRobotSecret()
}
existing.WebhookURL = token
existing.Secret = secret

if err := applyFeishuWebhookModeUpdate(existing, req); err != nil {
	c.ResponseError(err)
	return
}
```

```go
return &feishuGroupRobotResp{
	GroupNo:            model.GroupNo,
	WebhookURL:         webhookURL,
	Secret:             secret,
	AppID:              strings.TrimSpace(model.AppID),
	AppSecret:          appSecret,
	WebhookMode:        normalizeGroupRobotWebhookMode(model.WebhookMode),
	OfficialWebhookURL: strings.TrimSpace(model.OfficialWebhookURL),
	OfficialSecret:     strings.TrimSpace(model.OfficialSecret),
	DisplayName:        strings.TrimSpace(model.DisplayName),
	DisplayAvatar:      strings.TrimSpace(model.DisplayAvatar),
	Enabled:            model.Enabled,
	SecretSet:          secret != "",
	AppSecretSet:       appSecret != "",
	LastPushAt:         model.LastPushAt,
	LastError:          model.LastError,
	UpdatedAt:          model.UpdatedAt.String(),
}
```

- [ ] **Step 5: Re-run the focused backend robot tests**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestNormalizeGroupRobotWebhookMode|TestValidateFeishuOfficialWebhookURL|TestValidateDingTalkOfficialWebhookURL|TestNewFeishuGroupRobotRespIncludesWebhookModeFields|TestNewDingTalkGroupRobotRespIncludesWebhookModeFields' -count=1`

Expected: PASS

### Task 3: Extend Flutter Models And Group API For Dual-Mode Robot Configs

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_feishu_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_dingtalk_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\group_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\group_robot_config_test.dart`

- [ ] **Step 1: Write the failing Flutter model tests for webhook mode and official fields**

```dart
test('GroupFeishuRobotConfig preserves webhook mode and official fields', () {
  final config = GroupFeishuRobotConfig.fromJson(<String, dynamic>{
    'group_no': 'g_demo',
    'webhook_url': 'https://im.example.com/hook',
    'secret': 'sec_demo',
    'webhook_mode': 'official',
    'official_webhook_url': 'https://open.feishu.cn/open-apis/bot/v2/hook/demo',
    'official_secret': 'official_secret',
    'enabled': 1,
  });

  expect(config.webhookMode, 'official');
  expect(config.officialWebhookUrl, 'https://open.feishu.cn/open-apis/bot/v2/hook/demo');
  expect(config.officialSecret, 'official_secret');
});

test('GroupDingTalkRobotConfig defaults webhook mode to im_generated', () {
  final config = GroupDingTalkRobotConfig.fromJson(<String, dynamic>{
    'group_no': 'g_demo',
    'webhook_url': 'https://im.example.com/hook',
    'secret': 'sec_demo',
    'enabled': 1,
  });

  expect(config.webhookMode, 'im_generated');
});
```

- [ ] **Step 2: Run the model tests to verify they fail**

Run: `flutter test test/data/models/group_robot_config_test.dart`

Expected: FAIL with missing `webhookMode`, `officialWebhookUrl`, or `officialSecret`

- [ ] **Step 3: Extend the models and API payload methods**

```dart
class GroupFeishuRobotConfig {
  final String webhookMode;
  final String officialWebhookUrl;
  final String officialSecret;

  factory GroupFeishuRobotConfig.fromJson(Map<String, dynamic> json) {
    return GroupFeishuRobotConfig(
      groupNo: json['group_no']?.toString() ?? '',
      webhookUrl: json['webhook_url']?.toString() ?? '',
      secret: json['secret']?.toString() ?? '',
      appId: json['app_id']?.toString() ?? '',
      appSecret: json['app_secret']?.toString() ?? '',
      webhookMode: _normalizeWebhookMode(json['webhook_mode']?.toString()),
      officialWebhookUrl: json['official_webhook_url']?.toString() ?? '',
      officialSecret: json['official_secret']?.toString() ?? '',
      enabled: _readInt(json['enabled']) == 1,
      secretSet: _readBool(json['secret_set']),
      appSecretSet: _readBool(json['app_secret_set']),
      lastPushAt: _readInt(json['last_push_at']),
      lastError: json['last_error']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      displayAvatar: json['display_avatar']?.toString() ?? '',
    );
  }
}
```

```dart
Future<GroupFeishuRobotConfig> updateFeishuRobotConfig(
  String groupNo, {
  bool enabled = true,
  bool regenerateWebhook = false,
  bool regenerateSecret = false,
  String? appId,
  String? appSecret,
  String? webhookMode,
  String? officialWebhookUrl,
  String? officialSecret,
  String? displayName,
  String? displayAvatar,
}) async {
  final data = <String, dynamic>{
    'enabled': enabled ? 1 : 0,
    if (regenerateWebhook) 'regenerate_webhook': 1,
    if (regenerateSecret) 'regenerate_secret': 1,
    if (webhookMode != null) 'webhook_mode': webhookMode.trim(),
    if (officialWebhookUrl != null) 'official_webhook_url': officialWebhookUrl.trim(),
    if (officialSecret != null) 'official_secret': officialSecret.trim(),
  };
  ...
}
```

- [ ] **Step 4: Re-run the model tests and confirm the transport contract**

Run: `flutter test test/data/models/group_robot_config_test.dart`

Expected: PASS

### Task 4: Add Shared Flutter Webhook-Mode UI And Align The Avatar Action Row

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_webhook_mode.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_webhook_mode_section.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_robot_identity_section_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_identity_section.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_feishu_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_dingtalk_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_feishu_bot_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_dingtalk_bot_page_test.dart`

- [ ] **Step 1: Write the failing shared identity-section test for aligned avatar actions**

```dart
testWidgets('robot identity section uses aligned action buttons for upload and clear', (tester) async {
  final controller = TextEditingController(text: 'Robot');
  addTearDown(controller.dispose);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: GroupRobotIdentitySection(
          providerName: '飞书',
          displayNameController: controller,
          displayAvatar: 'https://im.example.com/avatar.png',
          isBusy: false,
          onUploadAvatar: () async {},
          onClearAvatar: () {},
        ),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('group-robot-avatar-action-row')), findsOneWidget);
  expect(find.byKey(const ValueKey('group-robot-upload-avatar-button')), findsOneWidget);
  expect(find.byKey(const ValueKey('group-robot-clear-avatar-button')), findsOneWidget);
});
```

- [ ] **Step 2: Extend the page widget tests with official-mode coverage**

```dart
testWidgets('feishu robot page validates official webhook host and submits official mode payload', (tester) async {
  Map<String, dynamic>? savedPayload;

  ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
    final method = options.method.toUpperCase();
    final path = options.uri.path;

    if (method == 'GET' && path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
      return _MockJsonResponse(<String, dynamic>{
        'code': 0,
        'data': <String, dynamic>{
          'group_no': 'g_feishu',
          'webhook_url': 'https://im.example.com/v1/groups/g_feishu/robot/feishu/webhook/token_demo',
          'secret': 'sign-secret',
          'webhook_mode': 'im_generated',
          'official_webhook_url': '',
          'official_secret': '',
          'enabled': 1,
        },
      });
    }
    if (method == 'PUT' && path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
      savedPayload = Map<String, dynamic>.from(options.data as Map);
      return _MockJsonResponse(<String, dynamic>{'code': 0, 'data': savedPayload});
    }
    return _MockJsonResponse(<String, dynamic>{'code': 404}, statusCode: 404);
  });

  await tester.pumpWidget(const MaterialApp(
    home: GroupFeishuBotPage(groupNo: 'g_feishu', groupName: '测试群'),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const ValueKey('group-robot-webhook-mode-official')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('group-robot-official-webhook-field')), 'https://open.feishu.cn/open-apis/bot/v2/hook/demo');
  await tester.enterText(find.byKey(const ValueKey('group-robot-official-secret-field')), 'official_secret');
  await tester.tap(find.byKey(const ValueKey('group-robot-save-config-cell')));
  await tester.pumpAndSettle();

  expect(savedPayload?['webhook_mode'], 'official');
  expect(savedPayload?['official_webhook_url'], 'https://open.feishu.cn/open-apis/bot/v2/hook/demo');
  expect(savedPayload?['official_secret'], 'official_secret');
});
```

- [ ] **Step 3: Run the shared/UI tests to verify they fail**

Run: `flutter test test/wukong_uikit/group/group_robot_identity_section_test.dart`

Expected: FAIL with missing alignment row keys or mixed button implementation

Run: `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`

Expected: FAIL with missing mode selector or missing official field support

Run: `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`

Expected: FAIL with missing mode selector or missing official field support

- [ ] **Step 4: Implement the shared mode helper and stable action-row layout**

```dart
enum GroupRobotWebhookMode { imGenerated, official }

extension GroupRobotWebhookModeApiValue on GroupRobotWebhookMode {
  String get apiValue => this == GroupRobotWebhookMode.official ? 'official' : 'im_generated';

  String get label => this == GroupRobotWebhookMode.official ? '官方 Webhook' : 'IM 接收 Webhook';
}

String? validateOfficialWebhook(
  GroupRobotWebhookMode mode, {
  required String provider,
  required String url,
}) {
  if (mode != GroupRobotWebhookMode.official) {
    return null;
  }
  final normalized = Uri.tryParse(url.trim());
  final host = normalized?.host.toLowerCase() ?? '';
  if (provider == 'feishu') {
    return host == 'open.feishu.cn' ? null : '无效的飞书 Webhook URL（必须包含 open.feishu.cn）';
  }
  return host == 'oapi.dingtalk.com' || host == 'api.dingtalk.com'
      ? null
      : '无效的钉钉 Webhook URL（必须包含 oapi.dingtalk.com 或 api.dingtalk.com）';
}
```

```dart
Row(
  key: const ValueKey('group-robot-avatar-action-row'),
  children: [
    Expanded(
      child: OutlinedButton.icon(
        key: const ValueKey('group-robot-upload-avatar-button'),
        onPressed: isBusy || onUploadAvatar == null ? null : () => onUploadAvatar!.call(),
        icon: const Icon(Icons.file_upload_outlined, size: 18),
        label: const Text('上传头像'),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: OutlinedButton.icon(
        key: const ValueKey('group-robot-clear-avatar-button'),
        onPressed: isBusy || onClearAvatar == null ? null : onClearAvatar,
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('清空头像'),
      ),
    ),
  ],
)
```

- [ ] **Step 5: Make both robot pages mode-aware and explicit about the no-sync boundary**

```dart
if (_webhookMode == GroupRobotWebhookMode.official) ...[
  GroupRobotWebhookModeSection(
    provider: GroupRobotProvider.feishu,
    mode: _webhookMode,
    officialWebhookController: _officialWebhookController,
    officialSecretController: _officialSecretController,
    isBusy: _isSaving,
    onModeChanged: _handleWebhookModeChanged,
    helperText: '当前官方 Webhook 仅用于官方域名校验与配置保存，不会自动同步消息回 IM 群。',
  ),
]
```

```dart
final validationError = validateOfficialWebhook(
  _webhookMode,
  provider: 'dingtalk',
  url: _officialWebhookController.text,
);
if (validationError != null) {
  _showMessage(validationError);
  return;
}
```

```dart
final saved = await GroupApi.instance.updateDingTalkRobotConfig(
  widget.groupNo,
  enabled: _enabled,
  regenerateWebhook: _webhookMode == GroupRobotWebhookMode.imGenerated && regenerateWebhook,
  regenerateSecret: _webhookMode == GroupRobotWebhookMode.imGenerated && regenerateSecret,
  webhookMode: _webhookMode.apiValue,
  officialWebhookUrl: _officialWebhookController.text.trim(),
  officialSecret: _officialSecretController.text.trim(),
  displayName: _displayNameController.text.trim(),
  displayAvatar: _displayAvatar.trim(),
);
```

- [ ] **Step 6: Re-run the shared and page widget tests**

Run: `flutter test test/wukong_uikit/group/group_robot_identity_section_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`

Expected: PASS

### Task 5: Full Verification And Manual Desktop Smoke For Dual-Mode Robot Settings

**Files:**
- No new files in this task. Use the code and tests from Tasks 1-4.

- [ ] **Step 1: Run the backend verification suite**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestNormalizeGroupRobotWebhookMode|TestValidateFeishuOfficialWebhookURL|TestValidateDingTalkOfficialWebhookURL|TestNewFeishuGroupRobotRespIncludesWebhookModeFields|TestNewDingTalkGroupRobotRespIncludesWebhookModeFields' -count=1`

Expected: PASS

- [ ] **Step 2: Run the Flutter verification suite**

Run: `flutter test test/data/models/group_robot_config_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_robot_identity_section_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`

Expected: PASS

- [ ] **Step 3: Start the Windows desktop client**

Run: `flutter run -d windows --no-resident`

Expected: Windows desktop app launches without build errors. If `INSTALL.vcxproj` fails because a previous `wukong_im_app.exe` process is locking plugin DLLs, stop the old process and re-run.

- [ ] **Step 4: Execute the manual smoke checklist in order**

```text
1. Open the Feishu robot page for a manageable group.
2. Confirm “上传头像” and “清空头像” appear aligned on one horizontal row.
3. Leave Feishu page in IM 接收 Webhook mode and confirm the generated webhook URL plus regenerate/test actions are visible.
4. Switch Feishu page to 官方 Webhook mode.
5. Enter an invalid official URL such as https://example.com/hook and confirm the page shows “无效的飞书 Webhook URL（必须包含 open.feishu.cn）”.
6. Enter a valid Feishu URL such as https://open.feishu.cn/open-apis/bot/v2/hook/demo plus a secret and save successfully.
7. Confirm the summary area shows 当前模式：官方 Webhook and the helper text states that official webhook traffic will not sync back into IM groups.
8. Switch back to IM 接收 Webhook mode and confirm the previously generated WuKongIM webhook still exists.
9. Repeat the same flow on the DingTalk page.
10. For DingTalk official mode, verify https://oapi.dingtalk.com/... and https://api.dingtalk.com/... are accepted while https://example.com/... is rejected with the official-host error.
```

- [ ] **Step 5: Record the local checkpoint because git commits are unavailable**

Run: `git -C C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app status`

Expected: `fatal: not a git repository (or any of the parent directories): .git`

Run: `git -C C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main status`

Expected: `fatal: not a git repository (or any of the parent directories): .git`

## Self-Review

- Spec coverage:
  - dual-mode Feishu and DingTalk robot settings pages: covered by Tasks 2-4
  - official-domain validation only: covered by Tasks 1, 2, and 4
  - no message sync back into IM groups for official mode: covered by Tasks 4 and 5 manual smoke
  - avatar upload/clear alignment: covered by Task 4
  - preserving generated WuKongIM webhook data while using official mode: covered by Task 2
- Placeholder scan:
  - no `TODO`, `TBD`, or “implement later” markers remain
  - every task includes exact files, named tests, and exact commands
- Type consistency:
  - backend transport fields use `webhook_mode`, `official_webhook_url`, and `official_secret`
  - Flutter fields use `webhookMode`, `officialWebhookUrl`, and `officialSecret`
  - mode values stay `im_generated` and `official` across backend, Flutter, and tests
