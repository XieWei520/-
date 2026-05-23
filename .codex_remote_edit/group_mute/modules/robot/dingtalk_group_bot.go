package robot

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"path"
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
)

const dingTalkGroupRobotWebhookSignTTLMillis = int64(60 * 60 * 1000)

var dingTalkMarkdownImagePattern = regexp.MustCompile(`!\[[^\]]*\]\((https?://[^\s)]+)\)`)

type dingTalkGroupRobotResp struct {
	GroupNo            string `json:"group_no"`
	WebhookURL         string `json:"webhook_url"`
	Secret             string `json:"secret"`
	WebhookMode        string `json:"webhook_mode"`
	OfficialWebhookURL string `json:"official_webhook_url"`
	OfficialSecret     string `json:"official_secret"`
	DisplayName        string `json:"display_name"`
	DisplayAvatar      string `json:"display_avatar"`
	Enabled            int    `json:"enabled"`
	SecretSet          bool   `json:"secret_set"`
	LastPushAt         int64  `json:"last_push_at"`
	LastError          string `json:"last_error"`
	UpdatedAt          string `json:"updated_at"`
}

type upsertDingTalkGroupRobotReq struct {
	Enabled            *int    `json:"enabled"`
	RegenerateWebhook  *int    `json:"regenerate_webhook"`
	RegenerateSecret   *int    `json:"regenerate_secret"`
	WebhookMode        *string `json:"webhook_mode"`
	OfficialWebhookURL *string `json:"official_webhook_url"`
	OfficialSecret     *string `json:"official_secret"`
	DisplayName        *string `json:"display_name"`
	DisplayAvatar      *string `json:"display_avatar"`
}

func newDingTalkGroupRobotResp(model *dingTalkGroupRobotConfig, webhookURL string) *dingTalkGroupRobotResp {
	if model == nil {
		return nil
	}
	secret := strings.TrimSpace(model.Secret)
	webhookMode := normalizeGroupRobotWebhookMode(model.WebhookMode)
	return &dingTalkGroupRobotResp{
		GroupNo:            model.GroupNo,
		WebhookURL:         webhookURL,
		Secret:             secret,
		WebhookMode:        webhookMode,
		OfficialWebhookURL: strings.TrimSpace(model.OfficialWebhookURL),
		OfficialSecret:     strings.TrimSpace(model.OfficialSecret),
		DisplayName:        strings.TrimSpace(model.DisplayName),
		DisplayAvatar:      strings.TrimSpace(model.DisplayAvatar),
		Enabled:            model.Enabled,
		SecretSet:          secret != "",
		LastPushAt:         model.LastPushAt,
		LastError:          model.LastError,
		UpdatedAt:          model.UpdatedAt.String(),
	}
}

func (rb *Robot) getDingTalkGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageDingTalkGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	model, err := rb.db.queryDingTalkGroupRobot(groupNo)
	if err != nil {
		rb.Error("load dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("load dingtalk robot config failed"))
		return
	}
	if model == nil {
		c.Response(map[string]interface{}{})
		return
	}
	c.Response(newDingTalkGroupRobotResp(model, rb.buildDingTalkGroupRobotWebhookURL(groupNo, extractDingTalkGroupRobotToken(model.WebhookURL), c.Request)))
}

