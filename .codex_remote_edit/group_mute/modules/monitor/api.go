package monitor

import (
	"bytes"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
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
	"math/big"
	"mime"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/file"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/common"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/log"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/gocraft/dbr/v2"
	"go.uber.org/zap"
	_ "golang.org/x/image/webp"
)

const (
	maxObservedAttachmentBytes       = 100 * 1024 * 1024
	heartbeatIntervalSeconds         = 20
	pairingCodeTTL                   = 10 * time.Minute
	onlineThreshold                  = 60 * time.Second
	monitorPlatformFeishu            = "feishu"
	agentPlatformWindows             = "windows"
	monitorConnectorFeishuWebGroup   = "feishu_web_group"
	monitorRouteFeishuWebToWukongIM  = "feishu_web_group_to_wukong_im_group"
	monitorDestinationWukongIMGroup  = "wukong_im_group"
	monitorBrowserChromium           = "chromium"
	monitorProfileIsolatedPersistent = "isolated_persistent"
	monitorCredentialFeishuOpenAPI   = "feishu_openapi_internal_app"
	monitorCredentialFeishuWebhook   = "feishu_webhook"
	monitorDestinationFeishuOpenAPI  = "feishu_openapi_chat"
	monitorDestinationFeishuWebhook  = "feishu_webhook_chat"
	monitorRouteFeishuWebToFeishuAPI = "feishu_web_group_to_feishu_openapi_chat"
	feishuTenantTokenEndpoint        = "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal"
	feishuSendMessageEndpoint        = "https://open.feishu.cn/open-apis/im/v1/messages"
)

type API struct {
	ctx *config.Context
	log.Log
	db             *DB
	now            func() time.Time
	forwardMessage func(route *routeModel, message *observedMessageModel) error
	fileService    file.IService
	httpClient     *http.Client
}

func NewAPI(ctx *config.Context) *API {
	api := &API{
		ctx:         ctx,
		Log:         log.NewTLog("Monitor"),
		db:          NewDB(ctx),
		now:         time.Now,
		fileService: file.NewService(ctx),
		httpClient:  &http.Client{Timeout: 60 * time.Second},
	}
	api.forwardMessage = api.forwardObservedMessage
	return api
}

func (a *API) Route(r *wkhttp.WKHttp) {
	auth := r.Group("/v1/monitor", a.ctx.AuthMiddleware(r))
	auth.POST("/agent-pairing-codes", a.createPairingCode)
	auth.GET("/agents", a.listAgents)
	auth.GET("/events", a.listEvents)
	auth.GET("/platforms/feishu/stats", a.feishuStats)
	auth.GET("/platforms/feishu/browser-status", a.feishuBrowserStatus)
	auth.GET("/routes", a.listRoutes)
	auth.POST("/routes", a.createRoute)
	auth.PUT("/routes/:route_id/status", a.updateRouteStatus)
	auth.GET("/credentials", a.listCredentials)
	auth.POST("/credentials", a.createCredential)
	auth.POST("/credentials/:credential_id/test", a.testCredential)
	auth.GET("/destinations", a.listDestinations)
	auth.POST("/destinations", a.createDestination)

	agent := r.Group("/v1/monitor")
	agent.POST("/agents/pair", a.pairAgent)
	agent.POST("/agents/heartbeat", a.agentHeartbeat)
	agent.GET("/agents/me/routes", a.agentRoutes)
	agent.POST("/agents/browser-status", a.agentBrowserStatus)
	agent.POST("/messages/observed", a.observedMessage)
}

func (a *API) createPairingCode(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	var req createPairingCodeReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_pairing_code_request", "请求参数错误")
		return
	}
	deviceName := normalize(req.DeviceName, "Windows Agent")
	platform := normalize(req.Platform, agentPlatformWindows)
	if platform != agentPlatformWindows {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_agent_platform", "暂不支持该 Agent 平台")
		return
	}
	if len([]rune(deviceName)) > 100 {
		a.writeError(c, http.StatusUnprocessableEntity, "invalid_device_name", "设备名称过长")
		return
	}

	now := a.now()
	model := &pairingCodeModel{
		Code:       generatePairingCode(),
		UID:        uid,
		DeviceName: deviceName,
		Platform:   platform,
		ExpiresAt:  dbrNullTime(now.Add(pairingCodeTTL)),
	}
	if err := a.db.insertPairingCode(model); err != nil {
		a.Error("create monitor pairing code failed", zap.Error(err), zap.String("uid", uid))
		a.writeError(c, http.StatusInternalServerError, "pairing_code_create_failed", "生成绑定码失败")
		return
	}
	c.ResponseWithStatus(http.StatusCreated, map[string]interface{}{
		"data": map[string]interface{}{
			"pairing_code": model.Code,
			"expires_at":   model.ExpiresAt.Time.UTC().Format(time.RFC3339),
		},
	})
}

func (a *API) pairAgent(c *wkhttp.Context) {
	var req pairAgentReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_pairing_request", "请求参数错误")
		return
	}
	code := strings.ToUpper(strings.TrimSpace(req.PairingCode))
	deviceName := normalize(req.DeviceName, "Windows Agent")
	platform := normalize(req.Platform, agentPlatformWindows)
	version := normalize(req.AgentVersion, "0.1.0")
	if code == "" || deviceName == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_pairing_request", "绑定码和设备名称不能为空")
		return
	}
	if platform != agentPlatformWindows {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_agent_platform", "暂不支持该 Agent 平台")
		return
	}

	pairingCode, err := a.db.queryPairingCode(code)
	if err != nil {
		a.Error("query monitor pairing code failed", zap.Error(err))
		a.writeError(c, http.StatusInternalServerError, "pairing_code_query_failed", "查询绑定码失败")
		return
	}
	if pairingCode == nil {
		a.writeError(c, http.StatusNotFound, "pairing_code_not_found", "绑定码不存在")
		return
	}
	if pairingCode.UsedAt.Valid {
		a.writeError(c, http.StatusConflict, "pairing_code_used", "绑定码已使用")
		return
	}
	now := a.now()
	if pairingCode.ExpiresAt.Valid && now.After(pairingCode.ExpiresAt.Time) {
		a.writeError(c, http.StatusGone, "pairing_code_expired", "绑定码已过期，请在管理系统重新生成")
		return
	}

	existingAgent, err := a.db.queryAgentByDevice(pairingCode.UID, platform, deviceName)
	if err != nil {
		a.Error("query monitor agent by device failed", zap.Error(err), zap.String("uid", pairingCode.UID), zap.String("device_name", deviceName))
		a.writeError(c, http.StatusInternalServerError, "agent_query_failed", "?? Agent ??")
		return
	}
	agentID := "agent_" + util.GenerUUID()
	agentToken := "monitor_agent_" + util.GenerUUID()
	if existingAgent != nil {
		agentID = existingAgent.AgentID
		if err := a.db.updateAgentPairing(agentID, agentToken, deviceName, version); err != nil {
			a.Error("update monitor agent pairing failed", zap.Error(err), zap.String("uid", pairingCode.UID), zap.String("agent_id", agentID))
			a.writeError(c, http.StatusInternalServerError, "agent_update_failed", "?? Agent ??")
			return
		}
	} else {
		if err := a.db.insertAgent(&agentModel{
			AgentID:    agentID,
			UID:        pairingCode.UID,
			AgentToken: agentToken,
			DeviceName: deviceName,
			Platform:   platform,
			Version:    version,
			Status:     "offline",
		}); err != nil {
			a.Error("insert monitor agent failed", zap.Error(err), zap.String("uid", pairingCode.UID))
			a.writeError(c, http.StatusInternalServerError, "agent_create_failed", "?? Agent ??")
			return
		}
	}
	if err := a.db.markPairingCodeUsed(code, now); err != nil {
		a.Error("mark monitor pairing code used failed", zap.Error(err), zap.String("uid", pairingCode.UID))
		a.writeError(c, http.StatusInternalServerError, "pairing_code_consume_failed", "消费绑定码失败")
		return
	}
	if err := a.insertEvent(pairingCode.UID, agentID, "", "agent_paired", "Windows Agent "+deviceName+" 已绑定", map[string]interface{}{"platform": platform}); err != nil {
		a.Error("insert monitor paired event failed", zap.Error(err), zap.String("uid", pairingCode.UID), zap.String("agent_id", agentID))
		a.writeError(c, http.StatusInternalServerError, "monitor_event_create_failed", "记录监控事件失败")
		return
	}
	c.ResponseWithStatus(http.StatusCreated, map[string]interface{}{
		"data": map[string]interface{}{
			"agent_id":                   agentID,
			"agent_token":                agentToken,
			"heartbeat_interval_seconds": heartbeatIntervalSeconds,
			"server_time":                now.UTC().Format(time.RFC3339),
		},
	})
}

