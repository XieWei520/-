# Group Avatar And Robot Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add desktop group avatar editing plus IM-only Feishu and DingTalk robot display name/avatar customization, then render that robot identity consistently in group chat bubbles, group conversation previews, and robot settings summaries.

**Architecture:** Keep the backend transport model unchanged for inbound webhook delivery, but extend the robot config records with IM presentation metadata and stamp that metadata into delivered message payloads. On Flutter, wire the existing group avatar backend to a desktop-friendly picker/upload flow, add IM-only robot identity controls to the robot settings pages, and parse robot metadata from message payloads so the presentation layer can override the sender label/avatar without turning robots into real group members.

**Tech Stack:** Flutter, flutter_test, flutter_riverpod, Dio, file_picker, image_picker, Go 1.20, gin, sql-migrate SQL files, WuKongIM Flutter SDK

---

## File Structure

## Workspace Reality

- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` is not a git repository on this machine.
- `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main` is not a git repository on this machine.
- Replace per-task commit steps with explicit verification checkpoints. If these directories are later mounted inside git, commit after each completed task using the checkpoint summaries from this plan.

## Backend Files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\sql\robot-20260422-02.sql`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_db.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_db.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`

## Flutter Files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\robot_message_identity.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_identity_section.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\group_robot_config_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\robot_message_identity_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_detail_page_avatar_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_feishu_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_dingtalk_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\file_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\group_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_detail_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_feishu_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_dingtalk_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_bubble_experience_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\conversation\conversation_list_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_feishu_bot_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_dingtalk_bot_page_test.dart`

## Verification Commands

- Backend focused tests:
  - `go test ./modules/robot -run "TestResolveGroupRobotDisplayIdentity|TestApplyGroupRobotDisplayMeta|TestNewFeishuGroupRobotRespIncludesIMDisplayFields|TestNewDingTalkGroupRobotRespIncludesIMDisplayFields"`
- Flutter focused tests:
  - `flutter test test/data/models/group_robot_config_test.dart`
  - `flutter test test/modules/chat/robot_message_identity_test.dart`
  - `flutter test test/modules/chat/message_bubble_experience_test.dart`
  - `flutter test test/modules/conversation/conversation_list_page_test.dart`
  - `flutter test test/wukong_uikit/group/group_detail_page_avatar_test.dart`
  - `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`
  - `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`
- Windows smoke launch:
  - `flutter run -d windows`

### Task 1: Extend Robot Persistence And Add Payload Metadata Helper

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\sql\robot-20260422-02.sql`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_db.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_db.go`

- [ ] **Step 1: Write the failing backend tests for IM display identity defaults and payload decoration**

```go
package robot

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestResolveGroupRobotDisplayIdentityUsesCustomIMFields(t *testing.T) {
	identity := resolveGroupRobotDisplayIdentity(
		"feishu",
		"飞书机器人",
		"file/preview/common/robot/feishu.png",
	)

	require.Equal(t, "feishu", identity.Provider)
	require.Equal(t, "飞书机器人", identity.DisplayName)
	require.Equal(t, "file/preview/common/robot/feishu.png", identity.DisplayAvatar)
}

func TestResolveGroupRobotDisplayIdentityFallsBackToProviderDefaults(t *testing.T) {
	identity := resolveGroupRobotDisplayIdentity("dingtalk", "", "")

	require.Equal(t, "dingtalk", identity.Provider)
	require.Equal(t, "钉钉机器人", identity.DisplayName)
	require.Empty(t, identity.DisplayAvatar)
}

func TestApplyGroupRobotDisplayMetaDecoratesPayload(t *testing.T) {
	payload := map[string]interface{}{
		"type":    1,
		"content": "hello",
	}

	decorated := applyGroupRobotDisplayMeta(payload, resolveGroupRobotDisplayIdentity(
		"feishu",
		"飞书机器人",
		"file/preview/common/robot/feishu.png",
	))

	robotMeta := decorated["robot"].(map[string]interface{})
	require.Equal(t, "feishu", robotMeta["provider"])
	require.Equal(t, "飞书机器人", robotMeta["display_name"])
	require.Equal(t, "file/preview/common/robot/feishu.png", robotMeta["display_avatar"])
}
```

- [ ] **Step 2: Run the backend tests to verify they fail first**

Run: `go test ./modules/robot -run "TestResolveGroupRobotDisplayIdentity|TestApplyGroupRobotDisplayMeta"`

