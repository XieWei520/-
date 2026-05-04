# Unified Robot Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dedicated `robot_card` message type that normalizes Feishu and DingTalk text-like robot messages into one premium IM card, while keeping conversation preview, search, reply, and pin flows text-based and stable.

**Architecture:** Add a shared backend normalization helper that converts Feishu and DingTalk text-like webhook payloads into a unified `robot_card.v1` envelope with content type `22`, then keep image/file robot traffic on the existing paths. On Flutter, register a dedicated `WKRobotCardContent`, surface `plain_text` through preview and search pipelines, render the premium card only in the chat page, and route whole-card taps to `link_url` when present.

**Tech Stack:** Flutter, flutter_test, Go 1.20, WuKongIM Flutter SDK, url_launcher

---

## Workspace Reality

- `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app` is not a git repository on this machine.
- `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main` is not a git repository on this machine.
- Replace commit steps with explicit verification checkpoints. If these paths later become git worktrees, commit after each task using the checkpoint summaries from this plan.

## File Structure

## Backend Files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\robot_card_payload.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\robot_card_payload_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot_test.go`

## Flutter Files

- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\wk_robot_card_content.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\robot_card_message.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\robot_message_card.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\wk_robot_card_content_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\robot_card_message_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\core\constants\im_constants.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\msg\msg_content_type.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\robot_message_identity.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\message_content_preview.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\search_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\search\data\search_repository_impl.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page_shell.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\robot_message_identity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_content_preview_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_bubble_experience_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\conversation\conversation_list_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\search\local_search_service_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\search\search_repository_test.dart`

## Verification Commands

- Backend focused tests:
  - `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestApplyGroupRobotDisplayMetaAddsRobotAliases|TestBuildFeishuRobotCardPayload|TestBuildDingTalkRobotCardPayload|TestBuildFeishuGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes|TestBuildDingTalkGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes' -count=1`
- Flutter focused tests:
  - `flutter test test/data/models/wk_robot_card_content_test.dart`
  - `flutter test test/modules/chat/robot_card_message_test.dart`
  - `flutter test test/modules/chat/robot_message_identity_test.dart`
  - `flutter test test/modules/chat/message_content_preview_test.dart`
  - `flutter test test/modules/conversation/conversation_list_page_test.dart`
  - `flutter test test/modules/search/local_search_service_test.dart`
  - `flutter test test/modules/search/search_repository_test.dart`
  - `flutter test test/modules/chat/message_bubble_experience_test.dart`
- Windows smoke launch:
  - `flutter run -d windows --no-resident`
- Remote API redeploy after local verification:
  - `ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose build tsdd-api && docker compose up -d tsdd-api"`

### Task 1: Add Shared Backend Robot Card Contract And Provider Metadata Aliases

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\robot_card_payload.go`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\robot_card_payload_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\group_robot_display_meta_test.go`

- [ ] **Step 1: Write the failing shared backend tests for robot-card payload shaping and robot metadata aliases**

```go
package robot

import "testing"

func TestApplyGroupRobotDisplayMetaAddsRobotAliases(t *testing.T) {
	payload := map[string]interface{}{"type": 1}
	identity := resolveGroupRobotDisplayIdentity(
		groupRobotProviderFeishu,
		"飞书机器人",
		"robots/feishu/avatar.png",
	)

	applyGroupRobotDisplayMeta(payload, identity)

	robotMeta := mapValue(payload["robot"])
	if robotMeta["provider"] != groupRobotProviderFeishu {
		t.Fatalf("unexpected provider: %#v", robotMeta["provider"])
	}
	if robotMeta["name"] != "飞书机器人" {
		t.Fatalf("unexpected robot name alias: %#v", robotMeta["name"])
	}
	if robotMeta["avatar"] != "robots/feishu/avatar.png" {
		t.Fatalf("unexpected robot avatar alias: %#v", robotMeta["avatar"])
	}
	if robotMeta["display_name"] != "飞书机器人" {
		t.Fatalf("unexpected display_name: %#v", robotMeta["display_name"])
	}
	if robotMeta["display_avatar"] != "robots/feishu/avatar.png" {
		t.Fatalf("unexpected display_avatar: %#v", robotMeta["display_avatar"])
	}
}

func TestBuildFeishuRobotCardPayload(t *testing.T) {
	incoming := map[string]interface{}{
		"msg_type": "interactive",
		"card": map[string]interface{}{
			"header": map[string]interface{}{
				"title": map[string]interface{}{"content": "消息通知"},
			},
			"elements": []interface{}{
				map[string]interface{}{
					"tag":     "markdown",
					"content": "feishu-link-test-001",
				},
			},
			"link": map[string]interface{}{"url": "https://example.com/detail"},
		},
	}

	payload, ok := buildFeishuRobotCardPayload(
		incoming,
		resolveGroupRobotDisplayIdentity(groupRobotProviderFeishu, "飞书机器人", "robots/feishu.png"),
	)
	if !ok {
		t.Fatal("expected feishu robot card payload")
	}
	if payload["type"] != groupRobotCardContentType {
		t.Fatalf("unexpected type: %#v", payload["type"])
	}
	if payload["schema"] != groupRobotCardSchemaV1 {
		t.Fatalf("unexpected schema: %#v", payload["schema"])
	}
	card := mapValue(payload["card"])
	if card["style"] != groupRobotCardStyleShowcase {
		t.Fatalf("unexpected style: %#v", card["style"])
	}
	if card["title"] != "消息通知" {
		t.Fatalf("unexpected title: %#v", card["title"])
	}
	if card["body"] != "feishu-link-test-001" {
		t.Fatalf("unexpected body: %#v", card["body"])
	}
	if card["badge"] != "LINK" {
		t.Fatalf("unexpected badge: %#v", card["badge"])
	}
	if card["link_url"] != "https://example.com/detail" {
		t.Fatalf("unexpected link_url: %#v", card["link_url"])
	}
	if payload["plain_text"] != "消息通知 feishu-link-test-001" {
		t.Fatalf("unexpected plain_text: %#v", payload["plain_text"])
	}
}

func TestBuildDingTalkRobotCardPayload(t *testing.T) {
	incoming := map[string]interface{}{
		"msgtype": "actionCard",
		"actionCard": map[string]interface{}{
			"title":     "发布通知已就绪",
			"text":      "dingtalk-action-test-001",
			"singleURL": "https://example.com/detail",
		},
	}

	payload, ok := buildDingTalkRobotCardPayload(
		incoming,
		resolveGroupRobotDisplayIdentity(groupRobotProviderDingTalk, "钉钉机器人", "robots/ding.png"),
	)
	if !ok {
		t.Fatal("expected dingtalk robot card payload")
	}
	card := mapValue(payload["card"])
	if card["title"] != "发布通知已就绪" {
		t.Fatalf("unexpected title: %#v", card["title"])
	}
	if card["body"] != "dingtalk-action-test-001" {
		t.Fatalf("unexpected body: %#v", card["body"])
	}
	if card["link_url"] != "https://example.com/detail" {
		t.Fatalf("unexpected link_url: %#v", card["link_url"])
	}
	if card["link_mode"] != groupRobotCardLinkModeWholeCard {
		t.Fatalf("unexpected link_mode: %#v", card["link_mode"])
	}
}
```