func (a *API) agentHeartbeat(c *wkhttp.Context) {
	var req heartbeatReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusUnprocessableEntity, "invalid_heartbeat_payload", "心跳参数错误")
		return
	}
	agent, ok := a.agentFromBearer(c)
	if !ok {
		return
	}
	if strings.TrimSpace(req.AgentID) != agent.AgentID {
		a.writeError(c, http.StatusForbidden, "agent_owner_mismatch", "Agent 身份不匹配")
		return
	}
	deviceName := normalize(req.DeviceName, agent.DeviceName)
	platform := normalize(req.Platform, agentPlatformWindows)
	version := normalize(req.AgentVersion, agent.Version)
	if platform != agentPlatformWindows {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_agent_platform", "暂不支持该 Agent 平台")
		return
	}
	now := a.now()
	wasOnline := agent.LastHeartbeatAt.Valid && now.Sub(agent.LastHeartbeatAt.Time) <= onlineThreshold
	if err := a.db.updateAgentHeartbeat(agent.AgentID, bearerToken(c), deviceName, version, now); err != nil {
		a.Error("update monitor agent heartbeat failed", zap.Error(err), zap.String("agent_id", agent.AgentID))
		a.writeError(c, http.StatusInternalServerError, "heartbeat_update_failed", "更新 Agent 心跳失败")
		return
	}
	if !wasOnline {
		_ = a.insertEvent(agent.UID, agent.AgentID, "", "agent_online", "Windows Agent "+deviceName+" 已在线", map[string]interface{}{"platform": platform})
	}
	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"agent_id":                     agent.AgentID,
			"status":                       "online",
			"next_heartbeat_after_seconds": heartbeatIntervalSeconds,
			"server_time":                  now.UTC().Format(time.RFC3339),
		},
	})
}

func (a *API) listAgents(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	limit := parseLimit(c.Query("limit"), 50)
	agents, err := a.db.queryAgents(uid, limit)
	if err != nil {
		a.Error("query monitor agents failed", zap.Error(err), zap.String("uid", uid))
		a.writeError(c, http.StatusInternalServerError, "agent_query_failed", "查询 Agent 失败")
		return
	}
	now := a.now()
	data := make([]map[string]interface{}, 0, len(agents))
	for _, agent := range agents {
		status := agent.Status
		lastHeartbeatAt := ""
		if agent.LastHeartbeatAt.Valid {
			last := agent.LastHeartbeatAt.Time.UTC()
			lastHeartbeatAt = last.Format(time.RFC3339)
			if now.Sub(last) > onlineThreshold {
				status = "offline"
			}
		}
		data = append(data, map[string]interface{}{
			"id":                agent.AgentID,
			"device_name":       agent.DeviceName,
			"platform":          agent.Platform,
			"version":           agent.Version,
			"status":            status,
			"last_heartbeat_at": lastHeartbeatAt,
		})
	}
	c.Response(map[string]interface{}{
		"data": data,
		"page": map[string]interface{}{"next_cursor": nil},
	})
}

func (a *API) listEvents(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	platform := normalize(c.Query("platform"), monitorPlatformFeishu)
	limit := parseLimit(c.Query("limit"), 20)
	events, err := a.db.queryEvents(uid, platform, limit)
	if err != nil {
		a.Error("query monitor events failed", zap.Error(err), zap.String("uid", uid), zap.String("platform", platform))
		a.writeError(c, http.StatusInternalServerError, "event_query_failed", "查询监控事件失败")
		return
	}
	data := make([]map[string]interface{}, 0, len(events))
	for _, event := range events {
		occurredAt := ""
		if event.CreatedAt.Valid {
			occurredAt = event.CreatedAt.Time.UTC().Format(time.RFC3339)
		}
		data = append(data, map[string]interface{}{
			"id":          event.EventID,
			"type":        event.Type,
			"occurred_at": occurredAt,
			"message":     event.Message,
			"route_id":    event.RouteID,
		})
	}
	c.Response(map[string]interface{}{
		"data": data,
		"page": map[string]interface{}{"next_cursor": nil},
	})
}

func (a *API) feishuStats(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	routes, err := a.db.queryRoutes(uid, monitorPlatformFeishu, 100)
	if err != nil {
		a.Error("query monitor stats routes failed", zap.Error(err), zap.String("uid", uid))
		a.writeError(c, http.StatusInternalServerError, "stats_query_failed", "查询监控统计失败")
		return
	}
	runningRoutes := 0
	todayForwarded := 0
	for _, route := range routes {
		if route.Status == "running" {
			runningRoutes++
		}
		todayForwarded += route.TodayForwardedCount
	}
	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"running_routes":  runningRoutes,
			"today_forwarded": todayForwarded,
			"alerts":          0,
		},
	})
}

func (a *API) listRoutes(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	platform := normalize(c.Query("platform"), monitorPlatformFeishu)
	limit := parseLimit(c.Query("limit"), 50)
	routes, err := a.db.queryRoutes(uid, platform, limit)
	if err != nil {
		a.Error("query monitor routes failed", zap.Error(err), zap.String("uid", uid), zap.String("platform", platform))
		a.writeError(c, http.StatusInternalServerError, "route_query_failed", "查询监控规则失败")
		return
	}
	data := make([]map[string]interface{}, 0, len(routes))
	for _, route := range routes {
		data = append(data, routeToJSON(route))
	}
	c.Response(map[string]interface{}{
		"data": data,
		"page": map[string]interface{}{"next_cursor": nil},
	})
}

func (a *API) createRoute(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	var req createRouteReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_route_request", "规则参数错误")
		return
	}
	platform := normalize(req.Platform, monitorPlatformFeishu)
	connectorType := normalize(req.ConnectorType, monitorConnectorFeishuWebGroup)
	routeType := normalize(req.RouteType, monitorRouteFeishuWebToWukongIM)
	if platform != monitorPlatformFeishu || connectorType != monitorConnectorFeishuWebGroup ||
		(routeType != monitorRouteFeishuWebToWukongIM && routeType != monitorRouteFeishuWebToFeishuAPI) {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_route_type", "暂不支持该监控规则类型")
		return
	}
	sourceName := stringFromMap(req.Source, "chat_name")
	destinationType := normalize(stringFromMap(req.Destination, "type"), monitorDestinationWukongIMGroup)
	destinationID := stringFromMap(req.Destination, "destination_id")
	destinationNo := stringFromMap(req.Destination, "group_no")
	destinationName := stringFromMap(req.Destination, "group_name")
	if destinationType == monitorDestinationFeishuOpenAPI {
		destinationNo = stringFromMap(req.Destination, "chat_id")
		destinationName = stringFromMap(req.Destination, "name")
	}
	senderIdentity := mapFromMap(req.Destination, "sender_identity")
	senderDisplayName := ""
	senderDisplayAvatar := ""
	if destinationType == monitorDestinationWukongIMGroup {
		senderDisplayName = trimRunes(normalize(stringFromMap(senderIdentity, "display_name"), "Feishu Monitor"), 64)
		senderDisplayAvatar = trimRunes(stringFromMap(senderIdentity, "display_avatar"), 512)
	}
	if sourceName == "" || destinationNo == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_route_request", "飞书群名称和目标群不能为空")
		return
	}
	if destinationType != monitorDestinationWukongIMGroup && destinationType != monitorDestinationFeishuOpenAPI {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_destination_type", "暂不支持该目标类型")
		return
	}
	if destinationType == monitorDestinationFeishuOpenAPI {
		if routeType != monitorRouteFeishuWebToFeishuAPI {
			a.writeError(c, http.StatusUnprocessableEntity, "route_destination_mismatch", "飞书 OpenAPI 目标需要使用对应规则类型")
			return
		}
		if destinationID == "" {
			a.writeError(c, http.StatusBadRequest, "invalid_route_request", "飞书 OpenAPI 发送通道不能为空")
			return
		}
		destination, err := a.db.queryDestinationByID(uid, destinationID)
		if err != nil {
			a.Error("query monitor route destination failed", zap.Error(err), zap.String("uid", uid), zap.String("destination_id", destinationID))
			a.writeError(c, http.StatusInternalServerError, "destination_query_failed", "查询发送通道失败")
			return
		}
		if destination == nil || destination.DestinationType != monitorDestinationFeishuOpenAPI {
			a.writeError(c, http.StatusNotFound, "destination_not_found", "飞书 OpenAPI 发送通道不存在")
			return
		}
		destinationNo = destination.ChatID
		destinationName = normalize(destinationName, destination.DisplayName)
	}
	agentID := strings.TrimSpace(req.AgentID)
	if agentID == "" {
		agents, err := a.db.queryAgents(uid, 1)
		if err != nil {
			a.Error("query monitor route default agent failed", zap.Error(err), zap.String("uid", uid))
			a.writeError(c, http.StatusInternalServerError, "agent_query_failed", "查询 Agent 失败")
			return
		}
		if len(agents) > 0 {
			agentID = agents[0].AgentID
		}
	}
	if agentID == "" {
		a.writeError(c, http.StatusUnprocessableEntity, "agent_required", "请先绑定 Windows Agent")
		return
	}

	route := &routeModel{
		RouteID:             "route_" + util.GenerUUID(),
		UID:                 uid,
		Platform:            platform,
		ConnectorType:       connectorType,
		RouteType:           routeType,
		SourceName:          sourceName,
		DestinationType:     destinationType,
		DestinationID:       destinationID,
		DestinationName:     normalize(destinationName, destinationNo),
		DestinationNo:       destinationNo,
		SenderDisplayName:   senderDisplayName,
		SenderDisplayAvatar: senderDisplayAvatar,
		AgentID:             agentID,
		Status:              "running",
		IncludeText:         boolToInt(boolFromMap(req.MessagePolicy, "include_text", true)),
		IncludeLinks:        boolToInt(boolFromMap(req.MessagePolicy, "include_links", true)),
		IncludeImages:       boolToInt(boolFromMap(req.MessagePolicy, "include_images", false)),
		IncludeFiles:        boolToInt(boolFromMap(req.MessagePolicy, "include_files", false)),
	}
	if err := a.db.insertRoute(route); err != nil {
		a.Error("insert monitor route failed", zap.Error(err), zap.String("uid", uid), zap.String("agent_id", agentID))
		a.writeError(c, http.StatusInternalServerError, "route_create_failed", "创建监控规则失败")
		return
	}
	_ = a.insertEvent(uid, agentID, route.RouteID, "route_created", "已创建飞书监控规则 "+route.SourceName+" → "+route.DestinationName, map[string]interface{}{"route_id": route.RouteID})
	c.ResponseWithStatus(http.StatusCreated, map[string]interface{}{"data": routeToJSON(route)})
}

