package monitor

import (
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/common"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/log"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/gocraft/dbr/v2"
	"go.uber.org/zap"
)

const (
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
)

type API struct {
	ctx *config.Context
	log.Log
	db             *DB
	now            func() time.Time
	forwardMessage func(route *routeModel, message *observedMessageModel) error
}

func NewAPI(ctx *config.Context) *API {
	api := &API{
		ctx: ctx,
		Log: log.NewTLog("Monitor"),
		db:  NewDB(ctx),
		now: time.Now,
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

	agentID := "agent_" + util.GenerUUID()
	agentToken := "monitor_agent_" + util.GenerUUID()
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
		a.writeError(c, http.StatusInternalServerError, "agent_create_failed", "创建 Agent 失败")
		return
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
	if platform != monitorPlatformFeishu || connectorType != monitorConnectorFeishuWebGroup || routeType != monitorRouteFeishuWebToWukongIM {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_route_type", "暂不支持该监控规则类型")
		return
	}
	sourceName := stringFromMap(req.Source, "chat_name")
	destinationNo := stringFromMap(req.Destination, "group_no")
	destinationName := stringFromMap(req.Destination, "group_name")
	destinationType := normalize(stringFromMap(req.Destination, "type"), monitorDestinationWukongIMGroup)
	if sourceName == "" || destinationNo == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_route_request", "飞书群名称和悟空 IM 群不能为空")
		return
	}
	if destinationType != monitorDestinationWukongIMGroup {
		a.writeError(c, http.StatusUnprocessableEntity, "unsupported_destination_type", "暂不支持该目标类型")
		return
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
		RouteID:         "route_" + util.GenerUUID(),
		UID:             uid,
		Platform:        platform,
		ConnectorType:   connectorType,
		RouteType:       routeType,
		SourceName:      sourceName,
		DestinationName: normalize(destinationName, destinationNo),
		DestinationNo:   destinationNo,
		AgentID:         agentID,
		Status:          "running",
		IncludeText:     boolToInt(boolFromMap(req.MessagePolicy, "include_text", true)),
		IncludeLinks:    boolToInt(boolFromMap(req.MessagePolicy, "include_links", true)),
		IncludeImages:   boolToInt(boolFromMap(req.MessagePolicy, "include_images", false)),
		IncludeFiles:    boolToInt(boolFromMap(req.MessagePolicy, "include_files", false)),
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
		SourceCreatedAt: optionalTime(req.SourceCreatedAt),
		ObservedAt:      dbrNullTime(observedAt),
		ForwardStatus:   "pending",
	}
	if message.Content == "" {
		a.writeError(c, http.StatusBadRequest, "invalid_observed_message_request", "消息内容不能为空")
		return
	}
	if err := a.db.insertObservedMessage(message); err != nil {
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
	if route.DestinationNo == "" {
		return errors.New("destination group is empty")
	}
	payload, err := json.Marshal(map[string]interface{}{
		"type":    common.Text,
		"content": message.Content,
		"source":  "feishu_monitor",
	})
	if err != nil {
		return err
	}
	return a.ctx.SendMessage(&config.MsgSendReq{
		Header: config.MsgHeader{
			NoPersist: 0,
			RedDot:    1,
			SyncOnce:  0,
		},
		FromUID:     message.UID,
		ChannelID:   route.DestinationNo,
		ChannelType: common.ChannelTypeGroup.Uint8(),
		Payload:     payload,
	})
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

func routeToJSON(route *routeModel) map[string]interface{} {
	return map[string]interface{}{
		"id":                    route.RouteID,
		"route_id":              route.RouteID,
		"platform":              route.Platform,
		"connector_type":        route.ConnectorType,
		"route_type":            route.RouteType,
		"source_name":           route.SourceName,
		"destination_name":      route.DestinationName,
		"destination_no":        route.DestinationNo,
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
			"type":       monitorDestinationWukongIMGroup,
			"group_no":   route.DestinationNo,
			"group_name": route.DestinationName,
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