- [ ] **Step 2: Run the shared backend tests to verify they fail first**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestApplyGroupRobotDisplayMetaAddsRobotAliases|TestBuildFeishuRobotCardPayload|TestBuildDingTalkRobotCardPayload' -count=1`

Expected: FAIL with missing robot-card constants, helper functions, or alias fields

- [ ] **Step 3: Implement the shared robot-card envelope builder and robot metadata aliases**

```go
package robot

import "strings"

const (
	groupRobotCardContentType      = 22
	groupRobotCardSchemaV1         = "robot_card.v1"
	groupRobotCardStyleShowcase    = "showcase"
	groupRobotCardLinkModeWholeCard = "whole_card"
)

func newGroupRobotCardPayload(
	identity groupRobotDisplayIdentity,
	platform string,
	originType string,
	title string,
	body string,
	badge string,
	linkURL string,
) map[string]interface{} {
	title = truncateRunes(strings.TrimSpace(title), 120)
	body = truncateRunes(strings.TrimSpace(body), 3000)
	badge = normalizeGroupRobotCardBadge(badge, linkURL)
	plainText := joinGroupRobotCardPlainText(title, body)

	return map[string]interface{}{
		"type":        groupRobotCardContentType,
		"schema":      groupRobotCardSchemaV1,
		"platform":    strings.TrimSpace(platform),
		"origin_type": strings.TrimSpace(originType),
		"robot": map[string]interface{}{
			"provider":       identity.Provider,
			"name":           identity.DisplayName,
			"avatar":         identity.DisplayAvatar,
			"display_name":   identity.DisplayName,
			"display_avatar": identity.DisplayAvatar,
		},
		"card": map[string]interface{}{
			"style":     groupRobotCardStyleShowcase,
			"title":     title,
			"body":      body,
			"badge":     badge,
			"link_url":  strings.TrimSpace(linkURL),
			"link_mode": groupRobotCardLinkModeWholeCard,
		},
		"plain_text": plainText,
	}
}

func joinGroupRobotCardPlainText(title, body string) string {
	parts := make([]string, 0, 2)
	if strings.TrimSpace(title) != "" {
		parts = append(parts, strings.TrimSpace(title))
	}
	if strings.TrimSpace(body) != "" {
		parts = append(parts, strings.TrimSpace(body))
	}
	return strings.Join(parts, " ")
}

func normalizeGroupRobotCardBadge(rawBadge, linkURL string) string {
	badge := strings.ToUpper(strings.TrimSpace(rawBadge))
	if badge != "" {
		return badge
	}
	if strings.TrimSpace(linkURL) != "" {
		return "LINK"
	}
	return "NOTICE"
}

func buildFeishuRobotCardPayload(incoming map[string]interface{}, identity groupRobotDisplayIdentity) (map[string]interface{}, bool) {
	msgType := strings.TrimSpace(strings.ToLower(stringValue(incoming["msg_type"])))
	content, _ := normalizeFeishuContent(incoming["content"])

	switch msgType {
	case "text", "post", "interactive":
		text, err := resolveFeishuGroupRobotMessageText(incoming)
		if err != nil {
			return nil, false
		}
		title, body := splitGroupRobotCardTitleAndBody(text)
		linkURL := strings.TrimSpace(extractFeishuRobotCardLinkURL(incoming, content))
		payload := newGroupRobotCardPayload(identity, groupRobotProviderFeishu, msgType, title, body, "", linkURL)
		return payload, strings.TrimSpace(payload["plain_text"].(string)) != ""
	default:
		return nil, false
	}
}

func buildDingTalkRobotCardPayload(incoming map[string]interface{}, identity groupRobotDisplayIdentity) (map[string]interface{}, bool) {
	msgType := strings.TrimSpace(strings.ToLower(stringValue(incoming["msgtype"])))

	switch msgType {
	case "text", "markdown", "link", "actioncard":
		text, err := resolveDingTalkGroupRobotMessageText(incoming)
		if err != nil {
			return nil, false
		}
		title, body := splitGroupRobotCardTitleAndBody(text)
		linkURL := strings.TrimSpace(extractDingTalkRobotCardLinkURL(incoming))
		payload := newGroupRobotCardPayload(identity, groupRobotProviderDingTalk, msgType, title, body, "", linkURL)
		return payload, strings.TrimSpace(payload["plain_text"].(string)) != ""
	default:
		return nil, false
	}
}

func splitGroupRobotCardTitleAndBody(text string) (string, string) {
	lines := strings.Split(strings.TrimSpace(text), "\n")
	if len(lines) == 0 {
		return "", ""
	}
	title := strings.TrimSpace(lines[0])
	body := strings.TrimSpace(strings.Join(lines[1:], "\n"))
	if body == "" {
		return "", title
	}
	return title, body
}

func extractFeishuRobotCardLinkURL(incoming map[string]interface{}, content map[string]interface{}) string {
	card := mapValue(incoming["card"])
	if len(card) == 0 {
		card = normalizeJSONObject(content["card"])
	}
	if link := strings.TrimSpace(stringValue(firstFeishuValue(card, "url", "link"))); link != "" {
		return link
	}
	link := mapValue(card["link"])
	return strings.TrimSpace(stringValue(firstFeishuValue(link, "url", "href", "link")))
}

func extractDingTalkRobotCardLinkURL(incoming map[string]interface{}) string {
	if link := mapValue(incoming["link"]); len(link) > 0 {
		return strings.TrimSpace(stringValue(firstDingTalkValue(link, "messageUrl", "picUrl", "url")))
	}
	if card := mapValue(incoming["actionCard"]); len(card) > 0 {
		return strings.TrimSpace(stringValue(firstDingTalkValue(card, "singleURL", "actionURL", "url")))
	}
	return ""
}
```