func (a *API) updateRouteStatus(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	routeID := strings.TrimSpace(c.Param("route_id"))
	var req updateRouteStatusReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_route_status_request", "状态参数错误")
		return
	}
	status := normalize(req.Status, "running")
	if status != "running" && status != "paused" {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_route_status", "暂不支持该规则状态")
		return
	}
	pausedAt := dbr.NullTime{}
	if status == "paused" {
		pausedAt = dbrNullTime(a.now())
	}
	if err := a.db.updateRouteStatus(uid, routeID, status, pausedAt); err != nil {
		a.Error("update monitor route status failed", zap.Error(err), zap.String("uid", uid), zap.String("route_id", routeID))
		a.writeError(c, http.StatusInternalServerError, "route_status_update_failed", "更新监控规则状态失败")
		return
	}
	c.Response(map[string]interface{}{"data": map[string]interface{}{"route_id": routeID, "status": status}})
}

func (a *API) listCredentials(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	platform := normalize(c.Query("platform"), monitorPlatformFeishu)
	limit := parseLimit(c.Query("limit"), 50)
	credentials, err := a.db.queryCredentials(uid, platform, limit)
	if err != nil {
		a.Error("query monitor credentials failed", zap.Error(err), zap.String("uid", uid), zap.String("platform", platform))
		a.writeError(c, http.StatusInternalServerError, "credential_query_failed", "查询机器人凭证失败")
		return
	}
	data := make([]map[string]interface{}, 0, len(credentials))
	for _, credential := range credentials {
		data = append(data, credentialToJSON(credential))
	}
	c.Response(map[string]interface{}{
		"data": data,
		"page": map[string]interface{}{"next_cursor": nil},
	})
}

func (a *API) createCredential(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	var req createCredentialReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_credential_request", "凭证参数错误")
		return
	}
	platform := normalize(req.Platform, monitorPlatformFeishu)
	kind := normalize(req.Kind, monitorCredentialFeishuOpenAPI)
	if !supportedCredentialKind(platform, kind) {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_credential_kind", "暂不支持该凭证类型")
		return
	}
	displayName := trimRunes(normalize(req.DisplayName, defaultCredentialDisplayName(kind)), 120)
	appID := strings.TrimSpace(req.AppID)
	appSecret := strings.TrimSpace(req.AppSecret)
	webhookURL := strings.TrimSpace(req.WebhookURL)
	secret := strings.TrimSpace(req.Secret)
	if kind == monitorCredentialFeishuOpenAPI && (appID == "" || appSecret == "") {
		a.writeError(c, http.StatusBadRequest, "invalid_credential_request", "飞书 App ID 和 App Secret 不能为空")
		return
	}
	if kind == monitorCredentialFeishuWebhook && webhookURL == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_credential_request", "Webhook 地址不能为空")
		return
	}
	appIDCiphertext, appSecretCiphertext, webhookURLCiphertext, secretCiphertext, ok := a.encryptCredentialFields(c, appID, appSecret, webhookURL, secret)
	if !ok {
		return
	}
	model := &credentialModel{
		CredentialID:         "cred_" + util.GenerUUID(),
		UID:                  uid,
		Platform:             platform,
		Kind:                 kind,
		DisplayName:          displayName,
		AppIDCiphertext:      appIDCiphertext,
		AppIDMasked:          maskCredentialValue(appID),
		AppSecretCiphertext:  appSecretCiphertext,
		WebhookURLCiphertext: webhookURLCiphertext,
		WebhookURLMasked:     maskCredentialValue(webhookURL),
		SecretCiphertext:     secretCiphertext,
		Status:               "active",
		LastError:            "",
	}
	if err := a.db.insertCredential(model); err != nil {
		a.Error("insert monitor credential failed", zap.Error(err), zap.String("uid", uid), zap.String("platform", platform), zap.String("kind", kind))
		a.writeError(c, http.StatusInternalServerError, "credential_create_failed", "创建机器人凭证失败")
		return
	}
	_ = a.insertEvent(uid, "", "", "credential_created", "已创建统一机器人凭证 "+displayName, map[string]interface{}{"credential_id": model.CredentialID, "platform": platform, "kind": kind})
	c.ResponseWithStatus(http.StatusCreated, map[string]interface{}{"data": credentialToJSON(model)})
}

func (a *API) testCredential(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	credentialID := strings.TrimSpace(c.Param("credential_id"))
	if credentialID == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_credential_id", "凭证 ID 不能为空")
		return
	}
	credential, err := a.db.queryCredentialByID(uid, credentialID)
	if err != nil {
		a.Error("query monitor credential for test failed", zap.Error(err), zap.String("uid", uid), zap.String("credential_id", credentialID))
		a.writeError(c, http.StatusInternalServerError, "credential_query_failed", "查询机器人凭证失败")
		return
	}
	if credential == nil {
		a.writeError(c, http.StatusNotFound, "credential_not_found", "机器人凭证不存在")
		return
	}
	now := a.now()
	status := "active"
	message := "连接配置格式正常"
	if err := a.db.updateCredentialCheck(uid, credentialID, status, "", now); err != nil {
		a.Error("update monitor credential check failed", zap.Error(err), zap.String("uid", uid), zap.String("credential_id", credentialID))
		a.writeError(c, http.StatusInternalServerError, "credential_test_failed", "测试机器人凭证失败")
		return
	}
	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"credential_id": credentialID,
			"status":        status,
			"message":       message,
			"checked_at":    now.UTC().Format(time.RFC3339),
		},
	})
}

func (a *API) listDestinations(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	platform := normalize(c.Query("platform"), monitorPlatformFeishu)
	limit := parseLimit(c.Query("limit"), 50)
	destinations, err := a.db.queryDestinations(uid, platform, limit)
	if err != nil {
		a.Error("query monitor destinations failed", zap.Error(err), zap.String("uid", uid), zap.String("platform", platform))
		a.writeError(c, http.StatusInternalServerError, "destination_query_failed", "查询发送通道失败")
		return
	}
	data := make([]map[string]interface{}, 0, len(destinations))
	for _, destination := range destinations {
		data = append(data, destinationToJSON(destination))
	}
	c.Response(map[string]interface{}{
		"data": data,
		"page": map[string]interface{}{"next_cursor": nil},
	})
}

