package robot

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"mime"
	"net/http"
	"net/url"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/common"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	_ "golang.org/x/image/webp"
)

const feishuGroupRobotWebhookSignTTLSeconds = 60 * 60

var feishuMarkdownImagePattern = regexp.MustCompile(`!\[[^\]]*\]\((https?://[^\s)]+)\)`)

type feishuGroupRobotResp struct {
	GroupNo            string `json:"group_no"`
	WebhookURL         string `json:"webhook_url"`
	Secret             string `json:"secret"`
	WebhookMode        string `json:"webhook_mode"`
	OfficialWebhookURL string `json:"official_webhook_url"`
	OfficialSecret     string `json:"official_secret"`
	AppID              string `json:"app_id"`
	AppSecret          string `json:"app_secret"`
	DisplayName        string `json:"display_name"`
	DisplayAvatar      string `json:"display_avatar"`
	Enabled            int    `json:"enabled"`
	SecretSet          bool   `json:"secret_set"`
	AppSecretSet       bool   `json:"app_secret_set"`
	LastPushAt         int64  `json:"last_push_at"`
	LastError          string `json:"last_error"`
	UpdatedAt          string `json:"updated_at"`
}

type upsertFeishuGroupRobotReq struct {
	Enabled            *int    `json:"enabled"`
	RegenerateWebhook  *int    `json:"regenerate_webhook"`
	RegenerateSecret   *int    `json:"regenerate_secret"`
	WebhookMode        *string `json:"webhook_mode"`
	OfficialWebhookURL *string `json:"official_webhook_url"`
	OfficialSecret     *string `json:"official_secret"`
	AppID              *string `json:"app_id"`
	AppSecret          *string `json:"app_secret"`
	DisplayName        *string `json:"display_name"`
	DisplayAvatar      *string `json:"display_avatar"`
}

func newFeishuGroupRobotResp(model *feishuGroupRobotConfig, webhookURL string) *feishuGroupRobotResp {
	if model == nil {
		return nil
	}
	secret := strings.TrimSpace(model.Secret)
	appSecret := strings.TrimSpace(model.AppSecret)
	webhookMode := normalizeGroupRobotWebhookMode(model.WebhookMode)
	return &feishuGroupRobotResp{
		GroupNo:            model.GroupNo,
		WebhookURL:         webhookURL,
		Secret:             secret,
		WebhookMode:        webhookMode,
		OfficialWebhookURL: strings.TrimSpace(model.OfficialWebhookURL),
		OfficialSecret:     strings.TrimSpace(model.OfficialSecret),
		AppID:              strings.TrimSpace(model.AppID),
		AppSecret:          appSecret,
		DisplayName:        strings.TrimSpace(model.DisplayName),
		DisplayAvatar:      strings.TrimSpace(model.DisplayAvatar),
		Enabled:            model.Enabled,
		SecretSet:          secret != "",
		AppSecretSet:       appSecret != "",
		LastPushAt:         model.LastPushAt,
		LastError:          model.LastError,
		UpdatedAt:          model.UpdatedAt.String(),
	}
}

func (rb *Robot) getFeishuGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageFeishuGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	model, err := rb.db.queryFeishuGroupRobot(groupNo)
	if err != nil {
		rb.Error("load feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("load feishu robot config failed"))
		return
	}
	if model == nil {
		c.Response(map[string]interface{}{})
		return
	}
	c.Response(newFeishuGroupRobotResp(model, rb.buildFeishuGroupRobotWebhookURL(groupNo, extractFeishuGroupRobotToken(model.WebhookURL), c.Request)))
}