Expected: FAIL with undefined `resolveGroupRobotDisplayIdentity`, `applyGroupRobotDisplayMeta`, or missing struct fields

- [ ] **Step 3: Add the schema migration and persistence fields**

```sql
-- +migrate Up

ALTER TABLE `robot_feishu_group`
  ADD COLUMN `display_name` varchar(80) NOT NULL DEFAULT '' AFTER `app_secret`,
  ADD COLUMN `display_avatar` varchar(500) NOT NULL DEFAULT '' AFTER `display_name`;

ALTER TABLE `robot_dingtalk_group`
  ADD COLUMN `display_name` varchar(80) NOT NULL DEFAULT '' AFTER `secret`,
  ADD COLUMN `display_avatar` varchar(500) NOT NULL DEFAULT '' AFTER `display_name`;

-- +migrate Down

ALTER TABLE `robot_feishu_group`
  DROP COLUMN `display_avatar`,
  DROP COLUMN `display_name`;

ALTER TABLE `robot_dingtalk_group`
  DROP COLUMN `display_avatar`,
  DROP COLUMN `display_name`;
```

```go
type feishuGroupRobotConfig struct {
	GroupNo       string
	WebhookURL    string
	Secret        string
	AppID         string
	AppSecret     string
	DisplayName   string
	DisplayAvatar string
	Enabled       int
	CreatedUID    string
	UpdatedUID    string
	LastPushAt    int64
	LastError     string
	db.BaseModel
}

func (d *robotDB) insertFeishuGroupRobot(model *feishuGroupRobotConfig) error {
	_, err := d.session.InsertInto("robot_feishu_group").
		Columns("group_no", "webhook_url", "secret", "app_id", "app_secret", "display_name", "display_avatar", "enabled", "created_uid", "updated_uid", "last_push_at", "last_error").
		Record(model).
		Exec()
	return err
}
```

```go
type dingTalkGroupRobotConfig struct {
	GroupNo       string
	WebhookURL    string
	Secret        string
	DisplayName   string
	DisplayAvatar string
	Enabled       int
	CreatedUID    string
	UpdatedUID    string
	LastPushAt    int64
	LastError     string
	db.BaseModel
}
```

- [ ] **Step 4: Implement the shared robot display metadata helper**

```go
package robot

import "strings"

type groupRobotDisplayIdentity struct {
	Provider      string
	DisplayName   string
	DisplayAvatar string
}

func resolveGroupRobotDisplayIdentity(provider, configuredName, configuredAvatar string) groupRobotDisplayIdentity {
	normalizedProvider := strings.TrimSpace(strings.ToLower(provider))
	normalizedName := strings.TrimSpace(configuredName)
	normalizedAvatar := strings.TrimSpace(configuredAvatar)
	if normalizedName == "" {
		switch normalizedProvider {
		case "dingtalk":
			normalizedName = "钉钉机器人"
		default:
			normalizedName = "飞书机器人"
		}
	}
	return groupRobotDisplayIdentity{
		Provider:      normalizedProvider,
		DisplayName:   normalizedName,
		DisplayAvatar: normalizedAvatar,
	}
}

func applyGroupRobotDisplayMeta(payload map[string]interface{}, identity groupRobotDisplayIdentity) map[string]interface{} {
	if len(payload) == 0 {
		return payload
	}
	payload["robot"] = map[string]interface{}{
		"provider":       identity.Provider,
		"display_name":   identity.DisplayName,
		"display_avatar": identity.DisplayAvatar,
	}
	return payload
}
```

- [ ] **Step 5: Re-run the backend helper tests and record the checkpoint**

Run: `go test ./modules/robot -run "TestResolveGroupRobotDisplayIdentity|TestApplyGroupRobotDisplayMeta"`

Expected: PASS

### Task 2: Extend Robot CRUD Responses And Stamp Metadata Into Delivered Messages

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta_test.go`

- [ ] **Step 1: Write failing response-contract tests for the new IM-only fields**

```go
func TestNewFeishuGroupRobotRespIncludesIMDisplayFields(t *testing.T) {
	resp := newFeishuGroupRobotResp(&feishuGroupRobotConfig{
		GroupNo:       "g_demo",
		WebhookURL:    "token",
		Secret:        "secret",
		DisplayName:   "飞书机器人",
		DisplayAvatar: "file/preview/common/robot/feishu.png",
	}, "https://example.com/feishu")

	require.Equal(t, "飞书机器人", resp.DisplayName)
	require.Equal(t, "file/preview/common/robot/feishu.png", resp.DisplayAvatar)
}