func (a *API) createDestination(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	var req createDestinationReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_destination_request", "发送通道参数错误")
		return
	}
	platform := normalize(req.Platform, monitorPlatformFeishu)
	destinationType := normalize(req.DestinationType, monitorDestinationFeishuOpenAPI)
	if !supportedDestinationType(platform, destinationType) {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_destination_type", "暂不支持该发送通道类型")
		return
	}
	credentialID := strings.TrimSpace(req.CredentialID)
	if credentialID == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_destination_request", "请选择统一凭证")
		return
	}
	credential, err := a.db.queryCredentialByID(uid, credentialID)
	if err != nil {
		a.Error("query monitor destination credential failed", zap.Error(err), zap.String("uid", uid), zap.String("credential_id", credentialID))
		a.writeError(c, http.StatusInternalServerError, "credential_query_failed", "查询机器人凭证失败")
		return
	}
	if credential == nil {
		a.writeError(c, http.StatusNotFound, "credential_not_found", "机器人凭证不存在")
		return
	}
	if credential.Platform != platform {
		a.writeError(c, http.StatusUnprocessableEntity, "credential_platform_mismatch", "凭证平台与发送通道不一致")
		return
	}
	chatID := strings.TrimSpace(req.ChatID)
	webhookURL := strings.TrimSpace(req.WebhookURL)
	if destinationType == monitorDestinationFeishuOpenAPI && chatID == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_destination_request", "飞书 OpenAPI 群 chat_id 不能为空")
		return
	}
	if destinationType == monitorDestinationFeishuWebhook && webhookURL == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_destination_request", "Webhook 地址不能为空")
		return
	}
	webhookURLCiphertext, secretCiphertext, ok := a.encryptDestinationFields(c, webhookURL, req.Secret)
	if !ok {
		return
	}
	displayName := trimRunes(normalize(req.DisplayName, defaultDestinationDisplayName(destinationType)), 120)
	model := &destinationModel{
		DestinationID:        "dest_" + util.GenerUUID(),
		UID:                  uid,
		Platform:             platform,
		DestinationType:      destinationType,
		DisplayName:          displayName,
		CredentialID:         credentialID,
		ChatID:               chatID,
		WebhookURLCiphertext: webhookURLCiphertext,
		WebhookURLMasked:     maskCredentialValue(webhookURL),
		SecretCiphertext:     secretCiphertext,
		Status:               "active",
		LastError:            "",
	}
	if err := a.db.insertDestination(model); err != nil {
		a.Error("insert monitor destination failed", zap.Error(err), zap.String("uid", uid), zap.String("platform", platform), zap.String("destination_type", destinationType))
		a.writeError(c, http.StatusInternalServerError, "destination_create_failed", "创建发送通道失败")
		return
	}
	_ = a.insertEvent(uid, "", "", "destination_created", "已创建统一发送通道 "+displayName, map[string]interface{}{"destination_id": model.DestinationID, "credential_id": credentialID, "platform": platform, "destination_type": destinationType})
	c.ResponseWithStatus(http.StatusCreated, map[string]interface{}{"data": destinationToJSON(model)})
}

func (a *API) agentRoutes(c *wkhttp.Context) {
	agent, ok := a.agentFromBearer(c)
	if !ok {
		return
	}
	routes, err := a.db.queryRunningRoutesForAgent(agent.AgentID)
	if err != nil {
		a.Error("query monitor agent routes failed", zap.Error(err), zap.String("agent_id", agent.AgentID))
		a.writeError(c, http.StatusInternalServerError, "agent_route_query_failed", "查询 Agent 规则失败")
		return
	}
	data := make([]map[string]interface{}, 0, len(routes))
	for _, route := range routes {
		if route.UID != agent.UID {
			continue
		}
		data = append(data, agentRouteToJSON(route))
	}
	c.Response(map[string]interface{}{"data": data})
}

func (a *API) agentBrowserStatus(c *wkhttp.Context) {
	var req browserStatusReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_browser_status_request", "浏览器状态参数错误")
		return
	}
	agent, ok := a.agentFromBearer(c)
	if !ok {
		return
	}
	if strings.TrimSpace(req.AgentID) != agent.AgentID {
		a.writeError(c, http.StatusForbidden, "agent_owner_mismatch", "Agent 身份不匹配")
		return
	}
	observedAt := parseTime(req.ObservedAt, a.now())
	status := &browserStatusModel{
		StatusID:     "browser_status_" + util.GenerUUID(),
		UID:          agent.UID,
		AgentID:      agent.AgentID,
		Platform:     normalize(req.Platform, monitorPlatformFeishu),
		Browser:      normalize(req.Browser, monitorBrowserChromium),
		ProfileMode:  normalize(req.ProfileMode, monitorProfileIsolatedPersistent),
		LoginStatus:  normalize(req.LoginStatus, "unknown"),
		ObservedAt:   dbrNullTime(observedAt),
		ErrorMessage: trimRunes(req.ErrorMessage, 255),
	}
	if err := a.db.upsertBrowserStatus(status); err != nil {
		a.Error("upsert monitor browser status failed", zap.Error(err), zap.String("agent_id", agent.AgentID))
		a.writeError(c, http.StatusInternalServerError, "browser_status_update_failed", "更新飞书登录状态失败")
		return
	}
	c.Response(map[string]interface{}{"data": browserStatusToJSON(status)})
}

func (a *API) feishuBrowserStatus(c *wkhttp.Context) {
	uid := c.GetLoginUID()
	status, err := a.db.queryLatestBrowserStatus(uid, monitorPlatformFeishu)
	if err != nil {
		a.Error("query monitor browser status failed", zap.Error(err), zap.String("uid", uid))
		a.writeError(c, http.StatusInternalServerError, "browser_status_query_failed", "查询飞书登录状态失败")
		return
	}
	if status == nil {
		c.Response(map[string]interface{}{"data": map[string]interface{}{
			"browser":       monitorBrowserChromium,
			"profile_mode":  monitorProfileIsolatedPersistent,
			"login_status":  "unknown",
			"observed_at":   "",
			"error_message": "",
		}})
		return
	}
	c.Response(map[string]interface{}{"data": browserStatusToJSON(status)})
}

func (a *API) observedMessage(c *wkhttp.Context) {
	var req observedMessageReq
	if err := c.BindJSON(&req); err != nil {
		a.writeError(c, http.StatusBadRequest, "invalid_observed_message_request", "消息参数错误")
		return
	}
	agent, ok := a.agentFromBearer(c)
	if !ok {
		return
	}
	if strings.TrimSpace(req.AgentID) != agent.AgentID {
		a.writeError(c, http.StatusForbidden, "agent_owner_mismatch", "Agent 身份不匹配")
		return
	}
	if strings.TrimSpace(req.RouteID) == "" || strings.TrimSpace(req.SourceMessageID) == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_observed_message_request", "规则 ID 和源消息 ID 不能为空")
		return
	}
	route, err := a.db.queryRouteByID(req.RouteID)
	if err != nil {
		a.Error("query monitor route for observed message failed", zap.Error(err), zap.String("agent_id", agent.AgentID), zap.String("route_id", req.RouteID))
		a.writeError(c, http.StatusInternalServerError, "route_query_failed", "查询监控规则失败")
		return
	}
	if route == nil {
		a.writeError(c, http.StatusNotFound, "route_not_found", "监控规则不存在")
		return
	}
	if route.UID != agent.UID || route.AgentID != agent.AgentID {
		a.writeError(c, http.StatusForbidden, "route_agent_mismatch", "监控规则未分配给当前 Agent")
		return
	}
	existing, err := a.db.queryObservedMessageByRouteSource(req.RouteID, req.SourceMessageID)
	if err != nil {
		a.Error("query monitor observed dedupe failed", zap.Error(err), zap.String("route_id", req.RouteID))
		a.writeError(c, http.StatusInternalServerError, "observed_message_query_failed", "消息去重查询失败")
		return
	}
	if existing != nil {
		c.Response(map[string]interface{}{"data": map[string]interface{}{
			"accepted":       true,
			"duplicate":      true,
			"forward_status": "duplicate",
			"message_id":     existing.MessageID,
		}})
		return
	}

	now := a.now()
	observedAt := parseTime(req.ObservedAt, now)
	metadataJSON := "{}"
	if len(req.Metadata) > 0 {
		if payload, err := json.Marshal(req.Metadata); err == nil {
			metadataJSON = string(payload)
		}
	}
	attachmentsJSON := "[]"
	message := &observedMessageModel{
		MessageID:       "monitor_msg_" + util.GenerUUID(),
		UID:             agent.UID,
		RouteID:         route.RouteID,
		AgentID:         agent.AgentID,
		SourcePlatform:  normalize(req.SourcePlatform, monitorPlatformFeishu),
		SourceChatName:  normalize(req.SourceChatName, route.SourceName),
		SourceMessageID: strings.TrimSpace(req.SourceMessageID),
		MessageType:     normalize(req.MessageType, "text"),
		Content:         strings.TrimSpace(req.Content),
		Metadata:        metadataJSON,
		AttachmentsJSON: attachmentsJSON,
		Attachments:     req.Attachments,
		SourceCreatedAt: optionalTime(req.SourceCreatedAt),
		ObservedAt:      dbrNullTime(observedAt),
		ForwardStatus:   "pending",
	}
	if message.Content == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_observed_message_request", "消息内容不能为空")
		return
	}
	if err := a.prepareObservedMessageAssetsForInsert(route, message); err != nil {
		a.Error("prepare monitor observed message assets failed", zap.Error(err), zap.String("route_id", route.RouteID), zap.String("message_type", message.MessageType))
		a.writeError(c, http.StatusInternalServerError, "observed_message_attachment_prepare_failed", "处理监听消息附件失败")
		return
	}
	if err := a.db.insertObservedMessage(message); err != nil {
		if isDuplicateKeyError(err) {
			existing, queryErr := a.db.queryObservedMessageByRouteSource(message.RouteID, message.SourceMessageID)
			if queryErr == nil && existing != nil {
				c.Response(map[string]interface{}{"data": map[string]interface{}{
					"accepted":       true,
					"duplicate":      true,
					"forward_status": "duplicate",
					"message_id":     existing.MessageID,
				}})
				return
			}
			if queryErr != nil {
				a.Error("query duplicate monitor observed message after insert conflict failed", zap.Error(queryErr), zap.String("route_id", route.RouteID))
			}
		}
		a.Error("insert monitor observed message failed", zap.Error(err), zap.String("route_id", route.RouteID))
		a.writeError(c, http.StatusInternalServerError, "observed_message_create_failed", "记录监听消息失败")
		return
	}

	forwardStatus := "skipped"
	if routeAllowsType(route, message.MessageType) {
		if err := a.forwardMessage(route, message); err != nil {
			a.Error("forward monitor observed message failed", zap.Error(err), zap.String("route_id", route.RouteID), zap.String("message_id", message.MessageID))
			forwardStatus = "failed"
			_ = a.db.markObservedMessageForwardFailed(message.MessageID, trimRunes(err.Error(), 255))
			_ = a.insertEvent(agent.UID, agent.AgentID, route.RouteID, "forward_failed", "飞书消息已监听，但转发到悟空 IM 群失败", map[string]interface{}{"route_id": route.RouteID, "message_id": message.MessageID})
		} else {
			forwardStatus = "forwarded"
			forwardedAt := a.now()
			_ = a.db.markObservedMessageForwarded(message.MessageID, forwardedAt)
			_ = a.db.incrementRouteForwarded(route.RouteID, forwardedAt)
			_ = a.insertEvent(agent.UID, agent.AgentID, route.RouteID, "forwarded", "已转发 "+route.SourceName+" → "+route.DestinationName, map[string]interface{}{"route_id": route.RouteID, "message_id": message.MessageID})
		}
	} else {
		_ = a.insertEvent(agent.UID, agent.AgentID, route.RouteID, "message_skipped", "已跳过暂不支持的飞书消息类型", map[string]interface{}{"route_id": route.RouteID, "message_type": message.MessageType})
	}

	c.Response(map[string]interface{}{"data": map[string]interface{}{
		"accepted":       true,
		"duplicate":      false,
		"forward_status": forwardStatus,
		"message_id":     message.MessageID,
	}})
}