func (rb *Robot) upsertFeishuGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageFeishuGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	var req upsertFeishuGroupRobotReq
	if c.Request != nil && c.Request.Body != nil {
		rawBody, err := io.ReadAll(c.Request.Body)
		if err != nil {
			c.ResponseError(errors.New("read request body failed"))
			return
		}
		if len(bytes.TrimSpace(rawBody)) > 0 {
			decoder := json.NewDecoder(bytes.NewReader(rawBody))
			decoder.UseNumber()
			if err := decoder.Decode(&req); err != nil {
				c.ResponseError(errors.New("invalid request body"))
				return
			}
		}
	}

	enabled := 1
	if req.Enabled != nil && *req.Enabled == 0 {
		enabled = 0
	}

	existing, err := rb.db.queryFeishuGroupRobot(groupNo)
	if err != nil {
		rb.Error("load feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("save feishu robot config failed"))
		return
	}

	isCreate := existing == nil
	if isCreate {
		existing = &feishuGroupRobotConfig{
			GroupNo:    groupNo,
			CreatedUID: loginUID,
		}
	}

	token := extractFeishuGroupRobotToken(existing.WebhookURL)
	if token == "" || intPointerTrue(req.RegenerateWebhook) {
		token = generateFeishuGroupRobotToken()
	}

	secret := strings.TrimSpace(existing.Secret)
	if secret == "" || intPointerTrue(req.RegenerateSecret) {
		secret = generateFeishuGroupRobotSecret()
	}

	existing.WebhookURL = token
	existing.Secret = secret
	if req.AppID != nil {
		existing.AppID = strings.TrimSpace(*req.AppID)
	}
	if req.AppSecret != nil {
		existing.AppSecret = strings.TrimSpace(*req.AppSecret)
	}
	if req.DisplayName != nil {
		existing.DisplayName = strings.TrimSpace(*req.DisplayName)
	}
	if req.DisplayAvatar != nil {
		existing.DisplayAvatar = strings.TrimSpace(*req.DisplayAvatar)
	}
	if err := applyFeishuWebhookModeUpdate(existing, &req); err != nil {
		c.ResponseError(err)
		return
	}
	existing.Enabled = enabled
	existing.UpdatedUID = loginUID
	if intPointerTrue(req.RegenerateWebhook) || intPointerTrue(req.RegenerateSecret) {
		existing.LastError = ""
	}

	if isCreate {
		if err := rb.db.insertFeishuGroupRobot(existing); err != nil {
			rb.Error("create feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
			c.ResponseError(errors.New("save feishu robot config failed"))
			return
		}
	} else {
		if err := rb.db.updateFeishuGroupRobot(existing); err != nil {
			rb.Error("update feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
			c.ResponseError(errors.New("save feishu robot config failed"))
			return
		}
	}

	current, err := rb.db.queryFeishuGroupRobot(groupNo)
	if err != nil {
		rb.Error("load saved feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("save feishu robot config failed"))
		return
	}
	c.Response(newFeishuGroupRobotResp(current, rb.buildFeishuGroupRobotWebhookURL(groupNo, extractFeishuGroupRobotToken(current.WebhookURL), c.Request)))
}

func applyFeishuWebhookModeUpdate(model *feishuGroupRobotConfig, req *upsertFeishuGroupRobotReq) error {
	if model == nil {
		return nil
	}

	webhookModeRaw := model.WebhookMode
	if req != nil && req.WebhookMode != nil {
		webhookModeRaw = *req.WebhookMode
	}
	nextMode := normalizeGroupRobotWebhookMode(webhookModeRaw)
	if nextMode == groupRobotWebhookModeOfficial {
		if req != nil && req.OfficialWebhookURL != nil {
			model.OfficialWebhookURL = strings.TrimSpace(*req.OfficialWebhookURL)
		}
		if req != nil && req.OfficialSecret != nil {
			model.OfficialSecret = strings.TrimSpace(*req.OfficialSecret)
		}
		if err := validateFeishuOfficialWebhookURL(model.OfficialWebhookURL); err != nil {
			return err
		}
	}
	model.WebhookMode = nextMode
	return nil
}

func (rb *Robot) deleteFeishuGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageFeishuGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	if err := rb.db.deleteFeishuGroupRobot(groupNo); err != nil {
		rb.Error("delete feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("delete feishu robot config failed"))
		return
	}
	c.ResponseOK()
}

func (rb *Robot) testFeishuGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageFeishuGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	model, err := rb.db.queryFeishuGroupRobot(groupNo)
	if err != nil {
		rb.Error("load feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("send test message failed"))
		return
	}
	if model == nil {
		c.ResponseError(errors.New("please create the feishu robot config first"))
		return
	}

	text := truncateRunes(fmt.Sprintf("[Feishu Robot]\nCompatibility test message\nGroup: %s\nOperator: %s\nTime: %s\nNote: this message confirms the generated webhook and sign secret are working.",
		rb.resolveGroupName(groupNo),
		loginUID,
		time.Now().Format("2006-01-02 15:04:05"),
	), 3000)
	if err := rb.sendFeishuGroupRobotTextMessage(groupNo, model, text); err != nil {
		rb.Error("send feishu robot test message failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateFeishuGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		c.ResponseError(fmt.Errorf("send test message failed: %w", err))
		return
	}
	_ = rb.db.updateFeishuGroupRobotPushState(groupNo, time.Now().Unix(), "")
	c.ResponseOK()
}

func (rb *Robot) receiveFeishuGroupRobotWebhook(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	token := strings.TrimSpace(c.Param("token"))
	if groupNo == "" || token == "" {
		respondFeishuGroupRobotWebhook(c, 19001, "invalid webhook")
		return
	}

	model, err := rb.db.queryFeishuGroupRobot(groupNo)
	if err != nil {
		rb.Error("load feishu robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		respondFeishuGroupRobotWebhook(c, 19001, "load robot config failed")
		return
	}
	if model == nil {
		respondFeishuGroupRobotWebhook(c, 19001, "robot config not found")
		return
	}
	if model.Enabled == 0 {
		respondFeishuGroupRobotWebhook(c, 19001, "robot disabled")
		return
	}
	if token != extractFeishuGroupRobotToken(model.WebhookURL) {
		respondFeishuGroupRobotWebhook(c, 19001, "invalid webhook token")
		return
	}

	payload, err := decodeFeishuGroupRobotPayload(c.Request)
	if err != nil {
		rb.Warn("decode feishu robot webhook payload failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateFeishuGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondFeishuGroupRobotWebhook(c, 19002, "invalid payload")
		return
	}

	if err := validateFeishuGroupRobotSignature(payload, strings.TrimSpace(model.Secret)); err != nil {
		rb.Warn("validate feishu robot signature failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateFeishuGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondFeishuGroupRobotWebhook(c, 19003, err.Error())
		return
	}

	messagePayload, err := rb.buildFeishuGroupRobotMessagePayload(groupNo, model, payload)
	if err != nil {
		rb.Warn("build feishu robot message payload failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateFeishuGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondFeishuGroupRobotWebhook(c, 19004, err.Error())
		return
	}

	if err := rb.sendFeishuGroupRobotPayload(groupNo, model, messagePayload); err != nil {
		rb.Warn("deliver feishu robot message failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateFeishuGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondFeishuGroupRobotWebhook(c, 19005, "deliver message failed")
		return
	}

	_ = rb.db.updateFeishuGroupRobotPushState(groupNo, time.Now().Unix(), "")
	respondFeishuGroupRobotWebhook(c, 0, "ok")
}

func (rb *Robot) ensureManageFeishuGroupRobot(groupNo, loginUID string) error {
	if groupNo == "" {
		return errors.New("group_no is required")
	}
	if loginUID == "" {
		return errors.New("login required")
	}

	exist, err := rb.groupService.ExistMember(groupNo, loginUID)
	if err != nil {
		return errors.New("check group membership failed")
	}
	if !exist {
		return errors.New("current user is not in the group")
	}

	allowed, err := rb.groupService.IsCreatorOrManager(groupNo, loginUID)
	if err != nil {
		return errors.New("check group admin permission failed")
	}
	if !allowed {
		return errors.New("only group owners or admins can manage the feishu robot")
	}
	return nil
}

func (rb *Robot) sendFeishuGroupRobotTextMessage(groupNo string, model *feishuGroupRobotConfig, text string) error {
	return rb.sendFeishuGroupRobotPayload(groupNo, model, map[string]interface{}{
		"content": truncateRunes(text, 3000),
		"type":    common.Text,
	})
}

func decorateFeishuGroupRobotPayload(payload map[string]interface{}, model *feishuGroupRobotConfig) {
	configuredName := ""
	configuredAvatar := ""
	if model != nil {
		configuredName = model.DisplayName
		configuredAvatar = model.DisplayAvatar
	}
	identity := resolveGroupRobotDisplayIdentity(groupRobotProviderFeishu, configuredName, configuredAvatar)
	applyGroupRobotDisplayMeta(payload, identity)
}

func (rb *Robot) sendFeishuGroupRobotPayload(groupNo string, model *feishuGroupRobotConfig, payload map[string]interface{}) error {
	if len(payload) == 0 {
		return errors.New("payload is empty")
	}
	decorateFeishuGroupRobotPayload(payload, model)
	return rb.ctx.SendMessage(&config.MsgSendReq{
		FromUID:     rb.ctx.GetConfig().Account.SystemUID,
		ChannelID:   groupNo,
		ChannelType: common.ChannelTypeGroup.Uint8(),
		Payload:     []byte(util.ToJson(payload)),
		Header: config.MsgHeader{
			RedDot: 1,
		},
	})
}

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

	msgType := strings.TrimSpace(stringValue(incoming["msg_type"]))
	if msgType == "" {
		return buildFallback()
	}

	content, _ := normalizeFeishuContent(incoming["content"])
	messageID := extractFeishuMessageID(incoming)
	if msgType == "post" || msgType == "interactive" {
		if imageContent, ok := findFeishuImageContent(incoming, content); ok {
			if messageID != "" {
				imageContent["message_id"] = messageID
			}
			if imageURL := findFeishuDirectImageURL(incoming, content); imageURL != "" && strings.TrimSpace(stringValue(firstFeishuValue(imageContent, "image_url", "imageUrl", "url"))) == "" {
				imageContent["image_url"] = imageURL
			}
			if payload, err := rb.buildFeishuImageRobotPayload(groupNo, model, imageContent); err == nil && len(payload) > 0 {
				return payload, nil
			} else if err != nil {
				if payload, ok := buildFeishuDirectImageURLRobotPayload(incoming, content, imageContent); ok {
					rb.logFeishuRobotPayloadURLFallback(groupNo, msgType, err, payload)
					return payload, nil
				}
				rb.logFeishuRobotPayloadFallback(groupNo, msgType, err, imageContent)
			}
		}
	}
	if payload, ok := buildFeishuMarkdownImageRobotPayload(incoming, content); ok {
		return payload, nil
	}
	switch msgType {
	case "image":
		if messageID != "" {
			content["message_id"] = messageID
		}
		if payload, err := rb.buildFeishuImageRobotPayload(groupNo, model, content); err == nil && len(payload) > 0 {
			return payload, nil
		} else if err != nil {
			rb.logFeishuRobotPayloadFallback(groupNo, msgType, err)
		}
	case "file":
		if payload, err := rb.buildFeishuFileRobotPayload(groupNo, model, content); err == nil && len(payload) > 0 {
			return payload, nil
		} else if err != nil {
			rb.logFeishuRobotPayloadFallback(groupNo, msgType, err)
		}
	case "audio":
		if payload, err := rb.buildFeishuAudioRobotPayload(groupNo, model, content); err == nil && len(payload) > 0 {
			return payload, nil
		} else if err != nil {
			rb.logFeishuRobotPayloadFallback(groupNo, msgType, err)
		}
	case "media":
		if payload, err := rb.buildFeishuVideoRobotPayload(groupNo, model, content); err == nil && len(payload) > 0 {
			return payload, nil
		} else if err != nil {
			rb.logFeishuRobotPayloadFallback(groupNo, msgType, err)
		}
	case "sticker":
		if payload, err := rb.buildFeishuStickerRobotPayload(groupNo, model, content); err == nil && len(payload) > 0 {
			return payload, nil
		} else if err != nil {
			rb.logFeishuRobotPayloadFallback(groupNo, msgType, err)
		}
	case "share_user":
		if payload := buildFeishuShareUserRobotPayload(content); len(payload) > 0 {
			return payload, nil
		}
	}

	return buildFallback()
}

func findFeishuImageContent(values ...interface{}) (map[string]interface{}, bool) {
	for _, value := range values {
		if content, ok := findFeishuImageContentValue(value); ok {
			return content, true
		}
	}
	return nil, false
}

func findFeishuImageContentValue(value interface{}) (map[string]interface{}, bool) {
	switch typed := value.(type) {
	case nil:
		return nil, false
	case map[string]interface{}:
		if content, ok := feishuImageContentFromMap(typed); ok {
			return content, true
		}
		for _, child := range typed {
			if content, ok := findFeishuImageContentValue(child); ok {
				return content, true
			}
		}
	case gin.H:
		return findFeishuImageContentValue(map[string]interface{}(typed))
	case []interface{}:
		for _, child := range typed {
			if content, ok := findFeishuImageContentValue(child); ok {
				return content, true
			}
		}
	case string:
		trimmed := strings.TrimSpace(typed)
		if trimmed == "" || !looksLikeFeishuJSONObject(trimmed) {
			return nil, false
		}
		var decoded interface{}
		decoder := json.NewDecoder(strings.NewReader(trimmed))
		decoder.UseNumber()
		if err := decoder.Decode(&decoded); err != nil {
			return nil, false
		}
		return findFeishuImageContentValue(decoded)
	}
	return nil, false
}

func feishuImageContentFromMap(value map[string]interface{}) (map[string]interface{}, bool) {
	if len(value) == 0 {
		return nil, false
	}
	tag := strings.TrimSpace(stringValue(value["tag"]))
	msgType := strings.TrimSpace(stringValue(value["msg_type"]))
	isImageNode := tag == "img" || tag == "image" || msgType == "image" || strings.TrimSpace(stringValue(firstFeishuValue(value, "image_key", "imageKey", "img_key", "imgKey", "image_url", "imageUrl"))) != ""
	if !isImageNode {
		return nil, false
	}

	content := map[string]interface{}{}
	if key := strings.TrimSpace(stringValue(firstFeishuValue(value, "image_key", "imageKey", "img_key", "imgKey"))); key != "" {
		content["image_key"] = key
	}
	if messageID := strings.TrimSpace(stringValue(firstFeishuValue(value, "message_id", "messageId", "open_message_id", "openMessageId"))); messageID != "" {
		content["message_id"] = messageID
	}
	if imageURL := strings.TrimSpace(stringValue(firstFeishuValue(value, "image_url", "imageUrl", "url", "href", "src"))); imageURL != "" {
		content["image_url"] = imageURL
	}
	for _, key := range []string{"width", "height", "image_width", "image_height"} {
		if raw, ok := value[key]; ok && strings.TrimSpace(stringValue(raw)) != "" {
			content[key] = raw
		}
	}
	if len(content) == 0 {
		return nil, false
	}
	return content, true
}

func buildFeishuDirectImageURLRobotPayload(values ...interface{}) (map[string]interface{}, bool) {
	imageURL := findFeishuDirectImageURL(values...)
	if imageURL == "" {
		return nil, false
	}
	return map[string]interface{}{
		"type":   common.Image,
		"url":    imageURL,
		"width":  int64(0),
		"height": int64(0),
	}, true
}

func findFeishuDirectImageURL(values ...interface{}) string {
	for _, value := range values {
		if imageURL := strings.TrimSpace(findFeishuDirectImageURLValue(value)); imageURL != "" {
			return imageURL
		}
	}
	return ""
}

func findFeishuDirectImageURLValue(value interface{}) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case map[string]interface{}:
		for _, key := range []string{"image_url", "imageUrl", "pic_url", "picUrl", "img_url", "imgUrl", "origin_url", "originUrl", "download_url", "downloadUrl"} {
			if imageURL := strings.TrimSpace(stringValue(typed[key])); strings.HasPrefix(strings.ToLower(imageURL), "http://") || strings.HasPrefix(strings.ToLower(imageURL), "https://") {
				return imageURL
			}
		}
		for _, key := range []string{"url", "href", "src"} {
			if imageURL := strings.TrimSpace(stringValue(typed[key])); looksLikeHTTPImageURL(imageURL) {
				return imageURL
			}
		}
		for _, child := range typed {
			if imageURL := findFeishuDirectImageURLValue(child); imageURL != "" {
				return imageURL
			}
		}
	case gin.H:
		return findFeishuDirectImageURLValue(map[string]interface{}(typed))
	case []interface{}:
		for _, child := range typed {
			if imageURL := findFeishuDirectImageURLValue(child); imageURL != "" {
				return imageURL
			}
		}
	case string:
		trimmed := strings.TrimSpace(typed)
		if trimmed == "" {
			return ""
		}
		if looksLikeFeishuJSONObject(trimmed) {
			var decoded interface{}
			decoder := json.NewDecoder(strings.NewReader(trimmed))
			decoder.UseNumber()
			if err := decoder.Decode(&decoded); err == nil {
				return findFeishuDirectImageURLValue(decoded)
			}
		}
		if looksLikeHTTPImageURL(trimmed) {
			return trimmed
		}
	}
	return ""
}

func looksLikeHTTPImageURL(value string) bool {
	value = strings.TrimSpace(value)
	lower := strings.ToLower(value)
	if !(strings.HasPrefix(lower, "http://") || strings.HasPrefix(lower, "https://")) {
		return false
	}
	if strings.Contains(lower, "qpic.cn/") || strings.Contains(lower, "image") || strings.Contains(lower, "img") || strings.Contains(lower, "pic") {
		return true
	}
	for _, ext := range []string{".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"} {
		if strings.Contains(lower, ext) {
			return true
		}
	}
	return false
}

func buildFeishuMarkdownImageRobotPayload(values ...interface{}) (map[string]interface{}, bool) {
	imageURL := findFeishuMarkdownImageURL(values...)
	if imageURL == "" {
		return nil, false
	}
	return map[string]interface{}{
		"type":   common.Image,
		"url":    imageURL,
		"width":  int64(0),
		"height": int64(0),
	}, true
}

func findFeishuMarkdownImageURL(values ...interface{}) string {
	for _, value := range values {
		if imageURL := strings.TrimSpace(findFeishuMarkdownImageURLValue(value)); imageURL != "" {
			return imageURL
		}
	}
	return ""
}

func findFeishuMarkdownImageURLValue(value interface{}) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case map[string]interface{}:
		for _, key := range []string{"text", "content", "markdown"} {
			if imageURL := findFeishuMarkdownImageURLValue(typed[key]); imageURL != "" {
				return imageURL
			}
		}
		for _, child := range typed {
			if imageURL := findFeishuMarkdownImageURLValue(child); imageURL != "" {
				return imageURL
			}
		}
	case gin.H:
		return findFeishuMarkdownImageURLValue(map[string]interface{}(typed))
	case []interface{}:
		for _, child := range typed {
			if imageURL := findFeishuMarkdownImageURLValue(child); imageURL != "" {
				return imageURL
			}
		}
	case string:
		trimmed := strings.TrimSpace(typed)
		if trimmed == "" {
			return ""
		}
		if looksLikeFeishuJSONObject(trimmed) {
			var decoded interface{}
			decoder := json.NewDecoder(strings.NewReader(trimmed))
			decoder.UseNumber()
			if err := decoder.Decode(&decoded); err == nil {
				return findFeishuMarkdownImageURLValue(decoded)
			}
		}
		matches := feishuMarkdownImagePattern.FindStringSubmatch(trimmed)
		if len(matches) > 1 {
			return strings.TrimSpace(matches[1])
		}
	}
	return ""
}

func extractFeishuMessageID(values ...interface{}) string {
	for _, value := range values {
		if messageID := strings.TrimSpace(extractFeishuMessageIDValue(value)); messageID != "" {
			return messageID
		}
	}
	return ""
}

func extractFeishuMessageIDValue(value interface{}) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case map[string]interface{}:
		for _, key := range []string{"message_id", "messageId", "open_message_id", "openMessageId"} {
			if messageID := strings.TrimSpace(stringValue(typed[key])); messageID != "" {
				return messageID
			}
		}
		for _, key := range []string{"event", "message", "body", "data"} {
			if messageID := extractFeishuMessageIDValue(typed[key]); messageID != "" {
				return messageID
			}
		}
		for _, child := range typed {
			if messageID := extractFeishuMessageIDValue(child); messageID != "" {
				return messageID
			}
		}
	case gin.H:
		return extractFeishuMessageIDValue(map[string]interface{}(typed))
	case []interface{}:
		for _, child := range typed {
			if messageID := extractFeishuMessageIDValue(child); messageID != "" {
				return messageID
			}
		}
	case string:
		trimmed := strings.TrimSpace(typed)
		if trimmed == "" || !looksLikeFeishuJSONObject(trimmed) {
			return ""
		}
		var decoded interface{}
		decoder := json.NewDecoder(strings.NewReader(trimmed))
		decoder.UseNumber()
		if err := decoder.Decode(&decoded); err != nil {
			return ""
		}
		return extractFeishuMessageIDValue(decoded)
	}
	return ""
}

func isFeishuResourceSenderError(err error) bool {
	if err == nil {
		return false
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "234008") || strings.Contains(message, "resource sender")
}

func (rb *Robot) logFeishuRobotPayloadFallback(groupNo, msgType string, err error, content ...map[string]interface{}) {
	if err == nil {
		return
	}
	fields := []zap.Field{
		zap.String("groupNo", groupNo),
		zap.String("msgType", msgType),
		zap.Error(err),
	}
	if len(content) > 0 && content[0] != nil {
		fields = append(fields,
			zap.Bool("hasMessageID", strings.TrimSpace(stringValue(firstFeishuValue(content[0], "message_id", "messageId", "open_message_id", "openMessageId"))) != ""),
			zap.Bool("hasImageURL", strings.TrimSpace(stringValue(firstFeishuValue(content[0], "image_url", "imageUrl", "url"))) != ""),
			zap.Bool("hasImageKey", strings.TrimSpace(stringValue(firstFeishuValue(content[0], "image_key", "imageKey", "img_key", "imgKey"))) != ""),
		)
	}
	rb.Warn("fall back to feishu text delivery", fields...)
}

func (rb *Robot) logFeishuRobotPayloadURLFallback(groupNo, msgType string, err error, payload map[string]interface{}) {
	if err == nil {
		return
	}
	rb.Warn("fall back to feishu image url delivery",
		zap.String("groupNo", groupNo),
		zap.String("msgType", msgType),
		zap.Bool("hasURL", strings.TrimSpace(stringValue(payload["url"])) != ""),
		zap.Error(err),
	)
}

func (rb *Robot) buildFeishuImageRobotPayload(groupNo string, model *feishuGroupRobotConfig, content map[string]interface{}) (map[string]interface{}, error) {
	imageURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "image_url", "imageUrl", "url")))
	if imageURL != "" && !rb.hasFeishuOpenAPICredentials(model) {
		return map[string]interface{}{
			"type":   common.Image,
			"url":    imageURL,
			"width":  intValue(firstFeishuValue(content, "width", "image_width")),
			"height": intValue(firstFeishuValue(content, "height", "image_height")),
		}, nil
	}

	imageKey := strings.TrimSpace(stringValue(content["image_key"]))
	if imageKey == "" {
		if imageURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "image_url", "imageUrl", "url"))); imageURL != "" {
			return map[string]interface{}{
				"type":   common.Image,
				"url":    imageURL,
				"width":  intValue(firstFeishuValue(content, "width", "image_width")),
				"height": intValue(firstFeishuValue(content, "height", "image_height")),
			}, nil
		}
		return nil, errors.New("image_key is required")
	}
	if !rb.hasFeishuOpenAPICredentials(model) {
		return nil, errors.New("feishu app credentials are not configured")
	}

	resource, err := rb.downloadFeishuImageResource(model, imageKey)
	if err != nil && isFeishuResourceSenderError(err) {
		if messageID := strings.TrimSpace(stringValue(firstFeishuValue(content, "message_id", "messageId", "open_message_id", "openMessageId"))); messageID != "" {
			resource, err = rb.downloadFeishuMessageImageResource(model, messageID, imageKey)
		}
	}
	if err != nil {
		if imageURL != "" && isFeishuResourceSenderError(err) {
			return map[string]interface{}{
				"type":   common.Image,
				"url":    imageURL,
				"width":  intValue(firstFeishuValue(content, "width", "image_width")),
				"height": intValue(firstFeishuValue(content, "height", "image_height")),
			}, nil
		}
		return nil, err
	}
	fileName := resource.FileName
	if strings.TrimSpace(fileName) == "" {
		fileName = imageKey + preferredExtForContentType(resource.ContentType)
	}
	previewURL, finalName, _, err := rb.uploadFeishuBinaryToWK(groupNo, fileName, resource.ContentType, resource.Data)
	if err != nil {
		return nil, err
	}
	width, height := detectFeishuImageSize(resource.Data)
	return map[string]interface{}{
		"type":   common.Image,
		"url":    previewURL,
		"width":  width,
		"height": height,
		"name":   finalName,
	}, nil
}