```go
func applyGroupRobotDisplayMeta(payload map[string]interface{}, identity groupRobotDisplayIdentity) {
	if payload == nil {
		return
	}
	payload["robot"] = map[string]interface{}{
		"provider":       identity.Provider,
		"name":           identity.DisplayName,
		"avatar":         identity.DisplayAvatar,
		"display_name":   identity.DisplayName,
		"display_avatar": identity.DisplayAvatar,
	}
}
```

- [ ] **Step 4: Re-run the shared backend tests to verify the new contract passes**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestApplyGroupRobotDisplayMetaAddsRobotAliases|TestBuildFeishuRobotCardPayload|TestBuildDingTalkRobotCardPayload' -count=1`

Expected: PASS

- [ ] **Step 5: Record the checkpoint**

Checkpoint summary: `Shared robot-card payload builder exists, content type 22 is fixed, and backend robot metadata now emits both name/avatar and display_name/display_avatar aliases.`

### Task 2: Route Feishu And DingTalk Text-Like Webhooks Through Robot Card Normalization

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\feishu_group_bot_test.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoServer-main\modules\robot\dingtalk_group_bot_test.go`

- [ ] **Step 1: Write the failing provider integration tests that prove text-like webhooks now become type 22**

```go
func TestBuildFeishuGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes(t *testing.T) {
	rb := &Robot{}
	model := &feishuGroupRobotConfig{
		DisplayName:   "飞书机器人",
		DisplayAvatar: "robots/feishu/avatar.png",
	}
	incoming := map[string]interface{}{
		"msg_type": "interactive",
		"card": map[string]interface{}{
			"header": map[string]interface{}{
				"title": map[string]interface{}{"content": "消息通知"},
			},
			"elements": []interface{}{
				map[string]interface{}{
					"tag":     "markdown",
					"content": "feishu-link-test-001",
				},
			},
			"link": map[string]interface{}{"url": "https://example.com/detail"},
		},
	}

	payload, err := rb.buildFeishuGroupRobotMessagePayload("g_demo", model, incoming)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if payload["type"] != groupRobotCardContentType {
		t.Fatalf("expected robot card type, got %#v", payload["type"])
	}
	card := mapValue(payload["card"])
	if card["title"] != "消息通知" || card["body"] != "feishu-link-test-001" {
		t.Fatalf("unexpected card payload: %#v", card)
	}
}

func TestBuildDingTalkGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes(t *testing.T) {
	rb := &Robot{}
	model := &dingTalkGroupRobotConfig{
		DisplayName:   "钉钉机器人",
		DisplayAvatar: "robots/ding/avatar.png",
	}
	incoming := map[string]interface{}{
		"msgtype": "link",
		"link": map[string]interface{}{
			"title":      "发布通知已就绪",
			"text":       "dingtalk-link-test-001",
			"messageUrl": "https://example.com/detail",
		},
	}

	payload, err := rb.buildDingTalkGroupRobotMessagePayload("g_demo", model, incoming)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if payload["type"] != groupRobotCardContentType {
		t.Fatalf("expected robot card type, got %#v", payload["type"])
	}
	card := mapValue(payload["card"])
	if card["title"] != "发布通知已就绪" || card["body"] != "dingtalk-link-test-001" {
		t.Fatalf("unexpected card payload: %#v", card)
	}
}
```

- [ ] **Step 2: Run the provider integration tests to verify they fail first**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestBuildFeishuGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes|TestBuildDingTalkGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes' -count=1`

Expected: FAIL because the builders still return `common.Text` payloads for text-like webhooks

- [ ] **Step 3: Integrate the new robot-card helper into the Feishu and DingTalk webhook builders while keeping image/file paths unchanged**

```go
func (rb *Robot) buildFeishuGroupRobotMessagePayload(groupNo string, model *feishuGroupRobotConfig, incoming map[string]interface{}) (map[string]interface{}, error) {
	buildFallback := func() (map[string]interface{}, error) {
		text, err := resolveFeishuGroupRobotMessageText(incoming)
		if err != nil {
			return nil, err
		}
		return map[string]interface{}{
			"content": truncateRunes(text, 3000),
			"type":    common.Text,
		}, nil
	}

	identity := resolveGroupRobotDisplayIdentity(groupRobotProviderFeishu, model.DisplayName, model.DisplayAvatar)
	if payload, ok := buildFeishuRobotCardPayload(incoming, identity); ok {
		return payload, nil
	}

	msgType := strings.TrimSpace(stringValue(incoming["msg_type"]))
	content, _ := normalizeFeishuContent(incoming["content"])
	switch msgType {
	case "image":
		if payload, err := rb.buildFeishuImageRobotPayload(groupNo, model, content); err == nil && len(payload) > 0 {
			return payload, nil
		}
	case "file":
		if payload, err := rb.buildFeishuFileRobotPayload(groupNo, model, content); err == nil && len(payload) > 0 {
			return payload, nil
		}
	}

	return buildFallback()
}
```

```go
func (rb *Robot) buildDingTalkGroupRobotMessagePayload(groupNo string, model *dingTalkGroupRobotConfig, incoming map[string]interface{}) (map[string]interface{}, error) {
	identity := resolveGroupRobotDisplayIdentity(groupRobotProviderDingTalk, model.DisplayName, model.DisplayAvatar)
	if payload, ok := buildDingTalkRobotCardPayload(incoming, identity); ok {
		return payload, nil
	}

	msgType := strings.TrimSpace(stringValue(incoming["msgtype"]))
	if msgType == "image" {
		if payload, err := rb.buildDingTalkImageRobotPayload(groupNo, mapValue(incoming["image"])); err == nil && len(payload) > 0 {
			return payload, nil
		} else if err != nil {
			rb.logDingTalkRobotPayloadFallback(groupNo, msgType, err)
		}
	}

	text, err := resolveDingTalkGroupRobotMessageText(incoming)
	if err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"content": truncateRunes(text, 3000),
		"type":    common.Text,
	}, nil
}
```

- [ ] **Step 4: Re-run the provider integration tests and the existing robot formatter tests**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestBuildFeishuGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes|TestBuildDingTalkGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes|TestResolveFeishuGroupRobotMessageTextSupportsAllDocumentedTypes|TestResolveDingTalkGroupRobotMessageTextSupportsDocumentedTypes|TestResolveDingTalkGroupRobotMessageTextDeduplicatesRepeatedVisibleLines' -count=1`

Expected: PASS

- [ ] **Step 5: Record the checkpoint**

Checkpoint summary: `Feishu text/post/interactive and DingTalk text/markdown/link/actionCard now shape into robot_card.v1, while image/file flows keep the old payload paths.`