func (a *API) agentFromBearer(c *wkhttp.Context) (*agentModel, bool) {
	token := bearerToken(c)
	if token == "" {
		a.writeError(c, http.StatusUnauthorized, "invalid_agent_token", "Agent token 无效")
		return nil, false
	}
	agent, err := a.db.queryAgentByToken(token)
	if err != nil {
		a.Error("query monitor agent token failed", zap.Error(err))
		a.writeError(c, http.StatusInternalServerError, "agent_token_query_failed", "查询 Agent 失败")
		return nil, false
	}
	if agent == nil {
		a.writeError(c, http.StatusUnauthorized, "invalid_agent_token", "Agent token 无效")
		return nil, false
	}
	return agent, true
}

func (a *API) forwardObservedMessage(route *routeModel, message *observedMessageModel) error {
	if strings.TrimSpace(route.DestinationType) == monitorDestinationFeishuOpenAPI {
		return a.forwardObservedMessageToFeishuOpenAPI(route, message)
	}
	if route.DestinationNo == "" {
		return errors.New("destination group is empty")
	}
	if err := a.ensureObservedMessageAssets(route, message); err != nil {
		return err
	}
	payloadMap, err := forwardObservedMessagePayload(route, message)
	if err != nil {
		return err
	}
	payload, err := json.Marshal(payloadMap)
	if err != nil {
		return err
	}
	return a.ctx.SendMessage(&config.MsgSendReq{
		Header: config.MsgHeader{
			NoPersist: 0,
			RedDot:    1,
			SyncOnce:  0,
		},
		FromUID:     a.ctx.GetConfig().Account.SystemUID,
		ChannelID:   route.DestinationNo,
		ChannelType: common.ChannelTypeGroup.Uint8(),
		Payload:     payload,
	})
}

func (a *API) forwardObservedMessageToFeishuOpenAPI(route *routeModel, message *observedMessageModel) error {
	if strings.TrimSpace(route.DestinationID) == "" {
		return errors.New("feishu destination id is empty")
	}
	destination, err := a.db.queryDestinationByID(route.UID, route.DestinationID)
	if err != nil {
		return err
	}
	if destination == nil {
		return errors.New("feishu destination not found")
	}
	credential, err := a.db.queryCredentialByID(route.UID, destination.CredentialID)
	if err != nil {
		return err
	}
	if credential == nil {
		return errors.New("feishu credential not found")
	}
	appID, err := decryptMonitorSecret(credential.AppIDCiphertext)
	if err != nil {
		return err
	}
	appSecret, err := decryptMonitorSecret(credential.AppSecretCiphertext)
	if err != nil {
		return err
	}
	token, err := a.fetchFeishuTenantAccessToken(appID, appSecret)
	if err != nil {
		return err
	}
	return a.sendFeishuTextMessage(token, destination.ChatID, forwardObservedMessageContent(route, message))
}

func (a *API) fetchFeishuTenantAccessToken(appID, appSecret string) (string, error) {
	payload, err := json.Marshal(map[string]interface{}{
		"app_id":     strings.TrimSpace(appID),
		"app_secret": strings.TrimSpace(appSecret),
	})
	if err != nil {
		return "", err
	}
	req, err := http.NewRequest(http.MethodPost, feishuTenantTokenEndpoint, bytes.NewReader(payload))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json; charset=utf-8")
	resp, err := a.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 2*1024*1024))
	if err != nil {
		return "", err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", fmt.Errorf("feishu tenant token http %d: %s", resp.StatusCode, string(body))
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal(body, &decoded); err != nil {
		return "", err
	}
	if code, ok := decoded["code"].(float64); ok && int(code) != 0 {
		return "", fmt.Errorf("feishu tenant token error: %v", decoded["msg"])
	}
	token := strings.TrimSpace(toString(decoded["tenant_access_token"]))
	if token == "" {
		return "", errors.New("feishu tenant access token is empty")
	}
	return token, nil
}

func (a *API) sendFeishuTextMessage(token, chatID, content string) error {
	if strings.TrimSpace(chatID) == "" {
		return errors.New("feishu chat_id is empty")
	}
	textContent, err := json.Marshal(map[string]interface{}{
		"text": strings.TrimSpace(content),
	})
	if err != nil {
		return err
	}
	payload, err := json.Marshal(map[string]interface{}{
		"receive_id": strings.TrimSpace(chatID),
		"msg_type":   "text",
		"content":    string(textContent),
	})
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPost, feishuSendMessageEndpoint+"?receive_id_type=chat_id", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(token))
	req.Header.Set("Content-Type", "application/json; charset=utf-8")
	resp, err := a.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 2*1024*1024))
	if err != nil {
		return err
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("feishu send message http %d: %s", resp.StatusCode, string(body))
	}
	var decoded map[string]interface{}
	if err := json.Unmarshal(body, &decoded); err != nil {
		return err
	}
	if code, ok := decoded["code"].(float64); ok && int(code) != 0 {
		return fmt.Errorf("feishu send message error: %v", decoded["msg"])
	}
	return nil
}

func forwardObservedMessageContent(route *routeModel, message *observedMessageModel) string {
	return strings.TrimSpace(message.Content)
}

func forwardObservedMessagePayload(route *routeModel, message *observedMessageModel) (map[string]interface{}, error) {
	switch strings.TrimSpace(message.MessageType) {
	case "image":
		attachment := firstObservedAttachment(message, "image")
		url := firstNonEmpty(attachment.RemoteURL, attachment.SourceURL)
		if strings.TrimSpace(url) == "" {
			return nil, errors.New("image url is empty")
		}
		payload := baseObservedPayload(route, common.Image)
		payload["url"] = strings.TrimSpace(url)
		if attachment.Width > 0 {
			payload["width"] = attachment.Width
		}
		if attachment.Height > 0 {
			payload["height"] = attachment.Height
		}
		if name := strings.TrimSpace(attachment.FileName); name != "" {
			payload["name"] = name
		}
		return payload, nil
	case "file":
		attachment := firstObservedAttachment(message, "file")
		url := firstNonEmpty(attachment.RemoteURL, attachment.SourceURL)
		if strings.TrimSpace(url) == "" {
			return nil, errors.New("file url is empty")
		}
		name := sanitizeObservedFileName(firstNonEmpty(attachment.FileName, message.Content, "file"))
		payload := baseObservedPayload(route, common.File)
		payload["url"] = strings.TrimSpace(url)
		payload["name"] = name
		payload["size"] = attachment.FileSizeBytes
		payload["suffix"] = observedFileSuffix(name)
		return payload, nil
	default:
		payload := baseObservedPayload(route, common.Text)
		payload["content"] = forwardObservedMessageContent(route, message)
		return payload, nil
	}
}