func (rb *Robot) buildFeishuFileRobotPayload(groupNo string, model *feishuGroupRobotConfig, content map[string]interface{}) (map[string]interface{}, error) {
	if fileURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "file_url", "fileUrl", "url"))); fileURL != "" && !rb.hasFeishuOpenAPICredentials(model) {
		name := sanitizeFeishuFileName(stringValue(firstFeishuValue(content, "file_name", "name", "title")))
		return map[string]interface{}{
			"type":   common.File,
			"url":    fileURL,
			"name":   name,
			"size":   intValue(firstFeishuValue(content, "file_size", "size")),
			"suffix": trimFileExtension(name),
		}, nil
	}

	fileKey := strings.TrimSpace(stringValue(content["file_key"]))
	if fileKey == "" {
		if fileURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "file_url", "fileUrl", "url"))); fileURL != "" {
			name := sanitizeFeishuFileName(stringValue(firstFeishuValue(content, "file_name", "name", "title")))
			return map[string]interface{}{
				"type":   common.File,
				"url":    fileURL,
				"name":   name,
				"size":   intValue(firstFeishuValue(content, "file_size", "size")),
				"suffix": trimFileExtension(name),
			}, nil
		}
		return nil, errors.New("file_key is required")
	}
	if !rb.hasFeishuOpenAPICredentials(model) {
		return nil, errors.New("feishu app credentials are not configured")
	}

	resource, err := rb.downloadFeishuFileResource(model, fileKey)
	if err != nil {
		return nil, err
	}
	fileName := sanitizeFeishuFileName(stringValue(firstFeishuValue(content, "file_name", "name", "title")))
	if fileName == "" {
		fileName = resource.FileName
	}
	if fileName == "" {
		fileName = fileKey + preferredExtForContentType(resource.ContentType)
	}
	previewURL, finalName, size, err := rb.uploadFeishuBinaryToWK(groupNo, fileName, resource.ContentType, resource.Data)
	if err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"type":   common.File,
		"url":    previewURL,
		"name":   finalName,
		"size":   size,
		"suffix": trimFileExtension(finalName),
	}, nil
}