### Task 3: Register Flutter Robot Card Content And Push Plain Text Through Preview/Search Pipelines

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\wk_robot_card_content.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\wk_robot_card_content_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\core\constants\im_constants.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\msg\msg_content_type.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\im\im_service.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\robot_message_identity.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\message_content_preview.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\search_api.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\search\data\search_repository_impl.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\robot_message_identity_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_content_preview_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\conversation\conversation_list_page_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\search\search_repository_test.dart`

- [ ] **Step 1: Write the failing Flutter tests for decode, preview text, conversation preview, and remote search preview fallback**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/modules/chat/message_content_preview.dart';
import 'package:wukong_im_app/modules/conversation/conversation_list_page.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('WKRobotCardContent decodes plain text and searchable words', () {
    final content =
        WKRobotCardContent().decodeJson(<String, dynamic>{
              'schema': 'robot_card.v1',
              'platform': 'feishu',
              'origin_type': 'interactive',
              'robot': <String, dynamic>{
                'provider': 'feishu',
                'name': '飞书机器人',
                'avatar': 'robots/feishu/avatar.png',
              },
              'card': <String, dynamic>{
                'style': 'showcase',
                'title': '消息通知',
                'body': 'feishu-link-test-001',
                'badge': 'LINK',
                'link_url': 'https://example.com/detail',
                'link_mode': 'whole_card',
              },
              'plain_text': '消息通知 feishu-link-test-001',
            }) as WKRobotCardContent;

    expect(content.contentType, MsgContentType.robotCard);
    expect(content.displayText(), '消息通知 feishu-link-test-001');
    expect(content.searchableWord(), contains('飞书机器人'));
    expect(content.searchableWord(), contains('消息通知'));
    expect(content.isClickable, isTrue);
  });

  test('resolveMessagePreview uses robot card plain text', () {
    final message = WKMsg()
      ..contentType = MsgContentType.robotCard
      ..messageContent = (WKRobotCardContent()
        ..plainText = '消息通知 feishu-link-test-001'
        ..title = '消息通知'
        ..body = 'feishu-link-test-001');

    final preview = resolveMessagePreview(message);

    expect(preview.text, '消息通知 feishu-link-test-001');
    expect(preview.isSystemNotice, isFalse);
  });

  test('conversation preview prefixes robot name for robot-card group messages', () {
    final content = WKRobotCardContent()
      ..plainText = '消息通知 feishu-link-test-001'
      ..robotName = '飞书机器人';
    final message = WKMsg()
      ..contentType = MsgContentType.robotCard
      ..messageContent = content;

    expect(
      resolveConversationPreviewText(
        message,
        conversationChannelType: WKChannelType.group,
      ),
      '飞书机器人: 消息通知 feishu-link-test-001',
    );
  });
}
```

```dart
test('search repository prefers plain_text for robot card remote hits', () async {
  gateway.keywordResults = <Map<String, dynamic>>[
    <String, dynamic>{
      'channel_id': 'group-1',
      'channel_type': WKChannelType.group,
      'message_seq': 88,
      'order_seq': 1088,
      'timestamp': 1712123456,
      'content_type': MsgContentType.robotCard,
      'from_uid': 'u_robot',
      'from_name': '飞书机器人',
      'content': '{"type":22,"schema":"robot_card.v1"}',
      'plain_text': '消息通知 feishu-link-test-001',
    },
  ];

  final hits = await repository.searchMessages(
    channelId: 'group-1',
    channelType: WKChannelType.group,
    keyword: 'feishu',
    page: 1,
    limit: 20,
  );

  expect(hits.single.previewText, '消息通知 feishu-link-test-001');
});
```

- [ ] **Step 2: Run the Flutter preview/search tests to verify they fail first**

Run: `flutter test test/data/models/wk_robot_card_content_test.dart test/modules/chat/robot_message_identity_test.dart test/modules/chat/message_content_preview_test.dart test/modules/conversation/conversation_list_page_test.dart test/modules/search/search_repository_test.dart`

Expected: FAIL with missing content type `22`, missing `WKRobotCardContent`, or preview/search code paths still treating robot cards as unknown

- [ ] **Step 3: Implement the typed Flutter content model, registration, preview rules, and search fallbacks**

```dart
import 'package:wukongimfluttersdk/model/wk_message_content.dart';
import '../../wukong_base/msg/msg_content_type.dart';

class WKRobotCardContent extends WKMessageContent {
  String schema = 'robot_card.v1';
  String platform = '';
  String originType = '';
  String robotProvider = '';
  String robotName = '';
  String robotAvatar = '';
  String style = 'showcase';
  String title = '';
  String body = '';
  String badge = '';
  String linkUrl = '';
  String linkMode = 'whole_card';
  String plainText = '';

  WKRobotCardContent() {
    contentType = MsgContentType.robotCard;
  }

  bool get isClickable => linkUrl.trim().isNotEmpty;

  @override
  Map<String, dynamic> encodeJson() {
    return <String, dynamic>{
      'schema': schema,
      'platform': platform,
      'origin_type': originType,
      'robot': <String, dynamic>{
        'provider': robotProvider,
        'name': robotName,
        'avatar': robotAvatar,
      },
      'card': <String, dynamic>{
        'style': style,
        'title': title,
        'body': body,
        'badge': badge,
        'link_url': linkUrl,
        'link_mode': linkMode,
      },
      'plain_text': plainText,
    };
  }

  @override
  WKMessageContent decodeJson(Map<String, dynamic> json) {
    schema = json['schema']?.toString() ?? 'robot_card.v1';
    platform = json['platform']?.toString() ?? '';
    originType = json['origin_type']?.toString() ?? '';
    final robot = (json['robot'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final card = (json['card'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    robotProvider = robot['provider']?.toString() ?? '';
    robotName = (robot['name'] ?? robot['display_name'] ?? '').toString();
    robotAvatar = (robot['avatar'] ?? robot['display_avatar'] ?? '').toString();
    style = card['style']?.toString() ?? 'showcase';
    title = card['title']?.toString() ?? '';
    body = card['body']?.toString() ?? '';
    badge = card['badge']?.toString() ?? '';
    linkUrl = card['link_url']?.toString() ?? '';
    linkMode = card['link_mode']?.toString() ?? 'whole_card';
    plainText = json['plain_text']?.toString() ?? '';
    return this;
  }

  @override
  String displayText() {
    final text = plainText.trim();
    if (text.isNotEmpty) {
      return text;
    }
    return <String>[title.trim(), body.trim()].where((value) => value.isNotEmpty).join(' ');
  }

  @override
  String searchableWord() {
    return <String>[
      robotName.trim(),
      title.trim(),
      body.trim(),
      plainText.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
  }
}
```