func TestNewDingTalkGroupRobotRespIncludesIMDisplayFields(t *testing.T) {
	resp := newDingTalkGroupRobotResp(&dingTalkGroupRobotConfig{
		GroupNo:       "g_demo",
		WebhookURL:    "token",
		Secret:        "secret",
		DisplayName:   "钉钉机器人",
		DisplayAvatar: "file/preview/common/robot/dingtalk.png",
	}, "https://example.com/dingtalk")

	require.Equal(t, "钉钉机器人", resp.DisplayName)
	require.Equal(t, "file/preview/common/robot/dingtalk.png", resp.DisplayAvatar)
}
```

- [ ] **Step 2: Run the response-contract tests to verify they fail**

Run: `go test ./modules/robot -run "TestNewFeishuGroupRobotRespIncludesIMDisplayFields|TestNewDingTalkGroupRobotRespIncludesIMDisplayFields"`

Expected: FAIL with missing `DisplayName` and `DisplayAvatar` response fields

- [ ] **Step 3: Accept and persist the IM-only fields in both handlers**

```go
type feishuGroupRobotResp struct {
	GroupNo       string `json:"group_no"`
	WebhookURL    string `json:"webhook_url"`
	Secret        string `json:"secret"`
	AppID         string `json:"app_id"`
	AppSecret     string `json:"app_secret"`
	DisplayName   string `json:"display_name"`
	DisplayAvatar string `json:"display_avatar"`
	Enabled       int    `json:"enabled"`
	SecretSet     bool   `json:"secret_set"`
	AppSecretSet  bool   `json:"app_secret_set"`
	LastPushAt    int64  `json:"last_push_at"`
	LastError     string `json:"last_error"`
	UpdatedAt     string `json:"updated_at"`
}

var req struct {
	Enabled           *int    `json:"enabled"`
	RegenerateWebhook *int    `json:"regenerate_webhook"`
	RegenerateSecret  *int    `json:"regenerate_secret"`
	AppID             *string `json:"app_id"`
	AppSecret         *string `json:"app_secret"`
	DisplayName       *string `json:"display_name"`
	DisplayAvatar     *string `json:"display_avatar"`
}

if req.DisplayName != nil {
	existing.DisplayName = strings.TrimSpace(*req.DisplayName)
}
if req.DisplayAvatar != nil {
	existing.DisplayAvatar = strings.TrimSpace(*req.DisplayAvatar)
}
```

```go
type dingTalkGroupRobotResp struct {
	GroupNo       string `json:"group_no"`
	WebhookURL    string `json:"webhook_url"`
	Secret        string `json:"secret"`
	DisplayName   string `json:"display_name"`
	DisplayAvatar string `json:"display_avatar"`
	Enabled       int    `json:"enabled"`
	SecretSet     bool   `json:"secret_set"`
	LastPushAt    int64  `json:"last_push_at"`
	LastError     string `json:"last_error"`
	UpdatedAt     string `json:"updated_at"`
}
```

- [ ] **Step 4: Decorate every delivered robot payload before sending it into the IM group**

```go
func (rb *Robot) sendFeishuGroupRobotPayload(groupNo string, payload map[string]interface{}, model *feishuGroupRobotConfig) error {
	if len(payload) == 0 {
		return errors.New("payload is empty")
	}
	payload = applyGroupRobotDisplayMeta(payload, resolveGroupRobotDisplayIdentity(
		"feishu",
		model.DisplayName,
		model.DisplayAvatar,
	))
	return rb.ctx.SendMessage(&config.MsgSendReq{
		FromUID:     rb.ctx.GetConfig().Account.SystemUID,
		ChannelID:   groupNo,
		ChannelType: common.ChannelTypeGroup.Uint8(),
		Payload:     []byte(util.ToJson(payload)),
		Header:      config.MsgHeader{RedDot: 1},
	})
}
```

```go
func (rb *Robot) sendDingTalkGroupRobotPayload(groupNo string, payload map[string]interface{}, model *dingTalkGroupRobotConfig) error {
	if len(payload) == 0 {
		return errors.New("payload is empty")
	}
	payload = applyGroupRobotDisplayMeta(payload, resolveGroupRobotDisplayIdentity(
		"dingtalk",
		model.DisplayName,
		model.DisplayAvatar,
	))
	return rb.ctx.SendMessage(&config.MsgSendReq{
		FromUID:     rb.ctx.GetConfig().Account.SystemUID,
		ChannelID:   groupNo,
		ChannelType: common.ChannelTypeGroup.Uint8(),
		Payload:     []byte(util.ToJson(payload)),
		Header:      config.MsgHeader{RedDot: 1},
	})
}
```

- [ ] **Step 5: Re-run the full backend robot test set for the new contract**

Run: `go test ./modules/robot -run "TestResolveGroupRobotDisplayIdentity|TestApplyGroupRobotDisplayMeta|TestNewFeishuGroupRobotRespIncludesIMDisplayFields|TestNewDingTalkGroupRobotRespIncludesIMDisplayFields"`

Expected: PASS

### Task 3: Extend Flutter Robot Models, Group API, And Common Image Upload Support

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\group_robot_config_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_feishu_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group_dingtalk_robot_config.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\group_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\file_api.dart`