func (rb *Robot) buildFeishuAudioRobotPayload(groupNo string, model *feishuGroupRobotConfig, content map[string]interface{}) (map[string]interface{}, error) {
	audioURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "file_url", "fileUrl", "url")))
	duration := normalizeFeishuDurationSeconds(firstFeishuValue(content, "duration", "audio_duration", "time"))
	if audioURL != "" && !rb.hasFeishuOpenAPICredentials(model) {
		return map[string]interface{}{
			"type":     common.Voice,
			"url":      audioURL,
			"timeTrad": duration,
			"waveform": "",
		}, nil
	}

	fileKey := strings.TrimSpace(stringValue(content["file_key"]))
	if fileKey == "" {
		if audioURL != "" {
			return map[string]interface{}{
				"type":     common.Voice,
				"url":      audioURL,
				"timeTrad": duration,
				"waveform": "",
			}, nil
		}
		return nil, errors.New("file_key is required")
	}
	if !rb.hasFeishuOpenAPICredentials(model) {
		return nil, errors.New("feishu app credentials are not configured")
	}

	resource, err := rb.downloadFeishuFileResource(model, fileKey)
	if err != nil {
		return nil, err
	}
	fileName := sanitizeFeishuFileName(stringValue(firstFeishuValue(content, "file_name", "name", "title")))
	if fileName == "" {
		fileName = resource.FileName
	}
	if fileName == "" {
		fileName = fileKey + preferredExtForContentType(resource.ContentType)
	}
	previewURL, _, _, err := rb.uploadFeishuBinaryToWK(groupNo, fileName, resource.ContentType, resource.Data)
	if err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"type":     common.Voice,
		"url":      previewURL,
		"timeTrad": duration,
		"waveform": "",
	}, nil
}

func (rb *Robot) buildFeishuVideoRobotPayload(groupNo string, model *feishuGroupRobotConfig, content map[string]interface{}) (map[string]interface{}, error) {
	videoURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "file_url", "fileUrl", "url")))
	coverURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "image_url", "imageUrl", "cover_url", "coverUrl")))
	duration := normalizeFeishuDurationSeconds(firstFeishuValue(content, "duration", "video_duration", "time"))
	if videoURL != "" && !rb.hasFeishuOpenAPICredentials(model) {
		return map[string]interface{}{
			"type":   common.Video,
			"url":    videoURL,
			"cover":  coverURL,
			"size":   intValue(firstFeishuValue(content, "file_size", "size")),
			"width":  intValue(firstFeishuValue(content, "width", "video_width")),
			"height": intValue(firstFeishuValue(content, "height", "video_height")),
			"second": duration,
		}, nil
	}

	fileKey := strings.TrimSpace(stringValue(content["file_key"]))
	if fileKey == "" {
		if videoURL != "" {
			return map[string]interface{}{
				"type":   common.Video,
				"url":    videoURL,
				"cover":  coverURL,
				"size":   intValue(firstFeishuValue(content, "file_size", "size")),
				"width":  intValue(firstFeishuValue(content, "width", "video_width")),
				"height": intValue(firstFeishuValue(content, "height", "video_height")),
				"second": duration,
			}, nil
		}
		return nil, errors.New("file_key is required")
	}
	if !rb.hasFeishuOpenAPICredentials(model) {
		return nil, errors.New("feishu app credentials are not configured")
	}

	resource, err := rb.downloadFeishuFileResource(model, fileKey)
	if err != nil {
		return nil, err
	}
	fileName := sanitizeFeishuFileName(stringValue(firstFeishuValue(content, "file_name", "name", "title")))
	if fileName == "" {
		fileName = resource.FileName
	}
	if fileName == "" {
		fileName = fileKey + preferredExtForContentType(resource.ContentType)
	}
	previewURL, _, size, err := rb.uploadFeishuBinaryToWK(groupNo, fileName, resource.ContentType, resource.Data)
	if err != nil {
		return nil, err
	}

	if imageKey := strings.TrimSpace(stringValue(content["image_key"])); imageKey != "" {
		if coverResource, coverErr := rb.downloadFeishuImageResource(model, imageKey); coverErr == nil {
			coverName := coverResource.FileName
			if coverName == "" {
				coverName = imageKey + preferredExtForContentType(coverResource.ContentType)
			}
			if uploadedCoverURL, _, _, uploadErr := rb.uploadFeishuBinaryToWK(groupNo, coverName, coverResource.ContentType, coverResource.Data); uploadErr == nil {
				coverURL = uploadedCoverURL
			}
		}
	}

	return map[string]interface{}{
		"type":   common.Video,
		"url":    previewURL,
		"cover":  coverURL,
		"size":   size,
		"width":  intValue(firstFeishuValue(content, "width", "video_width")),
		"height": intValue(firstFeishuValue(content, "height", "video_height")),
		"second": duration,
	}, nil
}