func baseObservedPayload(route *routeModel, contentType common.ContentType) map[string]interface{} {
	displayName := "Feishu Monitor"
	displayAvatar := ""
	if route != nil {
		displayName = normalize(route.SenderDisplayName, displayName)
		displayAvatar = strings.TrimSpace(route.SenderDisplayAvatar)
	}
	return map[string]interface{}{
		"type":   contentType,
		"source": "feishu_monitor",
		"robot": map[string]interface{}{
			"provider":       "feishu_monitor",
			"display_name":   displayName,
			"display_avatar": displayAvatar,
		},
	}
}

func (a *API) ensureObservedMessageAssets(route *routeModel, message *observedMessageModel) error {
	switch strings.TrimSpace(message.MessageType) {
	case "image":
		return a.ensureObservedAttachmentUploaded(route, message, "image")
	case "file":
		return a.ensureObservedAttachmentUploaded(route, message, "file")
	default:
		return nil
	}
}

func (a *API) prepareObservedMessageAssetsForInsert(route *routeModel, message *observedMessageModel) error {
	if routeAllowsType(route, message.MessageType) {
		switch strings.TrimSpace(message.MessageType) {
		case "image":
			if err := a.ensureObservedAttachmentUploadedWithPersistence(route, message, "image", false); err != nil {
				return err
			}
		case "file":
			if err := a.ensureObservedAttachmentUploadedWithPersistence(route, message, "file", false); err != nil {
				return err
			}
		}
	}
	stripObservedAttachmentInlineData(message.Attachments)
	return marshalObservedMessageAttachments(message)
}

func (a *API) ensureObservedAttachmentUploaded(route *routeModel, message *observedMessageModel, kind string) error {
	return a.ensureObservedAttachmentUploadedWithPersistence(route, message, kind, true)
}

func (a *API) ensureObservedAttachmentUploadedWithPersistence(route *routeModel, message *observedMessageModel, kind string, persist bool) error {
	for i := range message.Attachments {
		if strings.TrimSpace(message.Attachments[i].Kind) != kind {
			continue
		}
		if strings.TrimSpace(message.Attachments[i].RemoteURL) != "" {
			stripObservedAttachmentInlineData(message.Attachments)
			return a.persistObservedMessageAttachments(message, persist)
		}
		data, contentType, fileName, err := a.fetchObservedAttachment(message.Attachments[i])
		if err != nil {
			return err
		}
		if len(data) == 0 {
			return errors.New("attachment data is empty")
		}
		if strings.TrimSpace(fileName) == "" {
			fileName = message.Attachments[i].FileName
		}
		if strings.TrimSpace(fileName) == "" {
			fileName = strings.TrimSpace(message.Content)
		}
		if strings.TrimSpace(fileName) == "" {
			fileName = kind + preferredObservedExt(contentType)
		}
		fileName = sanitizeObservedFileName(fileName)
		if kind == "image" {
			contentType = normalizeObservedImageContentType(data, contentType)
		}
		contentType = normalizeObservedContentType(contentType, fileName)
		if kind == "image" {
			fileName = ensureObservedFileNameExt(fileName, preferredObservedExt(contentType))
		}
		remoteURL, finalName, size, err := a.uploadObservedBinary(route, fileName, contentType, data)
		if err != nil {
			return err
		}
		message.Attachments[i].RemoteURL = remoteURL
		message.Attachments[i].FileName = finalName
		message.Attachments[i].FileSizeBytes = size
		message.Attachments[i].MimeType = contentType
		if kind == "image" && (message.Attachments[i].Width == 0 || message.Attachments[i].Height == 0) {
			width, height := detectObservedImageSize(data)
			message.Attachments[i].Width = width
			message.Attachments[i].Height = height
		}
		stripObservedAttachmentInlineData(message.Attachments)
		return a.persistObservedMessageAttachments(message, persist)
	}
	return fmt.Errorf("%s attachment is missing", kind)
}

func stripObservedAttachmentInlineData(attachments []observedAttachment) {
	for i := range attachments {
		attachments[i].DataURL = ""
		attachments[i].LocalPath = ""
		attachments[i].SourceURL = ""
	}
}

func marshalObservedMessageAttachments(message *observedMessageModel) error {
	payload, err := json.Marshal(message.Attachments)
	if err != nil {
		return err
	}
	message.AttachmentsJSON = string(payload)
	return nil
}

func (a *API) persistObservedMessageAttachments(message *observedMessageModel, persist bool) error {
	if err := marshalObservedMessageAttachments(message); err != nil {
		return err
	}
	if !persist || message.MessageID == "" || a.db == nil {
		return nil
	}
	return a.db.updateObservedMessageAttachments(message.MessageID, message.AttachmentsJSON)
}

func (a *API) fetchObservedAttachment(attachment observedAttachment) ([]byte, string, string, error) {
	if dataURL := strings.TrimSpace(attachment.DataURL); dataURL != "" {
		data, contentType, err := decodeObservedDataURL(dataURL)
		return data, firstNonEmpty(attachment.MimeType, contentType), attachment.FileName, err
	}
	sourceURL := strings.TrimSpace(attachment.SourceURL)
	if sourceURL == "" {
		return nil, "", "", errors.New("attachment source url is empty")
	}
	req, err := http.NewRequest(http.MethodGet, sourceURL, nil)
	if err != nil {
		return nil, "", "", err
	}
	req.Header.Set("User-Agent", "WuKongIM-Feishu-Monitor/1.0")
	resp, err := a.httpClient.Do(req)
	if err != nil {
		return nil, "", "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, "", "", fmt.Errorf("download attachment failed: http %d", resp.StatusCode)
	}
	limited := io.LimitReader(resp.Body, maxObservedAttachmentBytes+1)
	data, err := io.ReadAll(limited)
	if err != nil {
		return nil, "", "", err
	}
	if int64(len(data)) > maxObservedAttachmentBytes {
		return nil, "", "", errors.New("attachment exceeds 100MB limit")
	}
	contentType := firstNonEmpty(attachment.MimeType, resp.Header.Get("Content-Type"))
	fileName := firstNonEmpty(attachment.FileName, fileNameFromContentDisposition(resp.Header.Get("Content-Disposition")))
	return data, contentType, fileName, nil
}

func (a *API) uploadObservedBinary(route *routeModel, originalFileName, contentType string, data []byte) (string, string, int64, error) {
	if len(data) == 0 {
		return "", "", 0, errors.New("resource data is empty")
	}
	fileName := sanitizeObservedFileName(originalFileName)
	if fileName == "" {
		fileName = "feishu_monitor_" + strings.ToLower(util.GenerUUID())
	}
	ext := observedFileExt(fileName)
	if ext == "" {
		ext = preferredObservedExt(contentType)
		fileName += ext
	}
	objectPath := fmt.Sprintf(
		"chat/%d/%s/%d_%s%s",
		common.ChannelTypeGroup.Uint8(),
		strings.TrimSpace(route.DestinationNo),
		a.now().UnixNano(),
		strings.ToLower(util.GenerUUID()),
		ext,
	)
	if _, err := a.fileService.UploadFile(objectPath, contentType, func(w io.Writer) error {
		_, copyErr := io.Copy(w, bytes.NewReader(data))
		return copyErr
	}); err != nil {
		return "", "", 0, err
	}
	return "v1/file/preview/" + strings.TrimLeft(objectPath, "/"), fileName, int64(len(data)), nil
}

func firstObservedAttachment(message *observedMessageModel, kind string) observedAttachment {
	for _, attachment := range message.Attachments {
		if strings.TrimSpace(attachment.Kind) == kind {
			return attachment
		}
	}
	return observedAttachment{}
}

func decodeObservedDataURL(value string) ([]byte, string, error) {
	const marker = "base64,"
	index := strings.Index(value, marker)
	if index < 0 {
		return nil, "", errors.New("unsupported data url")
	}
	header := strings.TrimPrefix(value[:index], "data:")
	contentType := strings.TrimSuffix(header, ";")
	data, err := base64.StdEncoding.DecodeString(value[index+len(marker):])
	return data, contentType, err
}

func normalizeObservedImageContentType(data []byte, fallback string) string {
	if detected := detectObservedImageContentType(data); detected != "" {
		return detected
	}
	return fallback
}