func (rb *Robot) upsertDingTalkGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageDingTalkGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	var req upsertDingTalkGroupRobotReq
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

	existing, err := rb.db.queryDingTalkGroupRobot(groupNo)
	if err != nil {
		rb.Error("load dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("save dingtalk robot config failed"))
		return
	}

	isCreate := existing == nil
	if isCreate {
		existing = &dingTalkGroupRobotConfig{
			GroupNo:    groupNo,
			CreatedUID: loginUID,
		}
	}

	token := extractDingTalkGroupRobotToken(existing.WebhookURL)
	if token == "" || intPointerTrue(req.RegenerateWebhook) {
		token = generateDingTalkGroupRobotToken()
	}

	secret := strings.TrimSpace(existing.Secret)
	if secret == "" || intPointerTrue(req.RegenerateSecret) {
		secret = generateDingTalkGroupRobotSecret()
	}

	existing.WebhookURL = token
	existing.Secret = secret
	if req.DisplayName != nil {
		existing.DisplayName = strings.TrimSpace(*req.DisplayName)
	}
	if req.DisplayAvatar != nil {
		existing.DisplayAvatar = strings.TrimSpace(*req.DisplayAvatar)
	}
	if err := applyDingTalkWebhookModeUpdate(existing, &req); err != nil {
		c.ResponseError(err)
		return
	}
	existing.Enabled = enabled
	existing.UpdatedUID = loginUID
	if intPointerTrue(req.RegenerateWebhook) || intPointerTrue(req.RegenerateSecret) {
		existing.LastError = ""
	}

	if isCreate {
		if err := rb.db.insertDingTalkGroupRobot(existing); err != nil {
			rb.Error("create dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
			c.ResponseError(errors.New("save dingtalk robot config failed"))
			return
		}
	} else {
		if err := rb.db.updateDingTalkGroupRobot(existing); err != nil {
			rb.Error("update dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
			c.ResponseError(errors.New("save dingtalk robot config failed"))
			return
		}
	}

	current, err := rb.db.queryDingTalkGroupRobot(groupNo)
	if err != nil {
		rb.Error("load saved dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("save dingtalk robot config failed"))
		return
	}
	c.Response(newDingTalkGroupRobotResp(current, rb.buildDingTalkGroupRobotWebhookURL(groupNo, extractDingTalkGroupRobotToken(current.WebhookURL), c.Request)))
}

func applyDingTalkWebhookModeUpdate(model *dingTalkGroupRobotConfig, req *upsertDingTalkGroupRobotReq) error {
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
		if err := validateDingTalkOfficialWebhookURL(model.OfficialWebhookURL); err != nil {
			return err
		}
	}
	model.WebhookMode = nextMode
	return nil
}

func (rb *Robot) deleteDingTalkGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageDingTalkGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	if err := rb.db.deleteDingTalkGroupRobot(groupNo); err != nil {
		rb.Error("delete dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("delete dingtalk robot config failed"))
		return
	}
	c.ResponseOK()
}

func (rb *Robot) testDingTalkGroupRobot(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	loginUID := strings.TrimSpace(c.GetLoginUID())
	if err := rb.ensureManageDingTalkGroupRobot(groupNo, loginUID); err != nil {
		c.ResponseError(err)
		return
	}

	model, err := rb.db.queryDingTalkGroupRobot(groupNo)
	if err != nil {
		rb.Error("load dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		c.ResponseError(errors.New("send test message failed"))
		return
	}
	if model == nil {
		c.ResponseError(errors.New("please create the dingtalk robot config first"))
		return
	}

	text := truncateRunes(fmt.Sprintf("[DingTalk Robot]\nCompatibility test message\nGroup: %s\nOperator: %s\nTime: %s\nNote: this message confirms the generated webhook and sign secret are working.",
		rb.resolveGroupName(groupNo),
		loginUID,
		time.Now().Format("2006-01-02 15:04:05"),
	), 3000)
	if err := rb.sendDingTalkGroupRobotTextMessage(groupNo, model, text); err != nil {
		rb.Error("send dingtalk robot test message failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateDingTalkGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		c.ResponseError(fmt.Errorf("send test message failed: %w", err))
		return
	}
	_ = rb.db.updateDingTalkGroupRobotPushState(groupNo, time.Now().Unix(), "")
	c.ResponseOK()
}

func (rb *Robot) receiveDingTalkGroupRobotWebhook(c *wkhttp.Context) {
	groupNo := strings.TrimSpace(c.Param("group_no"))
	token, query := resolveDingTalkGroupRobotRequestToken(c.Request, c.Param("token_path"))
	if groupNo == "" || token == "" {
		respondDingTalkGroupRobotWebhook(c, 31001, "invalid webhook")
		return
	}

	model, err := rb.db.queryDingTalkGroupRobot(groupNo)
	if err != nil {
		rb.Error("load dingtalk robot config failed", zap.Error(err), zap.String("groupNo", groupNo))
		respondDingTalkGroupRobotWebhook(c, 31001, "load robot config failed")
		return
	}
	if model == nil {
		respondDingTalkGroupRobotWebhook(c, 31001, "robot config not found")
		return
	}
	if model.Enabled == 0 {
		respondDingTalkGroupRobotWebhook(c, 31001, "robot disabled")
		return
	}
	if token != extractDingTalkGroupRobotToken(model.WebhookURL) {
		respondDingTalkGroupRobotWebhook(c, 31001, "invalid webhook token")
		return
	}

	payload, err := decodeDingTalkGroupRobotPayload(c.Request)
	if err != nil {
		rb.Warn("decode dingtalk robot webhook payload failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateDingTalkGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondDingTalkGroupRobotWebhook(c, 31002, "invalid payload")
		return
	}

	timestamp := strings.TrimSpace(query.Get("timestamp"))
	sign := strings.TrimSpace(query.Get("sign"))
	if err := validateDingTalkGroupRobotSignature(timestamp, sign, strings.TrimSpace(model.Secret)); err != nil {
		rb.Warn("validate dingtalk robot signature failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateDingTalkGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondDingTalkGroupRobotWebhook(c, 31003, err.Error())
		return
	}

	messagePayload, err := rb.buildDingTalkGroupRobotMessagePayload(groupNo, payload)
	if err != nil {
		rb.Warn("build dingtalk robot message payload failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateDingTalkGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondDingTalkGroupRobotWebhook(c, 31004, err.Error())
		return
	}

	if err := rb.sendDingTalkGroupRobotPayload(groupNo, model, messagePayload); err != nil {
		rb.Warn("deliver dingtalk robot message failed", zap.Error(err), zap.String("groupNo", groupNo))
		_ = rb.db.updateDingTalkGroupRobotPushState(groupNo, model.LastPushAt, truncateRunes(err.Error(), 255))
		respondDingTalkGroupRobotWebhook(c, 31005, "deliver message failed")
		return
	}

	_ = rb.db.updateDingTalkGroupRobotPushState(groupNo, time.Now().Unix(), "")
	respondDingTalkGroupRobotWebhook(c, 0, "ok")
}

func (rb *Robot) ensureManageDingTalkGroupRobot(groupNo, loginUID string) error {
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
		return errors.New("only group owners or admins can manage the dingtalk robot")
	}
	return nil
}

func (rb *Robot) sendDingTalkGroupRobotTextMessage(groupNo string, model *dingTalkGroupRobotConfig, text string) error {
	return rb.sendDingTalkGroupRobotPayload(groupNo, model, map[string]interface{}{
		"content": truncateRunes(text, 3000),
		"type":    common.Text,
	})
}

func decorateDingTalkGroupRobotPayload(payload map[string]interface{}, model *dingTalkGroupRobotConfig) {
	configuredName := ""
	configuredAvatar := ""
	if model != nil {
		configuredName = model.DisplayName
		configuredAvatar = model.DisplayAvatar
	}
	identity := resolveGroupRobotDisplayIdentity(groupRobotProviderDingTalk, configuredName, configuredAvatar)
	applyGroupRobotDisplayMeta(payload, identity)
}

func (rb *Robot) sendDingTalkGroupRobotPayload(groupNo string, model *dingTalkGroupRobotConfig, payload map[string]interface{}) error {
	if len(payload) == 0 {
		return errors.New("payload is empty")
	}
	decorateDingTalkGroupRobotPayload(payload, model)
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

func (rb *Robot) buildDingTalkGroupRobotMessagePayload(groupNo string, incoming map[string]interface{}) (map[string]interface{}, error) {
	msgType := strings.TrimSpace(stringValue(incoming["msgtype"]))
	if msgType == "image" {
		if payload, err := rb.buildDingTalkImageRobotPayload(groupNo, mapValue(incoming["image"])); err == nil && len(payload) > 0 {
			return payload, nil
		} else if err != nil {
			rb.logDingTalkRobotPayloadFallback(groupNo, msgType, err)
		}
	}
	if msgType == "markdown" {
		if payload, ok := buildDingTalkMarkdownImageRobotPayload(incoming); ok {
			return payload, nil
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

func (rb *Robot) logDingTalkRobotPayloadFallback(groupNo, msgType string, err error) {
	if err == nil || rb == nil || rb.Log == nil {
		return
	}
	rb.Warn("fall back to dingtalk text delivery",
		zap.String("groupNo", groupNo),
		zap.String("msgType", msgType),
		zap.Error(err),
	)
}

func (rb *Robot) buildDingTalkImageRobotPayload(groupNo string, content map[string]interface{}) (map[string]interface{}, error) {
	imageURL := strings.TrimSpace(stringValue(firstDingTalkValue(
		content,
		"picURL", "picUrl",
		"photoURL", "photoUrl",
		"pictureURL", "pictureUrl",
		"url",
	)))
	if imageURL == "" {
		return nil, errors.New("image url is required")
	}

	resource, err := rb.downloadDingTalkBinaryResource(imageURL)
	if err != nil {
		if payload, ok := buildDingTalkDirectImageURLRobotPayload(content); ok {
			return payload, nil
		}
		return nil, err
	}

	fileName := resource.FileName
	if strings.TrimSpace(fileName) == "" {
		fileName = fallbackDingTalkFileName(imageURL, "dingtalk_image")
	}

	previewURL, finalName, _, err := rb.uploadFeishuBinaryToWK(groupNo, fileName, resource.ContentType, resource.Data)
	if err != nil {
		return nil, err
	}

	width, height := detectFeishuImageSize(resource.Data)
	if width == 0 {
		width = int64(intValue(firstDingTalkValue(content, "width", "picWidth", "imageWidth")))
	}
	if height == 0 {
		height = int64(intValue(firstDingTalkValue(content, "height", "picHeight", "imageHeight")))
	}

	return map[string]interface{}{
		"type":   common.Image,
		"url":    previewURL,
		"width":  width,
		"height": height,
		"name":   finalName,
	}, nil
}

func buildDingTalkDirectImageURLRobotPayload(content map[string]interface{}) (map[string]interface{}, bool) {
	imageURL := strings.TrimSpace(stringValue(firstDingTalkValue(
		content,
		"picURL", "picUrl",
		"photoURL", "photoUrl",
		"pictureURL", "pictureUrl",
		"url",
	)))
	if imageURL == "" || !isDingTalkHTTPURL(imageURL) {
		return nil, false
	}
	return map[string]interface{}{
		"type":   common.Image,
		"url":    imageURL,
		"width":  intValue(firstDingTalkValue(content, "width", "picWidth", "imageWidth")),
		"height": intValue(firstDingTalkValue(content, "height", "picHeight", "imageHeight")),
	}, true
}

func isDingTalkHTTPURL(value string) bool {
	lower := strings.ToLower(strings.TrimSpace(value))
	return strings.HasPrefix(lower, "http://") || strings.HasPrefix(lower, "https://")
}

func buildDingTalkMarkdownImageRobotPayload(values ...interface{}) (map[string]interface{}, bool) {
	imageURL := findDingTalkMarkdownImageURL(values...)
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

func findDingTalkMarkdownImageURL(values ...interface{}) string {
	for _, value := range values {
		if imageURL := strings.TrimSpace(findDingTalkMarkdownImageURLValue(value)); imageURL != "" {
			return imageURL
		}
	}
	return ""
}

func findDingTalkMarkdownImageURLValue(value interface{}) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case map[string]interface{}:
		for _, key := range []string{"text", "content", "markdown"} {
			if imageURL := findDingTalkMarkdownImageURLValue(typed[key]); imageURL != "" {
				return imageURL
			}
		}
		for _, child := range typed {
			if imageURL := findDingTalkMarkdownImageURLValue(child); imageURL != "" {
				return imageURL
			}
		}
	case gin.H:
		return findDingTalkMarkdownImageURLValue(map[string]interface{}(typed))
	case []interface{}:
		for _, child := range typed {
			if imageURL := findDingTalkMarkdownImageURLValue(child); imageURL != "" {
				return imageURL
			}
		}
	case string:
		trimmed := strings.TrimSpace(typed)
		if trimmed == "" {
			return ""
		}
		matches := dingTalkMarkdownImagePattern.FindStringSubmatch(trimmed)
		if len(matches) > 1 {
			return strings.TrimSpace(matches[1])
		}
	}
	return ""
}

func (rb *Robot) downloadDingTalkBinaryResource(resourceURL string) (*feishuBinaryResource, error) {
	resourceURL = strings.TrimSpace(resourceURL)
	if resourceURL == "" {
		return nil, errors.New("resource url is empty")
	}

	req, err := http.NewRequest(http.MethodGet, resourceURL, nil)
	if err != nil {
		return nil, err
	}

	resp, err := (&http.Client{Timeout: 60 * time.Second}).Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= http.StatusBadRequest {
		return nil, fmt.Errorf("dingtalk resource request failed: %s", truncateRunes(strings.TrimSpace(string(data)), 200))
	}

	contentType := sanitizeContentType(resp.Header.Get("Content-Type"))
	fileName := parseDownloadFileName(resp.Header.Get("Content-Disposition"))
	if fileName == "" {
		fileName = fallbackDingTalkFileName(resourceURL, "dingtalk_image")
	}

	return &feishuBinaryResource{
		Data:        data,
		ContentType: contentType,
		FileName:    fileName,
	}, nil
}

func fallbackDingTalkFileName(rawURL, fallbackBase string) string {
	parsed, err := url.Parse(strings.TrimSpace(rawURL))
	if err == nil {
		if name := strings.TrimSpace(path.Base(parsed.Path)); name != "" && name != "." && name != "/" {
			return name
		}
	}
	return fallbackBase + preferredExtForContentType("")
}

func (rb *Robot) buildDingTalkGroupRobotWebhookURL(groupNo, token string, req *http.Request) string {
	baseURL := strings.TrimSpace(rb.ctx.GetConfig().External.BaseURL)
	if baseURL == "" {
		baseURL = buildFeishuGroupRobotBaseURLFromRequest(req)
	}
	return buildDingTalkGroupRobotWebhookURLFromBase(baseURL, groupNo, token)
}

func buildDingTalkGroupRobotWebhookURLFromBase(baseURL, groupNo, token string) string {
	baseURL = strings.TrimRight(strings.TrimSpace(baseURL), "/")
	groupNo = strings.TrimSpace(groupNo)
	token = strings.TrimSpace(token)
	if baseURL == "" || groupNo == "" || token == "" {
		return ""
	}
	query := url.Values{}
	query.Set("access_token", token)
	return fmt.Sprintf("%s/v1/groups/%s/robot/dingtalk/webhook?%s", baseURL, url.PathEscape(groupNo), query.Encode())
}

func extractDingTalkGroupRobotToken(raw string) string {
	value := strings.TrimSpace(raw)
	if value == "" {
		return ""
	}
	if parsed, err := url.Parse(value); err == nil {
		if token := strings.TrimSpace(parsed.Query().Get("access_token")); token != "" {
			return token
		}
		if token := strings.TrimSpace(parsed.Query().Get("token")); token != "" {
			return token
		}
		if strings.TrimSpace(parsed.Path) != "" {
			value = parsed.Path
		}
	}
	value = strings.Trim(value, "/")
	if value == "" {
		return ""
	}
	parts := strings.Split(value, "/")
	return strings.TrimSpace(parts[len(parts)-1])
}

func resolveDingTalkGroupRobotRequestToken(req *http.Request, pathToken string) (string, url.Values) {
	query := url.Values{}
	if req != nil && req.URL != nil {
		for key, values := range req.URL.Query() {
			query[key] = append([]string(nil), values...)
		}
	}
	if token := strings.TrimSpace(query.Get("access_token")); token != "" {
		return token, query
	}
	if token := strings.TrimSpace(query.Get("token")); token != "" {
		return token, query
	}

	token, extraQuery := parseDingTalkGroupRobotPathToken(pathToken)
	for key, values := range extraQuery {
		if _, exists := query[key]; exists {
			continue
		}
		query[key] = append([]string(nil), values...)
	}
	return token, query
}

func parseDingTalkGroupRobotPathToken(raw string) (string, url.Values) {
	value := strings.TrimSpace(strings.TrimPrefix(raw, "/"))
	query := url.Values{}
	if value == "" {
		return "", query
	}

	if token, extraQuery, ok := splitDingTalkGroupRobotTokenAndQuery(value, "?"); ok {
		return token, extraQuery
	}
	if token, extraQuery, ok := splitDingTalkGroupRobotTokenAndQuery(value, "&"); ok {
		return token, extraQuery
	}
	return value, query
}

func splitDingTalkGroupRobotTokenAndQuery(value, separator string) (string, url.Values, bool) {
	index := strings.Index(value, separator)
	if index <= 0 {
		return "", url.Values{}, false
	}
	token := strings.TrimSpace(value[:index])
	rawQuery := strings.TrimSpace(strings.TrimPrefix(value[index:], separator))
	if token == "" || rawQuery == "" {
		return "", url.Values{}, false
	}
	parsedQuery, err := url.ParseQuery(rawQuery)
	if err != nil || len(parsedQuery) == 0 {
		return "", url.Values{}, false
	}
	return token, parsedQuery, true
}

func generateDingTalkGroupRobotToken() string {
	return "dingtalk_" + strings.ToLower(util.GenerUUID())
}

func generateDingTalkGroupRobotSecret() string {
	return "SEC" + util.GenerUUID() + util.GetRandomString(12)
}

func decodeDingTalkGroupRobotPayload(req *http.Request) (map[string]interface{}, error) {
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

func validateDingTalkGroupRobotSignature(timestamp, sign, secret string) error {
	secret = strings.TrimSpace(secret)
	if secret == "" {
		return nil
	}

	timestamp = strings.TrimSpace(timestamp)
	sign = strings.TrimSpace(strings.ReplaceAll(sign, " ", "+"))
	if timestamp == "" || sign == "" {
		return errors.New("missing timestamp or sign")
	}

	timestampValue, err := strconv.ParseInt(timestamp, 10, 64)
	if err != nil {
		return errors.New("invalid timestamp")
	}
	nowMillis := time.Now().UnixMilli()
	if timestampValue < nowMillis-dingTalkGroupRobotWebhookSignTTLMillis || timestampValue > nowMillis+300000 {
		return errors.New("signature expired")
	}
	if buildDingTalkSign(timestamp, secret) != sign {
		return errors.New("invalid sign")
	}
	return nil
}

func resolveDingTalkGroupRobotMessageText(payload map[string]interface{}) (string, error) {
	msgType := strings.TrimSpace(stringValue(payload["msgtype"]))
	if msgType == "" {
		return "", errors.New("msgtype is required")
	}

	switch msgType {
	case "text":
		textPayload := mapValue(payload["text"])
		text := strings.TrimSpace(stringValue(textPayload["content"]))
		if text == "" {
			text = "[DingTalk text message]"
		}
		return formatDingTalkIncomingMessage(text), nil
	case "image":
		return formatDingTalkIncomingMessage(buildDingTalkImageMessageText(mapValue(payload["image"]))), nil
	case "markdown":
		markdownPayload := mapValue(payload["markdown"])
		lines := make([]string, 0, 2)
		if title := strings.TrimSpace(stringValue(markdownPayload["title"])); title != "" {
			lines = append(lines, title)
		}
		if text := strings.TrimSpace(stringValue(markdownPayload["text"])); text != "" {
			lines = append(lines, text)
		}
		if len(lines) == 0 {
			lines = append(lines, "[DingTalk markdown message]")
		}
		return formatDingTalkIncomingMessage(joinUniqueDingTalkLines(lines)), nil
	case "link":
		return formatDingTalkIncomingMessage(buildDingTalkLinkMessageText(mapValue(payload["link"]))), nil
	case "actionCard":
		return formatDingTalkIncomingMessage(buildDingTalkActionCardMessageText(mapValue(payload["actionCard"]))), nil
	case "feedCard":
		return formatDingTalkIncomingMessage(buildDingTalkFeedCardMessageText(mapValue(payload["feedCard"]))), nil
	default:
		return "", fmt.Errorf("unsupported msgtype: %s", msgType)
	}
}

func formatDingTalkIncomingMessage(text string) string {
	text = truncateRunes(strings.TrimSpace(text), 3000)
	if text == "" {
		return "[DingTalk message]"
	}
	return text
}

func buildDingTalkLinkMessageText(content map[string]interface{}) string {
	lines := make([]string, 0, 2)
	if title := strings.TrimSpace(stringValue(content["title"])); title != "" {
		lines = append(lines, title)
	}
	if text := strings.TrimSpace(stringValue(content["text"])); text != "" {
		lines = append(lines, text)
	}
	if len(lines) == 0 {
		if messageURL := strings.TrimSpace(stringValue(firstDingTalkValue(content, "messageUrl", "messageURL"))); messageURL != "" {
			lines = append(lines, messageURL)
		}
	}
	return joinUniqueDingTalkLines(lines)
}

func buildDingTalkActionCardMessageText(content map[string]interface{}) string {
	lines := make([]string, 0, 2)
	if title := strings.TrimSpace(stringValue(content["title"])); title != "" {
		lines = append(lines, title)
	}
	if text := strings.TrimSpace(stringValue(content["text"])); text != "" {
		lines = append(lines, text)
	}

	btns, _ := content["btns"].([]interface{})
	for _, item := range btns {
		button := mapValue(item)
		title := strings.TrimSpace(stringValue(button["title"]))
		if title == "" {
			continue
		}
		if len(lines) == 0 {
			lines = append(lines, title)
		}
	}

	if len(btns) == 0 {
		title := strings.TrimSpace(stringValue(content["singleTitle"]))
		if title != "" && len(lines) == 0 {
			lines = append(lines, title)
		}
	}
	return joinUniqueDingTalkLines(lines)
}

func buildDingTalkFeedCardMessageText(content map[string]interface{}) string {
	lines := make([]string, 0)
	items, _ := content["links"].([]interface{})
	for _, item := range items {
		link := mapValue(item)
		title := strings.TrimSpace(stringValue(link["title"]))
		messageURL := strings.TrimSpace(stringValue(firstDingTalkValue(link, "messageURL", "messageUrl")))
		if title == "" && messageURL == "" {
			continue
		}
		if title != "" {
			lines = append(lines, title)
			continue
		}
		lines = append(lines, messageURL)
	}
	return strings.Join(lines, "\n")
}

func buildDingTalkImageMessageText(content map[string]interface{}) string {
	lines := make([]string, 0, 1)
	if description := strings.TrimSpace(stringValue(firstDingTalkValue(content, "description", "title", "name"))); description != "" {
		lines = append(lines, description)
	}
	if len(lines) == 0 {
		if imageURL := strings.TrimSpace(stringValue(firstDingTalkValue(
			content,
			"picURL", "picUrl",
			"photoURL", "photoUrl",
			"pictureURL", "pictureUrl",
			"url",
		))); imageURL != "" {
			lines = append(lines, imageURL)
		}
	}
	return joinUniqueDingTalkLines(lines)
}

func joinUniqueDingTalkLines(lines []string) string {
	if len(lines) == 0 {
		return ""
	}
	result := make([]string, 0, len(lines))
	seen := make(map[string]struct{}, len(lines))
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		if _, ok := seen[line]; ok {
			continue
		}
		seen[line] = struct{}{}
		result = append(result, line)
	}
	return strings.Join(result, "\n")
}

func firstDingTalkValue(content map[string]interface{}, keys ...string) interface{} {
	for _, key := range keys {
		if key == "" {
			continue
		}
		value := content[key]
		if strings.TrimSpace(stringValue(value)) != "" {
			return value
		}
	}
	return nil
}

func respondDingTalkGroupRobotWebhook(c *wkhttp.Context, code int, msg string) {
	c.JSON(http.StatusOK, gin.H{
		"errcode": code,
		"errmsg":  msg,
	})
}

func buildDingTalkSign(timestamp, secret string) string {
	payload := fmt.Sprintf("%s\n%s", timestamp, secret)
	mac := hmac.New(sha256.New, []byte(secret))
	_, _ = mac.Write([]byte(payload))
	return base64.StdEncoding.EncodeToString(mac.Sum(nil))
}