func (rb *Robot) buildFeishuStickerRobotPayload(groupNo string, model *feishuGroupRobotConfig, content map[string]interface{}) (map[string]interface{}, error) {
	if imageKey := strings.TrimSpace(stringValue(content["image_key"])); imageKey != "" {
		return rb.buildFeishuImageRobotPayload(groupNo, model, map[string]interface{}{
			"image_key": imageKey,
			"image_url": firstFeishuValue(content, "image_url", "imageUrl", "url"),
		})
	}
	if fileKey := strings.TrimSpace(stringValue(content["file_key"])); fileKey != "" {
		if !rb.hasFeishuOpenAPICredentials(model) {
			if imageURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "image_url", "imageUrl", "url"))); imageURL != "" {
				return map[string]interface{}{
					"type":   common.Image,
					"url":    imageURL,
					"width":  intValue(firstFeishuValue(content, "width", "image_width")),
					"height": intValue(firstFeishuValue(content, "height", "image_height")),
				}, nil
			}
			return nil, errors.New("feishu app credentials are not configured")
		}
		resource, err := rb.downloadFeishuFileResource(model, fileKey)
		if err != nil {
			return nil, err
		}
		fileName := resource.FileName
		if fileName == "" {
			fileName = fileKey + preferredExtForContentType(resource.ContentType)
		}
		previewURL, _, _, err := rb.uploadFeishuBinaryToWK(groupNo, fileName, resource.ContentType, resource.Data)
		if err != nil {
			return nil, err
		}
		width, height := detectFeishuImageSize(resource.Data)
		return map[string]interface{}{
			"type":   common.Image,
			"url":    previewURL,
			"width":  width,
			"height": height,
		}, nil
	}
	if imageURL := strings.TrimSpace(stringValue(firstFeishuValue(content, "image_url", "imageUrl", "url"))); imageURL != "" {
		return map[string]interface{}{
			"type":   common.Image,
			"url":    imageURL,
			"width":  intValue(firstFeishuValue(content, "width", "image_width")),
			"height": intValue(firstFeishuValue(content, "height", "image_height")),
		}, nil
	}
	return nil, errors.New("sticker resource is unavailable")
}

func buildFeishuShareUserRobotPayload(content map[string]interface{}) map[string]interface{} {
	name := strings.TrimSpace(stringValue(firstFeishuValue(content, "user_name", "name", "title")))
	if name == "" {
		name = strings.TrimSpace(stringValue(firstFeishuValue(content, "user_id", "open_id", "email")))
	}
	if name == "" {
		return nil
	}
	return map[string]interface{}{
		"type":    common.Card,
		"uid":     "",
		"name":    name,
		"vercode": strings.TrimSpace(stringValue(firstFeishuValue(content, "user_id", "open_id", "email"))),
	}
}

type feishuBinaryResource struct {
	Data        []byte
	ContentType string
	FileName    string
}

func (rb *Robot) hasFeishuOpenAPICredentials(model *feishuGroupRobotConfig) bool {
	if model == nil {
		return false
	}
	return strings.TrimSpace(model.AppID) != "" && strings.TrimSpace(model.AppSecret) != ""
}

func (rb *Robot) getFeishuTenantAccessToken(model *feishuGroupRobotConfig) (string, error) {
	if !rb.hasFeishuOpenAPICredentials(model) {
		return "", errors.New("feishu app credentials are not configured")
	}

	body := []byte(util.ToJson(map[string]string{
		"app_id":     strings.TrimSpace(model.AppID),
		"app_secret": strings.TrimSpace(model.AppSecret),
	}))
	req, err := http.NewRequest(http.MethodPost, "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal", bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := (&http.Client{Timeout: 30 * time.Second}).Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	if resp.StatusCode >= http.StatusBadRequest {
		return "", fmt.Errorf("feishu token request failed: %s", truncateRunes(strings.TrimSpace(string(respBody)), 200))
	}

	data, err := decodeMessagePayload(respBody)
	if err != nil {
		return "", fmt.Errorf("decode feishu token response failed: %w", err)
	}
	if code := intValue(data["code"]); code != 0 {
		return "", fmt.Errorf("feishu token request failed: %s", firstNonEmptyString(stringValue(data["msg"]), stringValue(data["message"])))
	}

	token := strings.TrimSpace(stringValue(data["tenant_access_token"]))
	if token == "" {
		token = strings.TrimSpace(stringValue(mapValue(data["data"])["tenant_access_token"]))
	}
	if token == "" {
		return "", errors.New("tenant_access_token is empty")
	}
	return token, nil
}

func (rb *Robot) downloadFeishuImageResource(model *feishuGroupRobotConfig, imageKey string) (*feishuBinaryResource, error) {
	token, err := rb.getFeishuTenantAccessToken(model)
	if err != nil {
		return nil, err
	}
	return rb.downloadFeishuBinaryResource("https://open.feishu.cn/open-apis/im/v1/images/"+url.PathEscape(strings.TrimSpace(imageKey)), token)
}

func (rb *Robot) downloadFeishuMessageImageResource(model *feishuGroupRobotConfig, messageID, imageKey string) (*feishuBinaryResource, error) {
	token, err := rb.getFeishuTenantAccessToken(model)
	if err != nil {
		return nil, err
	}
	resourceURL := "https://open.feishu.cn/open-apis/im/v1/messages/" + url.PathEscape(strings.TrimSpace(messageID)) + "/resources/" + url.PathEscape(strings.TrimSpace(imageKey))
	vals := url.Values{}
	vals.Set("type", "image")
	return rb.downloadFeishuBinaryResource(resourceURL+"?"+vals.Encode(), token)
}

func (rb *Robot) downloadFeishuFileResource(model *feishuGroupRobotConfig, fileKey string) (*feishuBinaryResource, error) {
	token, err := rb.getFeishuTenantAccessToken(model)
	if err != nil {
		return nil, err
	}
	return rb.downloadFeishuBinaryResource("https://open.feishu.cn/open-apis/im/v1/files/"+url.PathEscape(strings.TrimSpace(fileKey)), token)
}

func (rb *Robot) downloadFeishuBinaryResource(resourceURL, tenantAccessToken string) (*feishuBinaryResource, error) {
	req, err := http.NewRequest(http.MethodGet, resourceURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(tenantAccessToken))

	resp, err := (&http.Client{Timeout: 60 * time.Second}).Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	contentType := sanitizeContentType(resp.Header.Get("Content-Type"))
	if resp.StatusCode >= http.StatusBadRequest {
		return nil, fmt.Errorf("feishu resource request failed: %s", truncateRunes(strings.TrimSpace(string(data)), 200))
	}
	if looksLikeFeishuJSONObject(string(data)) {
		if payload, parseErr := decodeMessagePayload(data); parseErr == nil && intValue(payload["code"]) != 0 {
			return nil, fmt.Errorf("feishu resource request failed: %s", firstNonEmptyString(stringValue(payload["msg"]), stringValue(payload["message"])))
		}
	}

	fileName := parseDownloadFileName(resp.Header.Get("Content-Disposition"))
	return &feishuBinaryResource{
		Data:        data,
		ContentType: contentType,
		FileName:    fileName,
	}, nil
}

func (rb *Robot) uploadFeishuBinaryToWK(groupNo, originalFileName, contentType string, data []byte) (string, string, int64, error) {
	if len(data) == 0 {
		return "", "", 0, errors.New("resource data is empty")
	}
	fileName := sanitizeFeishuFileName(originalFileName)
	if fileName == "" {
		fileName = "feishu_" + strings.ToLower(util.GenerUUID())
	}
	ext := strings.ToLower(filepath.Ext(fileName))
	if ext == "" {
		ext = preferredExtForContentType(contentType)
		fileName += ext
	}
	contentType = normalizeUploadContentType(contentType, fileName)
	objectPath := fmt.Sprintf("chat/%d/%s/%d_%s%s",
		common.ChannelTypeGroup.Uint8(),
		strings.TrimSpace(groupNo),
		time.Now().UnixNano(),
		strings.ToLower(util.GenerUUID()),
		ext,
	)
	if _, err := rb.fileService.UploadFile(objectPath, contentType, func(w io.Writer) error {
		_, copyErr := io.Copy(w, bytes.NewReader(data))
		return copyErr
	}); err != nil {
		return "", "", 0, err
	}
	return buildFeishuPreviewPath(objectPath), fileName, int64(len(data)), nil
}

func buildFeishuPreviewPath(objectPath string) string {
	return "file/preview/" + strings.TrimLeft(objectPath, "/")
}

func detectFeishuImageSize(data []byte) (int64, int64) {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return 0, 0
	}
	return int64(cfg.Width), int64(cfg.Height)
}