```dart
class MsgContentType {
  MsgContentType._();

  static const int robotCard = 22;
}

class MessageContentType {
  MessageContentType._();

  static const int robotCard = 22;
}

void _registerMessageContents() {
  WKIM.shared.messageManager.registerMsgContent(
    MsgContentType.robotCard,
    (data) => WKRobotCardContent().decodeJson(_asMap(data)),
  );
}
```

```dart
RobotMessageIdentity? parseRobotMessageIdentity(Map<String, dynamic>? structuredPayload) {
  if (structuredPayload == null) {
    return null;
  }
  final robot = _asStringDynamicMap(structuredPayload['robot']);
  if (robot == null) {
    return null;
  }
  final displayName = _firstNonEmpty(<dynamic>[
    robot['name'],
    robot['display_name'],
    robot['displayName'],
  ]);
  final displayAvatar = resolveAvatarUrl(
    _firstNonEmpty(<dynamic>[
      robot['avatar'],
      robot['display_avatar'],
      robot['displayAvatar'],
    ]),
  );
  final provider = _firstNonEmpty(<dynamic>[robot['provider'], robot['robot_provider']]);
  if (provider.isEmpty && displayName.isEmpty && (displayAvatar?.isEmpty ?? true)) {
    return null;
  }
  return RobotMessageIdentity(
    provider: provider,
    displayName: displayName,
    displayAvatar: displayAvatar,
  );
}
```

```dart
MessagePreviewData resolveMessagePreview(WKMsg message, {String fallback = _messageFallback}) {
  final content = resolveVisibleMessageContent(message);
  switch (message.contentType) {
    case MsgContentType.robotCard:
      if (content is WKRobotCardContent && content.displayText().trim().isNotEmpty) {
        return MessagePreviewData(text: content.displayText().trim());
      }
      return const MessagePreviewData(text: '[机器人卡片]');
  }
}

String resolveConversationPreviewText(WKMsg? msg, {int? conversationChannelType}) {
  switch (msg?.contentType) {
    case MsgContentType.robotCard:
      preview = resolveMessagePreview(msg!).text.trim().isEmpty
          ? '[Robot Card]'
          : resolveMessagePreview(msg).text.trim();
      break;
  }
}

Future<List<Map<String, dynamic>>> searchMessagesByMember({
  required String channelId,
  required String senderId,
  String? keyword,
  int channelType = WKChannelType.group,
  int page = 1,
  int limit = 50,
}) async {
  return _normalizeMessages(await _searchGlobal(
    keyword: keyword?.trim() ?? '',
    onlyMessage: 1,
    channelId: channelId,
    channelType: channelType,
    fromUid: senderId,
    contentTypes: const <int>[
      WkMessageContentType.text,
      WkMessageContentType.file,
      MsgContentType.robotCard,
    ],
    page: page,
    limit: limit,
  ));
}

Future<List<Map<String, dynamic>>> searchLinks({
  required String channelId,
  int? channelType,
  int page = 1,
  int limit = 50,
}) async {
  final response = await _searchGlobal(
    keyword: '',
    onlyMessage: 1,
    channelId: channelId,
    channelType: channelType,
    contentTypes: const <int>[
      14,
      WkMessageContentType.text,
      MsgContentType.robotCard,
    ],
    page: page,
    limit: limit,
  );
  return _normalizeMessages(response['messages'])
      .where((message) => _readString(message, const ['link_url']).isNotEmpty)
      .toList(growable: false);
}

String _resolvePreviewText(Map<String, dynamic> item) {
  final plainText = _readOptionalString(item, 'plain_text');
  if (plainText != null && plainText.isNotEmpty) {
    return plainText;
  }
  final content = _readString(item, 'content');
  if (content.isNotEmpty) {
    return content;
  }
  return _readString(item, 'searchable_word');
}
```

- [ ] **Step 4: Re-run the Flutter preview/search tests and confirm the typed content model is wired up**

Run: `flutter test test/data/models/wk_robot_card_content_test.dart test/modules/chat/robot_message_identity_test.dart test/modules/chat/message_content_preview_test.dart test/modules/conversation/conversation_list_page_test.dart test/modules/search/search_repository_test.dart`

Expected: PASS

- [ ] **Step 5: Record the checkpoint**

Checkpoint summary: `Flutter recognizes content type 22, resolves robot name/avatar from name/avatar aliases, uses plain_text in previews, and remote search rows no longer fall back to raw JSON.`