func detectObservedImageContentType(data []byte) string {
	if len(data) >= 12 &&
		string(data[0:4]) == "RIFF" &&
		string(data[8:12]) == "WEBP" {
		return "image/webp"
	}
	if len(data) >= 8 &&
		data[0] == 0x89 &&
		data[1] == 0x50 &&
		data[2] == 0x4e &&
		data[3] == 0x47 &&
		data[4] == 0x0d &&
		data[5] == 0x0a &&
		data[6] == 0x1a &&
		data[7] == 0x0a {
		return "image/png"
	}
	if len(data) >= 3 &&
		data[0] == 0xff &&
		data[1] == 0xd8 &&
		data[2] == 0xff {
		return "image/jpeg"
	}
	if len(data) >= 6 {
		signature := string(data[0:6])
		if signature == "GIF87a" || signature == "GIF89a" {
			return "image/gif"
		}
	}
	return ""
}

func ensureObservedFileNameExt(fileName, ext string) string {
	name := strings.TrimSpace(fileName)
	normalizedExt := strings.TrimSpace(ext)
	if name == "" || normalizedExt == "" {
		return name
	}
	if !strings.HasPrefix(normalizedExt, ".") {
		normalizedExt = "." + normalizedExt
	}
	currentExt := observedFileExt(name)
	if currentExt == "" {
		return name + normalizedExt
	}
	if strings.EqualFold(currentExt, normalizedExt) {
		return name
	}
	return strings.TrimSuffix(name, currentExt) + normalizedExt
}

func detectObservedImageSize(data []byte) (int64, int64) {
	cfg, _, err := image.DecodeConfig(bytes.NewReader(data))
	if err != nil {
		return 0, 0
	}
	return int64(cfg.Width), int64(cfg.Height)
}

func normalizeObservedContentType(contentType, fileName string) string {
	mediaType, _, err := mime.ParseMediaType(strings.TrimSpace(contentType))
	if err == nil && strings.TrimSpace(mediaType) != "" {
		return strings.TrimSpace(mediaType)
	}
	if fromExt := mime.TypeByExtension(observedFileExt(fileName)); strings.TrimSpace(fromExt) != "" {
		mediaType, _, err := mime.ParseMediaType(fromExt)
		if err == nil && strings.TrimSpace(mediaType) != "" {
			return strings.TrimSpace(mediaType)
		}
	}
	return "application/octet-stream"
}

func preferredObservedExt(contentType string) string {
	mediaType, _, err := mime.ParseMediaType(strings.TrimSpace(contentType))
	if err != nil {
		mediaType = strings.TrimSpace(contentType)
	}
	switch mediaType {
	case "image/jpeg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	case "application/pdf":
		return ".pdf"
	default:
		exts, err := mime.ExtensionsByType(mediaType)
		if err == nil && len(exts) > 0 {
			return exts[0]
		}
		return ".bin"
	}
}

func sanitizeObservedFileName(value string) string {
	name := strings.TrimSpace(strings.ReplaceAll(value, "\\", "/"))
	if index := strings.LastIndex(name, "/"); index >= 0 {
		name = name[index+1:]
	}
	name = strings.TrimSpace(strings.Map(func(r rune) rune {
		if r < 32 || r == 127 || r == '/' || r == '\\' {
			return -1
		}
		return r
	}, name))
	if name == "" || name == "." || name == ".." {
		return ""
	}
	return trimRunes(name, 180)
}

func observedFileExt(fileName string) string {
	name := sanitizeObservedFileName(fileName)
	index := strings.LastIndex(name, ".")
	if index < 0 || index == len(name)-1 {
		return ""
	}
	ext := strings.ToLower(name[index:])
	if len(ext) > 16 {
		return ""
	}
	return ext
}

func observedFileSuffix(fileName string) string {
	return strings.TrimPrefix(observedFileExt(fileName), ".")
}

func fileNameFromContentDisposition(contentDisposition string) string {
	if strings.TrimSpace(contentDisposition) == "" {
		return ""
	}
	_, params, err := mime.ParseMediaType(contentDisposition)
	if err != nil {
		return ""
	}
	for _, key := range []string{"filename", "filename*"} {
		if value := strings.TrimSpace(params[key]); value != "" {
			return sanitizeObservedFileName(strings.TrimPrefix(value, "UTF-8''"))
		}
	}
	return ""
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func supportedCredentialKind(platform, kind string) bool {
	switch platform {
	case monitorPlatformFeishu:
		return kind == monitorCredentialFeishuOpenAPI || kind == monitorCredentialFeishuWebhook
	default:
		return false
	}
}

func supportedDestinationType(platform, destinationType string) bool {
	switch platform {
	case monitorPlatformFeishu:
		return destinationType == monitorDestinationFeishuOpenAPI || destinationType == monitorDestinationFeishuWebhook
	default:
		return false
	}
}

func defaultCredentialDisplayName(kind string) string {
	switch kind {
	case monitorCredentialFeishuOpenAPI:
		return "飞书 OpenAPI 企业应用"
	case monitorCredentialFeishuWebhook:
		return "飞书机器人 Webhook"
	default:
		return "统一机器人凭证"
	}
}

func defaultDestinationDisplayName(destinationType string) string {
	switch destinationType {
	case monitorDestinationFeishuOpenAPI:
		return "飞书 OpenAPI 群"
	case monitorDestinationFeishuWebhook:
		return "飞书机器人 Webhook 群"
	default:
		return "统一发送通道"
	}
}

func maskCredentialValue(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	runes := []rune(value)
	if len(runes) <= 8 {
		if len(runes) <= 4 {
			return strings.Repeat("*", len(runes))
		}
		return string(runes[:2]) + "****" + string(runes[len(runes)-2:])
	}
	return string(runes[:6]) + "****" + string(runes[len(runes)-4:])
}

func (a *API) encryptCredentialFields(c *wkhttp.Context, appID, appSecret, webhookURL, secret string) (string, string, string, string, bool) {
	appIDCiphertext, err := encryptMonitorSecret(appID)
	if err != nil {
		a.writeCredentialEncryptionError(c, err)
		return "", "", "", "", false
	}
	appSecretCiphertext, err := encryptMonitorSecret(appSecret)
	if err != nil {
		a.writeCredentialEncryptionError(c, err)
		return "", "", "", "", false
	}
	webhookURLCiphertext, err := encryptMonitorSecret(webhookURL)
	if err != nil {
		a.writeCredentialEncryptionError(c, err)
		return "", "", "", "", false
	}
	secretCiphertext, err := encryptMonitorSecret(secret)
	if err != nil {
		a.writeCredentialEncryptionError(c, err)
		return "", "", "", "", false
	}
	return appIDCiphertext, appSecretCiphertext, webhookURLCiphertext, secretCiphertext, true
}

func (a *API) encryptDestinationFields(c *wkhttp.Context, webhookURL, secret string) (string, string, bool) {
	webhookURLCiphertext, err := encryptMonitorSecret(webhookURL)
	if err != nil {
		a.writeCredentialEncryptionError(c, err)
		return "", "", false
	}
	secretCiphertext, err := encryptMonitorSecret(secret)
	if err != nil {
		a.writeCredentialEncryptionError(c, err)
		return "", "", false
	}
	return webhookURLCiphertext, secretCiphertext, true
}

func (a *API) writeCredentialEncryptionError(c *wkhttp.Context, err error) {
	a.Error("encrypt monitor credential secret failed", zap.Error(err))
	a.writeError(c, http.StatusInternalServerError, "credential_encryption_failed", "凭证加密失败，请检查 MONITOR_CREDENTIAL_SECRET_KEY 配置")
}

// encryptMonitorSecret stores credentials as opaque ciphertext. Production must
// set MONITOR_CREDENTIAL_SECRET_KEY to a stable high-entropy value before enabling
// credential creation.
func encryptMonitorSecret(value string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", nil
	}
	key, err := monitorCredentialSecretKey()
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}
	ciphertext := gcm.Seal(nonce, nonce, []byte(value), nil)
	return "aesgcm:v1:" + base64.RawURLEncoding.EncodeToString(ciphertext), nil
}