func sanitizeContentType(value string) string {
	mediaType, _, err := mime.ParseMediaType(strings.TrimSpace(value))
	if err != nil {
		return strings.TrimSpace(value)
	}
	return strings.TrimSpace(mediaType)
}

func normalizeUploadContentType(contentType, fileName string) string {
	contentType = sanitizeContentType(contentType)
	if contentType != "" {
		return contentType
	}
	if fromExt := mime.TypeByExtension(strings.ToLower(filepath.Ext(fileName))); strings.TrimSpace(fromExt) != "" {
		return sanitizeContentType(fromExt)
	}
	return "application/octet-stream"
}

func parseDownloadFileName(contentDisposition string) string {
	if strings.TrimSpace(contentDisposition) == "" {
		return ""
	}
	_, params, err := mime.ParseMediaType(contentDisposition)
	if err != nil {
		return ""
	}
	for _, key := range []string{"filename*", "filename"} {
		if value := strings.TrimSpace(params[key]); value != "" {
			value = strings.TrimPrefix(value, "UTF-8''")
			if decoded, decodeErr := url.QueryUnescape(value); decodeErr == nil {
				value = decoded
			}
			return sanitizeFeishuFileName(value)
		}
	}
	return ""
}

func sanitizeFeishuFileName(value string) string {
	value = strings.TrimSpace(value)
	value = strings.ReplaceAll(value, "\\", "_")
	value = strings.ReplaceAll(value, "/", "_")
	if value == "" {
		return ""
	}
	return truncateRunes(value, 120)
}

func preferredExtForContentType(contentType string) string {
	contentType = sanitizeContentType(contentType)
	if contentType == "" {
		return ""
	}
	if exts, err := mime.ExtensionsByType(contentType); err == nil {
		for _, ext := range exts {
			if strings.TrimSpace(ext) != "" {
				return strings.ToLower(ext)
			}
		}
	}
	return ""
}

func trimFileExtension(fileName string) string {
	fileName = strings.TrimSpace(fileName)
	if fileName == "" {
		return ""
	}
	return strings.TrimPrefix(strings.ToLower(filepath.Ext(fileName)), ".")
}

func normalizeFeishuDurationSeconds(value interface{}) int64 {
	duration := intValue(value)
	if duration <= 0 {
		return 0
	}
	if duration > 600 {
		return (duration + 999) / 1000
	}
	return duration
}

func firstNonEmptyString(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func (rb *Robot) resolveGroupName(groupNo string) string {
	name := strings.TrimSpace(groupNo)
	groupInfo, err := rb.groupService.GetGroupWithGroupNo(groupNo)
	if err != nil || groupInfo == nil {
		return name
	}
	if strings.TrimSpace(groupInfo.Name) != "" {
		return strings.TrimSpace(groupInfo.Name)
	}
	return name
}

func (rb *Robot) buildFeishuGroupRobotWebhookURL(groupNo, token string, req *http.Request) string {
	baseURL := strings.TrimSpace(rb.ctx.GetConfig().External.BaseURL)
	if baseURL == "" {
		baseURL = buildFeishuGroupRobotBaseURLFromRequest(req)
	}
	return buildFeishuGroupRobotWebhookURLFromBase(baseURL, groupNo, token)
}

func buildFeishuGroupRobotWebhookURLFromBase(baseURL, groupNo, token string) string {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	groupNo = strings.TrimSpace(groupNo)
	token = strings.TrimSpace(token)
	if baseURL == "" || groupNo == "" || token == "" {
		return ""
	}
	return fmt.Sprintf("%s/v1/groups/%s/robot/feishu/webhook/%s", baseURL, url.PathEscape(groupNo), url.PathEscape(token))
}

func buildFeishuGroupRobotBaseURLFromRequest(req *http.Request) string {
	if req == nil {
		return ""
	}
	scheme := strings.TrimSpace(req.Header.Get("X-Forwarded-Proto"))
	if scheme == "" {
		if req.TLS != nil {
			scheme = "https"
		} else {
			scheme = "http"
		}
	}
	host := strings.TrimSpace(req.Header.Get("X-Forwarded-Host"))
	if host == "" {
		host = strings.TrimSpace(req.Host)
	}
	if host == "" {
		return ""
	}
	return fmt.Sprintf("%s://%s", scheme, host)
}

func extractFeishuGroupRobotToken(raw string) string {
	value := strings.TrimSpace(raw)
	if value == "" {
		return ""
	}
	if parsed, err := url.Parse(value); err == nil && strings.TrimSpace(parsed.Path) != "" {
		value = parsed.Path
	}
	value = strings.Trim(value, "/")
	if value == "" {
		return ""
	}
	parts := strings.Split(value, "/")
	return strings.TrimSpace(parts[len(parts)-1])
}

func generateFeishuGroupRobotToken() string {
	return "feishu_" + strings.ToLower(util.GenerUUID())
}

func generateFeishuGroupRobotSecret() string {
	return "sec_" + util.GenerUUID() + util.GetRandomString(16)
}

func decodeFeishuGroupRobotPayload(req *http.Request) (map[string]interface{}, error) {
	if req == nil || req.Body == nil {
		return nil, errors.New("request body is empty")
	}
	rawBody, err := io.ReadAll(req.Body)
	if err != nil {
		return nil, err
	}
	rawBody = bytes.TrimSpace(bytes.TrimPrefix(rawBody, []byte{0xEF, 0xBB, 0xBF}))
	if len(rawBody) == 0 {
		return nil, errors.New("payload is empty")
	}

	decoder := json.NewDecoder(bytes.NewReader(rawBody))
	decoder.UseNumber()
	var payload map[string]interface{}
	if err := decoder.Decode(&payload); err != nil {
		return nil, err
	}
	if payload == nil {
		return nil, errors.New("payload is empty")
	}
	return payload, nil
}

func validateFeishuGroupRobotSignature(payload map[string]interface{}, secret string) error {
	secret = strings.TrimSpace(secret)
	if secret == "" {
		return nil
	}

	timestamp := strings.TrimSpace(stringValue(payload["timestamp"]))
	sign := strings.TrimSpace(stringValue(payload["sign"]))
	if timestamp == "" || sign == "" {
		return errors.New("missing timestamp or sign")
	}

	timestampValue, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return errors.New("invalid timestamp")
	}
	now := time.Now().Unix()
	if timestampValue < now-feishuGroupRobotWebhookSignTTLSeconds || timestampValue > now+300 {
		return errors.New("signature expired")
	}
	if buildFeishuSign(timestamp, secret) != sign {
		return errors.New("invalid sign")
	}
	return nil
}