- [ ] **Step 1: Write failing Flutter model tests for the new transport fields**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/group_dingtalk_robot_config.dart';
import 'package:wukong_im_app/data/models/group_feishu_robot_config.dart';

void main() {
  test('GroupFeishuRobotConfig preserves IM display metadata', () {
    final config = GroupFeishuRobotConfig.fromJson(<String, dynamic>{
      'group_no': 'g_demo',
      'webhook_url': 'https://example.com/feishu',
      'secret': 'secret',
      'display_name': '飞书机器人',
      'display_avatar': 'https://example.com/feishu.png',
      'enabled': 1,
    });

    expect(config.displayName, '飞书机器人');
    expect(config.displayAvatar, 'https://example.com/feishu.png');
    expect(config.toJson()['display_name'], '飞书机器人');
  });

  test('GroupDingTalkRobotConfig preserves IM display metadata', () {
    final config = GroupDingTalkRobotConfig.fromJson(<String, dynamic>{
      'group_no': 'g_demo',
      'webhook_url': 'https://example.com/dingtalk',
      'secret': 'secret',
      'display_name': '钉钉机器人',
      'display_avatar': 'https://example.com/dingtalk.png',
      'enabled': 1,
    });

    expect(config.displayName, '钉钉机器人');
    expect(config.displayAvatar, 'https://example.com/dingtalk.png');
    expect(config.toJson()['display_avatar'], 'https://example.com/dingtalk.png');
  });
}
```

- [ ] **Step 2: Run the Flutter model tests to confirm they fail**

Run: `flutter test test/data/models/group_robot_config_test.dart`

Expected: FAIL with missing `displayName` and `displayAvatar` fields

- [ ] **Step 3: Extend the models, API payloads, and shared common-image upload helper**

```dart
class GroupFeishuRobotConfig {
  final String groupNo;
  final String webhookUrl;
  final String secret;
  final String appId;
  final String appSecret;
  final String displayName;
  final String displayAvatar;
  final bool enabled;
  final bool secretSet;
  final bool appSecretSet;
  final int lastPushAt;
  final String lastError;
  final String updatedAt;