### Task 4: Build The Premium Chat Card UI And Whole-Card Link Tap Path

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\robot_card_message.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\robot_message_card.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\robot_card_message_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page_shell.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_bubble_experience_test.dart`

- [ ] **Step 1: Write the failing view-data and widget tests for the premium card and whole-card click behavior**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukong_im_app/modules/chat/chat_message_mapper.dart';
import 'package:wukong_im_app/modules/chat/robot_card_message.dart';
import 'package:wukong_im_app/widgets/message_bubble.dart';
import 'package:wukong_im_app/wukong_base/msg/msg_content_type.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';
import 'package:wukongimfluttersdk/type/const.dart';

void main() {
  test('resolveRobotCardViewData returns whole-card link state', () {
    final message = WKMsg()
      ..channelType = WKChannelType.group
      ..contentType = MsgContentType.robotCard
      ..messageContent = (WKRobotCardContent()
        ..robotName = '飞书机器人'
        ..title = '消息通知'
        ..body = 'feishu-link-test-001'
        ..badge = 'LINK'
        ..linkUrl = 'https://example.com/detail'
        ..plainText = '消息通知 feishu-link-test-001');

    final data = resolveRobotCardViewData(message);

    expect(data, isNotNull);
    expect(data!.title, '消息通知');
    expect(data.body, 'feishu-link-test-001');
    expect(data.badge, 'LINK');
    expect(data.linkUrl, 'https://example.com/detail');
    expect(data.isClickable, isTrue);
  });

  testWidgets('message bubble renders premium robot card content', (tester) async {
    final message = WKMsg()
      ..fromUID = 'u_robot'
      ..channelType = WKChannelType.group
      ..contentType = MsgContentType.robotCard
      ..messageContent = (WKRobotCardContent()
        ..robotName = '飞书机器人'
        ..title = '消息通知'
        ..body = 'feishu-link-test-001'
        ..badge = 'LINK'
        ..linkUrl = 'https://example.com/detail'
        ..plainText = '消息通知 feishu-link-test-001')
      ..status = WKSendMsgResult.sendSuccess;

    final model = ChatMessageMapper().map(message, currentUid: 'u_self');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(model: model),
        ),
      ),
    );

    expect(find.byKey(const ValueKey<String>('robot-message-card')), findsOneWidget);
    expect(find.text('消息通知'), findsOneWidget);
    expect(find.text('feishu-link-test-001'), findsOneWidget);
    expect(find.text('LINK'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the robot-card UI tests to verify they fail first**

Run: `flutter test test/modules/chat/robot_card_message_test.dart test/modules/chat/message_bubble_experience_test.dart`

Expected: FAIL because there is no robot-card view model helper, no premium widget, and no message bubble case for content type 22

- [ ] **Step 3: Implement the robot-card view-data resolver, premium widget, and chat tap routing**

```dart
import 'package:wukong_im_app/data/models/wk_robot_card_content.dart';
import 'package:wukongimfluttersdk/entity/msg.dart';

class RobotCardViewData {
  const RobotCardViewData({
    required this.robotName,
    required this.robotAvatar,
    required this.title,
    required this.body,
    required this.badge,
    required this.linkUrl,
    required this.plainText,
  });

  final String robotName;
  final String robotAvatar;
  final String title;
  final String body;
  final String badge;
  final String linkUrl;
  final String plainText;

  bool get isClickable => linkUrl.trim().isNotEmpty;
}

RobotCardViewData? resolveRobotCardViewData(WKMsg message) {
  final content = message.messageContent;
  if (content is! WKRobotCardContent) {
    return null;
  }
  return RobotCardViewData(
    robotName: content.robotName.trim(),
    robotAvatar: content.robotAvatar.trim(),
    title: content.title.trim(),
    body: content.body.trim(),
    badge: content.badge.trim(),
    linkUrl: content.linkUrl.trim(),
    plainText: content.displayText().trim(),
  );
}
```

```dart
class RobotMessageCard extends StatelessWidget {
  const RobotMessageCard({
    super.key,
    required this.data,
    required this.timeText,
    required this.onTap,
  });