func resolveFeishuGroupRobotMessageText(payload map[string]interface{}) (string, error) {
	msgType := strings.TrimSpace(stringValue(payload["msg_type"]))
	if msgType == "" {
		if text := strings.TrimSpace(resolveFeishuGroupRobotV1Text(payload)); text != "" {
			return formatFeishuIncomingMessage(text), nil
		}
		return "", errors.New("msg_type is required")
	}

	content, rawContent := normalizeFeishuContent(payload["content"])
	switch msgType {
	case "text":
		text := strings.TrimSpace(extractFeishuTextContent(content, rawContent))
		if text == "" {
			text = "[Feishu text message]"
		}
		return formatFeishuIncomingMessage(text), nil
	case "post":
		text := strings.TrimSpace(extractFeishuPostText(content))
		if text == "" {
			text = "[Feishu post message]"
		}
		return formatFeishuIncomingMessage(text), nil
	case "interactive":
		text := strings.TrimSpace(extractFeishuInteractiveText(payload, content))
		if text == "" {
			text = "[Feishu card message]"
		}
		return formatFeishuIncomingMessage(text), nil
	case "image":
		return formatFeishuIncomingMessage(buildFeishuImageMessageText(content, rawContent)), nil
	case "file":
		return formatFeishuIncomingMessage(buildFeishuFileMessageText(content, rawContent)), nil
	case "audio":
		return formatFeishuIncomingMessage(buildFeishuAudioMessageText(content, rawContent)), nil
	case "media":
		return formatFeishuIncomingMessage(buildFeishuMediaMessageText(content, rawContent)), nil
	case "sticker":
		return formatFeishuIncomingMessage(buildFeishuStickerMessageText(content, rawContent)), nil
	case "share_chat":
		return formatFeishuIncomingMessage(buildFeishuShareChatMessageText(content, rawContent)), nil
	case "share_user":
		return formatFeishuIncomingMessage(buildFeishuShareUserMessageText(content, rawContent)), nil
	case "system":
		return formatFeishuIncomingMessage(buildFeishuSystemMessageText(content, rawContent)), nil
	default:
		if text := strings.TrimSpace(extractFeishuTextContent(content, rawContent)); text != "" {
			return formatFeishuIncomingMessage(text), nil
		}
		return formatFeishuIncomingMessage(buildFeishuGenericMessageText(msgType, content, rawContent)), nil
	}
}

func formatFeishuIncomingMessage(text string) string {
	text = truncateRunes(strings.TrimSpace(text), 3000)
	if text == "" {
		return "[Feishu message]"
	}
	return text
}

func resolveFeishuGroupRobotV1Text(payload map[string]interface{}) string {
	text := strings.TrimSpace(stringValue(payload["text"]))
	title := strings.TrimSpace(stringValue(payload["title"]))
	if title == "" {
		return text
	}
	if text == "" {
		return title
	}
	return title + "\n" + text
}

func extractFeishuPostText(content map[string]interface{}) string {
	post := mapValue(content["post"])
	if len(post) == 0 {
		post = content
	}
	localeContent := pickFeishuPostLocale(post)
	if len(localeContent) == 0 {
		if _, ok := post["content"]; ok {
			localeContent = post
		} else {
			return ""
		}
	}

	parts := make([]string, 0)
	if title := strings.TrimSpace(stringValue(localeContent["title"])); title != "" {
		parts = append(parts, title)
	}

	rows, ok := localeContent["content"].([]interface{})
	if !ok {
		return strings.Join(parts, "\n")
	}
	for _, row := range rows {
		items := normalizeFeishuPostRow(row)
		if len(items) == 0 {
			continue
		}
		rowParts := make([]string, 0)
		for _, item := range items {
			text := strings.TrimSpace(extractFeishuPostItemText(mapValue(item)))
			if text != "" {
				rowParts = append(rowParts, text)
			}
		}
		if len(rowParts) > 0 {
			parts = append(parts, strings.Join(rowParts, " "))
		}
	}
	return strings.Join(parts, "\n")
}

func normalizeFeishuPostRow(row interface{}) []interface{} {
	if items, ok := row.([]interface{}); ok {
		return items
	}
	if item := mapValue(row); len(item) > 0 {
		return []interface{}{item}
	}
	return nil
}

func pickFeishuPostLocale(post map[string]interface{}) map[string]interface{} {
	if locale := mapValue(post["zh_cn"]); len(locale) > 0 {
		return locale
	}
	if locale := mapValue(post["en_us"]); len(locale) > 0 {
		return locale
	}
	for _, value := range post {
		if locale := mapValue(value); len(locale) > 0 {
			return locale
		}
	}
	return map[string]interface{}{}
}

func extractFeishuPostItemText(item map[string]interface{}) string {
	if len(item) == 0 {
		return ""
	}
	tag := strings.TrimSpace(stringValue(item["tag"]))
	switch tag {
	case "text":
		return stringValue(item["text"])
	case "a":
		if text := strings.TrimSpace(stringValue(item["text"])); text != "" {
			return text
		}
		return stringValue(item["href"])
	case "at":
		if text := strings.TrimSpace(stringValue(item["user_name"])); text != "" {
			return "@" + text
		}
		if text := strings.TrimSpace(stringValue(item["text"])); text != "" {
			return text
		}
		return "@member"
	case "img":
		return "[image]"
	case "markdown":
		return stringValue(item["text"])
	default:
		if text := strings.TrimSpace(stringValue(item["text"])); text != "" {
			return text
		}
	}
	return ""
}