  factory GroupFeishuRobotConfig.fromJson(Map<String, dynamic> json) {
    return GroupFeishuRobotConfig(
      groupNo: json['group_no']?.toString() ?? '',
      webhookUrl: json['webhook_url']?.toString() ?? '',
      secret: json['secret']?.toString() ?? '',
      appId: json['app_id']?.toString() ?? '',
      appSecret: json['app_secret']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      displayAvatar: json['display_avatar']?.toString() ?? '',
      enabled: _readInt(json['enabled']) == 1,
      secretSet: _readBool(json['secret_set']),
      appSecretSet: _readBool(json['app_secret_set']),
      lastPushAt: _readInt(json['last_push_at']),
      lastError: json['last_error']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
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
  String? displayName,
  String? displayAvatar,
}) async {
  final data = <String, dynamic>{
    'enabled': enabled ? 1 : 0,
    if (regenerateWebhook) 'regenerate_webhook': 1,
    if (regenerateSecret) 'regenerate_secret': 1,
  };
  if (displayName != null) {
    data['display_name'] = displayName.trim();
  }
  if (displayAvatar != null) {
    data['display_avatar'] = displayAvatar.trim();
  }
  if (appId != null) {
    data['app_id'] = appId.trim();
  }
  if (appSecret != null) {
    data['app_secret'] = appSecret.trim();
  }
  final response = await _client.put('${ApiConfig.groups}/$groupNo/robot/feishu', data: data);
  _ensureSuccess(response, fallback: 'Save Feishu robot config failed');
  return GroupFeishuRobotConfig.fromJson(Map<String, dynamic>.from(response.data['data'] ?? response.data));
}
```

```dart
Future<String> uploadCommonImage({
  required String filePath,
  required String uploadPath,
}) {
  return _uploadFile(
    filePath: filePath,
    fileType: 'common',
    uploadPath: uploadPath,
  );
}
```

- [ ] **Step 4: Re-run the Flutter model test checkpoint**

Run: `flutter test test/data/models/group_robot_config_test.dart`

Expected: PASS

### Task 4: Add Group Avatar Editing To Desktop Group Detail

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_detail_page_avatar_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_detail_page.dart`

- [ ] **Step 1: Write the failing widget tests for avatar permissions and upload**

```dart
testWidgets('owner can pick and upload a group avatar from group detail', (tester) async {
  String? uploadedFilePath;

  await tester.pumpWidget(
    MaterialApp(
      home: GroupDetailPage(
        channelId: 'g_avatar',
        pickAvatarImage: () async => 'C:/tmp/group-avatar.png',
        uploadAvatarImage: (groupNo, filePath) async {
          uploadedFilePath = filePath;
          return 'https://example.com/group-avatar.png';
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('group-detail-avatar-button')));
  await tester.pumpAndSettle();

  expect(uploadedFilePath, 'C:/tmp/group-avatar.png');
  expect(find.text('群头像已更新'), findsOneWidget);
});

testWidgets('normal member sees read-only group avatar', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: GroupDetailPage(channelId: 'g_avatar'),
    ),
  );

  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey<String>('group-detail-avatar-edit-badge')), findsNothing);
});
```

- [ ] **Step 2: Run the avatar widget test to verify it fails**

Run: `flutter test test/wukong_uikit/group/group_detail_page_avatar_test.dart`

Expected: FAIL with missing constructor parameters or missing avatar edit controls

- [ ] **Step 3: Implement the avatar edit flow with injected test hooks and cache refresh**

```dart
class GroupDetailPage extends StatefulWidget {
  const GroupDetailPage({
    super.key,
    required this.channelId,
    this.channelType = 1,
    this.pickAvatarImage,
    this.uploadAvatarImage,
  });

  final String channelId;
  final int channelType;
  final Future<String?> Function()? pickAvatarImage;
  final Future<String> Function(String groupNo, String filePath)? uploadAvatarImage;
}
```

```dart
bool get _canEditGroupAvatar => _canManageMembers;

Future<void> _changeGroupAvatar() async {
  if (!_canEditGroupAvatar || _isUpdating) {
    return;
  }
  final picker = widget.pickAvatarImage ?? _pickGroupAvatarImage;
  final uploader = widget.uploadAvatarImage ?? GroupApi.instance.uploadGroupAvatar;
  final filePath = await picker();
  if (filePath == null || filePath.trim().isEmpty) {
    return;
  }

  await _runAction(() async {
    final uploadedAvatar = await uploader(widget.channelId, filePath);
    await WKAvatar.evictUrl(uploadedAvatar);
    await WKIM.shared.channelManager.updateAvatarCacheKey(
      widget.channelId,
      widget.channelType,
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    await _loadData(showLoading: false);
  }, successMessage: '群头像已更新', failurePrefix: '更新群头像失败');
}
```

```dart
Widget _buildGroupInfoSection() {
  final groupName = (_group?.name ?? '群聊').trim();
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        InkWell(
          key: const ValueKey<String>('group-detail-avatar-button'),
          onTap: _canEditGroupAvatar ? _changeGroupAvatar : null,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              WKAvatar(
                url: _group?.avatar,
                name: groupName.isEmpty ? widget.channelId : groupName,
                isGroup: true,
                size: 72,
              ),
              if (_canEditGroupAvatar)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    key: const ValueKey<String>('group-detail-avatar-edit-badge'),
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: WKColors.brand500,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Re-run the avatar widget test and the existing settings regression test**

Run: `flutter test test/wukong_uikit/group/group_detail_page_avatar_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_detail_page_settings_test.dart`

Expected: PASS

### Task 5: Add IM-Only Robot Display Controls And Readable Copy To Both Robot Pages

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_robot_identity_section.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_feishu_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_dingtalk_bot_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_feishu_bot_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\group\group_dingtalk_bot_page_test.dart`

- [ ] **Step 1: Write failing widget tests that assert IM-only fields and request payloads**

```dart
testWidgets('group feishu bot page submits IM-only display metadata', (tester) async {
  Map<String, dynamic>? savedPayload;

  ApiClient.instance.dio.httpClientAdapter = _RoutingJsonAdapter((options) {
    final method = options.method.toUpperCase();
    final path = options.uri.path;
    if (method == 'GET' && path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
      return _MockJsonResponse(<String, dynamic>{'code': 0, 'data': <String, dynamic>{'group_no': 'g_feishu', 'enabled': 1}});
    }
    if (method == 'PUT' && path == '${ApiConfig.groups}/g_feishu/robot/feishu') {
      savedPayload = Map<String, dynamic>.from(options.data as Map);
      return _MockJsonResponse(<String, dynamic>{'code': 0, 'data': savedPayload});
    }
    return _MockJsonResponse(<String, dynamic>{'code': 404}, statusCode: 404);
  });

  await tester.pumpWidget(
    const MaterialApp(home: GroupFeishuBotPage(groupNo: 'g_feishu', groupName: '测试群')),
  );
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const ValueKey<String>('group-robot-display-name-field')), '飞书机器人');
  await tester.tap(find.text('保存当前配置'));
  await tester.pumpAndSettle();

  expect(savedPayload?['display_name'], '飞书机器人');
  expect(find.text('仅影响悟空 IM 内显示，不会修改飞书官方机器人资料。'), findsOneWidget);
});
```

- [ ] **Step 2: Run the two robot page widget tests to verify they fail**

Run: `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`

Expected: FAIL with missing IM-only display controls

Run: `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`

Expected: FAIL with missing IM-only display controls

- [ ] **Step 3: Implement the shared identity section, readable Chinese copy, and avatar upload flow**

```dart
class GroupRobotIdentitySection extends StatelessWidget {
  const GroupRobotIdentitySection({
    super.key,
    required this.displayNameController,
    required this.displayAvatarUrl,
    required this.onPickAvatar,
    required this.onResetAvatar,
    required this.isBusy,
    required this.providerLabel,
  });

  final TextEditingController displayNameController;
  final String displayAvatarUrl;
  final Future<void> Function() onPickAvatar;
  final VoidCallback onResetAvatar;
  final bool isBusy;
  final String providerLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('IM 内显示', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '仅影响悟空 IM 内显示，不会修改$providerLabel官方机器人资料。',
            style: const TextStyle(fontSize: 13, height: 1.5, color: WKColors.color999),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey<String>('group-robot-display-name-field'),
            controller: displayNameController,
            enabled: !isBusy,
            decoration: const InputDecoration(
              labelText: '机器人显示名称',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}
```

```dart
Future<void> _pickDisplayAvatar() async {
  final picker = widget.pickDisplayAvatar ?? _pickImagePath;
  final uploader = widget.uploadDisplayAvatar ?? _uploadRobotDisplayAvatar;
  final filePath = await picker();
  if (filePath == null || filePath.trim().isEmpty) {
    return;
  }
  await _runBusyAction(() async {
    final uploadedUrl = await uploader(filePath);
    if (!mounted) {
      return;
    }
    setState(() => _displayAvatarUrl = uploadedUrl);
  });
}

Future<String> _uploadRobotDisplayAvatar(String filePath) {
  final safeGroupNo = widget.groupNo.trim().isEmpty ? 'group' : widget.groupNo.trim();
  final uploadPath = '/robot/$safeGroupNo/${DateTime.now().millisecondsSinceEpoch}_${widget.runtimeType}.png';
  return FileApi.instance.uploadCommonImage(filePath: filePath, uploadPath: uploadPath);
}
```

```dart
final saved = await GroupApi.instance.updateDingTalkRobotConfig(
  widget.groupNo,
  enabled: _enabled,
  regenerateWebhook: regenerateWebhook,
  regenerateSecret: regenerateSecret,
  displayName: _displayNameController.text.trim(),
  displayAvatar: _displayAvatarUrl.trim(),
);
```

- [ ] **Step 4: Re-run the two robot page widget tests**

Run: `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`

Expected: PASS

### Task 6: Resolve Robot Sender Identity In Message Bubbles And Group Conversation Previews

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\robot_message_identity.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\robot_message_identity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_bubble_experience_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\conversation\conversation_list_page_test.dart`

- [ ] **Step 1: Write failing tests for robot identity parsing and preview prefixing**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/robot_message_identity.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('resolveMessageParticipantInfo prefers robot payload identity', () {
    final message = WKMsg()
      ..fromUID = 'system_uid'
      ..channelType = WKChannelType.group
      ..contentType = WkMessageContentType.text
      ..content = '{"type":1,"content":"hello","robot":{"provider":"feishu","display_name":"飞书机器人","display_avatar":"file/preview/common/robot/feishu.png"}}';

    final info = resolveMessageParticipantInfo(message);

    expect(info.displayName, '飞书机器人');
    expect(info.avatarUrl, isNotNull);
  });

  test('resolveConversationPreviewText prefixes robot display name for group robot messages', () {
    final message = WKMsg()
      ..fromUID = 'system_uid'
      ..channelType = WKChannelType.group
      ..contentType = WkMessageContentType.text
      ..content = '{"type":1,"content":"部署完成","robot":{"provider":"dingtalk","display_name":"钉钉机器人"}}';

    expect(resolveConversationPreviewText(message), '钉钉机器人: 部署完成');
  });
}
```

- [ ] **Step 2: Run the new identity tests to verify they fail**

Run: `flutter test test/modules/chat/robot_message_identity_test.dart`

Expected: FAIL with missing robot identity parser or unchanged preview formatting

- [ ] **Step 3: Implement the parser and wire it into bubble and preview resolution**

```dart
import 'dart:convert';

import 'package:wukongimfluttersdk/entity/msg.dart';

import '../../core/config/api_config.dart';
import '../../core/utils/avatar_utils.dart';

class RobotMessageIdentity {
  const RobotMessageIdentity({
    required this.provider,
    required this.displayName,
    required this.displayAvatarUrl,
  });

  final String provider;
  final String displayName;
  final String? displayAvatarUrl;
}

RobotMessageIdentity? resolveRobotMessageIdentity(WKMsg message) {
  final raw = message.content.trim();
  if (!raw.startsWith('{')) {
    return null;
  }
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return null;
  }
  final payload = Map<String, dynamic>.from(decoded);
  final robotMap = payload['robot'];
  if (robotMap is! Map) {
    return null;
  }
  final robot = Map<String, dynamic>.from(robotMap);
  final displayName = (robot['display_name']?.toString() ?? '').trim();
  final rawAvatar = (robot['display_avatar']?.toString() ?? '').trim();
  if (displayName.isEmpty && rawAvatar.isEmpty) {
    return null;
  }
  final resolvedAvatar =
      resolveAvatarUrl(rawAvatar) ??
      (rawAvatar.isEmpty ? null : ApiConfig.resolveMediaUrl(rawAvatar));
  return RobotMessageIdentity(
    provider: (robot['provider']?.toString() ?? '').trim(),
    displayName: displayName,
    displayAvatarUrl: resolvedAvatar,
  );
}
```

```dart
MessageParticipantInfo resolveMessageParticipantInfo(
  WKMsg message, {
  WKChannelMember? fallbackGroupMember,
}) {
  final robotIdentity = resolveRobotMessageIdentity(message);
  final member = message.getMemberOfFrom();
  final from = message.getFrom();
  final channelInfo = message.getChannelInfo();

  final displayName = _firstNonEmpty([
    robotIdentity?.displayName,
    _resolveGroupMemberName(member),
    _resolveGroupMemberName(fallbackGroupMember),
    _resolveChannelName(from),
    _resolveChannelName(channelInfo),
    message.fromUID.trim(),
    message.channelID.trim(),
    '未知用户',
  ]);

  final avatarUrl = _resolveParticipantAvatarUrl(
    _firstNonEmpty([
      robotIdentity?.displayAvatarUrl,
      _resolveGroupMemberAvatar(member),
      _resolveGroupMemberAvatar(fallbackGroupMember),
      from?.avatar.trim(),
      channelInfo?.avatar.trim(),
    ]),
    message.fromUID,
  );

  return MessageParticipantInfo(displayName: displayName, avatarUrl: avatarUrl);
}
```

```dart
String resolveConversationPreviewText(WKMsg? msg) {
  if (msg == null) {
    return 'No message';
  }

  final basePreview = (() {
    switch (msg.contentType) {
      case WkMessageContentType.text:
        final resolved = resolveVisibleTextMessage(msg, fallback: '').trim();
        return resolved.isEmpty ? 'Text message' : resolved;
      case WkMessageContentType.image:
        return '[Image]';
      case WkMessageContentType.voice:
        return '[Voice]';
      default:
        final raw = msg.content.trim();
        final resolved = resolveStructuredMessagePreview(raw).text.trim();
        return resolved.isEmpty ? 'New message' : resolved;
    }
  })();

  final identity = resolveRobotMessageIdentity(msg);
  if (msg.channelType == WKChannelType.group &&
      identity != null &&
      identity.displayName.trim().isNotEmpty) {
    return '${identity.displayName}: $basePreview';
  }
  return basePreview;
}
```

- [ ] **Step 4: Re-run the robot identity tests plus the impacted conversation and bubble regressions**

Run: `flutter test test/modules/chat/robot_message_identity_test.dart`

Expected: PASS

Run: `flutter test test/modules/chat/message_bubble_experience_test.dart`

Expected: PASS

Run: `flutter test test/modules/conversation/conversation_list_page_test.dart`

Expected: PASS

### Task 7: Full Verification, Migration Application, And Windows Manual Smoke

**Files:**
- No new files in this task. Use the code and tests from Tasks 1-6.

- [ ] **Step 1: Run the backend verification suite**

Run: `go test ./modules/robot -run "TestResolveGroupRobotDisplayIdentity|TestApplyGroupRobotDisplayMeta|TestNewFeishuGroupRobotRespIncludesIMDisplayFields|TestNewDingTalkGroupRobotRespIncludesIMDisplayFields"`

Expected: PASS

- [ ] **Step 2: Run the Flutter verification suite**

Run: `flutter test test/data/models/group_robot_config_test.dart`

Expected: PASS

Run: `flutter test test/modules/chat/robot_message_identity_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_detail_page_avatar_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_feishu_bot_page_test.dart`

Expected: PASS

Run: `flutter test test/wukong_uikit/group/group_dingtalk_bot_page_test.dart`

Expected: PASS

- [ ] **Step 3: Start the Windows desktop client and apply backend migrations by launching the server binary in the normal environment**

Run: `flutter run -d windows`

Expected: Windows desktop client launches and reaches the login or restored session screen

Run: `go run .`

Expected: server boots without SQL errors and applies the new `robot-20260422-02.sql` migration during startup

- [ ] **Step 4: Execute the manual smoke checklist in order**

```text
1. Log in as a group owner or admin and open group detail.
2. Click the group avatar, choose a local image, and confirm the group avatar updates in:
   - group detail
   - chat header
   - conversation list
3. Open Feishu robot settings, set IM display name to “飞书机器人”, upload a custom IM avatar, save, and send a webhook message.
4. Verify the Feishu message shows the custom avatar and “飞书机器人” in the group chat bubble, and the group conversation preview becomes “飞书机器人: <message>”.
5. Repeat the same flow for DingTalk using IM display name “钉钉机器人”.
6. Confirm the robot settings summary card shows the IM-only display name/avatar and the helper copy states that provider-side identity is unchanged.
7. Confirm the helper copy still states that strict official-domain third-party tools require an external proxy outside the IM product.
```

- [ ] **Step 5: Record the local checkpoint since git commits are unavailable in this workspace**

Run: `git -C C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app status`

Expected: `fatal: not a git repository (or any of the parent directories): .git`

Run: `git -C C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main status`

Expected: `fatal: not a git repository (or any of the parent directories): .git`

## Self-Review

- Spec coverage:
  - Group avatar desktop edit flow: covered by Task 4
  - Local cache refresh after group avatar change: covered by Task 4
  - IM-only robot display name/avatar fields in backend and Flutter: covered by Tasks 1-3 and Task 5
  - Robot settings UI updates and helper copy: covered by Task 5
  - Inbound robot message bubble identity override: covered by Task 6
  - Group conversation preview identity when robot messages surface: covered by Task 6
  - External proxy compatibility guidance without official webhook mode: covered by Task 5 and Task 7 manual smoke
  - Windows rebuild and manual smoke: covered by Task 7
- Placeholder scan:
  - No `TODO`, `TBD`, or “implement later” markers remain in this plan.
  - Each task lists exact files, concrete test code, concrete implementation code, and explicit commands.
- Type consistency:
  - Shared backend field names stay `display_name` and `display_avatar`.
  - Shared Flutter field names stay `displayName` and `displayAvatar`.
  - Shared payload metadata lives under `robot.provider`, `robot.display_name`, and `robot.display_avatar`.
