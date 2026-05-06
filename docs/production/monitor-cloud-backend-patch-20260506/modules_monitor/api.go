package monitor

import (
	"crypto/rand"
	"encoding/json"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/config"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/log"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/util"
	"github.com/TangSengDaoDao/TangSengDaoDaoServerLib/pkg/wkhttp"
	"github.com/gocraft/dbr/v2"
	"go.uber.org/zap"
)

const (
	heartbeatIntervalSeconds = 20
	pairingCodeTTL           = 10 * time.Minute
	onlineThreshold          = 60 * time.Second
	monitorPlatformFeishu    = "feishu"
	agentPlatformWindows     = "windows"
)

type API struct {
	ctx *config.Context
	log.Log
	db  *DB
	now func() time.Time
}

func NewAPI(ctx *config.Context) *API {
	return &API{
		ctx: ctx,
		Log: log.NewTLog("Monitor"),
		db:  NewDB(ctx),
		now: time.Now,
	}
}

func (a *API) Route(r *wkhttp.WKHttp) {
	auth := r.Group("/v1/monitor", a.ctx.AuthMiddleware(r))
	auth.POST("/agent-pairing-codes", a.createPairingCode)
	auth.GET("/agents", a.listAgents)
	auth.GET("/events", a.listEvents)
	auth.GET("/platforms/feishu/stats", a.feishuStats)
	auth.GET("/routes", a.listRoutes)

	agent := r.Group("/v1/monitor")
	agent.POST("/agents/pair", a.pairAgent)
	agent.POST("/agents/heartbeat", a.agentHeartbeat)
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
	if err := a.insertEvent(pairingCode.UID, agentID, "agent_paired", "Windows Agent "+deviceName+" 已绑定", map[string]interface{}{"platform": platform}); err != nil {
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
	token := bearerToken(c)
	if token == "" {
		a.writeError(c, http.StatusUnauthorized, "invalid_agent_token", "Agent token 无效")
		return
	}
	agent, err := a.db.queryAgentByToken(token)
	if err != nil {
		a.Error("query monitor agent token failed", zap.Error(err))
		a.writeError(c, http.StatusInternalServerError, "agent_token_query_failed", "查询 Agent 失败")
		return
	}
	if agent == nil {
		a.writeError(c, http.StatusUnauthorized, "invalid_agent_token", "Agent token 无效")
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
	if err := a.db.updateAgentHeartbeat(agent.AgentID, token, deviceName, version, now); err != nil {
		a.Error("update monitor agent heartbeat failed", zap.Error(err), zap.String("agent_id", agent.AgentID))
		a.writeError(c, http.StatusInternalServerError, "heartbeat_update_failed", "更新 Agent 心跳失败")
		return
	}
	if !wasOnline {
		_ = a.insertEvent(agent.UID, agent.AgentID, "agent_online", "Windows Agent "+deviceName+" 已在线", map[string]interface{}{"platform": platform})
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
	c.Response(map[string]interface{}{
		"data": map[string]interface{}{
			"running_routes":  0,
			"today_forwarded": 0,
			"alerts":          0,
		},
	})
}

func (a *API) listRoutes(c *wkhttp.Context) {
	c.Response(map[string]interface{}{
		"data": []interface{}{},
		"page": map[string]interface{}{"next_cursor": nil},
	})
}

func (a *API) insertEvent(uid, agentID, eventType, message string, metadata map[string]interface{}) error {
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
		RouteID:  "",
		Type:     eventType,
		Message:  message,
		Metadata: metadataJSON,
	})
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