func extractFeishuInteractiveText(payload map[string]interface{}, content map[string]interface{}) string {
	card := mapValue(payload["card"])
	if len(card) == 0 {
		card = normalizeJSONObject(content["card"])
	}
	if len(card) == 0 {
		card = content
	}
	if len(card) == 0 {
		return ""
	}

	lines := make([]string, 0, 2)
	header := mapValue(card["header"])
	title := mapValue(header["title"])
	if value := strings.TrimSpace(stringValue(title["content"])); value != "" {
		lines = append(lines, value)
	}
	if body := strings.TrimSpace(extractFeishuCardBodyText(card)); body != "" {
		lines = append(lines, body)
	}
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func normalizeJSONObject(value interface{}) map[string]interface{} {
	if result := mapValue(value); len(result) > 0 {
		return result
	}
	raw, ok := value.(string)
	if !ok || strings.TrimSpace(raw) == "" {
		return map[string]interface{}{}
	}
	decoder := json.NewDecoder(strings.NewReader(raw))
	decoder.UseNumber()
	var result map[string]interface{}
	if err := decoder.Decode(&result); err != nil {
		return map[string]interface{}{}
	}
	return result
}

func normalizeFeishuContent(value interface{}) (map[string]interface{}, string) {
	if result := mapValue(value); len(result) > 0 {
		return result, ""
	}
	raw := strings.TrimSpace(stringValue(value))
	if raw == "" {
		return map[string]interface{}{}, ""
	}
	if result := normalizeJSONObject(raw); len(result) > 0 {
		return result, raw
	}
	return map[string]interface{}{}, raw
}

func extractFeishuTextContent(content map[string]interface{}, rawContent string) string {
	if text := strings.TrimSpace(stringValue(content["text"])); text != "" {
		return text
	}
	if text := strings.TrimSpace(stringValue(content["title"])); text != "" {
		return text
	}
	if rawContent != "" && !looksLikeFeishuJSONObject(rawContent) {
		return rawContent
	}
	return ""
}

func buildFeishuImageMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu image message]"}
	appendFeishuMetadataLine(&lines, "image_key", content["image_key"])
	appendFeishuMetadataLine(&lines, "image_url", firstFeishuValue(content, "image_url", "imageUrl", "url"))
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuFileMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu file message]"}
	appendFeishuMetadataLine(&lines, "file_name", firstFeishuValue(content, "file_name", "name", "title"))
	appendFeishuMetadataLine(&lines, "file_key", content["file_key"])
	appendFeishuMetadataLine(&lines, "file_size", firstFeishuValue(content, "file_size", "size"))
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuAudioMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu audio message]"}
	appendFeishuMetadataLine(&lines, "file_name", firstFeishuValue(content, "file_name", "name", "title"))
	appendFeishuMetadataLine(&lines, "file_key", content["file_key"])
	appendFeishuMetadataLine(&lines, "duration", firstFeishuValue(content, "duration", "audio_duration", "time"))
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuMediaMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu video message]"}
	appendFeishuMetadataLine(&lines, "file_name", firstFeishuValue(content, "file_name", "name", "title"))
	appendFeishuMetadataLine(&lines, "file_key", content["file_key"])
	appendFeishuMetadataLine(&lines, "image_key", content["image_key"])
	appendFeishuMetadataLine(&lines, "duration", firstFeishuValue(content, "duration", "video_duration", "time"))
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuStickerMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu sticker message]"}
	appendFeishuMetadataLine(&lines, "file_key", firstFeishuValue(content, "file_key", "sticker_key"))
	appendFeishuMetadataLine(&lines, "emoji_type", content["emoji_type"])
	appendFeishuMetadataLine(&lines, "sticker_id", content["sticker_id"])
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuShareChatMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu shared a group card]"}
	appendFeishuMetadataLine(&lines, "chat_name", firstFeishuValue(content, "chat_name", "name", "title"))
	appendFeishuMetadataLine(&lines, "chat_id", firstFeishuValue(content, "chat_id", "share_chat_id"))
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuShareUserMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu shared a user card]"}
	appendFeishuMetadataLine(&lines, "user_name", firstFeishuValue(content, "user_name", "name", "title"))
	appendFeishuMetadataLine(&lines, "user_id", firstFeishuValue(content, "user_id", "share_user_id", "open_id"))
	appendFeishuMetadataLine(&lines, "email", content["email"])
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuSystemMessageText(content map[string]interface{}, rawContent string) string {
	lines := []string{"[Feishu system message]"}
	if text := strings.TrimSpace(extractFeishuTextContent(content, rawContent)); text != "" {
		lines = append(lines, text)
	}
	appendFeishuMetadataLine(&lines, "template", firstFeishuValue(content, "template", "template_id"))
	appendFeishuRawContentLine(&lines, content, rawContent)
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func buildFeishuGenericMessageText(msgType string, content map[string]interface{}, rawContent string) string {
	lines := make([]string, 0, 2)
	if text := strings.TrimSpace(extractFeishuTextContent(content, rawContent)); text != "" {
		lines = append(lines, text)
	}
	appendFeishuRawContentLine(&lines, content, rawContent)
	if len(lines) == 0 {
		lines = append(lines, fmt.Sprintf("[Feishu %s message]", msgType))
	}
	return strings.Join(uniqueFeishuLines(lines), "\n")
}

func extractFeishuCardBodyText(card map[string]interface{}) string {
	fragments := make([]string, 0)
	seen := make(map[string]struct{})

	collectFeishuTextFragments(card["elements"], seen, &fragments)
	if len(fragments) == 0 {
		body := mapValue(card["body"])
		collectFeishuTextFragments(body["elements"], seen, &fragments)
	}
	if len(fragments) == 0 {
		collectFeishuTextFragments(card, seen, &fragments)
	}
	if len(fragments) > 6 {
		fragments = fragments[:6]
	}
	return strings.Join(fragments, "\n")
}

func collectFeishuTextFragments(value interface{}, seen map[string]struct{}, fragments *[]string) {
	switch typed := value.(type) {
	case []interface{}:
		for _, item := range typed {
			collectFeishuTextFragments(item, seen, fragments)
		}
	case map[string]interface{}:
		tag := strings.TrimSpace(stringValue(typed["tag"]))
		switch tag {
		case "img":
			appendFeishuUniqueFragment("[image]", seen, fragments)
		case "hr":
			return
		}
		for _, key := range []string{"content", "text"} {
			appendFeishuExtractedFragment(typed[key], seen, fragments)
		}
		for _, child := range typed {
			collectFeishuTextFragments(child, seen, fragments)
		}
	case string:
		if parsed := normalizeJSONObject(typed); len(parsed) > 0 {
			collectFeishuTextFragments(parsed, seen, fragments)
			return
		}
		appendFeishuUniqueFragment(typed, seen, fragments)
	}
}

func appendFeishuExtractedFragment(value interface{}, seen map[string]struct{}, fragments *[]string) {
	switch typed := value.(type) {
	case string:
		appendFeishuUniqueFragment(typed, seen, fragments)
	case map[string]interface{}:
		appendFeishuUniqueFragment(firstFeishuValue(typed, "content", "text", "title"), seen, fragments)
	case []interface{}:
		for _, item := range typed {
			appendFeishuExtractedFragment(item, seen, fragments)
		}
	}
}

func appendFeishuUniqueFragment(value interface{}, seen map[string]struct{}, fragments *[]string) {
	valueText := sanitizeFeishuDisplayText(feishuDisplayValue(value))
	if valueText == "" {
		return
	}
	if isFeishuStructuralFragment(valueText) {
		return
	}
	if _, ok := seen[valueText]; ok {
		return
	}
	seen[valueText] = struct{}{}
	*fragments = append(*fragments, valueText)
}

func appendFeishuMetadataLine(lines *[]string, label string, value interface{}) {
	valueText := sanitizeFeishuDisplayText(feishuDisplayValue(value))
	if label == "" || valueText == "" {
		return
	}
	*lines = append(*lines, fmt.Sprintf("%s: %s", label, valueText))
}

func appendFeishuRawContentLine(lines *[]string, content map[string]interface{}, rawContent string) {
	if len(content) > 0 {
		return
	}
	rawContent = sanitizeFeishuDisplayText(rawContent)
	if rawContent == "" {
		return
	}
	*lines = append(*lines, rawContent)
}

func uniqueFeishuLines(lines []string) []string {
	result := make([]string, 0, len(lines))
	seen := make(map[string]struct{})
	for _, line := range lines {
		line = sanitizeFeishuDisplayText(line)
		if line == "" {
			continue
		}
		if _, ok := seen[line]; ok {
			continue
		}
		seen[line] = struct{}{}
		result = append(result, line)
	}
	return result
}

func firstFeishuValue(content map[string]interface{}, keys ...string) interface{} {
	for _, key := range keys {
		if key == "" {
			continue
		}
		value := content[key]
		if strings.TrimSpace(feishuDisplayValue(value)) != "" {
			return value
		}
	}
	return nil
}

func feishuDisplayValue(value interface{}) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case string:
		return typed
	case json.Number:
		return typed.String()
	default:
		data, err := json.Marshal(typed)
		if err == nil {
			return string(data)
		}
		return fmt.Sprintf("%v", typed)
	}
}

func sanitizeFeishuDisplayText(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	if looksLikeFeishuJSONObject(value) {
		return ""
	}
	return truncateRunes(value, 500)
}

func looksLikeFeishuJSONObject(value string) bool {
	value = strings.TrimSpace(value)
	if value == "" {
		return false
	}
	if !(strings.HasPrefix(value, "{") || strings.HasPrefix(value, "[")) {
		return false
	}
	return json.Valid([]byte(value))
}

func isFeishuStructuralFragment(value string) bool {
	switch strings.TrimSpace(strings.ToLower(value)) {
	case "text", "markdown", "plain_text", "lark_md", "img", "hr", "div", "note", "column_set", "column", "action", "button", "overflow", "date_picker", "picker_time", "picker_date", "picker_datetime", "form", "input", "select_static", "select_person", "chart", "table":
		return true
	default:
		return false
	}
}

func mapValue(value interface{}) map[string]interface{} {
	switch typed := value.(type) {
	case map[string]interface{}:
		return typed
	case gin.H:
		return map[string]interface{}(typed)
	default:
		return map[string]interface{}{}
	}
}

func intPointerTrue(value *int) bool {
	return value != nil && *value != 0
}

func respondFeishuGroupRobotWebhook(c *wkhttp.Context, code int, msg string) {
	c.JSON(http.StatusOK, gin.H{
		"code": code,
		"msg":  msg,
	})
}

func buildFeishuSign(timestamp, secret string) string {
	payload := fmt.Sprintf("%s\n%s", timestamp, secret)
	mac := hmac.New(sha256.New, []byte(payload))
	_, _ = mac.Write([]byte{})
	return base64.StdEncoding.EncodeToString(mac.Sum(nil))
}

func decodeMessagePayload(payload []byte) (map[string]interface{}, error) {
	if len(payload) == 0 {
		return map[string]interface{}{}, nil
	}
	decoder := json.NewDecoder(bytes.NewReader(payload))
	decoder.UseNumber()
	var data map[string]interface{}
	if err := decoder.Decode(&data); err != nil {
		return nil, err
	}
	return data, nil
}

func intValue(value interface{}) int64 {
	switch typed := value.(type) {
	case nil:
		return 0
	case int:
		return int64(typed)
	case int8:
		return int64(typed)
	case int16:
		return int64(typed)
	case int32:
		return int64(typed)
	case int64:
		return typed
	case uint:
		return int64(typed)
	case uint8:
		return int64(typed)
	case uint16:
		return int64(typed)
	case uint32:
		return int64(typed)
	case uint64:
		return int64(typed)
	case float32:
		return int64(typed)
	case float64:
		return int64(typed)
	case json.Number:
		if parsed, err := typed.Int64(); err == nil {
			return parsed
		}
		if parsed, err := typed.Float64(); err == nil {
			return int64(parsed)
		}
	case string:
		parsed, _ := strconv.ParseInt(strings.TrimSpace(typed), 10, 64)
		return parsed
	}
	return 0
}

func stringValue(value interface{}) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case string:
		return typed
	case json.Number:
		return typed.String()
	default:
		return fmt.Sprintf("%v", typed)
	}
}

func truncateRunes(value string, limit int) string {
	if limit <= 0 {
		return ""
	}
	runes := []rune(value)
	if len(runes) <= limit {
		return value
	}
	return string(runes[:limit])
}