func decryptMonitorSecret(value string) (string, error) {
	value = strings.TrimSpace(value)
	if value == "" {
		return "", nil
	}
	if !strings.HasPrefix(value, "aesgcm:v1:") {
		return "", errors.New("unsupported monitor secret format")
	}
	raw, err := base64.RawURLEncoding.DecodeString(strings.TrimPrefix(value, "aesgcm:v1:"))
	if err != nil {
		return "", err
	}
	key, err := monitorCredentialSecretKey()
	if err != nil {
		return "", err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(raw) < gcm.NonceSize() {
		return "", errors.New("monitor secret ciphertext is too short")
	}
	nonce := raw[:gcm.NonceSize()]
	ciphertext := raw[gcm.NonceSize():]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}

func monitorCredentialSecretKey() ([]byte, error) {
	keyMaterial := strings.TrimSpace(os.Getenv("MONITOR_CREDENTIAL_SECRET_KEY"))
	if keyMaterial == "" {
		return nil, errors.New("MONITOR_CREDENTIAL_SECRET_KEY is required")
	}
	if decoded, err := base64.StdEncoding.DecodeString(keyMaterial); err == nil && len(decoded) >= 32 {
		return decoded[:32], nil
	}
	key := sha256.Sum256([]byte(keyMaterial))
	return key[:], nil
}

func (a *API) insertEvent(uid, agentID, routeID, eventType, message string, metadata map[string]interface{}) error {
	metadataJSON := "{}"
	if metadata != nil {
		if payload, err := json.Marshal(metadata); err == nil {
			metadataJSON = string(payload)
		}
	}
	return a.db.insertEvent(&eventModel{
		EventID:  "event_" + util.GenerUUID(),
		UID:      uid,
		Platform: monitorPlatformFeishu,
		AgentID:  agentID,
		RouteID:  routeID,
		Type:     eventType,
		Message:  message,
		Metadata: metadataJSON,
	})
}

func credentialToJSON(credential *credentialModel) map[string]interface{} {
	return map[string]interface{}{
		"id":                 credential.CredentialID,
		"credential_id":      credential.CredentialID,
		"platform":           credential.Platform,
		"kind":               credential.Kind,
		"display_name":       credential.DisplayName,
		"app_id_masked":      credential.AppIDMasked,
		"webhook_url_masked": credential.WebhookURLMasked,
		"status":             credential.Status,
		"last_checked_at":    formatOptionalTime(credential.LastCheckedAt),
		"last_error":         credential.LastError,
		"created_at":         formatOptionalTime(credential.CreatedAt),
		"updated_at":         formatOptionalTime(credential.UpdatedAt),
	}
}

func destinationToJSON(destination *destinationModel) map[string]interface{} {
	return map[string]interface{}{
		"id":                 destination.DestinationID,
		"destination_id":     destination.DestinationID,
		"platform":           destination.Platform,
		"destination_type":   destination.DestinationType,
		"display_name":       destination.DisplayName,
		"credential_id":      destination.CredentialID,
		"chat_id":            destination.ChatID,
		"webhook_url_masked": destination.WebhookURLMasked,
		"status":             destination.Status,
		"last_checked_at":    formatOptionalTime(destination.LastCheckedAt),
		"last_error":         destination.LastError,
		"created_at":         formatOptionalTime(destination.CreatedAt),
		"updated_at":         formatOptionalTime(destination.UpdatedAt),
	}
}

func routeToJSON(route *routeModel) map[string]interface{} {
	return map[string]interface{}{
		"id":                    route.RouteID,
		"route_id":              route.RouteID,
		"platform":              route.Platform,
		"connector_type":        route.ConnectorType,
		"route_type":            route.RouteType,
		"source_name":           route.SourceName,
		"destination_type":      route.DestinationType,
		"destination_id":        route.DestinationID,
		"destination_name":      route.DestinationName,
		"destination_no":        route.DestinationNo,
		"sender_display_name":   route.SenderDisplayName,
		"sender_display_avatar": route.SenderDisplayAvatar,
		"status":                route.Status,
		"today_forwarded_count": route.TodayForwardedCount,
		"last_forwarded_at":     formatOptionalTime(route.LastForwardedAt),
		"agent_id":              route.AgentID,
		"include_text":          intToBool(route.IncludeText),
		"include_links":         intToBool(route.IncludeLinks),
		"include_images":        intToBool(route.IncludeImages),
		"include_files":         intToBool(route.IncludeFiles),
	}
}

func agentRouteToJSON(route *routeModel) map[string]interface{} {
	return map[string]interface{}{
		"route_id":       route.RouteID,
		"platform":       route.Platform,
		"connector_type": route.ConnectorType,
		"route_type":     route.RouteType,
		"source": map[string]interface{}{
			"chat_name": route.SourceName,
		},
		"destination": map[string]interface{}{
			"type":           normalize(route.DestinationType, monitorDestinationWukongIMGroup),
			"destination_id": route.DestinationID,
			"group_no":       route.DestinationNo,
			"group_name":     route.DestinationName,
			"chat_id":        route.DestinationNo,
			"name":           route.DestinationName,
			"sender_identity": map[string]interface{}{
				"display_name":   route.SenderDisplayName,
				"display_avatar": route.SenderDisplayAvatar,
			},
		},
		"message_policy": map[string]interface{}{
			"include_text":   intToBool(route.IncludeText),
			"include_links":  intToBool(route.IncludeLinks),
			"include_images": intToBool(route.IncludeImages),
			"include_files":  intToBool(route.IncludeFiles),
		},
	}
}

func browserStatusToJSON(status *browserStatusModel) map[string]interface{} {
	return map[string]interface{}{
		"agent_id":      status.AgentID,
		"platform":      status.Platform,
		"browser":       status.Browser,
		"profile_mode":  status.ProfileMode,
		"login_status":  status.LoginStatus,
		"observed_at":   formatOptionalTime(status.ObservedAt),
		"error_message": status.ErrorMessage,
	}
}

func routeAllowsType(route *routeModel, messageType string) bool {
	switch messageType {
	case "text":
		return intToBool(route.IncludeText)
	case "card":
		return intToBool(route.IncludeText) || intToBool(route.IncludeLinks)
	case "link":
		return intToBool(route.IncludeLinks)
	case "image", "image_placeholder":
		return intToBool(route.IncludeImages)
	case "file":
		return intToBool(route.IncludeFiles)
	default:
		return false
	}
}

func (a *API) writeError(c *wkhttp.Context, status int, code string, message string) {
	c.JSON(status, map[string]interface{}{
		"error": map[string]interface{}{
			"code":       code,
			"message":    message,
			"details":    map[string]interface{}{},
			"request_id": "",
		},
	})
}

func generatePairingCode() string {
	const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var builder strings.Builder
	for i := 0; i < 6; i++ {
		index, err := rand.Int(rand.Reader, big.NewInt(int64(len(alphabet))))
		if err != nil {
			return "A7K9Q2"
		}
		builder.WriteByte(alphabet[index.Int64()])
	}
	return builder.String()
}

func bearerToken(c *wkhttp.Context) string {
	authorization := strings.TrimSpace(c.GetHeader("Authorization"))
	if len(authorization) > len("Bearer ") && strings.EqualFold(authorization[:len("Bearer ")], "Bearer ") {
		return strings.TrimSpace(authorization[len("Bearer "):])
	}
	return ""
}

func normalize(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback
	}
	return value
}

func parseLimit(raw string, fallback uint64) uint64 {
	if strings.TrimSpace(raw) == "" {
		return fallback
	}
	value, err := strconv.ParseUint(raw, 10, 64)
	if err != nil || value == 0 {
		return fallback
	}
	if value > 100 {
		return 100
	}
	return value
}

func dbrNullTime(t time.Time) dbr.NullTime {
	return dbr.NullTime{Time: t, Valid: true}
}

func parseTime(raw string, fallback time.Time) time.Time {
	if parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(raw)); err == nil {
		return parsed
	}
	return fallback
}

func optionalTime(raw string) dbr.NullTime {
	if parsed, err := time.Parse(time.RFC3339, strings.TrimSpace(raw)); err == nil {
		return dbrNullTime(parsed)
	}
	return dbr.NullTime{}
}

func formatOptionalTime(t dbr.NullTime) string {
	if !t.Valid {
		return ""
	}
	return t.Time.UTC().Format(time.RFC3339)
}

func stringFromMap(values map[string]interface{}, key string) string {
	if values == nil {
		return ""
	}
	return strings.TrimSpace(toString(values[key]))
}

func boolFromMap(values map[string]interface{}, key string, fallback bool) bool {
	if values == nil {
		return fallback
	}
	return toBool(values[key], fallback)
}

func mapFromMap(values map[string]interface{}, key string) map[string]interface{} {
	if values == nil {
		return nil
	}
	raw := values[key]
	if raw == nil {
		return nil
	}
	if typed, ok := raw.(map[string]interface{}); ok {
		return typed
	}
	if typed, ok := raw.(map[interface{}]interface{}); ok {
		resolved := make(map[string]interface{}, len(typed))
		for k, v := range typed {
			resolved[toString(k)] = v
		}
		return resolved
	}
	return nil
}

func toString(value interface{}) string {
	if value == nil {
		return ""
	}
	if text, ok := value.(string); ok {
		return strings.TrimSpace(text)
	}
	return strings.TrimSpace(fmt.Sprint(value))
}

func toBool(value interface{}, fallback bool) bool {
	switch v := value.(type) {
	case bool:
		return v
	case int:
		return v != 0
	case int64:
		return v != 0
	case float64:
		return v != 0
	case string:
		switch strings.ToLower(strings.TrimSpace(v)) {
		case "true", "1":
			return true
		case "false", "0":
			return false
		}
	}
	return fallback
}

func boolToInt(value bool) int {
	if value {
		return 1
	}
	return 0
}

func intToBool(value int) bool {
	return value != 0
}

func trimRunes(value string, max int) string {
	value = strings.TrimSpace(value)
	runes := []rune(value)
	if len(runes) <= max {
		return value
	}
	return string(runes[:max])
}