  final RobotCardViewData data;
  final String timeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('robot-message-card'),
        onTap: data.isClickable ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF1F2B3D), Color(0xFF38506E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(data.badge, style: const TextStyle(color: Color(0xFFFFD2A3), fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(data.title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(data.body, style: const TextStyle(color: Color(0xFFF7F3EF), fontSize: 14, height: 1.6)),
                const SizedBox(height: 14),
                Text('${data.robotName} · $timeText', style: const TextStyle(color: Color(0xCCF7F3EF), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

```dart
  Widget _buildContent({
  required BuildContext context,
  required String previewText,
  int? effectiveContentType,
}) {
  final resolvedContentType = effectiveContentType ?? _resolveEffectiveContentType();
  Widget content = switch (resolvedContentType) {
    MsgContentType.robotCard => _buildRobotCardContent(),
    WkMessageContentType.text => _buildTextContent(previewText),
    _ => _buildTextContent(previewText),
  };
  return content;
}

Widget _buildRobotCardContent() {
  final data = resolveRobotCardViewData(message);
  if (data == null) {
    return _buildTextContent(model.previewText);
  }
  final timeText = message.timestamp > 0 ? WKTimeUtils.formatTimeOnly(message.timestamp) : '';
  return RobotMessageCard(
    data: data,
    timeText: timeText,
    onTap: onTap,
  );
}
```

```dart
final bubble = GestureDetector(
  onTap: effectiveContentType == MsgContentType.robotCard ? null : onTap,
  onLongPress: onLongPress,
  onSecondaryTapDown: onSecondaryTapDown,
  child: Container(
    key: const ValueKey<String>('message-bubble-body'),
  ),
);

VoidCallback? _messageTapHandler(ChatMessageViewModel model, ChatViewportState viewport) {
  switch (_resolvedMessageContentType(model)) {
    case MsgContentType.robotCard:
    case WkMessageContentType.image:
    case WkMessageContentType.file:
    case WkMessageContentType.location:
    case WkMessageContentType.card:
      return () => unawaited(_handleMessageTap(model, viewport));
    default:
      return null;
  }
}

Future<void> _handleMessageTap(ChatMessageViewModel model, ChatViewportState viewport) async {
  switch (_resolvedMessageContentType(model)) {
    case MsgContentType.robotCard:
      final data = resolveRobotCardViewData(model.message);
      final uri = Uri.tryParse(data?.linkUrl ?? '');
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
  }
}
```

- [ ] **Step 4: Re-run the robot-card UI tests and verify card rendering plus whole-card taps are wired**

Run: `flutter test test/modules/chat/robot_card_message_test.dart test/modules/chat/message_bubble_experience_test.dart`

Expected: PASS

- [ ] **Step 5: Record the checkpoint**

Checkpoint summary: `Chat bubbles now render the premium showcase card, and message taps route robot-card links through whole-card external launch behavior.`

### Task 5: Verify Search Coverage, Windows Desktop Smoke, And Production Deploy Sequence

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\search\local_search_service_test.dart`

- [ ] **Step 1: Add the failing local-search test that proves typed robot-card content remains discoverable through searchableWord/displayText**

```dart
test('local search uses robot card display text for per-message previews', () async {
  final service = LocalSearchService(
    searchChannels: (_) async => const <WKChannelSearchResult>[],
    searchFollowedUsers: (_, __, ___) async => const <WKChannel>[],
    searchGlobalMessages: (_) async => const <WKMessageSearchResult>[],
    searchMessagesWithChannel: (_, __, ___) async => <WKMsg>[
      WKMsg()
        ..channelID = 'group-1'
        ..channelType = WKChannelType.group
        ..messageSeq = 501
        ..orderSeq = 1501
        ..timestamp = 1712123999
        ..fromUID = 'u_robot'
        ..contentType = MsgContentType.robotCard
        ..messageID = 'robot-card-501'
        ..messageContent = (WKRobotCardContent()
          ..robotName = '飞书机器人'
          ..title = '消息通知'
          ..body = 'feishu-link-test-001'
          ..plainText = '消息通知 feishu-link-test-001'),
    ],
  );

  final hits = await service.searchMessages(
    channelId: 'group-1',
    channelType: WKChannelType.group,
    keyword: 'feishu',
    page: 1,
    limit: 20,
  );

  expect(hits.single.previewText, '消息通知 feishu-link-test-001');
});
```

- [ ] **Step 2: Run the full focused test suite before any manual smoke testing**

Run: `& 'C:\Users\COLORFUL\.codex\toolchains\go1.20.14\go\bin\go.exe' test ./modules/robot -run 'TestApplyGroupRobotDisplayMetaAddsRobotAliases|TestBuildFeishuRobotCardPayload|TestBuildDingTalkRobotCardPayload|TestBuildFeishuGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes|TestBuildDingTalkGroupRobotMessagePayloadPrefersRobotCardForTextLikeTypes' -count=1`

Run: `flutter test test/data/models/wk_robot_card_content_test.dart test/modules/chat/robot_card_message_test.dart test/modules/chat/robot_message_identity_test.dart test/modules/chat/message_content_preview_test.dart test/modules/conversation/conversation_list_page_test.dart test/modules/search/local_search_service_test.dart test/modules/search/search_repository_test.dart test/modules/chat/message_bubble_experience_test.dart`

Expected: PASS for both commands

- [ ] **Step 3: Run desktop and live-environment smoke verification**

Run: `flutter run -d windows --no-resident`

Expected: Windows app launches and reaches the login or message surface without a startup regression

Run: `ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose build tsdd-api && docker compose up -d tsdd-api"`

Expected: `tsdd-api` rebuilds and restarts cleanly

Then verify these manual cases in the live IM group:

1. Send one Feishu `interactive` message and confirm the group chat shows the premium card with title, body, badge, and whole-card click.
2. Send one DingTalk `actionCard` or `link` message and confirm it renders with the same premium card skin rather than provider-native styling.
3. Confirm the conversation list preview is text-only and prefixed with the robot name in group chat.
4. Search for the card title or body and confirm the result opens the original message location instead of a blank conversation state.
5. Confirm reply/pin/favorite style surfaces show lightweight text preview rather than a broken or oversized card fragment.

- [ ] **Step 4: Record the final checkpoint**

Checkpoint summary: `Robot cards pass focused backend and Flutter tests, Windows desktop launches, live webhook traffic renders as premium cards, and search/preview flows stay stable.`
